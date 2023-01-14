import { Card, Center, Container } from "@chakra-ui/react";
import colors from "pillminder-webclient/src/pages/_common/colors";
import React from "react";

export interface CardPageProps {
	// Represents the width of the container; corresponds to the widths in Chakra's themes.size.container
	// https://chakra-ui.com/docs/styled-system/theme#sizes
	//
	// Defaults to 60ch
	maxWidth?: string;
}

const CardPage = ({
	maxWidth,
	children,
}: React.PropsWithChildren<CardPageProps>) => {
	return (
		<Center h="100%" flexDirection="column" backgroundColor={colors.BACKGROUND}>
			<Container maxW={maxWidth}>
				<Card backgroundColor="white" shadow="2xl">
					{children}
				</Card>
			</Container>
		</Center>
	);
};

export default CardPage;
