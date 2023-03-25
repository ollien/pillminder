import { CardBody, CardHeader, Heading } from "@chakra-ui/react";
import CardError from "pillminder-webclient/src/pages/_common/CardError";
import CardPage from "pillminder-webclient/src/pages/_common/CardPage";
import { makeErrorString } from "pillminder-webclient/src/pages/_common/errors";
import StatsCardContents from "pillminder-webclient/src/pages/stats/StatsCardContents";
import React from "react";
import { ErrorBoundary, FallbackProps } from "react-error-boundary";

const NO_PILLMINDER_ERROR = "No pillminder selected";
const INVALID_TOKEN_ERROR = "Your session has expired. Please log in again";

interface StatsProps {
	pillminder?: string;
	token?: string;
}

const getHeadingMsg = (pillminder: string | undefined) => {
	if (pillminder == null) {
		return "Stats";
	} else {
		return `Stats for ${pillminder}`;
	}
};

const BoundaryError = ({ error }: FallbackProps) => {
	return <CardError>{makeErrorString(error)}</CardError>;
};

const Stats = ({ pillminder, token }: StatsProps) => {
	const propError = (() => {
		if (pillminder == null) {
			NO_PILLMINDER_ERROR;
		} else if (token == null) {
			return INVALID_TOKEN_ERROR;
		} else {
			return null;
		}
	})();

	const propErrorComponent = propError ? (
		<CardError>{propError}</CardError>
	) : null;

	const cardBody = (
		<ErrorBoundary FallbackComponent={BoundaryError}>
			{/*
				Typescript isn't smart enough to see this, but if we're rendering
				this, we've already asserted both of these aren't null
			*/}
			<StatsCardContents pillminder={pillminder!} token={token!} />
		</ErrorBoundary>
	);

	return (
		<CardPage maxWidth="container.md">
			<CardHeader>
				<Heading size={{ base: "lg", lg: "md" }}>
					{getHeadingMsg(pillminder)}
				</Heading>
			</CardHeader>
			<CardBody width="100%">{propErrorComponent ?? cardBody}</CardBody>
		</CardPage>
	);
};

export default Stats;
