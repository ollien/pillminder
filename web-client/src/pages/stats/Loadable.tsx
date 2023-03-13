import { Center } from "@chakra-ui/react";
import ErrorText from "pillminder-webclient/src/pages/_common/ErrorText";
import React from "react";
import { BounceLoader } from "react-spinners";

interface LoadableProps {
	isLoading: boolean;
	error: string | null;
}

const Loadable = ({
	isLoading,
	error,
	children,
}: React.PropsWithChildren<LoadableProps>) => {
	if (isLoading) {
		return (
			<Center>
				<BounceLoader></BounceLoader>
			</Center>
		);
	} else if (error) {
		return (
			<Center>
				<ErrorText>{error}</ErrorText>
			</Center>
		);
	} else {
		return <>{children}</>;
	}
};

export default Loadable;
