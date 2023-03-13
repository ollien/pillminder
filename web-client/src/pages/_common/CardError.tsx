import ErrorText from "./ErrorText";
import { Center } from "@chakra-ui/react";
import React from "react";

const CardError = ({ children }: { children: React.ReactNode }) => {
	return (
		<Center>
			<ErrorText>{children}</ErrorText>
		</Center>
	);
};

export default CardError;
