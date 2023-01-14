import Stats from "./Stats";
import { ChakraProvider } from "@chakra-ui/react";
import React from "react";
import { createRoot } from "react-dom/client";

const getPillminder = (): string | undefined => {
	const params = new URLSearchParams(window.location.search);
	const pillminderParam = params.get("pillminder");
	if (pillminderParam == null || pillminderParam === "") {
		return undefined;
	}

	return pillminderParam;
};

const rootElement = document.getElementById("root");
const reactRoot = createRoot(rootElement!);

reactRoot.render(
	<ChakraProvider>
		<Stats pillminder={getPillminder()} />
	</ChakraProvider>
);
