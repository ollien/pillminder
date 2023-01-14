import { CheckIcon, CloseIcon } from "@chakra-ui/icons";
import { Center, HStack, Tag, TagLeftIcon, TagLabel } from "@chakra-ui/react";
import { TakenDate } from "pillminder-webclient/src/lib/api";
import React from "react";

interface HistoryProps {
	takenDates: TakenDate[];
}

const History = ({ takenDates }: HistoryProps) => {
	const listItems = takenDates.map((takenDate) => {
		const icon = takenDate.taken ? CheckIcon : CloseIcon;
		const color = takenDate.taken ? "green" : "red";
		const dateDisplay = takenDate.date.toLocaleString({ dateStyle: "short" });

		return (
			<Tag
				size="lg"
				colorScheme={color}
				minWidth="fit-content"
				key={dateDisplay}
			>
				<TagLeftIcon boxSize={2} as={icon}></TagLeftIcon>
				<TagLabel>{dateDisplay}</TagLabel>
			</Tag>
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
