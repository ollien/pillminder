import { DateTime } from "luxon";

/**
 * A summary of statistics about a user's medication
 */
export interface StatsSummary {
	streakLength: number;
	lastTaken: DateTime | null;
}

/**
 * A summary of statistics about a user's medication
 */
export interface TakenDate {
	date: DateTime;
	taken: boolean;
}

/**
 * Get statistics about the given pillminder
 * @param pillminder The pillminder to get a summary for
 * @returns A summary of the given pillminder. Note that if a pillminder is not found, empty information
 *          will be returned.
 */
export async function getStatsSummary(
	pillminder: string
): Promise<StatsSummary> {
	const res = await fetch(`/stats/${encodeURIComponent(pillminder)}/summary`);

	if (res.status !== 200) {
		// This api doesn't return any real errors, so we can just give a generic message
		throw new Error("Failed to load streak");
	}

	const resJson = await res.json();

	return {
		streakLength: resJson.streak_length,
		lastTaken: parseDate(resJson.last_taken_on),
	};
}

/**
 * Get the recent dates that the medication was taken
 * @param pillminder The pillminder to get history for
 * @returns Recent dates that the medication were taken. These will be consecutive.
 */
export async function getTakenDates(pillminder: string): Promise<TakenDate[]> {
	const res = await fetch(`/stats/${encodeURIComponent(pillminder)}/history`);
	if (res.status !== 200) {
		throw new Error("Failed to load taken dates");
	}

	const resJson = await res.json();
	const sentTakenDates: Record<string, boolean> | undefined =
		resJson.taken_dates;
	if (sentTakenDates === undefined) {
		// This is a defensive assertion on the response
		throw new Error("Invalid stats log returned from server");
	}

	return Object.entries(sentTakenDates).map(([rawDate, taken]) => ({
		taken,
		date: parseDate(rawDate),
	}));
}

function parseDate(date: null): null;
function parseDate(date: string): DateTime;
function parseDate(date: string | null): DateTime | null {
	if (date == null) {
		return null;
	}

	const parsed = DateTime.fromISO(date);
	if (!parsed.isValid) {
		throw Error(`Invalid date returned from server (${date})`);
	}

	return parsed;
}
