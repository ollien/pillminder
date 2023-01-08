import Login from "./Login";
import { ChakraProvider } from "@chakra-ui/react";
import React from "react";
import { createRoot } from "react-dom/client";

const rootElement = document.getElementById("root");
const reactRoot = createRoot(rootElement!);
reactRoot.render(
	<ChakraProvider>
		<Login />
	</ChakraProvider>
);
