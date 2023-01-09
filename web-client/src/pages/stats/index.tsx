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
// eslint-disable-next-line @typescript-eslint/no-non-null-assertion
const reactRoot = createRoot(rootElement!);

reactRoot.render(
	<ChakraProvider>
		<Stats pillminder={getPillminder()} />
	</ChakraProvider>
);
