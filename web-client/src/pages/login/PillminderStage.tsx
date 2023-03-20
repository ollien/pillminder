import {
	FormControl,
	FormErrorMessage,
	FormLabel,
	Input,
} from "@chakra-ui/react";
import { Field, FieldProps } from "formik";
import { APIClient } from "pillminder-webclient/src/lib/api";
import FormStage from "pillminder-webclient/src/pages/login/FormStage";
import React from "react";

interface PillminderFormProps {
	onAccessCode: () => void;
}

interface FormData {
	pillminder: string;
}

const validateRequired = (value: string) => {
	if (value) {
		return undefined;
	}

	return "Required field";
};

const PillminderStage = ({ onAccessCode }: PillminderFormProps) => {
	const client = new APIClient();
	const submit = async ({ pillminder }: FormData) => {
		await client.requestAccessCode(pillminder);
		onAccessCode();
	};

	return (
		<FormStage<FormData>
			initialData={{ pillminder: "" }}
			onSubmit={submit}
			submitButtonText="Login"
		>
			<Field name="pillminder" validate={validateRequired}>
				{({ field, form }: FieldProps) => (
					<FormControl
						isInvalid={!!form.errors.pillminder && !!form.touched.pillminder}
					>
						<FormLabel>Pillminder name</FormLabel>
						<FormErrorMessage>
							{form.errors.pillminder?.toString()}
						</FormErrorMessage>
						<Input {...field} placeholder="My Awesome Pillminder"></Input>
					</FormControl>
				)}
			</Field>
		</FormStage>
	);
};

export default PillminderStage;
