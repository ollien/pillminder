import { HStack, Stack, StackDivider } from "@chakra-ui/react";
import { APIClient } from "pillminder-webclient/src/lib/api";
import CardError from "pillminder-webclient/src/pages/_common/CardError";
import { makeErrorString } from "pillminder-webclient/src/pages/_common/errors";
import Controls from "pillminder-webclient/src/pages/stats/Controls";
import History from "pillminder-webclient/src/pages/stats/History";
import Loadable from "pillminder-webclient/src/pages/stats/Loadable";
import Summary from "pillminder-webclient/src/pages/stats/Summary";
import React from "react";
import {
	useMutation,
	useQuery,
	useQueryClient,
	UseQueryResult,
} from "react-query";

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
	const queryClient = useQueryClient();
	const apiClient = new APIClient(token);
	const summaryQuery = useQuery({
		queryKey: ["summary", pillminder, token],
		queryFn: () => apiClient.getStatsSummary(pillminder),
	});

	const historyQuery = useQuery({
		queryKey: ["history", pillminder, token],
		queryFn: () => apiClient.getTakenDates(pillminder),
	});

	const markTakenMutation = useMutation({
		mutationFn: () => apiClient.markTodayAsTaken(pillminder),
	});

	const markSkippedMutation = useMutation({
		mutationFn: () => apiClient.skipToday(pillminder),
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

	const controls = (
		<Controls
			onMarkedTaken={async () => {
				await markTakenMutation.mutateAsync();
				queryClient.invalidateQueries();
			}}
			onSkipped={async () => {
				await markSkippedMutation.mutateAsync();
			}}
		/>
	);

	const cardBody = (
		<Stack>
			{statsBody}
			{controls}
		</Stack>
	);

	const errorComponent = makeErrorComponent(
		makeQueryError(summaryQuery),
		makeQueryError(historyQuery)
	);

	return errorComponent ?? cardBody;
};

export default StatsCardContents;
