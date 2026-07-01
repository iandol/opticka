% ========================================================================
%> @class RunExperimentTest
%> @brief Class-based unit tests for runExperiment.
%>
%> Tests construction, property defaults, set methods, and many public
%> methods that do not require a PTB screen. CI-safe tests run without
%> PTB; hardware-tagged tests exercise the full pipeline with a window.
%>
%> Run with:
%>   >> runtests('tests/RunExperimentTest.m')
%>   >> runtests('tests/RunExperimentTest.m', '-ExcludeTag', 'hardware')
%>
%> Copyright (c) 2026 Ian Max Andolina — LGPL3, see LICENCE.md
% ========================================================================
classdef RunExperimentTest < matlab.unittest.TestCase

	methods (TestClassSetup)
		function setupPath(testCase)
			addOptickaToPath;
		end
	end

	% ===================================================================
	% CI-SAFE TESTS
	% ===================================================================
	methods (Test, TestTags = {'CI'})

		% --- construction defaults ---
		function testConstructionDefaults(testCase)
			rE = runExperiment('verbose', false);
			verifyFalse(testCase, rE.isRunning, 'isRunning false initially');
			verifyEqual(testCase, rE.stateMachineClass, 'stateMachine', ...
				'default stateMachineClass');
			verifyEqual(testCase, rE.verbose, false, 'verbose false');
			verifyEqual(testCase, rE.debug, false, 'debug false');
			verifyEqual(testCase, rE.logFrames, true, 'logFrames true');
			verifyEqual(testCase, rE.sessionData.subjectName, 'Simulcra', ...
				'default subjectName');
			verifyEqual(testCase, rE.strobe.device, '', 'default strobe device empty');
			verifyEqual(testCase, rE.reward.device, '', 'default reward device empty');
			verifyTrue(testCase, rE.eyetracker.dummy, 'default eyetracker dummy true');
			verifyEqual(testCase, rE.eyetracker.device, '', 'default tracker device empty');
			verifyEqual(testCase, rE.touch.device, '', 'default touch device empty');
			verifyEqual(testCase, rE.control.device, '', 'default control device empty');
		end

		% --- constructor with custom properties ---
		function testConstructorCustomProperties(testCase)
			rE = runExperiment('verbose', true, 'debug', true, ...
				'logFrames', false, 'stateMachineClass', 'stateMachineTree');
			verifyTrue(testCase, rE.verbose, 'verbose set');
			verifyTrue(testCase, rE.debug, 'debug set');
			verifyFalse(testCase, rE.logFrames, 'logFrames set');
			verifyEqual(testCase, rE.stateMachineClass, 'stateMachineTree', ...
				'stateMachineClass set');
		end

		% --- UUID and fullName from optickaCore ---
		function testUUID(testCase)
			rE = runExperiment('verbose', false, 'name', 'TestRun');
			verifyTrue(testCase, ~isempty(rE.uuid), 'UUID not empty');
			rE2 = runExperiment('verbose', false);
			verifyNotEqual(testCase, rE.uuid, rE2.uuid, 'UUIDs unique');
		end

		function testFullName(testCase)
			rE = runExperiment('verbose', false, 'name', 'TestRun');
			verifyTrue(testCase, contains(rE.fullName, 'TestRun'), ...
				'fullName contains name');
			verifyTrue(testCase, contains(rE.fullName, 'runExperiment'), ...
				'fullName contains class');
		end

		% --- set.verbose cascading ---
		function testVerboseCascade(testCase)
			rE = runExperiment('verbose', false);
			rE.task = taskSequence();
			rE.task.verbose = false;
			rE.verbose = true;
			verifyTrue(testCase, rE.verbose, 'verbose set');
			verifyTrue(testCase, rE.task.verbose, 'task inherits verbose');
			rE.verbose = false;
			verifyFalse(testCase, rE.verbose, 'verbose unset');
		end

		% --- set.stimuli with metaStimulus ---
		function testSetStimuliMetaStimulus(testCase)
			rE = runExperiment('verbose', false);
			ms = metaStimulus();
			d = discStimulus('verbose', false);
			ms{1} = d;
			rE.stimuli = ms;
			verifyTrue(testCase, isa(rE.stimuli, 'metaStimulus'), 'stimuli is metaStimulus');
			verifyEqual(testCase, rE.stimuli.n, 1, 'one stimulus');
		end

		% --- set.stimuli with baseStimulus ---
		function testSetStimuliBaseStimulus(testCase)
			rE = runExperiment('verbose', false);
			d = discStimulus('verbose', false);
			try rE.stimuli = d; end %#ok<*TRYNC>
			verifyEmpty(testCase, rE.stimuli, 'should not set a baseStimulus');
		end

		% --- set.stimuli with cell array ---
		function testSetStimuliCell(testCase)
			rE = runExperiment('verbose', false);
			d = discStimulus('verbose', false);
			g = gratingStimulus('verbose', false);
			try rE.stimuli = {d, g}; end
			verifyEmpty(testCase, rE.stimuli, 'should not set a cell array');
		end

		% --- initialise creates defaults ---
		function testInitialiseDefaults(testCase)
			rE = runExperiment('verbose', false);
			rE.mock = true;
			rE.initialise();
			verifyTrue(testCase, isa(rE.stimuli, 'metaStimulus'), 'stimuli created');
			verifyTrue(testCase, isa(rE.task, 'taskSequence'), 'task created');
			verifyTrue(testCase, isa(rE.strobeDevice, 'ioManager'), 'strobeDevice created');
			verifyFalse(testCase, isempty(rE.stateInfoFile), 'stateInfoFile set');
			verifyTrue(testCase, contains(rE.stateInfoFile, 'DefaultStateInfo.m'), ...
				'stateInfoFile is DefaultStateInfo');
		end

		% --- initialise with config options ---
		function testInitialiseWithConfig(testCase)
			rE = runExperiment('verbose', false);
			rE.stimuli = metaStimulus(); % pre-set
			rE.initialise('nostimuli');
			verifyTrue(testCase, isa(rE.stimuli, 'metaStimulus'), 'stimuli preserved');
			rE.initialise('notask');
			verifyTrue(testCase, isa(rE.task, 'taskSequence'), 'task still created');
		end

		% --- refreshScreen without PTB ---
		function testRefreshScreenWithoutPTB(testCase)
			rE = runExperiment('verbose', false);
			s = screenManager('verbose', false);
			rE.screen = s;
			refreshScreen(rE);
			% isPTB is false, so prepareScreen returns early with warning
			verifyTrue(testCase, isstruct(rE.screenVals), 'screenVals is struct');
		end

		% --- noop method ---
		function testNoop(testCase)
			rE = runExperiment('verbose', false);
			noop(rE);
			verifyTrue(testCase, true, 'noop completed');
		end

		% --- enableFlip / disableFlip ---
		function testEnableDisableFlip(testCase)
			rE = runExperiment('verbose', false);
			enableFlip(rE);
			disableFlip(rE);
		end

		% --- needEyeSample ---
		function testNeedEyeSample(testCase)
			rE = runExperiment('verbose', false);
			needEyeSample(rE, true);
			needEyeSample(rE, false);
		end

		% --- doSyncTime ---
		function testDoSyncTime(testCase)
			rE = runExperiment('verbose', false);
			doSyncTime(rE);
		end

		% --- doStrobe ---
		function testDoStrobe(testCase)
			rE = runExperiment('verbose', false);
			doStrobe(rE, true);
			doStrobe(rE, false);
		end

		% --- getTaskIndex without task data ---
		function testGetTaskIndexNoData(testCase)
			rE = runExperiment('verbose', false);
			rE.task = taskSequence();
			idx = getTaskIndex(rE);
			verifyEqual(testCase, idx, -1, 'no data returns -1');
			idx = getTaskIndex(rE, 1);
			verifyEqual(testCase, idx, -1, 'no data at index 1 returns -1');
		end

		% --- checkTaskEnded without stateMachine ---
		function testCheckTaskEndedNoSM(testCase)
			rE = runExperiment('verbose', false);
			rE.task = taskSequence();
			rE.task.nBlocks = 1;
			% no stateMachine, should not error
			checkTaskEnded(rE);
		end

		% --- checkScreenError without screen ---
		function testCheckScreenErrorNoScreen(testCase)
			rE = runExperiment('verbose', false);
			err = false;
			try err = checkScreenError(rE); end
			verifyFalse(testCase, err, 'no error when no screen');
		end

		% --- randomiseTrainingList without thisStim ---
		function testRandomiseTrainingListEmpty(testCase)
			rE = runExperiment('verbose', false);
			randomiseTrainingList(rE);
			verifyTrue(testCase, true, 'no-op completed');
		end

		% --- updateFixationTarget without stimuli ---
		function testUpdateFixationTargetEmpty(testCase)
			rE = runExperiment('verbose', false);
			rE.stimuli = metaStimulus();
			updateFixationTarget(rE, true);
			verifyTrue(testCase, true, 'no-op completed when no stims');
		end

		% --- updateExclusionZones without stimuli ---
		function testUpdateExclusionZonesEmpty(testCase)
			rE = runExperiment('verbose', false);
			rE.stimuli = metaStimulus();
			updateExclusionZones(rE, true);
			verifyTrue(testCase, true, 'no-op completed when no stims');
		end

		% --- updateConditionalFixationTarget without stimulus ---
		function testUpdateConditionalFixationNoStim(testCase)
			rE = runExperiment('verbose', false);
			rE.stimuli = metaStimulus();
			updateConditionalFixationTarget(rE, discStimulus('verbose', false), ...
				'xyPosition', [0 0]);
			verifyTrue(testCase, true, 'no-op completed when index out of range');
		end

		% --- deleteRunLog ---
		function testDeleteRunLog(testCase)
			rE = runExperiment('verbose', false);
			deleteRunLog(rE);
			verifyTrue(testCase, isempty(rE.runLog), 'runLog cleared');
			verifyTrue(testCase, isempty(rE.taskLog), 'taskLog cleared');
		end

		% --- logRun when not running ---
		function testLogRunNotRunning(testCase)
			rE = runExperiment('verbose', false);
			logRun(rE, 'test');
			verifyTrue(testCase, true, 'no-op completed when not running');
		end

		% --- setStrobeValue with default device ---
		function testSetStrobeValue(testCase)
			rE = runExperiment('verbose', false);
			setStrobeValue(rE, 42);
			verifyTrue(testCase, true, 'setStrobeValue completed');
		end

		function testSetStrobeValueInf(testCase)
			rE = runExperiment('verbose', false);
			setStrobeValue(rE, -Inf);
			verifyEqual(testCase, rE.strobe.stimOFFValue, 255, 'stimOFFValue default');
		end

		% --- sessionData defaults ---
		function testSessionData(testCase)
			rE = runExperiment('verbose', false);
			verifyEqual(testCase, rE.sessionData.subjectName, 'Simulcra');
			verifyEqual(testCase, rE.sessionData.researcherName, 'Jane Doe');
			verifyEqual(testCase, rE.sessionData.labName, 'lab');
			verifyFalse(testCase, rE.sessionData.useAlyx, 'useAlyx default false');
		end

		% --- stateInfoFile default ---
		function testStateInfoFileDefault(testCase)
			rE = runExperiment('verbose', false);
			% if not initialised, stateInfoFile is empty
			verifyTrue(testCase, isempty(rE.stateInfoFile) || ...
				contains(rE.stateInfoFile, 'DefaultStateInfo.m'), ...
				'stateInfoFile defaults to DefaultStateInfo');
		end

		% --- keyboardDevice default ---
		function testKeyboardDeviceDefault(testCase)
			rE = runExperiment('verbose', false);
			verifyTrue(testCase, isempty(rE.keyboardDevice), 'keyboardDevice empty');
		end

		% --- constructor with strobe / reward / eyetracker config ---
		function testConstructorIOConfig(testCase)
			rE = runExperiment('verbose', false, ...
				'strobe', struct('device', 'labjack', 'port', '/dev/ttyUSB0', ...
					'mode', 'plain', 'stimOFFValue', 255), ...
				'reward', struct('device', 'arduino', 'port', 'COM3', 'board', ''), ...
				'eyetracker', struct('device', 'eyelink', 'dummy', true));
			verifyEqual(testCase, rE.strobe.device, 'labjack');
			verifyEqual(testCase, rE.reward.device, 'arduino');
			verifyEqual(testCase, rE.eyetracker.device, 'eyelink');
			verifyTrue(testCase, rE.eyetracker.dummy);
		end

		% --- clone from optickaCore ---
		function testClone(testCase)
			rE = runExperiment('verbose', false, 'name', 'Original');
			rE2 = rE.clone;
			verifyEqual(testCase, rE2.name, 'Original', 'name preserved');
			verifyNotEqual(testCase, rE2.uuid, rE.uuid, 'UUID unique');
		end

		% --- verbosityLevel through screen (no PTB) ---
		function testVerboseFalseDoesNotError(testCase)
			rE = runExperiment('verbose', false);
			rE.verbose = false;
			verifyFalse(testCase, rE.verbose, 'verbose false');
		end

		% --- isRunTask private property check ---
		function testInitialRunTaskState(testCase)
			rE = runExperiment('verbose', false);
			% isRunTask is private, but we can infer isRunning
			verifyFalse(testCase, rE.isRunning, 'not running');
		end

		% --- photoDiode hidden property ---
		function testPhotoDiodeDefault(testCase)
			rE = runExperiment('verbose', false);
			verifyFalse(testCase, rE.photoDiode, 'photoDiode default false');
		end

		% --- logStateTimers hidden property ---
		function testLogStateTimersDefault(testCase)
			rE = runExperiment('verbose', false);
			verifyFalse(testCase, rE.logStateTimers, 'logStateTimers default false');
		end

		% --- displayLoop (hidden) ---
		function testBenchmarkDefault(testCase)
			rE = runExperiment('verbose', false);
			verifyFalse(testCase, rE.benchmark, 'benchmark default false');
		end

		% --- drawFixation default ---
		function testDrawFixationDefault(testCase)
			rE = runExperiment('verbose', false);
			verifyFalse(testCase, rE.drawFixation, 'drawFixation default false');
		end

		% --- alyx manager default ---
		function testAlyxDefault(testCase)
			rE = runExperiment('verbose', false);
			verifyTrue(testCase, isempty(rE.alyx) || isa(rE.alyx, 'alyxManager'), ...
				'alyx default');
		end

	end

	% ===================================================================
	% HARDWARE TESTS (need PTB screen)
	% ===================================================================
	methods (Test, TestTags = {'hardware'})

		% --- full construction with stimuli and screen ---
		function testConstructWithStimuliAndScreen(testCase)
			assumeFalse(testCase, ~isempty(getenv('GITHUB_ACTIONS')), 'Skip in CI');
			sM = screenManager; sM.windowed = [0 0 800 600];
			sM.disableSyncTests = true; sM.visualDebug = true; sM.bitDepth = '8Bit';
			sM.verbose = false;
			ms = metaStimulus();
			ms{1} = discStimulus('verbose', false, 'size', 5);
			ms{2} = fixationCrossStimulus('verbose', false, 'size', 0.8);
			task = taskSequence();
			task.nVar(1).name = 'xyPosition';
			task.nVar(1).stimulus = 1;
			task.nVar(1).values = {[-5 -5], [0 0], [5 5]};
			task.nBlocks = 2;
			randomiseTask(task);
			rE = runExperiment('stimuli', ms, 'screen', sM, 'task', task, ...
				'verbose', false, 'debug', true);
			rE.mock = true;
			rE.eyetracker.device = 'irec';
			verifyTrue(testCase, isa(rE.stimuli, 'metaStimulus'));
			verifyTrue(testCase, isa(rE.screen, 'screenManager'));
			verifyTrue(testCase, isa(rE.task, 'taskSequence'));
			verifyEqual(testCase, rE.stimuli.n, 2);
		end

		% --- open screen via initialise ---
		function testOpenScreenViaInitialise(testCase)
			assumeFalse(testCase, ~isempty(getenv('GITHUB_ACTIONS')), 'Skip in CI');
			sM = screenManager; sM.windowed = [0 0 800 600];
			sM.disableSyncTests = true; sM.visualDebug = true; sM.bitDepth = '8Bit';
			sM.verbose = false;
			rE = runExperiment('verbose', false, 'debug', true);
			rE.mock = true;
			rE.screen = sM;
			rE.initialise();
			open(sM); cleanup = onCleanup(@() close(sM));
			verifyTrue(testCase, sM.isOpen, 'screen opens');
			verifyTrue(testCase, ~isempty(rE.screenVals), 'screenVals populated');
		end

		% --- refreshScreen with open screen ---
		function testRefreshScreenWithOpenScreen(testCase)
			assumeFalse(testCase, ~isempty(getenv('GITHUB_ACTIONS')), 'Skip in CI');
			sM = screenManager; sM.windowed = [0 0 800 600];
			sM.disableSyncTests = true; sM.visualDebug = true; sM.bitDepth = '8Bit';
			sM.verbose = false;
			rE = runExperiment('verbose', false);
			rE.mock = true;
			rE.screen = sM;
			open(sM); cleanup = onCleanup(@() close(sM));
			refreshScreen(rE);
			verifyTrue(testCase, ~isempty(rE.screenVals), 'screenVals after refresh');
		end

		% --- checkScreenError with open screen ---
		function testCheckScreenErrorWithOpenScreen(testCase)
			assumeFalse(testCase, ~isempty(getenv('GITHUB_ACTIONS')), 'Skip in CI');
			sM = screenManager; sM.windowed = [0 0 800 600];
			sM.disableSyncTests = true; sM.visualDebug = true; sM.bitDepth = '8Bit';
			sM.verbose = false;
			rE = runExperiment('verbose', false);
			rE.mock = true;
			rE.screen = sM;
			open(sM); cleanup = onCleanup(@() close(sM));
			rE.isRunning = true;
			err = checkScreenError(rE);
			verifyFalse(testCase, err, 'no error when screen is open');
		end


		% --- updateFixationTarget with stimuli ---
		function testUpdateFixationTargetWithStim(testCase)
			assumeFalse(testCase, ~isempty(getenv('GITHUB_ACTIONS')), 'Skip in CI');
			sM = screenManager; sM.windowed = [0 0 800 600];
			sM.disableSyncTests = true; sM.visualDebug = true; sM.bitDepth = '8Bit';
			sM.verbose = false;
			ms = metaStimulus();
			ms{1} = discStimulus('verbose', false, 'size', 5);
			rE = runExperiment('verbose', false);
			rE.mock = true;
			rE.stimuli = ms;
			rE.screen = sM;
			open(sM); cleanup = onCleanup(@() close(sM));
			setup(ms, sM);
			updateFixationTarget(rE, true);
			verifyTrue(testCase, true, 'updateFixationTarget with stims completed');
		end

		% --- updateExclusionZones with stimuli ---
		function testUpdateExclusionZonesWithStim(testCase)
			assumeFalse(testCase, ~isempty(getenv('GITHUB_ACTIONS')), 'Skip in CI');
			sM = screenManager; sM.windowed = [0 0 800 600];
			sM.disableSyncTests = true; sM.visualDebug = true; sM.bitDepth = '8Bit';
			sM.verbose = false;
			ms = metaStimulus();
			ms{1} = discStimulus('verbose', false, 'size', 5);
			rE = runExperiment('verbose', false);
			rE.mock = true;
			rE.stimuli = ms;
			rE.screen = sM;
			open(sM); cleanup = onCleanup(@() close(sM));
			setup(ms, sM);
			updateExclusionZones(rE, true);
			verifyTrue(testCase, true, 'updateExclusionZones with stims completed');
		end

		% --- updateConditionalFixationTarget with valid stimulus ---
		function testUpdateConditionalFixationWithStim(testCase)
			assumeFalse(testCase, ~isempty(getenv('GITHUB_ACTIONS')), 'Skip in CI');
			sM = screenManager; sM.windowed = [0 0 800 600];
			sM.disableSyncTests = true; sM.visualDebug = true; sM.bitDepth = '8Bit';
			sM.verbose = false;
			ms = metaStimulus();
			d = discStimulus('verbose', false, 'size', 5, 'name', 'Target');
			ms{1} = d;
			rE = runExperiment('verbose', false);
			rE.mock = true;
			rE.stimuli = ms;
			rE.screen = sM;
			open(sM); cleanup = onCleanup(@() close(sM));
			setup(ms, sM);
			updateConditionalFixationTarget(rE, d, 'xyPosition', [3 4]);
			verifyTrue(testCase, true, 'conditional fixation target updated');
		end

	end
end