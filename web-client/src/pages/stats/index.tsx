import Stats from "./Stats";
import { ChakraProvider } from "@chakra-ui/react";
import React from "react";
import { createRoot } from "react-dom/client";

const getPillminder = (): string | undefined => {
	return localStorage.getItem("pillminder") ?? undefined;
};

const getToken = (): string | undefined => {
	return localStorage.getItem("token") ?? undefined;
};

const rootElement = document.getElementById("root");
const reactRoot = createRoot(rootElement!);

reactRoot.render(
	<ChakraProvider>
		<Stats pillminder={getPillminder()} token={getToken()} />
	</ChakraProvider>
);
