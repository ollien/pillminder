import { useComfortWait } from "./hooks";
import { Center, FormControl } from "@chakra-ui/react";
import { Form, Formik, FormikHelpers, FormikProps } from "formik";
import ErrorText from "pillminder-webclient/src/pages/_common/ErrorText";
import SubmitButton from "pillminder-webclient/src/pages/login/SubmitButton";
import React from "react";

interface FormStageProps<T> {
	initialData: T;
	onSubmit: (data: T) => Promise<void>;
	submitButtonText?: string;
	children: ((props: FormikProps<T>) => React.ReactNode) | React.ReactNode;
}

// eslint-disable-next-line @typescript-eslint/no-explicit-any
const FormStage = <FormData extends Record<string, any>>({
	initialData,
	onSubmit,
	submitButtonText,
	children,
}: FormStageProps<FormData>) => {
	// comfortSubmitting is a helper to make submitting a little more "friendly". If the response
	// comes back too quickly, we don't want the loading button to flicker, so we use this as a way
	// to "debounce" it
	const [comfortSubmitting, setComfortSubmitting] = useComfortWait();

	const submit = (data: FormData, formHelpers: FormikHelpers<FormData>) => {
		setComfortSubmitting();

		onSubmit(data).catch((err) => {
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
		<Formik<FormData> initialValues={initialData} onSubmit={submit}>
			{(formik) => {
				const submitError = getSubmissionError(formik);
				const submitErrorText = submitError ? (
					<ErrorText>{`${submitError}. Please try again`}</ErrorText>
				) : null;

				return (
					<>
						<Center>{submitErrorText}</Center>
						<Form>
							{typeof children === "function" ? children(formik) : children}

							<FormControl>
								<SubmitButton
									isSubmitting={isSubmitting(formik)}
									disabled={!formik.dirty || !formik.isValid}
								>
									{submitButtonText ?? "Submit"}
								</SubmitButton>
							</FormControl>
						</Form>
					</>
				);
			}}
		</Formik>
	);
};

export default FormStage;
