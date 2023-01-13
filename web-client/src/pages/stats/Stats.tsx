import { CardBody, CardHeader, Center, Heading, Text } from "@chakra-ui/react";
import {
	getStatsSummary,
	StatsSummary,
} from "pillminder-webclient/src/lib/api";
import CardPage from "pillminder-webclient/src/pages/_common/CardPage";
import LoadingOr from "pillminder-webclient/src/pages/stats/LoadingOr";
import Summary from "pillminder-webclient/src/pages/stats/Summary";
import React, { useEffect, useState } from "react";

const NO_PILLMINDER_ERROR = "No pillminder selected";

const getFirstError = (...errors: (string | null)[]): string | null => {
	return errors.find((error) => error != null) ?? null;
};

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

const Stats = ({ pillminder }: { pillminder: string | undefined }) => {
	const [statsSummary, setStatsSummary] = useState<StatsSummary | null>(null);
	const [storedError, setStoredError] = useState<string | null>(null);
	const emptyPillminderError = makeEmptyPillminderError(pillminder);

	const error = getFirstError(storedError, emptyPillminderError);
	useEffect(() => {
		if (error != null) {
			return;
		}

		if (pillminder == null) {
			// Ideally this should be prevented by getError, but if somehow at broke, we can be defensive here
			// (doing it here is ineffective since it causes a second render)
			setStoredError(NO_PILLMINDER_ERROR);
			return;
		}

		getStatsSummary(pillminder)
			.then(setStatsSummary)
			.catch((fetchErr: Error) => {
				setStoredError(fetchErr.message);
			});
	}, [pillminder, error]);

	const statsSummaryElement = (
		<LoadingOr isLoading={statsSummary == null}>
			<Summary statsSummary={statsSummary} />
		</LoadingOr>
	);

	const errorElement = (
		<Center>
			<Text color="red.400" fontSize="lg" fontWeight="bold">
				{error}
			</Text>
		</Center>
	);

	return (
		<CardPage maxWidth="container.md">
			<CardHeader>
				<Heading size={{ base: "lg", lg: "md" }}>
					{getHeadingMsg(pillminder)}
				</Heading>
			</CardHeader>
			<CardBody width="100%">
				{error == null ? statsSummaryElement : errorElement}
			</CardBody>
		</CardPage>
	);
};

export default Stats;
