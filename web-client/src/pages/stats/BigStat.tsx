import { Stack, Text } from "@chakra-ui/react";
import React from "react";

interface BigStatProps {
	value: string;
	name: string;
}

const BigStat = ({ value, name }: BigStatProps) => {
	return (
		<Stack textAlign="center">
			<Text fontSize="6xl" lineHeight="0.5">
				{value}
			</Text>
			<Text fontSize="md">{name}</Text>
		</Stack>
	);
};

export default BigStat;
