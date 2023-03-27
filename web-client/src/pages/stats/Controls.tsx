import { CheckIcon, WarningIcon } from "@chakra-ui/icons";
import {
	AlertDialog,
	AlertDialogBody,
	AlertDialogContent,
	AlertDialogFooter,
	AlertDialogHeader,
	AlertDialogOverlay,
	Button,
	Fade,
	Stack,
	useDisclosure,
} from "@chakra-ui/react";
import React, { useRef } from "react";
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

interface SkipDoseDialogProps {
	isOpen: boolean;
	close: () => void;
	onConfirm: () => void;
}

interface ControlButtonProps {
	color: string;
	control: Control;
}
/**
 * The status of an individual control
 */
export type ControlStatus =
	| IdleControlStatus
	| LoadingControlStatus
	| CompleteControlStatus
	| FailedControlStatus;

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

const wrapControlAction = (
	control: Control,
	onAction: () => void
): Control => ({
	...control,
	onAction,
});

const SkipDoseDialog = ({ isOpen, close, onConfirm }: SkipDoseDialogProps) => {
	// Passing null is necessary here to satisfy the type checker
	// https://github.com/chakra-ui/chakra-ui/discussions/2936
	const cancelRef = useRef<HTMLButtonElement>(null);
	const closeAndConfirm = () => {
		close();
		onConfirm();
	};

	const headerMsg = "Skip today?";
	const confirmationMessage =
		"Are you sure you want to skip today's medication? You will not receive any notifications for it today.";

	return (
		<AlertDialog
			isCentered
			leastDestructiveRef={cancelRef}
			isOpen={isOpen}
			onClose={close}
		>
			<AlertDialogOverlay />
			<AlertDialogContent>
				<AlertDialogHeader>{headerMsg}</AlertDialogHeader>
				<AlertDialogBody>{confirmationMessage}</AlertDialogBody>
				<AlertDialogFooter>
					<Button ref={cancelRef} onClick={close}>
						Cancel
					</Button>
					<Button colorScheme="red" marginLeft={3} onClick={closeAndConfirm}>
						Skip
					</Button>
				</AlertDialogFooter>
			</AlertDialogContent>
		</AlertDialog>
	);
};

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

const Controls = (controls: ControlProps) => {
	const {
		isOpen: isSkipDialogOpen,
		onOpen: openSkipDialog,
		onClose: closeSkipDialog,
	} = useDisclosure();

	const confirmationSkipAction = wrapControlAction(
		controls.markSkipped,
		openSkipDialog
	);

	return (
		<>
			<Stack justifyContent="center">
				<ControlButton color="teal" control={controls.markTaken}>
					Mark taken
				</ControlButton>

				<ControlButton color="red" control={confirmationSkipAction}>
					Skip today
				</ControlButton>
			</Stack>
			<SkipDoseDialog
				isOpen={isSkipDialogOpen}
				close={closeSkipDialog}
				onConfirm={controls.markSkipped.onAction}
			/>
		</>
	);
};

export default Controls;
