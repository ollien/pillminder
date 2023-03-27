import {
	Accordion,
	AccordionButton,
	AccordionItem,
	AccordionPanel,
	Box,
} from "@chakra-ui/react";
import React from "react";

interface IconMenuProps {
	icon: React.ReactElement;
}

const IconMenu = ({
	icon,
	children,
}: React.PropsWithChildren<IconMenuProps>) => (
	<Accordion allowToggle>
		<AccordionItem border="none">
			<h2>
				<AccordionButton>
					<Box flex={1}></Box>
					{icon}
				</AccordionButton>
			</h2>
			<AccordionPanel>{children}</AccordionPanel>
		</AccordionItem>
	</Accordion>
);

export default IconMenu;
