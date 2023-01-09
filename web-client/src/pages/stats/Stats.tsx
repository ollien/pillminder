import {
	Card,
	CardBody,
	CardHeader,
	Center,
	Container,
	Heading,
	Stack,
	Text,
} from "@chakra-ui/react";
import {
	getStatsSummary,
	StatsSummary,
} from "pillminder-webclient/src/lib/api";
import colors from "pillminder-webclient/src/pages/_common/colors";
import BigStat from "pillminder-webclient/src/pages/stats/BigStat";
import LoadingOr from "pillminder-webclient/src/pages/stats/LoadingOr";
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

const formatLastTakenOn = (lastTakenOn: Date | null) => {
	if (lastTakenOn == null) {
		return "Never";
	}

	return lastTakenOn.toLocaleDateString();
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
			<Stack direction="row" justifyContent="space-around" alignItems="">
				<BigStat value={`${statsSummary?.streakLength}`} name="Streak" />
				<BigStat
					value={formatLastTakenOn(statsSummary?.lastTaken)}
					name="Last taken on"
				/>
			</Stack>
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
		<Center h="100%" flexDirection="column" backgroundColor={colors.BACKGROUND}>
			<Container>
				<Card backgroundColor="white" shadow="2xl">
					<CardHeader>
						<Heading size="md">{getHeadingMsg(pillminder)}</Heading>
					</CardHeader>
					<CardBody width="100%">
						{error == null ? statsSummaryElement : errorElement}
					</CardBody>
				</Card>
			</Container>
		</Center>
	);
};

export default Stats;
