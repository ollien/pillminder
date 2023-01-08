import Login from "./Login";
import { ChakraProvider } from "@chakra-ui/react";
import React from "react";
import { render } from "react-dom";

render(
	<ChakraProvider>
		<Login />
	</ChakraProvider>,
	document.getElementById("root")
);
