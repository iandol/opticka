% ========================================================================
%> @class OptickaGUITest
%> @brief Class-based unit tests for the opticka GUI wrapper.
%>
%> Opens the opticka GUI, loads a protocol from CoreProtocols, configures
%> a dummy iRec eyetracker, sets nBlocks, and runs a behavioural task
%> using xdotool to keep the mouse at the fixation point.
%>
%> Run with:
%>   >> runtests('tests/OptickaGUITest.m')
%>   >> runtests('tests/OptickaGUITest.m', '-IncludeTag', 'hardware')
%>
%> Copyright (c) 2026 Ian Max Andolina — LGPL3, see LICENCE.md
% ========================================================================
classdef OptickaGUITest < matlab.unittest.TestCase

	properties
		%> path to xdotool binary for mouse/keyboard automation
		xdotoolPath = '/usr/bin/xdotool'
		%> original directory before test, restored in teardown
		origDir char
	end

	methods (TestClassSetup)
		function setupPath(testCase)
			[ret, out] = system('which xdotool 2>/dev/null');
			if ret == 0 && ~isempty(strip(out))
				testCase.xdotoolPath = strip(out);
			end
		end
	end

	methods(Test, TestTags = {'CI'})

		function testUIAlone(testCase)
			testCase.origDir = pwd;
		end

	end

	% ===================================================================
	% HARDWARE TESTS
	% ===================================================================
	methods (Test, TestTags = {'hardware'})

		% ===============================================================
		%> @brief Open GUI, load OrientationTuning, set nBlocks=2, run task
		%> with dummy iRec eyetracker. Mouse stays at center (0,0 deg)
		%> so the dummy eyetracker detects fixation. xdotool sends 'p'
		%> after the screen opens to unpause the state machine.
		% ===============================================================
		function testLoadProtocolAndRunTask(testCase)
			% ----- CI + xdotool guards -----
			assumeFalse(testCase, ~isempty(getenv('GITHUB_ACTIONS')), ...
				'Skip in CI: requires display + PTB');
			assumeTrue(testCase, exist(testCase.xdotoolPath, 'file') == 2 ...
				|| ~isempty(which('xdotool')), ...
				'xdotool must be installed for mouse/keyboard automation');

			testCase.origDir = pwd;

			% ===========================================================
			% 1. Open the opticka GUI
			% ===========================================================
			o = opticka('verbose', false);
			verifyTrue(testCase, isa(o.r, 'runExperiment'), ...
				'GUI should create a runExperiment object');
			verifyTrue(testCase, ~isempty(o.ui), ...
				'GUI should have a ui struct with handles');

			% ===========================================================
			% 2. Load a protocol via the GUI
			% ===========================================================
			corePath = fullfile(o.paths.root, 'CoreProtocols');
			verifyTrue(testCase, exist(corePath, 'dir') == 7, ...
				'CoreProtocols folder should exist');
			o.store.protocolsPath = corePath;
			refreshProtocolsList(o, corePath);
			o.ui.OKProtocolsList.Value = 'OrientationTuning.mat';
			loadProtocol(o, true);
			cd(testCase.origDir); % loadProtocol changes directory, restore it
			drawnow();
			WaitSecs(1);
			verifyTrue(testCase, o.r.stimuli.n > 0, ...
				'protocol should have at least one stimulus');
			verifyTrue(testCase, ~isempty(o.r.stateInfoFile) ...
				&& exist(o.r.stateInfoFile, 'file') == 2, ...
				'stateInfoFile should exist after load');
			verifyTrue(testCase, isa(o.r.task, 'taskSequence'), ...
				'taskSequence should exist after load');
			verifyTrue(testCase, o.r.task.nVars > 0, ...
				'task should have variables defined');

			% ===========================================================
			% 3. Configure for dummy test run
			% ===========================================================
			o.r.mock = true; % enable mocking to bypass keyboard and ui
			o.r.debug = true;
			o.r.eyetracker = struct('device', 'irec', 'dummy', true, ...
				'eyelinkSettings', [], 'tobiiSettings', [], ...
				'irecSettings', [], 'pupilcoreSettings', []);
			o.r.strobe.device = '';
			o.r.reward.device = '';
			o.r.control.device = '';
			o.r.sessionData.saveData = false;
			o.r.sessionData.useAlyx = false;
			o.r.screen.windowed = [0 0 800 600];
			o.r.screen.disableSyncTests = true;
			o.r.screen.bitDepth = '8Bit';
			o.r.screen.verbose = false;
			o.r.logFrames = false;
			o.r.verbose = false;

			% ===========================================================
			% 4. Set nBlocks = 2 and randomise
			% ===========================================================
			o.r.task.nBlocks = 1;
			randomiseTask(o.r.task);
			expectedTrials = o.r.task.nRuns;
			verifyGreaterThan(testCase, expectedTrials, 0, ...
				'task should have at least one trial');

			% ===========================================================
			% 5. Pre-position mouse at screen center via xdotool
			% ===========================================================
			wRect = o.r.screen.windowed;
			cx = round((wRect(3) - wRect(1)) / 2); % 400
			cy = round((wRect(4) - wRect(2)) / 2); % 300
			scr = o.r.screen.screen;
			system(sprintf('%s mousemove --screen %d %d %d', ...
				testCase.xdotoolPath, scr, cx, cy));

			% ===========================================================
			% 6. Schedule 'p' keypress to unpause the state machine.
			%    The task starts in 'pause' state; after ~3s the PTB
			%    window is open and warmup is done, so we send 'p'.
			%    runTask is blocking, so this runs in the background.
			% ===========================================================
			%system(sprintf('(sleep 3 && %s type p) &', ...
			%	testCase.xdotoolPath));

			% ===========================================================
			% 7. Run the behavioural task (blocks until completion)
			% ===========================================================
			runTask(o.r);

			% ===========================================================
			% 8. Verify results
			% ===========================================================
			verifyFalse(testCase, o.r.stateMachine.isRunning, ...
				'stateMachine should have stopped');
			verifyEqual(testCase, o.r.task.totalRuns, expectedTrials, ...
				'all trials should have been completed');
			verifyTrue(testCase, o.r.stateMachine.log.n > 0, ...
				'stateMachine log should have entries');
			verifyTrue(testCase, ~isempty(o.r.behaviouralRecord), ...
				'behaviouralRecord should exist');
			verifyTrue(testCase, ~isempty(o.r.task.outValues), ...
				'task output values should exist');

			o.ui.quit();

		end
	end
end