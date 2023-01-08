import React from "react";
import { render } from "react-dom";
import Login from "./Login";
import { ChakraProvider } from "@chakra-ui/react";

render(
	<ChakraProvider>
		<Login />
	</ChakraProvider>,
	document.getElementById("root")
);
