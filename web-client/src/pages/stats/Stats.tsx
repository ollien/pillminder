import {
	CardBody,
	CardHeader,
	Center,
	Heading,
	HStack,
	StackDivider,
} from "@chakra-ui/react";
import {
	getStatsSummary,
	getTakenDates,
} from "pillminder-webclient/src/lib/api";
import CardPage from "pillminder-webclient/src/pages/_common/CardPage";
import ErrorText from "pillminder-webclient/src/pages/_common/ErrorText";
import History from "pillminder-webclient/src/pages/stats/History";
import Loadable from "pillminder-webclient/src/pages/stats/Loadable";
import Summary from "pillminder-webclient/src/pages/stats/Summary";
import React, { useCallback, useEffect, useState } from "react";

const NO_PILLMINDER_ERROR = "No pillminder selected";
const INVALID_TOKEN_ERROR = "Your session has expired. Please log in again";

interface StatsProps {
	pillminder?: string;
	token?: string;
}

const makeErrorString = (err: Error | unknown): string => {
	if (err instanceof Error && err.cause != null) {
		return `${err.message}: ${makeErrorString(err.cause)}`;
	} else if (err instanceof Error) {
		return err.message;
	} else {
		return `${err}`;
	}
};

const makeEmptyPillminderError = (pillminder: string | undefined) => {
	if (pillminder == null) {
		return NO_PILLMINDER_ERROR;
	}

	return null;
};

const makeConsolidatedFetchError = (
	...fetchErrors: (string | undefined)[]
): string | null => {
	if (
		fetchErrors.length == 0 ||
		!fetchErrors.every((item) => item === fetchErrors[0] && item != null)
	) {
		// Either the messages can't be conslidated, or there are no errors, which is fine. We just won't use them.
		return null;
	}

	// We know that this can't be null from the `every` above.
	return fetchErrors[0]!;
};

const makeErrorComponentMessage = (
	pillminder: string | undefined,
	...fetchErrors: (string | undefined)[]
): string | null => {
	const emptyPillminderError = makeEmptyPillminderError(pillminder);
	if (emptyPillminderError) {
		return emptyPillminderError;
	}

	const consolidatedFetchError = makeConsolidatedFetchError(...fetchErrors);
	if (consolidatedFetchError) {
		// We know from the `every` that this must be non-null.
		return consolidatedFetchError;
	}

	return null;
};

const makeErrorComponent = (
	pillminder: string | undefined,
	...fetchErrors: (string | undefined)[]
): JSX.Element | null => {
	const errorMsg = makeErrorComponentMessage(pillminder, ...fetchErrors);
	if (errorMsg == null) {
		return null;
	}

	return StatsError(errorMsg);
};

const getHeadingMsg = (pillminder: string | undefined) => {
	if (pillminder == null) {
		return "Stats";
	} else {
		return `Stats for ${pillminder}`;
	}
};

const useAPI = <T,>(doFetch: () => Promise<T>): [T?, string?] => {
	const [data, setData] = useState<T | undefined>(undefined);
	const [error, setError] = useState<string | undefined>(undefined);

	useEffect(() => {
		doFetch()
			.then(setData)
			.catch((err) => {
				const msg = makeErrorString(err);
				setError(msg);
			});
	}, [doFetch]);

	return [data, error];
};

const StatsError = (msg: string) => {
	return (
		<Center>
			<ErrorText>{msg}</ErrorText>
		</Center>
	);
};

const Stats = ({ pillminder, token }: StatsProps) => {
	const summaryCallback = useCallback(async () => {
		if (pillminder == null) {
			throw Error(NO_PILLMINDER_ERROR);
		} else if (token == null) {
			throw Error(INVALID_TOKEN_ERROR);
		}

		try {
			return getStatsSummary(token, pillminder);
		} catch (err) {
			throw new Error("Failed to fetch summary", {
				cause: makeErrorString(err),
			});
		}
	}, [pillminder, token]);
	const [statsSummary, statsSummaryError] = useAPI(summaryCallback);

	const takenDatesCallback = useCallback(async () => {
		if (pillminder == null) {
			throw Error(NO_PILLMINDER_ERROR);
		} else if (token == null) {
			throw Error(INVALID_TOKEN_ERROR);
		}

		try {
			return getTakenDates(token, pillminder);
		} catch (err) {
			throw new Error("Failed to fetch taken dates", {
				cause: makeErrorString(err),
			});
		}
	}, [pillminder, token]);
	const [takenDates, takenDatesError] = useAPI(takenDatesCallback);

	const statsBody = (
		<HStack
			divider={<StackDivider />}
			justifyContent="space-evenly"
			alignItems="stretch"
			height="100%"
		>
			<Loadable
				isLoading={statsSummary == null && statsSummaryError == null}
				error={statsSummaryError}
			>
				<Summary statsSummary={statsSummary!} />
			</Loadable>
			<Loadable
				isLoading={takenDates == null && takenDatesError == null}
				error={takenDatesError}
			>
				<History takenDates={takenDates!} />
			</Loadable>
		</HStack>
	);

	const errorComponent = makeErrorComponent(
		pillminder,
		statsSummaryError,
		takenDatesError
	);

	return (
		<CardPage maxWidth="container.md">
			<CardHeader>
				<Heading size={{ base: "lg", lg: "md" }}>
					{getHeadingMsg(pillminder)}
				</Heading>
			</CardHeader>
			<CardBody width="100%">{errorComponent ?? statsBody}</CardBody>
		</CardPage>
	);
};

export default Stats;
