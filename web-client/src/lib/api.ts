import axios, {
	AxiosInstance,
	AxiosError,
	AxiosResponse,
	AxiosRequestConfig,
} from "axios";
// There is no type declaration for this module, and I still want TS to compile here
// eslint-disable-next-line @typescript-eslint/ban-ts-comment
// @ts-ignore
import contentTypeParser from "content-type-parser";
import joi from "joi";
import { DateTime } from "luxon";

const INVALID_TOKEN_ERROR =
	"Your session has expired, or this pillminder no longer exists. Please log in again";

/**
 * A summary of statistics about a user's medication
 */
export interface StatsSummary {
	streakLength: number;
	lastTaken: DateTime | null;
}

/**
 * A summary of statistics about a user's medication
 */
export interface TakenDate {
	date: DateTime;
	taken: boolean;
}

export interface TokenInformation {
	token: string;
	pillminder: string;
}

export class APIError extends Error {
	private retryability?: APIError.Retryability;
	// Technically speaking this is on the superclass, but to make typing easier
	// during reconstruction, we store it here, too.
	private errorCause?: Error;

	constructor(
		msg: string,
		retryability: APIError.Retryability = APIError.Retryability.CANNOT_RETRY,
		cause?: Error | unknown
	) {
		super(msg, { cause: cause });
		this.cause = cause;
		this.retryability = retryability;
	}

	withMessage(msg: string): APIError {
		return new APIError(msg, this.retryability, this.errorCause);
	}

	canRetry(): boolean {
		return this.retryability == APIError.Retryability.CAN_RETRY;
	}

	response(): AxiosResponse | null {
		if (this.cause instanceof AxiosError) {
			return this.cause.response ?? null;
		} else {
			return null;
		}
	}
}

export namespace APIError {
	export enum Retryability {
		CANNOT_RETRY = 0,
		CAN_RETRY = 1,
	}
}

class BadResponseFormatError extends APIError {
	constructor(private malformedResponse: AxiosResponse) {
		super("Malformed response");
	}

	response(): AxiosResponse {
		return this.malformedResponse;
	}
}

enum WasTaken {
	NOT_TAKEN,
	TAKEN,
}

export class APIClient {
	private static readonly FALLBACK_ERROR = "Failed to perform action";

	private unauthenticatedClient: AxiosInstance;
	private authenticatedClient?: AxiosInstance;

	/**
	 * Construct a new APIClient
	 * @param token The session token, if available. If not provided, no authenticated requests will be possible.
	 */
	constructor(token?: string) {
		this.unauthenticatedClient = this.makeHttpClient();
		if (token) {
			this.authenticatedClient = this.makeAuthenticatedHTTPClient(token);
		}
	}

	/**
	 * Request an access code for the given pillminder. This will be sent to a user, and not returned to us.
	 *
	 * @param pillminder The pillminder to request an access code for
	 * @returns A promise that will resolve when the access code has been sent. If the promise has not resolved,
	 *          nothing can be assumed.
	 */
	async requestAccessCode(pillminder: string): Promise<void> {
		await this.unauthenticatedClient
			.post("/api/v1/auth/access-code", {
				pillminder,
			})
			.catch((error) => {
				throw this.refineErrorMessage(
					error,
					{ 400: "Invalid pillminder" },
					"Failed to request access code"
				);
			});
	}

	/**
	 * Convert the given access code to a session token
	 *
	 * @param accessCode The access code to exchange
	 * @returns Information about the token.
	 */
	async exchangeAccessCode(accessCode: string): Promise<TokenInformation> {
		const schema = joi.object({
			token: joi.string(),
			pillminder: joi.string(),
		});

		const res = await this.unauthenticatedClient
			.post("/api/v1/auth/token", {
				access_code: accessCode,
			})
			.catch((error) => {
				throw this.refineErrorMessage(
					error,
					{ 400: "Invalid access code" },
					"Failed to validate access code"
				);
			});

		const jsonBody = res.data;
		this.assertValidResponse(jsonBody, schema);

		return jsonBody;
	}

