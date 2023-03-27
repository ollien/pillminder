import { CheckIcon, WarningIcon } from "@chakra-ui/icons";
import { Button, Fade, Stack } from "@chakra-ui/react";
import React from "react";
import { BeatLoader } from "react-spinners";

interface IdleControlStatus {
	status: "idle";
}

interface LoadingControlStatus {
	status: "loading";
}

interface CompleteControlStatus {
	status: "complete";
}

interface FailedControlStatus {
	status: "error";
	error: string;
}

interface Control {
	status: ControlStatus;
	onAction: () => void;
}

interface ControlProps {
	markTaken: Control;
	markSkipped: Control;
}

interface ControlButtonProps {
	color: string;
	control: Control;
}

const getControlIcon = (
	status: ControlStatus
): React.ReactElement | undefined => {
	switch (status.status) {
		case "error":
			return <WarningIcon />;
		case "complete":
			return <CheckIcon />;
		default:
			return undefined;
	}
};

/**
 * The status of an individual control
 */
export type ControlStatus =
	| IdleControlStatus
	| LoadingControlStatus
	| CompleteControlStatus
	| FailedControlStatus;

const ControlButton = ({
	color,
	control,
	children,
}: React.PropsWithChildren<ControlButtonProps>) => {
	const loader = <BeatLoader size={8} color={color} />;
	const controlIcon = <Fade in={true}>{getControlIcon(control.status)}</Fade>;

	return (
		<Button
			colorScheme={color}
			variant="outline"
			onClick={control.onAction}
			leftIcon={controlIcon}
			isLoading={control.status.status === "loading"}
			spinner={loader}
		>
			{children}
		</Button>
	);
};

const Controls = (controls: ControlProps) => (
	<Stack justifyContent="center">
		<ControlButton color="teal" control={controls.markTaken}>
			Mark taken
		</ControlButton>

		<ControlButton color="red" control={controls.markSkipped}>
			Skip today
		</ControlButton>
	</Stack>
);

export default Controls;
