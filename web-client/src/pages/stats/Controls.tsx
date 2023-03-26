import { Button, Stack } from "@chakra-ui/react";
import React from "react";

interface ControlProps {
	onMarkedTaken: () => void;
	onSkipped: () => void;
}

interface ControlButtonProps {
	color: string;
	onClick: () => void;
}

const ControlButton = ({
	color,
	onClick,
	children,
}: React.PropsWithChildren<ControlButtonProps>) => (
	<Button colorScheme={color} variant="outline" onClick={onClick}>
		{children}
	</Button>
);

const Controls = ({ onMarkedTaken, onSkipped }: ControlProps) => (
	<Stack justifyContent="center">
		<ControlButton color="teal" onClick={onMarkedTaken}>
			Mark taken
		</ControlButton>

		<ControlButton color="red" onClick={onSkipped}>
			Skip today
		</ControlButton>
	</Stack>
);

export default Controls;
