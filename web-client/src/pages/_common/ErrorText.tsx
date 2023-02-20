import { Text } from "@chakra-ui/react";
import React from "react";

const ErrorText = ({ children }: { children: React.ReactNode }) => (
	<Text color="red.400" fontSize="lg" fontWeight="bold">
		{children}
	</Text>
);

export default ErrorText;
