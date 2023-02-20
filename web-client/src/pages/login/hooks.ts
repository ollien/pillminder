import { useState } from "react";

/**
 * Make submission a bit more "comfy" by preventing flicker when a value is submitted too quickly.
 * On fast network connections, a form may submit really fast, so a small amount of "comfort time"
 * may make that a bit prettier.
 *
 * @param waitMs The number of ms to wait before setting the value back to false
 *
 * @returns A boolean which indicates whether or not we're still "waiting", and a function to set
 * a beginning of the "wait"
 */
export const useComfortWait = (waitMs: number = 250): [boolean, () => void] => {
	const [comfortWaiting, setComfortWaiting] = useState(false);
	const setWaiting = () => {
		setComfortWaiting(true);
		setTimeout(() => {
			setComfortWaiting(false);
		}, waitMs);
	};

	return [comfortWaiting, setWaiting];
};
