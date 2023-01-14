import { CardBody, CardHeader, Heading } from "@chakra-ui/react";
import CardPage from "pillminder-webclient/src/pages/_common/CardPage";
import LoginForm from "pillminder-webclient/src/pages/login/LoginForm";
import React from "react";

const Login = () => (
	<CardPage>
		<CardHeader>
			<Heading size="md">Welcome to Pillminder</Heading>
		</CardHeader>
		<CardBody>
			<LoginForm></LoginForm>
		</CardBody>
	</CardPage>
);

export default Login;
