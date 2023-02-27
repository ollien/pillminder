import { List } from "@chakra-ui/react";
import { TakenDate } from "pillminder-webclient/src/lib/api";
import HistoryListItem, {
	Status as HistoryStatus,
} from "pillminder-webclient/src/pages/stats/HistoryListItem";
import React from "react";

interface HistoryProps {
	takenDates: TakenDate[];
}

const History = ({ takenDates }: HistoryProps) => {
	const listItems = takenDates
		.slice(0)
		.reverse()
		.map((takenDate, idx) => {
			const dateDisplay = takenDate.date.toLocaleString({
				dateStyle: "medium",
			});
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
				<HistoryListItem
					key={`history-list-${dateDisplay}`}
					label={dateDisplay}
					status={status}
				/>
			);
		});

	return <List spacing={4}>{listItems}</List>;
};

export default History;