	/**
	 * Get statistics about the given pillminder
	 * @param token The token for this session
	 * @param pillminder The pillminder to get a summary for
	 * @returns A summary of the given pillminder. Note that if a pillminder is not found, empty information
	 *          will be returned.
	 */
	async getStatsSummary(pillminder: string) {
		if (!this.authenticatedClient) {
			// We have no token, so we have an invalid token
			throw new APIError(INVALID_TOKEN_ERROR);
		}

		const schema = joi.object({
			streak_length: joi.number(),
			last_taken_on: joi.string().allow(null),
		});

		const res = await this.authenticatedClient
			.get(`/api/v1/stats/${encodeURIComponent(pillminder)}/summary`)
			.catch((error) => {
				throw this.refineErrorMessage(
					error,
					{ 404: INVALID_TOKEN_ERROR },
					"Failed to load streak"
				);
			});

		const resBody = await res.data;
		this.assertValidResponse(resBody, schema);

		return {
			streakLength: resBody.streak_length,
			lastTaken: this.parseDate(resBody.last_taken_on),
		};
	}

	/**
	 * Get the recent dates that the medication was taken
	 * @param pillminder The pillminder to get history for
	 * @returns Recent dates that the medication were taken. These will be consecutive.
	 */
	async getTakenDates(pillminder: string): Promise<TakenDate[]> {
		if (!this.authenticatedClient) {
			// We have no token, so we have an invalid token
			throw new APIError(INVALID_TOKEN_ERROR);
		}

		const schema = joi.object({
			taken_dates: joi
				.array()
				.items(joi.object({ date: joi.string(), taken: joi.boolean() })),
		});

		const res = await this.authenticatedClient
			.get(`/api/v1/stats/${encodeURIComponent(pillminder)}/history`)
			.catch((error) => {
				throw this.refineErrorMessage(
					error,
					{ 404: INVALID_TOKEN_ERROR },
					"Failed to load taken dates"
				);
			});

		const resBody = await res.data;
		this.assertValidResponse(resBody, schema);

		const sentTakenDates: { date: string; taken: boolean }[] =
			resBody.taken_dates;

		return sentTakenDates.map(({ date: rawDate, taken }) => ({
			taken,
			date: this.parseDate(rawDate),
		}));
	}

	async markTodayAsTaken(pillminder: string): Promise<void> {
		await this.deleteTimer(pillminder, WasTaken.TAKEN);
	}

	async skipToday(pillminder: string): Promise<void> {
		await this.deleteTimer(pillminder, WasTaken.NOT_TAKEN);
	}

	private makeAuthenticatedHTTPClient(token: string): AxiosInstance {
		return this.makeHttpClient({
			headers: {
				Authorization: `Token ${token}`,
			},
		});
	}

	private makeHttpClient(extraConfig?: AxiosRequestConfig): AxiosInstance {
		const client = axios.create({
			// If we use `transformResponse` to map from `body` to itself, we can handle the JSON parsing manually
			// in our interceptor
			transformResponse: (body) => body,
			...extraConfig,
		});

		client.interceptors.response.use(
			(res) => this.ensureResponseIsJSON(res),
			(err) => this.remapToAPIError(err)
		);

		return client;
	}

	private ensureResponseIsJSON(response: AxiosResponse) {
		const contentType = response.headers?.["content-type"];
		if (contentType && !this.isJSONContentType(contentType)) {
			throw new BadResponseFormatError(response);
		}

		try {
			response.data = JSON.parse(response.data);
			return response;
		} catch {
			const cause = new BadResponseFormatError(response);
			throw new APIError(
				APIClient.FALLBACK_ERROR,
				APIError.Retryability.CANNOT_RETRY,
				cause
			);
		}
	}

