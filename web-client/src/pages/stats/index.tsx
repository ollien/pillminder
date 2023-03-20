import Stats from "./Stats";
import { ChakraProvider } from "@chakra-ui/react";
import { APIError } from "pillminder-webclient/src/lib/api";
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
			retry: (failureCount: number, error: unknown) => {
				if (failureCount >= 3) {
					return false;
				}

				if (error instanceof APIError) {
					return error.canRetry();
				} else {
					return false;
				}
			},
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
