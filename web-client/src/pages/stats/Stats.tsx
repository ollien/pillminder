import {
	CardBody,
	CardHeader,
	Center,
	Divider,
	Heading,
	Stack,
	Text,
} from "@chakra-ui/react";
import {
	getStatsSummary,
	getTakenDates,
} from "pillminder-webclient/src/lib/api";
import CardPage from "pillminder-webclient/src/pages/_common/CardPage";
import History from "pillminder-webclient/src/pages/stats/History";
import Loadable from "pillminder-webclient/src/pages/stats/Loadable";
import Summary from "pillminder-webclient/src/pages/stats/Summary";
import React, { useCallback, useEffect, useState } from "react";

const NO_PILLMINDER_ERROR = "No pillminder selected";

const makeEmptyPillminderError = (pillminder: string | undefined) => {
	if (pillminder == null) {
		return NO_PILLMINDER_ERROR;
	}

	return null;
};

const getHeadingMsg = (pillminder: string | undefined) => {
	if (pillminder == null) {
		return "Stats";
	} else {
		return `Stats for ${pillminder}`;
	}
};

const useAPI = <T,>(
	doFetch: () => Promise<T>,
	dependencies: React.DependencyList
): [T?, string?] => {
	const [data, setData] = useState<T | undefined>(undefined);
	const [error, setError] = useState<string | undefined>(undefined);
	// I think this is correct as-is. `dependencies` corresponds with the fetch callback as-is.
	// eslint-disable-next-line react-hooks/exhaustive-deps
	const fetchCallback = useCallback(doFetch, dependencies);

	useEffect(() => {
		fetchCallback()
			.then(setData)
			.catch((error: Error) => {
				setError(error.message);
			});
	}, [fetchCallback]);

	return [data, error];
};

const Stats = ({ pillminder }: { pillminder: string | undefined }) => {
	const [statsSummary, statsSummaryError] = useAPI(async () => {
		if (pillminder == null) {
			throw Error(NO_PILLMINDER_ERROR);
		}

		return getStatsSummary(pillminder);
	}, [pillminder]);

	const [takenDates, takenDatesError] = useAPI(async () => {
		if (pillminder == null) {
			throw Error(NO_PILLMINDER_ERROR);
		}

		return getTakenDates(pillminder);
	}, [pillminder]);

	const statsBody = (
		<Stack spacing={4}>
			<Loadable
				isLoading={statsSummary == null && statsSummaryError == null}
				error={statsSummaryError}
			>
				<Summary statsSummary={statsSummary!} />
			</Loadable>
			<Divider />
			<Loadable
				isLoading={takenDates == null && takenDatesError == null}
				error={takenDatesError}
			>
				<History takenDates={takenDates!} />
			</Loadable>
		</Stack>
	);

	const emptyPillminderError = makeEmptyPillminderError(pillminder);
	const makeEmptyPillminderErrorElement = emptyPillminderError ? (
		<Center>
			<Text color="red.400" fontSize="lg" fontWeight="bold">
				{emptyPillminderError}
			</Text>
		</Center>
	) : null;

	return (
		<CardPage maxWidth="container.md">
			<CardHeader>
				<Heading size={{ base: "lg", lg: "md" }}>
					{getHeadingMsg(pillminder)}
				</Heading>
			</CardHeader>
			<CardBody width="100%">
				{makeEmptyPillminderErrorElement ?? statsBody}
			</CardBody>
		</CardPage>
	);
};

export default Stats;
