import {
	Card,
	CardBody,
	CardHeader,
	Center,
	Container,
	Heading,
} from "@chakra-ui/react";
import colors from "pillminder-webclient/src/pages/_common/colors";
import LoginForm from "pillminder-webclient/src/pages/login/LoginForm";
import * as React from "react";

const Login = () => (
	<Center h="100%" flexDirection="column" backgroundColor={colors.BACKGROUND}>
		<Container>
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
