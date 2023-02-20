import { useComfortWait } from "./hooks";
import {
	Center,
	FormControl,
	FormErrorMessage,
	FormLabel,
	Input,
} from "@chakra-ui/react";
import {
	Field,
	Form,
	Formik,
	FieldProps,
	FormikHelpers,
	FormikProps,
} from "formik";
import { requestAccessCode } from "pillminder-webclient/src/lib/api";
import ErrorText from "pillminder-webclient/src/pages/_common/ErrorText";
import SubmitButton from "pillminder-webclient/src/pages/login/SubmitButton";
import React from "react";

interface FormData {
	pillminder: string;
}

const validateRequired = (value: string) => {
	if (value) {
		return undefined;
	}

	return "Required field";
};

const PillminderForm = ({ onAccessCode }: { onAccessCode: () => void }) => {
	// comfortSubmitting is a helper to make submitting a little more "friendly". If the response
	// comes back too quickly, we don't want the loading button to flicker, so we use this as a way
	// to "debounce" it
	const [comfortSubmitting, setComfortSubmitting] = useComfortWait();

	const submit = (
		{ pillminder }: FormData,
		formHelpers: FormikHelpers<FormData>
	) => {
		setComfortSubmitting();

		requestAccessCode(pillminder)
			.then(onAccessCode)
			.catch((err) => {
				formHelpers.setSubmitting(false);
				formHelpers.setStatus({ submitError: err?.message ?? err.toString() });
			});
	};

	const isSubmitting = (formik: FormikProps<FormData>) => {
		return formik.isSubmitting || comfortSubmitting;
	};

	const getSubmissionError = (formik: FormikProps<FormData>) => {
		if (isSubmitting(formik)) {
			return null;
		}

		return formik.status?.submitError ?? null;
	};

	return (
		<Formik<FormData> initialValues={{ pillminder: "" }} onSubmit={submit}>
			{(formik) => {
				const submitError = getSubmissionError(formik);
				const submitErrorText = submitError ? (
					<ErrorText>{`${submitError}. Please try again`}</ErrorText>
				) : null;

				return (
					<>
						<Center>{submitErrorText}</Center>
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
											{form.errors.pillminder?.toString()}
										</FormErrorMessage>
										<Input
											{...field}
											placeholder="My Awesome Pillminder"
										></Input>
									</FormControl>
								)}
							</Field>
							<FormControl>
								<SubmitButton
									isSubmitting={isSubmitting(formik)}
									disabled={!formik.dirty || !formik.isValid}
								>
									Login
								</SubmitButton>
							</FormControl>
						</Form>
					</>
				);
			}}
		</Formik>
	);
};

export default PillminderForm;
