import { List } from "@chakra-ui/react";
import { As, ListIcon, ListItem } from "@chakra-ui/react";
import { TakenDate } from "pillminder-webclient/src/lib/api";
import { assertUnreachable } from "pillminder-webclient/src/pages/_common/errors";
import React from "react";
import {
	AiOutlineCheckCircle,
	AiOutlineCloseCircle,
	AiOutlineHourglass,
} from "react-icons/ai";

enum Status {
	TAKEN,
	NOT_TAKEN,
	NOT_TAKEN_YET,
}

interface HistoryListItemProps {
	status: Status;
	label: string;
}

interface HistoryProps {
	takenDates: TakenDate[];
}

const colorForStatus = (status: Status): string => {
	switch (status) {
		case Status.TAKEN:
			return "green";
		case Status.NOT_TAKEN:
			return "red";
		case Status.NOT_TAKEN_YET:
			return "gray";
		default:
			return assertUnreachable(status);
	}
};

// The types for these icons are annoying to express, and not important other than that they are chakra.As
// eslint-disable-next-line @typescript-eslint/no-explicit-any
const iconForStatus = (status: Status): As<any> => {
	switch (status) {
		case Status.TAKEN:
			return AiOutlineCheckCircle;
		case Status.NOT_TAKEN:
			return AiOutlineCloseCircle;
		case Status.NOT_TAKEN_YET:
			return AiOutlineHourglass;
		default:
			return assertUnreachable(status);
	}
};

const HistoryListItem = ({ status, label }: HistoryListItemProps) => (
	<ListItem fontSize={{ base: "3xl", lg: "2xl" }}>
		<ListIcon as={iconForStatus(status)} color={colorForStatus(status)} />
		<span style={{ verticalAlign: "-0.125em" }}>{label}</span>
	</ListItem>
);

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
					return Status.NOT_TAKEN_YET;
				} else if (!takenDate.taken) {
					return Status.NOT_TAKEN;
				} else {
					return Status.TAKEN;
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
