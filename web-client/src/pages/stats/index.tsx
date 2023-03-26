import Stats from "./Stats";
import { ChakraProvider } from "@chakra-ui/react";
import { APIError } from "pillminder-webclient/src/lib/api";
import {
	AuthContext,
	AuthContextData,
} from "pillminder-webclient/src/pages/stats/auth_context";
import React from "react";
import { createRoot } from "react-dom/client";
import { QueryClient, QueryClientProvider } from "react-query";

const buildAuthContext = (): AuthContextData | null => {
	const pillminder = localStorage.getItem("pillminder");
	const token = localStorage.getItem("token");
	if (!(pillminder && token)) {
		return null;
	}

	return { pillminder, token };
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
			<AuthContext.Provider value={buildAuthContext()}>
				<Stats />
			</AuthContext.Provider>
		</QueryClientProvider>
	</ChakraProvider>
);
