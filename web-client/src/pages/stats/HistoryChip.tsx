import { CheckIcon, CloseIcon, MinusIcon } from "@chakra-ui/icons";
import { As, Tag, TagLabel, TagLeftIcon } from "@chakra-ui/react";
import React from "react";

export enum Status {
	TAKEN,
	NOT_TAKEN,
	NOT_TAKEN_YET,
}

interface HistoryChipProps {
	status: Status;
	label: string;
}

const assertUnreachable = <T,>(x: never): T => {
	throw Error(`assertUnreachable was called with ${x}`);
};

const colorForStatus = (status: Status): string => {
	switch (status) {
		case Status.TAKEN:
			return "green";
		case Status.NOT_TAKEN:
			return "red";
		case Status.NOT_TAKEN_YET:
			return "blue";
		default:
			return assertUnreachable(status);
	}
};

// The types for these icons are annoying to express, and not important other than that they are chakra.As
// eslint-disable-next-line @typescript-eslint/no-explicit-any
const iconForStatus = (status: Status): As<any> => {
	switch (status) {
		case Status.TAKEN:
			return CheckIcon;
		case Status.NOT_TAKEN:
			return CloseIcon;
		case Status.NOT_TAKEN_YET:
			return MinusIcon;
		default:
			return assertUnreachable(status);
	}
};

const HistoryChip = ({ status, label }: HistoryChipProps) => (
	<Tag size="lg" minWidth="fit-content" colorScheme={colorForStatus(status)}>
		<TagLeftIcon boxSize={2} as={iconForStatus(status)}></TagLeftIcon>
		<TagLabel>{label}</TagLabel>
	</Tag>
);

export default HistoryChip;
