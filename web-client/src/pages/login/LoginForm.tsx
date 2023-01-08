import React, { useState } from "react";
import { BeatLoader } from "react-spinners";
import { Button, Flex, FormControl, FormLabel, Input } from "@chakra-ui/react";

const LoginForm = () => {
	const [isLoading, setIsLoading] = useState<boolean>(false);
	const submit = () => {
		setIsLoading(true);
	};

	return (
		<>
			<FormControl>
				<FormLabel>Pillminder name</FormLabel>
				<Input placeholder="My Awesome Pillminder"></Input>
			</FormControl>
			<FormControl>
				<Button
					isLoading={isLoading}
					onClick={submit}
					spinner={<BeatLoader size={8} color="white" />}
					width="100%"
					marginTop={4}
					type="submit"
					colorScheme="teal"
				>
					Log In
				</Button>
			</FormControl>
		</>
	);
};

export default LoginForm;
