import { Center } from "@chakra-ui/react";
import * as React from "react";
import { BounceLoader } from "react-spinners";

interface LoadingOrProps {
	isLoading: boolean;
}

const LoadingOr = ({
	isLoading,
	children,
}: React.PropsWithChildren<LoadingOrProps>) => {
	if (isLoading) {
		return (
			<Center>
				<BounceLoader></BounceLoader>
			</Center>
		);
	} else {
		return <>{children}</>;
	}
};

export default LoadingOr;
