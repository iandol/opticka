function PsychJavaSwingCleanup()
	if isMATLABReleaseOlderThan("R2025a")
		oldcd = pwd;
		cd([PsychtoolboxRoot 'PsychJava']);
		PsychJavaSwingCleanup;
		cd(pwd);
	end
end