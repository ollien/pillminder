import React from "react";
import { BeatLoader } from "react-spinners";
import {
	Button,
	FormControl,
	FormErrorMessage,
	FormLabel,
	Input,
} from "@chakra-ui/react";
import { Field, Form, Formik, FieldProps, FormikBag } from "formik";

const validateRequired = (value: string) => {
	if (value) {
		return undefined;
	}

	return "Required field";
};

interface FormData {
	pillminder: string;
}

const LoginForm = () => {
	const submit = (values: FormData, { setSubmitting }) => {
		console.log(values);
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
