import { CardBody, CardHeader, Heading } from "@chakra-ui/react";
import CardPage from "pillminder-webclient/src/pages/_common/CardPage";
import StatsCardContents from "pillminder-webclient/src/pages/stats/StatsCardContents";
import React from "react";

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

const Stats = ({ pillminder, token }: StatsProps) => {
	return (
		<CardPage maxWidth="container.md">
			<CardHeader>
				<Heading size={{ base: "lg", lg: "md" }}>
					{getHeadingMsg(pillminder)}
				</Heading>
			</CardHeader>
			<CardBody width="100%">
				<StatsCardContents pillminder={pillminder} token={token} />
			</CardBody>
		</CardPage>
	);
};

export default Stats;
