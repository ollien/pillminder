export function makeErrorString(err: Error | unknown): string {
	if (err instanceof Error && err.cause != null) {
		return `${err.message}: ${makeErrorString(err.cause)}`;
	} else if (err instanceof Error) {
		return err.message;
	} else {
		return `${err}`;
	}
}
