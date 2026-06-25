function setupCI()
	%> setupCI — Configure the MATLAB path for CI without PTB's interactive
	%> SetupPsychtoolbox (which fails on CI due to savepath permissions).
	%>
	%> This script is the CI equivalent of:
	%>   1. Cloning/installing Psychtoolbox
	%>   2. Running SetupPsychtoolbox(1) — but without the savepath failure
	%>   3. Running addOptickaToPath(true) — but safe-guarded against savepath
	%>
	%> Usage in GitHub Actions:
	%>   matlab-actions/run-command@v3
	%>     command: setupCI; runOptickaTests;
	%>
	%> PREREQUISITES (done before this in the workflow YAML):
	%>   - PTB cloned to /tmp/PTB
	%>   - Xvfb running on :99
	%>
	%> Copyright (c) 2026 Ian Max Andolina — LGPL3, see LICENCE.md

	% --- Step 1: Add Psychtoolbox to the path ---
	ptbRoot = '/tmp/PTB/Psychtoolbox';
	if ~isfolder(ptbRoot)
		error('setupCI:PTBNotFound', ...
			'Psychtoolbox not found at %s. Clone it first in the workflow.', ptbRoot);
	end
	addpath(genpath(ptbRoot));
	fprintf('setupCI: Added PTB from %s to MATLAB path.\n', ptbRoot);

	% --- Step 2: Add Opticka to the path ---
	% addOptickaToPath is in the repo root (pwd on CI).
	% It calls savepath which fails on CI (no write permission to
	% MATLAB's pathdef.m). The failure prints a warning but does NOT
	% error — addOptickaToPath ignores savepath's return value.
	% All path changes persist for the duration of this MATLAB session,
	% which is all we need for running tests.
	addOptickaToPath();

	% --- Step 3: Add the tests directory ---
	% addOptickaToPath explicitly excludes tests/ from the path.
	% We need it for the test runner and test classes.
	cd(optickaRoot);
	if isfolder('tests')
		addpath('tests');
	end

	% --- Step 4: Verify critical PTB functions are available ---
	if exist('GetSecs', 'file') ~= 3  % 3 = MEX-file
		warning('setupCI:GetSecsNotMEX', ...
			'GetSecs is not a MEX file — timing precision will be reduced.');
	end
	if exist('WaitSecs', 'file') ~= 3
		warning('setupCI:WaitSecsNotMEX', ...
			'WaitSecs is not a MEX file — wait precision will be reduced.');
	end

	fprintf('setupCI: Path configuration complete.\n');
end
