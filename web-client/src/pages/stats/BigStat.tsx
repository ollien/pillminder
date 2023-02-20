import { Stack, Text } from "@chakra-ui/react";
import React from "react";

interface BigStatProps {
	value: string;
	name: string;
}

const BigStat = ({ value, name }: BigStatProps) => {
	return (
		<Stack textAlign="center">
			<Text fontSize={{ base: "6rem", lg: "4rem" }} marginBottom="-6">
				{value}
			</Text>
			<Text fontSize={{ base: "2xl", lg: "lg" }}>{name}</Text>
		</Stack>
	);
};

export default BigStat;
