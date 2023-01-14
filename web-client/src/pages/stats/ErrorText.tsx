import { Text } from "@chakra-ui/react";
import React from "react";

const ErrorText = ({ text }: { text: string }) => (
	<Text color="red.400" fontSize="lg" fontWeight="bold">
		{text}
	</Text>
);

export default ErrorText;
