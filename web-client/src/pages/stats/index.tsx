import Stats from "./Stats";
import { ChakraProvider } from "@chakra-ui/react";
import React from "react";
import { createRoot } from "react-dom/client";
import { QueryClient, QueryClientProvider } from "react-query";

const getPillminder = (): string | undefined => {
	return localStorage.getItem("pillminder") ?? undefined;
};

const getToken = (): string | undefined => {
	return localStorage.getItem("token") ?? undefined;
};

const rootElement = document.getElementById("root");
const reactRoot = createRoot(rootElement!);
const queryClient = new QueryClient({
	defaultOptions: {
		queries: {
			refetchOnWindowFocus: false,
			// TODO: I do want to allow retries, but I want to clean up some of the error throws
			// so we don't just retry when a status code is bad or something. Network errors are fine...
			retry: false,
		},
	},
});

reactRoot.render(
	<ChakraProvider>
		<QueryClientProvider client={queryClient}>
			<Stats pillminder={getPillminder()} token={getToken()} />
		</QueryClientProvider>
	</ChakraProvider>
);
