import LoginForm from "./LoginForm";
import {
	Card,
	CardBody,
	CardHeader,
	Center,
	Container,
	Heading,
} from "@chakra-ui/react";
import React from "react";

const BACKGROUND_COLOR = "#37474F";

const Login = () => (
	<Center h="100%" flexDirection="column" backgroundColor={BACKGROUND_COLOR}>
		<Container paddingTop={2}>
			<Card backgroundColor="white" shadow="2xl">
				<CardHeader>
					<Heading size="md">Welcome to Pillminder</Heading>
				</CardHeader>
				<CardBody>
					<LoginForm></LoginForm>
				</CardBody>
			</Card>
		</Container>
	</Center>
);

export default Login;
