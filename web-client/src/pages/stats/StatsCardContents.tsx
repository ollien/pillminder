import { HStack, StackDivider } from "@chakra-ui/react";
import { APIClient } from "pillminder-webclient/src/lib/api";
import CardError from "pillminder-webclient/src/pages/_common/CardError";
import { makeErrorString } from "pillminder-webclient/src/pages/_common/errors";
import History from "pillminder-webclient/src/pages/stats/History";
import Loadable from "pillminder-webclient/src/pages/stats/Loadable";
import Summary from "pillminder-webclient/src/pages/stats/Summary";
import React from "react";
import { useQuery, UseQueryResult } from "react-query";

interface StatsCardBodyProps {
	pillminder: string;
	token: string;
}

const makeQueryError = <T, E>(
	query: UseQueryResult<T, E>,
	prefix?: string
): string | null => {
	if (!query.isError) {
		return null;
	}

	const errString = makeErrorString(query.error);
	if (prefix) {
		return `${prefix}: ` + errString;
	} else {
		return errString;
	}
};

const makeConsolidatedFetchError = (
	...fetchErrors: (string | null)[]
): string | null => {
	if (
		fetchErrors.length == 0 ||
		!fetchErrors.every((item) => item === fetchErrors[0] && item != null)
	) {
		// Either the messages can't be consolidated, or there are no errors, which is fine. We just won't use them.
		return null;
	}

	// We know that this can't be null from the `every` above.
	return fetchErrors[0]!;
};

const makeErrorComponent = (
	...fetchErrors: (string | null)[]
): JSX.Element | null => {
	const errorMsg = makeConsolidatedFetchError(...fetchErrors);
	if (errorMsg == null) {
		return null;
	}

	return <CardError>{errorMsg}</CardError>;
};

const StatsCardContents = ({ pillminder, token }: StatsCardBodyProps) => {
	const client = new APIClient(token);
	const summaryQuery = useQuery({
		queryKey: ["summary", pillminder, token],
		queryFn: () => client.getStatsSummary(pillminder),
	});

	const historyQuery = useQuery({
		queryKey: ["history", pillminder, token],
		queryFn: () => client.getTakenDates(pillminder),
	});

	const statsBody = (
		<HStack
			divider={<StackDivider />}
			justifyContent="space-evenly"
			alignItems="stretch"
			height="100%"
		>
			<Loadable
				isLoading={summaryQuery.isLoading}
				error={makeQueryError(summaryQuery, "Failed to load summary")}
			>
				<Summary statsSummary={summaryQuery.data!} />
			</Loadable>
			<Loadable
				isLoading={historyQuery.isLoading}
				error={makeQueryError(historyQuery, "Failed to load history")}
			>
				<History takenDates={historyQuery.data!} />
			</Loadable>
		</HStack>
	);

	const errorComponent = makeErrorComponent(
		makeQueryError(summaryQuery),
		makeQueryError(historyQuery)
	);

	return errorComponent ?? statsBody;
};

export default StatsCardContents;
