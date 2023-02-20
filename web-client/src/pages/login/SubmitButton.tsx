import { Button } from "@chakra-ui/react";
import React from "react";
import { BeatLoader } from "react-spinners";

interface SubmitButtonProps {
	isSubmitting: boolean;
	disabled?: boolean;
}

const SubmitButton = ({
	isSubmitting,
	disabled,
	children,
}: React.PropsWithChildren<SubmitButtonProps>) => {
	return (
		<Button
			disabled={disabled ?? false}
			isLoading={isSubmitting}
			spinner={<BeatLoader size={8} color="white" />}
			width="100%"
			marginTop={4}
			type="submit"
			colorScheme="teal"
		>
			{children ?? "Submit"}
		</Button>
	);
};

export default SubmitButton;
