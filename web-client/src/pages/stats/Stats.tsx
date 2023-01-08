import {
	Card,
	CardBody,
	CardHeader,
	Center,
	Container,
	Heading,
} from "@chakra-ui/react";
import colors from "pillminder-webclient/src/pages/_common/colors";
import BigStat from "pillminder-webclient/src/pages/stats/BigStat";
import * as React from "react";

const Stats = ({ pillminder }: { pillminder: string | undefined }) => {
	return (
		<Center h="100%" flexDirection="column" backgroundColor={colors.BACKGROUND}>
			<Container>
				<Card backgroundColor="white" shadow="2xl">
					<CardHeader>
						<Heading size="md">Stats for {pillminder}</Heading>
					</CardHeader>
					<CardBody>
						<BigStat value="5" name="Streak" />
					</CardBody>
				</Card>
			</Container>
		</Center>
	);
};

export default Stats;
