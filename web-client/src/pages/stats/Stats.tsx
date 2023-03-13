import { CardBody, CardHeader, Heading } from "@chakra-ui/react";
import CardError from "pillminder-webclient/src/pages/_common/CardError";
import CardPage from "pillminder-webclient/src/pages/_common/CardPage";
import { makeErrorString } from "pillminder-webclient/src/pages/_common/errors";
import StatsCardContents from "pillminder-webclient/src/pages/stats/StatsCardContents";
import React from "react";
import { ErrorBoundary, FallbackProps } from "react-error-boundary";

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
	return (
		<CardPage maxWidth="container.md">
			<CardHeader>
				<Heading size={{ base: "lg", lg: "md" }}>
					{getHeadingMsg(pillminder)}
				</Heading>
			</CardHeader>
			<CardBody width="100%">
				<ErrorBoundary FallbackComponent={BoundaryError}>
					<StatsCardContents pillminder={pillminder} token={token} />
				</ErrorBoundary>
			</CardBody>
		</CardPage>
	);
};

export default Stats;
