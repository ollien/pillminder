import { CardBody, CardHeader, Heading } from "@chakra-ui/react";
import CardError from "pillminder-webclient/src/pages/_common/CardError";
import CardPage from "pillminder-webclient/src/pages/_common/CardPage";
import { makeErrorString } from "pillminder-webclient/src/pages/_common/errors";
import StatsCardContents from "pillminder-webclient/src/pages/stats/StatsCardContents";
import { AuthContext } from "pillminder-webclient/src/pages/stats/auth_context";
import React, { useContext } from "react";
import { ErrorBoundary, FallbackProps } from "react-error-boundary";

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

const Stats = () => {
	const authContext = useContext(AuthContext);
	return (
		<CardPage maxWidth="container.md">
			<CardHeader>
				<Heading size={{ base: "lg", lg: "md" }}>
					{getHeadingMsg(authContext?.pillminder)}
				</Heading>
			</CardHeader>
			<CardBody width="100%">
				<ErrorBoundary FallbackComponent={BoundaryError}>
					<StatsCardContents />
				</ErrorBoundary>
			</CardBody>
		</CardPage>
	);
};

export default Stats;
