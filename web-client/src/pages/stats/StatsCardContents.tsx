import { SettingsIcon } from "@chakra-ui/icons";
import { HStack, Stack, StackDivider } from "@chakra-ui/react";
import { APIClient } from "pillminder-webclient/src/lib/api";
import CardError from "pillminder-webclient/src/pages/_common/CardError";
import {
	assertUnreachable,
	makeErrorString,
} from "pillminder-webclient/src/pages/_common/errors";
import Controls, {
	ControlStatus,
} from "pillminder-webclient/src/pages/stats/Controls";
import History from "pillminder-webclient/src/pages/stats/History";
import IconMenu from "pillminder-webclient/src/pages/stats/IconMenu";
import Loadable from "pillminder-webclient/src/pages/stats/Loadable";
import Summary from "pillminder-webclient/src/pages/stats/Summary";
import { AuthContext } from "pillminder-webclient/src/pages/stats/auth_context";
import React, { useContext, useMemo } from "react";
import {
	useMutation,
	UseMutationResult,
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

const mutationToControlStatus = <
	MutationData,
	MutationError,
	MutationVariables,
	MutationContext
>(
	mutation: UseMutationResult<
		MutationData,
		MutationError,
		MutationVariables,
		MutationContext
	>
): ControlStatus => {
	const status = mutation.status;

	switch (status) {
		case "idle":
			return { status: "idle" };
		case "loading":
			return { status: "loading" };
		case "success":
			return { status: "complete" };
		case "error":
			return {
				status: "error",
				error: makeErrorString(mutation.error),
			};
		default:
			return assertUnreachable(status);
	}
};

const useControl = <T,>(
	fn: () => T,
	// This is necessary, otherwise we can't pass a mutation (given the default is "unknown")
	// eslint-disable-next-line @typescript-eslint/no-explicit-any
	mutation: UseMutationResult<any, any, any, any>,
	extraDeps: unknown[] = []
): T => {
	return useMemo(
		fn,
		// We only need to re-render if the status of the mutation changes.
		// Asking for "fn" to be a dependency of the render is just going to
		// cause constant re-renders, as every render the fn will be different.
		//
		// eslint-disable-next-line: react-hooks/exhaustive-deps
		[fn, mutation.status, ...extraDeps]
	);
};

const StatsBody = () => {
	const authContext = useContext(AuthContext);
	if (!authContext) {
		// This shouldn't happen during normal operation, and the error boundary above this will catch it
		throw Error(INVALID_TOKEN_ERROR);
	}

	const apiClient = new APIClient(authContext.token);
	const summaryQuery = useQuery({
		queryKey: ["summary", authContext.pillminder, authContext.token],
		queryFn: () => apiClient.getStatsSummary(authContext.pillminder),
	});

	const historyQuery = useQuery({
		queryKey: ["history", authContext.pillminder, authContext.token],
		queryFn: () => apiClient.getTakenDates(authContext.pillminder),
	});

	const cardBody = (
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

	return errorComponent ?? cardBody;
};

const ControlsMenu = () => {
	const authContext = useContext(AuthContext);
	if (!authContext) {
		// This shouldn't happen during normal operation, and the error boundary above this will catch it
		throw Error(INVALID_TOKEN_ERROR);
	}

	const apiClient = new APIClient(authContext.token);
	const queryClient = useQueryClient();

	const markTakenMutation = useMutation({
		mutationFn: () => apiClient.markTodayAsTaken(authContext.pillminder),
	});

	const markSkippedMutation = useMutation({
		mutationFn: () => apiClient.skipToday(authContext.pillminder),
	});

	const markTakenControl = useControl(
		() => ({
			status: mutationToControlStatus(markTakenMutation),
			onAction: async () => {
				await markTakenMutation.mutateAsync();
				queryClient.invalidateQueries();
			},
		}),
		markTakenMutation
	);

	const markSkippedControl = useControl(
		() => ({
			status: mutationToControlStatus(markSkippedMutation),
			onAction: () => markSkippedMutation.mutate(),
		}),
		markSkippedMutation
	);

	const controls = (
		<IconMenu icon={<SettingsIcon />}>
			<Controls markTaken={markTakenControl} markSkipped={markSkippedControl} />
		</IconMenu>
	);

	return controls;
};

const StatsCardContents = () => (
	<Stack>
		<StatsBody />
		<ControlsMenu />
	</Stack>
);

export default StatsCardContents;
