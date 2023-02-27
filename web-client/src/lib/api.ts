import joi from "joi";
import { DateTime } from "luxon";

const INVALID_TOKEN_ERROR = "Your session has expired. Please log in again";

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

/**
 * Request an access code for the given pillminder. This will be sent to a user, and not returned to us.
 *
 * @param pillminder The pillminder to request an access code for
 * @returns A promise that will resolve when the access code has been sent. If the promise has not resolved,
 *          nothing can be assumed.
 */
export async function requestAccessCode(pillminder: string): Promise<void> {
	const res = await fetch("/api/v1/auth/access-code", {
		method: "POST",
		body: JSON.stringify({ pillminder }),
		headers: {
			"Content-Type": "application/json",
		},
	});

	const getErrorMsg = async () => {
		try {
			const resJSON = await res.json();
			return resJSON.error ?? "Failed to request token";
		} catch (e) {
			return "Failed to request token";
		}
	};

	if (res.status >= 400) {
		const msg = await getErrorMsg();
		throw new Error(msg);
	}
}

/**
 * Convert the given access code to a sessino token
 *
 * @param accessCode The access code to exchange
 * @returns Information about the token.
 */
export async function exchangeAccessCode(
	accessCode: string
): Promise<TokenInformation> {
	const schema = joi.object({
		token: joi.string(),
		pillminder: joi.string(),
	});

	const res = await fetch("/api/v1/auth/token", {
		method: "POST",
		body: JSON.stringify({ access_code: accessCode }),
		headers: {
			"Content-Type": "application/json",
		},
	});

	if (res.status === 400) {
		throw new Error("Invalid access code");
	} else if (res.status > 400) {
		throw new Error("Failed to validate access code");
	}

	const jsonRes = res.json();
	assertValidResponse(jsonRes, schema);

	return jsonRes;
}

/**
 * Get statistics about the given pillminder
 * @param token The token for this session
 * @param pillminder The pillminder to get a summary for
 * @returns A summary of the given pillminder. Note that if a pillminder is not found, empty information
 *          will be returned.
 */
export async function getStatsSummary(
	token: string,
	pillminder: string
): Promise<StatsSummary> {
	const schema = joi.object({
		streak_length: joi.number(),
		last_taken_on: joi.string(),
	});

	const res = await fetch(
		`/api/v1/stats/${encodeURIComponent(pillminder)}/summary`,
		{
			headers: { Authorization: `Token ${token}` },
		}
	);

	if (res.status === 401) {
		throw new Error(INVALID_TOKEN_ERROR);
	} else if (res.status >= 400) {
		// This api doesn't return any real errors, so we can just give a generic message
		throw new Error("Failed to load streak");
	}

	const resJson = await res.json();
	assertValidResponse(resJson, schema);

	return {
		streakLength: resJson.streak_length,
		lastTaken: parseDate(resJson.last_taken_on),
	};
}

/**
 * Get the recent dates that the medication was taken
 * @param token The token for this session
 * @param pillminder The pillminder to get history for
 * @returns Recent dates that the medication were taken. These will be consecutive.
 */
export async function getTakenDates(
	token: string,
	pillminder: string
): Promise<TakenDate[]> {
	const schema = joi.object({
		taken_dates: joi
			.array()
			.items(joi.object({ date: joi.string(), taken: joi.boolean() })),
	});

	const res = await fetch(
		`/api/v1/stats/${encodeURIComponent(pillminder)}/history`,
		{
			headers: { Authorization: `Token ${token}` },
		}
	);

	if (res.status === 401) {
		throw new Error(INVALID_TOKEN_ERROR);
	} else if (res.status >= 400) {
		throw new Error("Failed to load taken dates");
	}

	const resJson = await res.json();
	assertValidResponse(resJson, schema);

	const sentTakenDates: { date: string; taken: boolean }[] =
		resJson.taken_dates;

	return sentTakenDates.map(({ date: rawDate, taken }) => ({
		taken,
		date: parseDate(rawDate),
	}));
}

function parseDate(date: null): null;
function parseDate(date: string): DateTime;
function parseDate(date: string | null): DateTime | null {
	if (date == null) {
		return null;
	}

	const parsed = DateTime.fromISO(date);
	if (!parsed.isValid) {
		throw Error(`Invalid date returned from server (${date})`);
	}

	return parsed;
}

function assertValidResponse(data: unknown, schema: joi.Schema) {
	const validationResult = schema.validate(data);
	if (validationResult.error) {
		throw new Error("Invalid data from server");
	}
}
