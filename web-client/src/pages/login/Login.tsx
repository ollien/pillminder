import { CardBody, CardHeader, Heading } from "@chakra-ui/react";
import CardError from "pillminder-webclient/src/pages/_common/CardError";
import CardPage from "pillminder-webclient/src/pages/_common/CardPage";
import { makeErrorString } from "pillminder-webclient/src/pages/_common/errors";
import LoginForm from "pillminder-webclient/src/pages/login/LoginForm";
import React from "react";
import { ErrorBoundary, FallbackProps } from "react-error-boundary";

const BoundaryError = ({ error }: FallbackProps) => {
	return <CardError>{makeErrorString(error)}</CardError>;
};

const Login = () => (
	<CardPage>
		<CardHeader>
			<Heading size="md">Welcome to Pillminder</Heading>
		</CardHeader>
		<CardBody>
			<ErrorBoundary FallbackComponent={BoundaryError}>
				<LoginForm />
			</ErrorBoundary>
		</CardBody>
	</CardPage>
);

export default Login;
