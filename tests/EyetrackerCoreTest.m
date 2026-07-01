% ========================================================================
%> @class EyetrackerCoreTest
%> @brief Class-based unit tests for eyetrackerCore / eyelinkManager.
%>
%> Tests the fixation-window logic, exclusion zones, fixInit, offset,
%> reset methods, and dummy-mode (mouse) sample acquisition using
%> eyelinkManager as the concrete subclass. CI-safe tests run without
%> PTB; hardware-tagged tests exercise getMouseSample / isFixated /
%> testSearchHoldFixation with a real PTB window and xdotool mouse
%> automation to simulate gaze position.
%>
%> Run with:
%>   >> runtests('tests/EyetrackerCoreTest.m')
%>   >> runtests('tests/EyetrackerCoreTest.m', '-ExcludeTag', 'hardware')
%>
%> Copyright (c) 2026 Ian Max Andolina — LGPL3, see LICENCE.md
% ========================================================================
classdef EyetrackerCoreTest < matlab.unittest.TestCase

	properties
		% path to xdotool binary for mouse automation
		xdotoolPath = '/usr/bin/xdotool'
	end

	methods (TestClassSetup)
		function setupPath(testCase)
			%> Add Opticka to MATLAB path once for all tests.
			addOptickaToPath;
			try %#ok<*TRYNC>
				[r,t] = system('which xdotool');
				if r == 0; testCase.xdotoolPath = strip(t); end
			end
		end
	end

	% ===================================================================
	% CI-SAFE TESTS (no PTB window required)
	% ===================================================================
	methods (Test, TestTags = {'CI'})
		% ---------------------------------------------------------------
		%> @brief Test construction of eyelinkManager with defaults.
		% ---------------------------------------------------------------
		function testConstructionDefaults(testCase)
			eT = eyelinkManager('verbose', false);
			verifyEqual(testCase, eT.type, 'eyelink', 'type should be eyelink');
			verifyFalse(testCase, eT.isDummy, 'default isDummy should be false');
			verifyEqual(testCase, eT.sampleRate, 1000, 'default sampleRate should be 1000');
			verifyFalse(testCase, eT.isConnected, 'should not be connected');
			verifyFalse(testCase, eT.isRecording, 'should not be recording');
			verifyEqual(testCase, eT.eyeUsed, -1, 'default eyeUsed should be -1');
			verifyTrue(testCase, ~isempty(eT.uuid), 'should have a UUID');
			verifyEqual(testCase, eT.name, 'Eyelink', 'default name should be Eyelink');
		end

		% ---------------------------------------------------------------
		%> @brief Test construction in dummy mode.
		% ---------------------------------------------------------------
		function testDummyModeConstruction(testCase)
			eT = eyelinkManager('verbose', false, 'isDummy', true);
			verifyTrue(testCase, eT.isDummy, 'isDummy should be true');
		end

		% ---------------------------------------------------------------
		%> @brief Test fixation window template structure.
		% ---------------------------------------------------------------
		function testFixationTemplate(testCase)
			eT = eyelinkManager('verbose', false);
			verifyEqual(testCase, eT.fixation.X, 0, 'default fixation X');
			verifyEqual(testCase, eT.fixation.Y, 0, 'default fixation Y');
			verifyEqual(testCase, eT.fixation.initTime, 1, 'default initTime');
			verifyEqual(testCase, eT.fixation.time, 1, 'default fixation time');
			verifyEqual(testCase, eT.fixation.radius, 1, 'default radius');
			verifyTrue(testCase, eT.fixation.strict, 'default strict should be true');
		end

		% ---------------------------------------------------------------
		%> @brief Test fixInit template structure.
		% ---------------------------------------------------------------
		function testFixInitTemplate(testCase)
			eT = eyelinkManager('verbose', false);
			verifyEmpty(testCase, eT.fixInit.X, 'default fixInit X should be empty');
			verifyEmpty(testCase, eT.fixInit.Y, 'default fixInit Y should be empty');
			verifyEqual(testCase, eT.fixInit.time, 0.1, 'default fixInit time');
			verifyEqual(testCase, eT.fixInit.radius, 2, 'default fixInit radius');
		end

		% ---------------------------------------------------------------
		%> @brief Test offset template structure.
		% ---------------------------------------------------------------
		function testOffsetTemplate(testCase)
			eT = eyelinkManager('verbose', false);
			verifyEqual(testCase, eT.offset.X, 0, 'default offset X');
			verifyEqual(testCase, eT.offset.Y, 0, 'default offset Y');
		end

		% ---------------------------------------------------------------
		%> @brief Test custom fixation window via constructor.
		% ---------------------------------------------------------------
		function testCustomFixation(testCase)
			eT = eyelinkManager('verbose', false, 'isDummy', true, ...
				'fixation', struct('X', 5, 'Y', 3, 'initTime', 0.5, ...
				'time', 2, 'radius', 2, 'strict', false));
			verifyEqual(testCase, eT.fixation.X, 5, 'custom fixation X');
			verifyEqual(testCase, eT.fixation.Y, 3, 'custom fixation Y');
			verifyEqual(testCase, eT.fixation.initTime, 0.5, 'custom initTime');
			verifyEqual(testCase, eT.fixation.time, 2, 'custom fixation time');
			verifyEqual(testCase, eT.fixation.radius, 2, 'custom radius');
			verifyFalse(testCase, eT.fixation.strict, 'custom strict should be false');
		end

		% ---------------------------------------------------------------
		%> @brief Test exclusion zone property.
		% ---------------------------------------------------------------
		function testExclusionZone(testCase)
			eT = eyelinkManager('verbose', false, 'isDummy', true);
			verifyEmpty(testCase, eT.exclusionZone, 'default exclusionZone empty');
			eT.exclusionZone = [-5 5 -5 5; -10 -8 -10 -8];
			verifyEqual(testCase, size(eT.exclusionZone, 1), 2, ...
				'should have 2 exclusion zones');
		end

		% ---------------------------------------------------------------
		%> @brief Test updateFixationValues method.
		% ---------------------------------------------------------------
		function testUpdateFixationValues(testCase)
			eT = eyelinkManager('verbose', false, 'isDummy', true);
			eT.updateFixationValues(3, 4, 0.5, 1.5, 2.5, true);
			verifyEqual(testCase, eT.fixation.X, 3, 'X should be 3');
			verifyEqual(testCase, eT.fixation.Y, 4, 'Y should be 4');
			verifyEqual(testCase, eT.fixation.initTime, 0.5, 'initTime should be 0.5');
			verifyEqual(testCase, eT.fixation.time, 1.5, 'time should be 1.5');
			verifyEqual(testCase, eT.fixation.radius, 2.5, 'radius should be 2.5');
			verifyTrue(testCase, eT.fixation.strict, 'strict should be true');
		end

		% ---------------------------------------------------------------
		%> @brief Test updateFixationValues partial update (empty = keep).
		% ---------------------------------------------------------------
		function testUpdateFixationValuesPartial(testCase)
			eT = eyelinkManager('verbose', false, 'isDummy', true);
			% Set initial values
			eT.updateFixationValues(3, 4, 0.5, 1.5, 2.5, true);
			% Update only initTime, keep rest
			eT.updateFixationValues([], [], 1.0, [], [], []);
			verifyEqual(testCase, eT.fixation.X, 3, 'X should still be 3');
			verifyEqual(testCase, eT.fixation.Y, 4, 'Y should still be 4');
			verifyEqual(testCase, eT.fixation.initTime, 1.0, 'initTime should be 1.0');
			verifyEqual(testCase, eT.fixation.time, 1.5, 'time should still be 1.5');
		end

		% ---------------------------------------------------------------
		%> @brief Test resetFixation clears state.
		% ---------------------------------------------------------------
		function testResetFixation(testCase)
			eT = eyelinkManager('verbose', false, 'isDummy', true);
			eT.resetFixation;
			verifyEqual(testCase, eT.fixStartTime, 0, 'fixStartTime should be 0');
			verifyEqual(testCase, eT.fixLength, 0, 'fixLength should be 0');
			verifyEqual(testCase, eT.fixBuffer, 0, 'fixBuffer should be 0');
			verifyEqual(testCase, eT.fixTotal, 0, 'fixTotal should be 0');
			verifyEqual(testCase, eT.fixWindow, 0, 'fixWindow should be 0');
			verifyFalse(testCase, eT.isFix, 'isFix should be false');
			verifyFalse(testCase, eT.isBlink, 'isBlink should be false');
			verifyFalse(testCase, eT.isExclusion, 'isExclusion should be false');
			verifyFalse(testCase, eT.isInitFail, 'isInitFail should be false');
		end

		% ---------------------------------------------------------------
		%> @brief Test resetFixation with removeHistory clears xAll/yAll.
		% ---------------------------------------------------------------
		function testResetFixationHistory(testCase)
			eT = eyelinkManager('verbose', false, 'isDummy', true);
			eT.resetFixation(true);
			verifyEmpty(testCase, eT.xAll, 'xAll should be empty after reset');
			verifyEmpty(testCase, eT.yAll, 'yAll should be empty after reset');
			verifyEmpty(testCase, eT.pupilAll, 'pupilAll should be empty');
		end

		% ---------------------------------------------------------------
		%> @brief Test resetFixInit clears fixInit X/Y.
		% ---------------------------------------------------------------
		function testResetFixInit(testCase)
			eT = eyelinkManager('verbose', false, 'isDummy', true);
			eT.fixInit.X = 3;
			eT.fixInit.Y = 4;
			eT.resetFixInit;
			verifyEmpty(testCase, eT.fixInit.X, 'fixInit X should be empty');
			verifyEmpty(testCase, eT.fixInit.Y, 'fixInit Y should be empty');
		end

		% ---------------------------------------------------------------
		%> @brief Test resetOffset clears offset.
		% ---------------------------------------------------------------
		function testResetOffset(testCase)
			eT = eyelinkManager('verbose', false, 'isDummy', true);
			eT.offset.X = 2;
			eT.offset.Y = 3;
			eT.resetOffset;
			verifyEqual(testCase, eT.offset.X, 0, 'offset X should be 0');
			verifyEqual(testCase, eT.offset.Y, 0, 'offset Y should be 0');
		end

		% ---------------------------------------------------------------
		%> @brief Test resetExclusionZones clears exclusion zones.
		% ---------------------------------------------------------------
		function testResetExclusionZones(testCase)
			eT = eyelinkManager('verbose', false, 'isDummy', true);
			eT.exclusionZone = [-5 5 -5 5];
			eT.resetExclusionZones;
			verifyEmpty(testCase, eT.exclusionZone, 'exclusionZone should be empty');
		end

		% ---------------------------------------------------------------
		%> @brief Test resetAll calls all reset methods.
		% ---------------------------------------------------------------
		function testResetAll(testCase)
			eT = eyelinkManager('verbose', false, 'isDummy', true);
			eT.exclusionZone = [-5 5 -5 5];
			eT.fixInit.X = 3;
			eT.fixInit.Y = 4;
			eT.resetAll;
			verifyEqual(testCase, eT.fixInitStartTime, 0, 'start time is zero');
			verifyEmpty(testCase, eT.exclusionZone, 'exclusionZone should be empty');
			verifyEmpty(testCase, eT.fixInit.X, 'fixInit X should be empty');
			verifyEqual(testCase, eT.fixTotal, 0, 'fixTotal should be 0');
		end

		% ---------------------------------------------------------------
		%> @brief Test resetFixationTime only resets time counters.
		% ---------------------------------------------------------------
		function testResetFixationTime(testCase)
			eT = eyelinkManager('verbose', false, 'isDummy', true);
			eT.resetFixationTime;
			verifyEqual(testCase, eT.fixStartTime, 0, 'fixStartTime should be 0');
			verifyEqual(testCase, eT.fixLength, 0, 'fixLength should be 0');
			verifyEqual(testCase, eT.fixBuffer, 0, 'fixBuffer should be 0');
		end

		% ---------------------------------------------------------------
		%> @brief Test sampleRate property.
		% ---------------------------------------------------------------
		function testSampleRate(testCase)
			eT = eyelinkManager('verbose', false, 'sampleRate', 500);
			verifyEqual(testCase, eT.sampleRate, 500, 'sampleRate should be 500');
		end

		% ---------------------------------------------------------------
		%> @brief Test recordData property.
		% ---------------------------------------------------------------
		function testRecordData(testCase)
			eT = eyelinkManager('verbose', false, 'recordData', false);
			verifyFalse(testCase, eT.recordData, 'recordData should be false');
		end

		% ---------------------------------------------------------------
		%> @brief Test ignoreBlinks property.
		% ---------------------------------------------------------------
		function testIgnoreBlinks(testCase)
			eT = eyelinkManager('verbose', false, 'ignoreBlinks', true);
			verifyTrue(testCase, eT.ignoreBlinks, 'ignoreBlinks should be true');
		end

		% ---------------------------------------------------------------
		%> @brief Test multiple fixation windows (multi-row X/Y).
		% ---------------------------------------------------------------
		function testMultipleFixationWindows(testCase)
			eT = eyelinkManager('verbose', false, 'isDummy', true, ...
				'fixation', struct('X', [0 5], 'Y', [0 3], 'initTime', 1, ...
				'time', 1, 'radius', 1, 'strict', true));
			verifyEqual(testCase, length(eT.fixation.X), 2, 'should have 2 fixation windows');
			verifyEqual(testCase, eT.fixation.X(2), 5, 'second window X should be 5');
		end

		% ---------------------------------------------------------------
		%> @brief Test rectangular fixation window (radius has 2 values).
		% ---------------------------------------------------------------
		function testRectangularFixationWindow(testCase)
			eT = eyelinkManager('verbose', false, 'isDummy', true, ...
				'fixation', struct('X', 0, 'Y', 0, 'initTime', 1, ...
				'time', 1, 'radius', [3 2], 'strict', true));
			verifyEqual(testCase, length(eT.fixation.radius), 2, 'radius should have 2 values');
			verifyEqual(testCase, eT.fixation.radius(1), 3, 'radius width should be 3');
			verifyEqual(testCase, eT.fixation.radius(2), 2, 'radius height should be 2');
		end

		% ---------------------------------------------------------------
		%> @brief Test saveFile property.
		% ---------------------------------------------------------------
		function testSaveFile(testCase)
			eT = eyelinkManager('verbose', false, 'saveFile', 'testData');
			verifyEqual(testCase, eT.saveFile, 'testData', 'saveFile should be testData');
		end

		% ---------------------------------------------------------------
		%> @brief Test subjectName property.
		% ---------------------------------------------------------------
		function testSubjectName(testCase)
			eT = eyelinkManager('verbose', false, 'subjectName', 'TestSubject');
			verifyEqual(testCase, eT.subjectName, 'TestSubject', 'subjectName should be set');
		end

		% ---------------------------------------------------------------
		%> @brief Test default state properties are clean.
		% ---------------------------------------------------------------
		function testDefaultStateClean(testCase)
			eT = eyelinkManager('verbose', false, 'isDummy', true);
			verifyEmpty(testCase, eT.x, 'x should be empty');
			verifyEmpty(testCase, eT.y, 'y should be empty');
			verifyEmpty(testCase, eT.pupil, 'pupil should be empty');
			verifyFalse(testCase, eT.isFix, 'isFix should be false');
			verifyFalse(testCase, eT.isBlink, 'isBlink should be false');
			verifyFalse(testCase, eT.isExclusion, 'isExclusion should be false');
			verifyFalse(testCase, eT.isInitFail, 'isInitFail should be false');
			verifyEmpty(testCase, eT.xAll, 'xAll should be empty');
			verifyEmpty(testCase, eT.yAll, 'yAll should be empty');
		end

		% ---------------------------------------------------------------
		%> @brief Test isOff hidden property.
		% ---------------------------------------------------------------
		function testIsOffProperty(testCase)
			eT = eyelinkManager('verbose', false, 'isDummy', true);
			verifyFalse(testCase, eT.isOff, 'default isOff should be false');
			eT.isOff = true;
			verifyTrue(testCase, eT.isOff, 'isOff should be true');
		end

		% ---------------------------------------------------------------
		%> @brief Test calibration structure for eyelinkManager.
		% ---------------------------------------------------------------
		function testCalibrationStructure(testCase)
			eT = eyelinkManager('verbose', false);
			verifyEqual(testCase, eT.calibration.style, 'HV9', 'default calibration style');
			verifyEqual(testCase, eT.calibration.IP, '', 'default IP should be empty');
			verifyEqual(testCase, eT.calibration.eyeUsed, 0, 'default eyeUsed');
			verifyTrue(testCase, eT.calibration.enableCallbacks, 'enableCallbacks should be true');
		end

		% ---------------------------------------------------------------
		%> @brief Test useOperatorScreen property.
		% ---------------------------------------------------------------
		function testUseOperatorScreen(testCase)
			eT = eyelinkManager('verbose', false, 'useOperatorScreen', true);
			verifyTrue(testCase, eT.useOperatorScreen, 'useOperatorScreen should be true');
		end
	end

	% ===================================================================
	% HARDWARE TESTS (require PTB window — excluded from CI)
	% Uses xdotool to automate mouse movement for dummy mode testing.
	% ===================================================================
	methods (Test, TestTags = {'hardware'})
		% ---------------------------------------------------------------
		%> @brief Helper: create a screenManager and eyelinkManager in
		%> dummy mode, return both with cleanup.
		% ---------------------------------------------------------------
		function [sM, eT, cleanup] = createDummySetup(testCase)
			assumeFalse(testCase, ~isempty(getenv('GITHUB_ACTIONS')), ...
				'Skipping PTB eyetracker test in CI');
			sM = screenManager;
			sM.windowed = [0 0 800 600];
			sM.disableSyncTests = true;
			sM.visualDebug = true;
			sM.bitDepth = '8bit';
			open(sM);
			cleanup = onCleanup(@() close(sM));
			eT = eyelinkManager('verbose', false, 'isDummy', true);
			eT.initialise(sM);
		end

		% ---------------------------------------------------------------
		%> @brief Test dummy mode getMouseSample acquires position.
		% ---------------------------------------------------------------
		function testGetMouseSample(testCase)
			assumeTrue(testCase, exist('GetMouse') == 2 || ~isempty(which('GetMouse')), ...
				'PTB GetMouse must be available');
			[sM, eT, cleanup] = createDummySetup(testCase);
			% Move mouse to a known position
			system(sprintf('%s mousemove --screen %d %d %d', testCase.xdotoolPath, sM.screen, 400, 300));
			WaitSecs(0.1);
			sample = eT.getMouseSample;
			verifyTrue(testCase, ~isempty(sample), 'sample should not be empty');
			verifyTrue(testCase, ~isnan(sample.time), 'sample time should not be NaN');
			% gx, gy are raw pixel coordinates from GetMouse
			verifyTrue(testCase, sample.gx > 0, 'gx should be positive');
			verifyTrue(testCase, sample.gy > 0, 'gy should be positive');
		end

		% ---------------------------------------------------------------
		%> @brief Test getMouseSample detects mouse button (blink).
		% ---------------------------------------------------------------
		function testGetMouseSampleBlink(testCase)
			assumeTrue(testCase, exist(testCase.xdotoolPath) == 2 || ~isempty(which('xdotool')), ...
				'xdotool must be available for mouse automation');
			[sM, eT, cleanup] = createDummySetup(testCase);
			system(sprintf('%s mousemove --screen %d %d %d', testCase.xdotoolPath, sM.screen, 400, 300));
			% Right-click (button 3) simulates blink in dummy mode
			system(sprintf('%s mousedown 3', testCase.xdotoolPath));
			WaitSecs(0.1);
			sample = eT.getSample;
			system(sprintf('%s mouseup 3', testCase.xdotoolPath));
			verifyTrue(testCase, eT.isBlink, 'should detect blink when right button pressed');
			verifyTrue(testCase, ~sample.valid, 'sample should be invalid during blink');
			verifyEqual(testCase, eT.x, NaN, 'x should be NaN during blink');
			WaitSecs(0.05);
		end

		% ---------------------------------------------------------------
		%> @brief Test getMouseSample with left button (valid sample).
		% ---------------------------------------------------------------
		function testGetMouseSampleValid(testCase)
			assumeFalse(testCase, ~isempty(getenv('GITHUB_ACTIONS')), ...
				'Skipping PTB eyetracker test in CI');
			assumeTrue(testCase, exist(testCase.xdotoolPath) == 2 || ~isempty(which('xdotool')), ...
				'xdotool must be available for mouse automation');
			[sM, eT, cleanup] = createDummySetup(testCase);
			system(sprintf('%s mousemove --screen %d %d %d', testCase.xdotoolPath, sM.screen, 400, 300));
			WaitSecs(0.1);
			sample = eT.getSample;
			verifyFalse(testCase, eT.isBlink, 'should not blink with left button');
			verifyTrue(testCase, sample.valid, 'sample should be valid');
			verifyTrue(testCase, ~isnan(eT.x), 'x should not be NaN');
			verifyTrue(testCase, ~isnan(eT.y), 'y should not be NaN');
			verifyTrue(testCase, ~isempty(eT.xAll), 'xAll should have data');
			verifyTrue(testCase, ~isempty(eT.yAll), 'yAll should have data');
			WaitSecs(0.05);
		end

		% ---------------------------------------------------------------
		%> @brief Test isFixated returns false with no sample.
		% ---------------------------------------------------------------
		function testIsFixatedNoSample(testCase)
			assumeFalse(testCase, ~isempty(getenv('GITHUB_ACTIONS')), ...
				'Skipping PTB eyetracker test in CI');
			[~, eT, cleanup] = createDummySetup(testCase);
			eT.resetFixation;
			[fixated, ~, searching, ~, ~, ~, ~] = eT.isFixated;
			verifyFalse(testCase, fixated, 'should not be fixated with no sample');
			verifyTrue(testCase, searching, 'should be searching with no sample');
		end

		% ---------------------------------------------------------------
		%> @brief Test isFixated returns true when mouse is in window.
		% ---------------------------------------------------------------
		function testIsFixatedInWindow(testCase)
			assumeFalse(testCase, ~isempty(getenv('GITHUB_ACTIONS')), ...
				'Skipping PTB eyetracker test in CI');
			assumeTrue(testCase, exist(testCase.xdotoolPath) == 2 || ~isempty(which('xdotool')), ...
				'xdotool must be available for mouse automation');
			[sM, eT, cleanup] = createDummySetup(testCase);
			% Set fixation window at center (0,0 deg) with radius 5 deg
			eT.updateFixationValues(0, 0, 0.1, 0.1, 10, true);
			eT.resetFixation;
			% Move mouse to center of window
			system(sprintf('%s mousemove --screen %d %d %d', testCase.xdotoolPath, sM.screen, ...
				sM.screenVals.width/2, sM.screenVals.height/2));
			WaitSecs(0.1);
			eT.getSample;
			fixated = eT.isFixated;
			WaitSecs(0.5);
			eT.getSample;
			[fixated, fixtime, searching] = eT.isFixated;
			verifyTrue(testCase, fixated, 'should be fixated when in window');
			verifyTrue(testCase, fixtime, 'should be fixated longer than the fix time');
			verifyFalse(testCase, searching, 'should not be searching when fixated');
			WaitSecs(0.05);
		end

		% ---------------------------------------------------------------
		%> @brief Test isFixated returns false when mouse is outside window.
		% ---------------------------------------------------------------
		function testIsFixatedOutsideWindow(testCase)
			assumeFalse(testCase, ~isempty(getenv('GITHUB_ACTIONS')), ...
				'Skipping PTB eyetracker test in CI');
			assumeTrue(testCase, exist(testCase.xdotoolPath) == 2 || ~isempty(which('xdotool')), ...
				'xdotool must be available for mouse automation');
			[sM, eT, cleanup] = createDummySetup(testCase);
			% Small fixation window at center
			eT.updateFixationValues(0, 0, 1, 0.01, 0.5, true);
			eT.resetFixation;
			% Move mouse to corner (far from center)
			system(sprintf('%s mousemove --screen %d %d %d', testCase.xdotoolPath, sM.screen, 10, 10));
			system(sprintf('%s mousedown 1', testCase.xdotoolPath));
			WaitSecs(0.1);
			eT.getMouseSample;
			[fixated, ~, searching, ~, ~, ~, ~] = eT.isFixated;
			verifyFalse(testCase, fixated, 'should not be fixated outside window');
			verifyTrue(testCase, searching, 'should be searching outside window');
			system(sprintf('%s mouseup 1', testCase.xdotoolPath));
			WaitSecs(0.05);
		end

		% ---------------------------------------------------------------
		%> @brief Test testSearchHoldFixation returns 'no' when outside.
		% ---------------------------------------------------------------
		function testSearchHoldFixationOutside(testCase)
			assumeFalse(testCase, ~isempty(getenv('GITHUB_ACTIONS')), ...
				'Skipping PTB eyetracker test in CI');
			assumeTrue(testCase, exist(testCase.xdotoolPath) == 2 || ~isempty(which('xdotool')), ...
				'xdotool must be available for mouse automation');
			[sM, eT, cleanup] = createDummySetup(testCase);
			eT.updateFixationValues(0, 0, 0.25, 0.25, 0.25, true);
			eT.resetFixation;
			% Move mouse to corner
			system(sprintf('%s mousemove --screen %d %d %d', testCase.xdotoolPath, sM.screen, 10, 10));
			eT.getSample;
			WaitSecs(0.1);
			result = eT.testSearchHoldFixation('yes', 'no'); 
			WaitSecs(1);
			eT.getSample;
			result = eT.testSearchHoldFixation('yes', 'no');
			verifyEqual(testCase, result, 'no', 'should return no when outside window');
			WaitSecs(0.05);
		end

		% ---------------------------------------------------------------
		%> @brief Test exclusion zone detection.
		% ---------------------------------------------------------------
		function testExclusionZoneDetection(testCase)
			assumeFalse(testCase, ~isempty(getenv('GITHUB_ACTIONS')), ...
				'Skipping PTB eyetracker test in CI');
			assumeTrue(testCase, exist(testCase.xdotoolPath) == 2 || ~isempty(which('xdotool')), ...
				'xdotool must be available for mouse automation');
			[sM, eT, cleanup] = createDummySetup(testCase);
			% Set an exclusion zone at center [-2 2 -2 2] deg
			eT.exclusionZone = [-5 5 -5 5];
			eT.resetFixation;
			% Move mouse to center (inside exclusion zone)
			system(sprintf('%s mousemove --screen %d %d %d', testCase.xdotoolPath, sM.screen, ...
				sM.screenVals.width/2, sM.screenVals.height/2));
			WaitSecs(0.1);
			eT.getSample;
			[~, ~, ~, ~, exclusion, ~, ~] = eT.isFixated;
			verifyTrue(testCase, exclusion, 'should detect exclusion zone');
			verifyTrue(testCase, eT.isExclusion, 'isExclusion should be true');
			WaitSecs(0.05);
		end

		% ---------------------------------------------------------------
		%> @brief Test resetFixationHistory clears xAll/yAll after samples.
		% ---------------------------------------------------------------
		function testResetFixationHistoryAfterSamples(testCase)
			assumeFalse(testCase, ~isempty(getenv('GITHUB_ACTIONS')), ...
				'Skipping PTB eyetracker test in CI');
			assumeTrue(testCase, exist(testCase.xdotoolPath) == 2 || ~isempty(which('xdotool')), ...
				'xdotool must be available for mouse automation');
			[sM, eT, cleanup] = createDummySetup(testCase);
			system(sprintf('%s mousemove --screen %d %d %d', testCase.xdotoolPath, sM.screen, 400, 300));
			system(sprintf('%s mousedown 1', testCase.xdotoolPath));
			WaitSecs(0.1);
			eT.getMouseSample;
			verifyTrue(testCase, ~isempty(eT.xAll), 'xAll should have data');
			eT.resetFixationHistory;
			verifyEmpty(testCase, eT.xAll, 'xAll should be empty after reset');
			verifyEmpty(testCase, eT.yAll, 'yAll should be empty after reset');
			system(sprintf('%s mouseup 1', testCase.xdotoolPath));
			WaitSecs(0.05);
		end

		% ---------------------------------------------------------------
		%> @brief Test coordinate tracking accumulates in xAll/yAll.
		% ---------------------------------------------------------------
		function testCoordinateAccumulation(testCase)
			assumeFalse(testCase, ~isempty(getenv('GITHUB_ACTIONS')), ...
				'Skipping PTB eyetracker test in CI');
			assumeTrue(testCase, exist(testCase.xdotoolPath) == 2 || ~isempty(which('xdotool')), ...
				'xdotool must be available for mouse automation');
			[sM, eT, cleanup] = createDummySetup(testCase);
			eT.resetFixation(true);
			% Get multiple samples at different positions
			system(sprintf('%s mousemove --screen %d %d %d', testCase.xdotoolPath, sM.screen, 300, 200));
			system(sprintf('%s mousedown 1', testCase.xdotoolPath));
			WaitSecs(0.05);
			eT.getMouseSample;
			system(sprintf('%s mousemove --screen %d %d %d', testCase.xdotoolPath, sM.screen, 400, 300));
			WaitSecs(0.05);
			eT.getMouseSample;
			verifyEqual(testCase, length(eT.xAll), 2, 'should have 2 samples in xAll');
			verifyEqual(testCase, length(eT.yAll), 2, 'should have 2 samples in yAll');
			verifyEqual(testCase, length(eT.pupilAll), 2, 'should have 2 pupil samples');
			system(sprintf('%s mouseup 1', testCase.xdotoolPath));
			WaitSecs(0.05);
		end
	end
end
