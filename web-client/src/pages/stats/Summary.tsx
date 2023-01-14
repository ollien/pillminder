import { Stack } from "@chakra-ui/react";
import { DateTime } from "luxon";
import { StatsSummary } from "pillminder-webclient/src/lib/api";
import BigStat from "pillminder-webclient/src/pages/stats/BigStat";
import React from "react";

const formatLastTakenOn = (lastTakenOn: DateTime | null) => {
	if (lastTakenOn == null) {
		return "Never";
	}

	return lastTakenOn.toLocaleString({ dateStyle: "short" });
};

const Summary = ({ statsSummary }: { statsSummary: StatsSummary }) => (
	<Stack
		direction={{ base: "column", sm: "row" }}
		justifyContent="space-around"
	>
		<BigStat value={`${statsSummary?.streakLength}`} name="Streak" />
		<BigStat
			value={formatLastTakenOn(statsSummary?.lastTaken)}
			name="Last taken on"
		/>
	</Stack>
);

export default Summary;
