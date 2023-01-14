import { Center, HStack } from "@chakra-ui/react";
import { TakenDate } from "pillminder-webclient/src/lib/api";
import HistoryChip, {
	Status as HistoryStatus,
} from "pillminder-webclient/src/pages/stats/HistoryChip";
import React from "react";

interface HistoryProps {
	takenDates: TakenDate[];
}

const History = ({ takenDates }: HistoryProps) => {
	const listItems = takenDates.map((takenDate, idx) => {
		const dateDisplay = takenDate.date.toLocaleString({ dateStyle: "short" });
		const status = (() => {
			if (idx == 0 && !takenDate.taken) {
				return HistoryStatus.NOT_TAKEN_YET;
			} else if (!takenDate.taken) {
				return HistoryStatus.NOT_TAKEN;
			} else {
				return HistoryStatus.TAKEN;
			}
		})();

		return (
			<HistoryChip
				status={status}
				label={dateDisplay}
				key={dateDisplay}
			></HistoryChip>
		);
	});
	listItems.reverse();

	return (
		<Center>
			<HStack spacing={2} overflowX="scroll">
				{listItems}
			</HStack>
		</Center>
	);
};

export default History;