	private isJSONContentType(contentType: string) {
		const parsedContentType = contentTypeParser(contentType);
		const type = parsedContentType.type as string;
		const subtype = parsedContentType.subtype as string;

		return type == "application" && subtype == "json";
	}

	private remapToAPIError(error: AxiosError | APIError | unknown) {
		if (error instanceof APIError) {
			throw error;
		} else if (!(error instanceof AxiosError)) {
			throw new APIError(
				APIClient.FALLBACK_ERROR,
				APIError.Retryability.CANNOT_RETRY,
				error
			);
		}

		if (error.response) {
			error.response = this.ensureResponseIsJSON(error.response);
		}

		if (
			error.response &&
			error.response?.status >= 400 &&
			error.response?.status < 500
		) {
			const msg = this.getErrorMessageFromResponse(error.response);
			throw new APIError(msg, APIError.Retryability.CANNOT_RETRY, error);
		} else if (error.response) {
			const msg = this.getErrorMessageFromResponse(error.response);
			throw new APIError(msg, APIError.Retryability.CAN_RETRY, error);
		} else if (error.request) {
			throw new APIError(
				APIClient.FALLBACK_ERROR,
				APIError.Retryability.CANNOT_RETRY,
				error
			);
		} else {
			throw error;
		}
	}

	private getErrorMessageFromResponse(response: AxiosResponse) {
		return response.data?.error ?? APIClient.FALLBACK_ERROR;
	}

	private refineErrorMessage(
		error: APIError,
		codes: Record<number, string>,
		fallback: string
	): APIError;

	private refineErrorMessage(
		error: unknown,
		codes: Record<number, string>,
		fallback: string
	): unknown;

	/**
	 * Refine the given error based on HTTP status code and response body. If a status code matches the
	 * code map given, that error will be used. If not, and there is an in the body, that is used.
	 * Otherwise, the fallback message is used.
	 *
	 * @param error The error to refine. If this is not an APIError, or no response is set, this error will
	 * 				be returned unmodified.
	 * @param codes The status codes to map to error strings.
	 * @param fallback The default error message to use if the status code is not in the codes map, and no
	 * 				   error is defined on the body.
	 * @returns If not an APIError (or there is no response), the error is returned unmodified. If there
	 * 			is an error in the response or the status code map/fallback produces a new error message,
	 * 			a new APIError is generated.
	 */
	private refineErrorMessage(
		error: APIError | unknown,
		codes: Record<number, string>,
		fallback: string = APIClient.FALLBACK_ERROR
	): APIError | unknown {
		if (!(error instanceof APIError)) {
			return error;
		}

		const response = error.response();
		if (response == null) {
			return error;
		}

		const responseErrorMessage = response.data?.error;
		const statusCode = response.status;

		const msg = codes[statusCode] ?? responseErrorMessage ?? fallback;
		throw error.withMessage(msg);
	}

	private async deleteTimer(pillminder: string, taken: WasTaken) {
		if (!this.authenticatedClient) {
			// We have no token, so we have an invalid token
			throw new APIError(INVALID_TOKEN_ERROR);
		}

		await this.authenticatedClient
			.delete(`/api/v1/timer/${encodeURIComponent(pillminder)}`, {
				params: { taken: taken == WasTaken.TAKEN },
			})
			.catch((error) => {
				throw this.refineErrorMessage(
					error,
					{ 404: INVALID_TOKEN_ERROR },
					"Failed to mark as taken"
				);
			});
	}

	private parseDate(date: null): null;
	private parseDate(date: string): DateTime;
	private parseDate(date: string | null): DateTime | null {
		if (date == null) {
			return null;
		}

		const parsed = DateTime.fromISO(date);
		if (!parsed.isValid) {
			throw Error(`Invalid date returned from server (${date})`);
		}

		return parsed;
	}

	private assertValidResponse(data: unknown, schema: joi.Schema) {
		const validationResult = schema.validate(data);
		if (validationResult.error) {
			throw new Error("Invalid data from server");
		}
	}
}
