import { ChakraProvider } from "@chakra-ui/react";
import Login from "pillminder-webclient/src/pages/login/Login";
import React from "react";
import { createRoot } from "react-dom/client";

const rootElement = document.getElementById("root");
// eslint-disable-next-line @typescript-eslint/no-non-null-assertion
const reactRoot = createRoot(rootElement!);
reactRoot.render(
	<ChakraProvider>
		<Login />
	</ChakraProvider>
);
