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
import colors from "pillminder-webclient/src/pages/_common/colors";
import BigStat from "pillminder-webclient/src/pages/stats/BigStat";
import LoadingOr from "pillminder-webclient/src/pages/stats/LoadingOr";
import * as React from "react";
import { useEffect, useState } from "react";

const NO_PILLMINDER_ERROR = "No pillminder selected";

const getStreakLength = async (
	pillminder: string
): Promise<{ streak_length: number }> => {
	const res = await fetch(`/stats/${encodeURIComponent(pillminder)}/summary`);

	if (res.status !== 200) {
		// This api doesn't return any real errors, so we can just give a generic message
		throw new Error("Failed to load streak");
	}

	return res.json();
};

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
	const [streakLength, setStreakLength] = useState<number | null>(null);
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

		getStreakLength(pillminder)
			.then(({ streak_length: fetchedLength }) => {
				setStreakLength(fetchedLength);
			})
			.catch((fetchErr: Error) => {
				setStoredError(fetchErr.message);
			});
	}, [pillminder, error]);

	const statsSummary = (
		<LoadingOr isLoading={streakLength == null}>
			<Stack direction="row" justifyContent="space-around" alignItems="">
				<BigStat value={`${streakLength}`} name="Streak" />
				{/* TODO: add other stats here */}
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
						{error == null ? statsSummary : errorElement}
					</CardBody>
				</Card>
			</Container>
		</Center>
	);
};

export default Stats;
