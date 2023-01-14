import { ChakraProvider } from "@chakra-ui/react";
import Login from "pillminder-webclient/src/pages/login/Login";
import React from "react";
import { createRoot } from "react-dom/client";

const rootElement = document.getElementById("root");
const reactRoot = createRoot(rootElement!);
reactRoot.render(
	<ChakraProvider>
		<Login />
	</ChakraProvider>
);
