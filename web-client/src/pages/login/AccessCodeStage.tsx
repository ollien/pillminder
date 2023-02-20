import {
	FormControl,
	FormErrorMessage,
	FormLabel,
	Input,
	Text,
} from "@chakra-ui/react";
import { Field, FieldProps } from "formik";
import {
	exchangeAccessCode,
	TokenInformation,
} from "pillminder-webclient/src/lib/api";
import FormStage from "pillminder-webclient/src/pages/login/FormStage";
import React from "react";

interface AccessCodeStageProps {
	onValidLogin: (tokenInfo: TokenInformation) => void;
}

interface FormData {
	accessCode: string;
}

const validateAccessCode = (value: string) => {
	if (/^\d{6}$/.test(value)) {
		return undefined;
	}

	return "Access code must be six digits";
};

const AccessCodeStage = ({ onValidLogin }: AccessCodeStageProps) => {
	const submit = ({ accessCode }: FormData) => {
		return exchangeAccessCode(accessCode).then(onValidLogin);
	};

	return (
		<FormStage<FormData> initialData={{ accessCode: "" }} onSubmit={submit}>
			<Text marginBottom={8} fontWeight="bold" textAlign="center">
				An access code has been sent to your device.
			</Text>
			<Field name="accessCode" validate={validateAccessCode}>
				{({ field, form }: FieldProps) => (
					<FormControl
						isInvalid={!!form.errors.accessCode && !!form.touched.accessCode}
					>
						<FormLabel>Access code</FormLabel>
						<FormErrorMessage>
							{form.errors.accessCode?.toString()}
						</FormErrorMessage>
						<Input {...field} placeholder="012345"></Input>
					</FormControl>
				)}
			</Field>
		</FormStage>
	);
};

export default AccessCodeStage;
