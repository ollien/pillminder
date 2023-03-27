export function makeErrorString(err: Error | unknown): string {
	if (err instanceof Error && err.cause != null) {
		return `${err.message}: ${makeErrorString(err.cause)}`;
	} else if (err instanceof Error) {
		return err.message;
	} else {
		return `${err}`;
	}
}

/**
 * Assert that a given branch is unreachable. This is primarily intended to be used for type checking, but can
 * assert at runtime.
 */
export function assertUnreachable<T>(x: never): T {
	throw Error(`assertUnreachable was called with ${x}`);
}
