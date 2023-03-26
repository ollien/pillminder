import { HStack, Stack, StackDivider } from "@chakra-ui/react";
import { APIClient } from "pillminder-webclient/src/lib/api";
import CardError from "pillminder-webclient/src/pages/_common/CardError";
import { makeErrorString } from "pillminder-webclient/src/pages/_common/errors";
import Controls from "pillminder-webclient/src/pages/stats/Controls";
import History from "pillminder-webclient/src/pages/stats/History";
import Loadable from "pillminder-webclient/src/pages/stats/Loadable";
import Summary from "pillminder-webclient/src/pages/stats/Summary";
import { AuthContext } from "pillminder-webclient/src/pages/stats/auth_context";
import React, { useContext } from "react";
import {
	useMutation,
	useQuery,
	useQueryClient,
	UseQueryResult,
} from "react-query";

const INVALID_TOKEN_ERROR = "Your session has expired. Please log in again";

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

const StatsCardContents = () => {
	const authContext = useContext(AuthContext);
	if (!authContext) {
		// This shouldn't happen during normal operation, and the error boundary above this will catch it
		throw Error(INVALID_TOKEN_ERROR);
	}

	const queryClient = useQueryClient();
	const apiClient = new APIClient(authContext.token);
	const summaryQuery = useQuery({
		queryKey: ["summary", authContext.pillminder, authContext.token],
		queryFn: () => apiClient.getStatsSummary(authContext.pillminder),
	});

	const historyQuery = useQuery({
		queryKey: ["history", authContext.pillminder, authContext.token],
		queryFn: () => apiClient.getTakenDates(authContext.pillminder),
	});

	const markTakenMutation = useMutation({
		mutationFn: () => apiClient.markTodayAsTaken(authContext.pillminder),
	});

	const markSkippedMutation = useMutation({
		mutationFn: () => apiClient.skipToday(authContext.pillminder),
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
