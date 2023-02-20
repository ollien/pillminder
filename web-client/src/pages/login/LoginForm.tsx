import AccessCodeStage from "./AccessCodeStage";
import { SlideFade } from "@chakra-ui/react";
import { TokenInformation } from "pillminder-webclient/src/lib/api";
import PillminderStage from "pillminder-webclient/src/pages/login/PillminderStage";
import React, { useState } from "react";

const redirectToStatsPage = () => {
	window.location.href = "stats.html";
};

const LoginForm = () => {
	const [stageIdx, setStageIdx] = useState(0);
	const stages = [
		<PillminderStage
			key="pillminder-stage"
			onAccessCode={() => {
				setStageIdx(stageIdx + 1);
			}}
		/>,
		<AccessCodeStage
			key="access-code-stage"
			onValidLogin={({ token, pillminder }: TokenInformation) => {
				localStorage.setItem("pillminder", pillminder);
				localStorage.setItem("token", token);
				redirectToStatsPage();
			}}
		/>,
	];

	const currentStage = stages[stageIdx];
	if (stageIdx === 0) {
		return currentStage;
	} else {
		return (
			<SlideFade in={true} key={`stage-${stageIdx}`}>
				{currentStage}
			</SlideFade>
		);
	}
};

export default LoginForm;
