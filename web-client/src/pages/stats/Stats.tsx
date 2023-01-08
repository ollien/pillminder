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

const Stats = ({ pillminder }: { pillminder: string | undefined }) => {
	const [streakLength, setStreakLength] = useState<number | null>(null);
	const [error, setError] = useState<string | null>(null);

	useEffect(() => {
		getStreakLength(pillminder)
			.then(({ streak_length: fetchedLength }) => {
				setStreakLength(fetchedLength);
			})
			.catch((fetchErr: Error) => {
				setError(fetchErr.message);
			});
	}, [pillminder]);

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
						<Heading size="md">Stats for {pillminder}</Heading>
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
