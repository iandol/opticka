function runScreenHardwareTests()
%> runScreenHardwareTests — CI entry point for the ScreenManagerTest hardware suite.
%>
%> Runs the hardware-tagged tests in tests/ScreenManagerTest.m against the
%> patched Screen.mexa64 installed into /tmp/PTB/Psychtoolbox/PsychBasic, and
%> fails if any test fails OR is skipped.
%>
%> The skip check matters: the hardware tests call
%>   assumeFalse(testCase, ~isempty(getenv('GITHUB_ACTIONS')), 'Skip in CI')
%> so on a GitHub runner they would all report as Incomplete and the job would
%> go green without testing anything. The workflow clears GITHUB_ACTIONS for
%> this job; if that ever stops working, this function errors instead of
%> reporting a false pass.
%>
%> Usage (in the workflow):
%>   matlab -batch "addpath('ci'); runScreenHardwareTests"

	root = fileparts(fileparts(mfilename('fullpath'))); %> ci/ -> repository root
	addpath(root);
	setupOptickaCI();

	suiteFile = fullfile(root, 'tests', 'ScreenManagerTest.m');
	suite = matlab.unittest.TestSuite.fromFile(suiteFile, 'Tag', 'hardware');

	if isempty(suite)
		error('runScreenHardwareTests:NoTests', ...
			'No hardware-tagged tests found in %s', suiteFile);
	end

	fprintf('runScreenHardwareTests: running %d hardware tests\n', numel(suite));
	runner = matlab.unittest.TestRunner.withTextOutput;
	results = runner.run(suite);

	nFailed = sum([results.Failed]);
	nSkipped = sum([results.Incomplete]);
	nPassed = numel(results) - nFailed - nSkipped;

	fprintf('runScreenHardwareTests: %d passed, %d skipped, %d failed\n', ...
		nPassed, nSkipped, nFailed);

	if nSkipped > 0
		error('runScreenHardwareTests:Skipped', ...
			['%d hardware tests were skipped (Incomplete). The job is meant to run ' ...
			 'them with GITHUB_ACTIONS cleared - check that the workflow still does.'], ...
			nSkipped);
	end

	if nFailed > 0
		error('runScreenHardwareTests:Failed', '%d hardware tests failed', nFailed);
	end

	fprintf('runScreenHardwareTests: all %d hardware tests passed\n', nPassed);
end
