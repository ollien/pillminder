import {
	Button,
	FormControl,
	FormErrorMessage,
	FormLabel,
	Input,
} from "@chakra-ui/react";
import { Field, Form, Formik, FieldProps } from "formik";
import * as React from "react";
import { BeatLoader } from "react-spinners";

interface FormData {
	pillminder: string;
}

const validateRequired = (value: string) => {
	if (value) {
		return undefined;
	}

	return "Required field";
};

const redirectToStatsPage = (pillminder: string) => {
	// TODO: This is a bit silly, but will work for an initial prototype.
	// In the future, I want this to send to the webserver so we can have some kind of authentication,
	// and let that direct us to the stats page.
	window.location.href =
		"stats.html?pillminder=" + encodeURIComponent(pillminder);
};

const LoginForm = () => {
	const submit = (values: FormData) => {
		redirectToStatsPage(values.pillminder);
	};

	return (
		<Formik<FormData> initialValues={{ pillminder: "" }} onSubmit={submit}>
			{(formik) => (
				<Form>
					<Field name="pillminder" validate={validateRequired}>
						{({ field, form }: FieldProps) => (
							<FormControl
								isInvalid={
									!!form.errors.pillminder && !!form.touched.pillminder
								}
							>
								<FormLabel>Pillminder name</FormLabel>
								<FormErrorMessage>
									{form.errors.pillminder?.toString() ?? ""}
								</FormErrorMessage>
								<Input {...field} placeholder="My Awesome Pillminder"></Input>
							</FormControl>
						)}
					</Field>
					<FormControl>
						<Button
							isLoading={formik.isSubmitting}
							spinner={<BeatLoader size={8} color="white" />}
							width="100%"
							marginTop={4}
							type="submit"
							colorScheme="teal"
						>
							Log In
						</Button>
					</FormControl>
				</Form>
			)}
		</Formik>
	);
};

export default LoginForm;
