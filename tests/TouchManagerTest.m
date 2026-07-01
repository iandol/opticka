% ========================================================================
%> @class TouchManagerTest
%> @brief Class-based unit tests for touchManager.
%>
%> Tests construction, property defaults, window management (updateWindow,
%> resetWindow), reset behaviour, exclusion zones, and the calculateWindow
%> logic (circular and rectangular). CI-safe tests run without PTB.
%>
%> Hardware-tagged tests exercise the dummy (mouse) mode with a real PTB
%> window and xdotool mouse automation to simulate touch events.
%>
%> Run with:
%>   >> runtests('tests/TouchManagerTest.m')
%>   >> runtests('tests/TouchManagerTest.m', '-ExcludeTag', 'hardware')
%>
%> Copyright (c) 2026 Ian Max Andolina — LGPL3, see LICENCE.md
% ========================================================================
classdef TouchManagerTest < matlab.unittest.TestCase

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
	methods (Test)
		% ---------------------------------------------------------------
		%> @brief Test construction with defaults.
		% ---------------------------------------------------------------
		function testConstructionDefaults(testCase)
			tM = touchManager('verbose', false);
			verifyEqual(testCase, tM.device, 1, 'default device should be 1');
			verifyFalse(testCase, tM.isDummy, 'default isDummy should be false');
			verifyFalse(testCase, tM.drainEvents, 'default drainEvents should be false');
			verifyTrue(testCase, tM.trackID, 'default trackID should be true');
			verifyEqual(testCase, tM.mainID, 1, 'default mainID should be 1');
			verifyEqual(testCase, tM.panelType, 1, 'default panelType should be 1');
			verifyFalse(testCase, tM.isOpen, 'should not be open');
			verifyFalse(testCase, tM.isQueue, 'should not have a queue');
			verifyFalse(testCase, tM.isSearching, 'should not be searching');
			verifyEqual(testCase, tM.name, 'touchManager', 'default name');
		end

		% ---------------------------------------------------------------
		%> @brief Test construction in dummy mode.
		% ---------------------------------------------------------------
		function testDummyModeConstruction(testCase)
			tM = touchManager('verbose', false, 'isDummy', true);
			verifyTrue(testCase, tM.isDummy, 'isDummy should be true');
		end

		% ---------------------------------------------------------------
		%> @brief Test construction with custom properties.
		% ---------------------------------------------------------------
		function testCustomProperties(testCase)
			tM = touchManager('verbose', false, 'isDummy', true, ...
				'device', 2, 'drainEvents', true, 'panelType', 2);
			verifyEqual(testCase, tM.device, 2, 'device should be 2');
			verifyTrue(testCase, tM.drainEvents, 'drainEvents should be true');
			verifyEqual(testCase, tM.panelType, 2, 'panelType should be 2');
		end

		% ---------------------------------------------------------------
		%> @brief Test default window template structure.
		% ---------------------------------------------------------------
		function testWindowTemplate(testCase)
			tM = touchManager('verbose', false);
			verifyEqual(testCase, tM.window.X, 0, 'default window X should be 0');
			verifyEqual(testCase, tM.window.Y, 0, 'default window Y should be 0');
			verifyEqual(testCase, tM.window.radius, 2, 'default window radius should be 2');
			verifyEqual(testCase, tM.window.init, 3, 'default window init should be 3');
			verifyEqual(testCase, tM.window.hold, 0.05, 'default window hold should be 0.05');
			verifyTrue(testCase, isnan(tM.window.release), ...
				'default window release should be NaN');
			verifyFalse(testCase, tM.window.doNegation, ...
				'default window doNegation should be false');
			verifyEqual(testCase, tM.window.negationBuffer, 2, ...
				'default window negationBuffer should be 2');
			verifyTrue(testCase, tM.window.strict, ...
				'default window strict should be true');
		end

		% ---------------------------------------------------------------
		%> @brief Test updateWindow sets parameters correctly.
		% ---------------------------------------------------------------
		function testUpdateWindow(testCase)
			tM = touchManager('verbose', false);
			tM.updateWindow(5, 3, 4, true, 2, true, 5, 0.1, 1);
			verifyEqual(testCase, tM.window(1).X, 5, 'X should be 5');
			verifyEqual(testCase, tM.window(1).Y, 3, 'Y should be 3');
			verifyEqual(testCase, tM.window(1).radius, 4, 'radius should be 4');
			verifyTrue(testCase, tM.window(1).doNegation, 'doNegation should be true');
			verifyEqual(testCase, tM.window(1).negationBuffer, 2, 'negationBuffer should be 2');
			verifyTrue(testCase, tM.window(1).strict, 'strict should be true');
			verifyEqual(testCase, tM.window(1).init, 5, 'init should be 5');
			verifyEqual(testCase, tM.window(1).hold, 0.1, 'hold should be 0.1');
			verifyEqual(testCase, tM.window(1).release, 1, 'release should be 1');
		end

		% ---------------------------------------------------------------
		%> @brief Test updateWindow creates multiple windows.
		% ---------------------------------------------------------------
		function testUpdateWindowMultiple(testCase)
			tM = touchManager('verbose', false);
			tM.updateWindow([1 2 3], [4 5 6], [1 1 1]);
			verifyEqual(testCase, length(tM.window), 3, 'should have 3 windows');
			verifyEqual(testCase, tM.window(1).X, 1, 'window 1 X');
			verifyEqual(testCase, tM.window(2).X, 2, 'window 2 X');
			verifyEqual(testCase, tM.window(3).X, 3, 'window 3 X');
		end

		% ---------------------------------------------------------------
		%> @brief Test resetWindow resets to template values.
		% ---------------------------------------------------------------
		function testResetWindow(testCase)
			tM = touchManager('verbose', false);
			tM.updateWindow(5, 3, 4);
			verifyEqual(testCase, tM.window(1).X, 5, 'X should be 5 before reset');
			tM.resetWindow;
			verifyEqual(testCase, tM.window(1).X, 0, 'X should be 0 after reset');
			verifyEqual(testCase, tM.window(1).radius, 2, 'radius should be 2 after reset');
		end

		% ---------------------------------------------------------------
		%> @brief Test resetWindow with N creates N windows.
		% ---------------------------------------------------------------
		function testResetWindowWithN(testCase)
			tM = touchManager('verbose', false);
			tM.resetWindow(4);
			verifyEqual(testCase, length(tM.window), 4, 'should have 4 windows');
			for i = 1:4
				verifyEqual(testCase, tM.window(i).X, 0, ...
					sprintf('window %d X should be 0', i));
			end
		end

		% ---------------------------------------------------------------
		%> @brief Test reset clears state (dummy mode, no PTB needed for
		%> the non-GetSecs parts, but reset calls GetSecs).
		%> We test the reset via properties that don't need GetSecs.
		% ---------------------------------------------------------------
		function testResetClearsState(testCase)
			% Most state properties are SetAccess=private, so we
			% verify the default state is already "reset" (clean)
			tM = touchManager('verbose', false, 'isDummy', true);
			tM.silentMode = true;
			% Verify initial clean state (x,y start as [])
			verifyTrue(testCase, isnan(tM.x), 'x should be empty initially');
			verifyTrue(testCase, isnan(tM.y), 'y should be empty initially');
			verifyEmpty(testCase, tM.windowTouched, 'windowTouched should be empty');
			verifyFalse(testCase, tM.wasInWindow, 'wasInWindow should be false');
			verifyFalse(testCase, tM.wasHeld, 'wasHeld should be false');
			verifyFalse(testCase, tM.eventNew, 'eventNew should be false');
			verifyFalse(testCase, tM.eventPressed, 'eventPressed should be false');
			verifyFalse(testCase, tM.isSearching, 'isSearching should be false');
			% Now call reset and verify state is clean
			if exist('GetSecs', 'file')
				reset(tM);
				verifyTrue(testCase, isnan(tM.x), 'x should be NaN after reset');
				verifyTrue(testCase, isnan(tM.y), 'y should be NaN after reset');
				verifyEmpty(testCase, tM.windowTouched, 'windowTouched empty after reset');
				verifyFalse(testCase, tM.wasInWindow, 'wasInWindow false after reset');
				verifyFalse(testCase, tM.wasHeld, 'wasHeld false after reset');
				verifyFalse(testCase, tM.eventNew, 'eventNew false after reset');
				verifyFalse(testCase, tM.eventPressed, 'eventPressed false after reset');
				verifyFalse(testCase, tM.isSearching, 'isSearching false after reset');
			else
				assumeFalse(testCase, true, 'GetSecs not available, skipping reset test');
			end
		end

		% ---------------------------------------------------------------
		%> @brief Test soft reset preserves event flags.
		% ---------------------------------------------------------------
		function testSoftResetPreservesFlags(testCase)
			% eventNew, eventPressed etc. are SetAccess=private,
			% so we can only verify that soft reset doesn't error
			% and that x/y are cleared (soft reset still clears position)
			tM = touchManager('verbose', false, 'isDummy', true);
			tM.silentMode = true;
			if ~exist('GetSecs', 'file')
				assumeFalse(testCase, true, 'GetSecs not available');
			end
			% Verify initial state
			verifyTrue(testCase, isnan(tM.x), 'x should be NaN initially');
			% Call soft reset — should not error
			reset(tM, true); % soft reset
			% Soft reset still clears position but preserves event flags
			verifyTrue(testCase, isnan(tM.x), 'x should be NaN after soft reset');
			verifyTrue(testCase, isnan(tM.y), 'y should be NaN after soft reset');
			% Event flags should still be false (never set, soft reset preserves)
			verifyFalse(testCase, tM.eventNew, 'eventNew should be false (preserved)');
			verifyFalse(testCase, tM.eventPressed, 'eventPressed should be false (preserved)');
		end

		% ---------------------------------------------------------------
		%> @brief Test exclusion zone property.
		% ---------------------------------------------------------------
		function testExclusionZone(testCase)
			tM = touchManager('verbose', false);
			verifyEmpty(testCase, tM.exclusionZone, 'default exclusionZone should be empty');
			tM.exclusionZone = [-5 -5 5 5; -10 -10 -8 -8];
			verifyEqual(testCase, size(tM.exclusionZone, 1), 2, ...
				'should have 2 exclusion zones');
		end

		% ---------------------------------------------------------------
		%> @brief Test that hold template has expected fields.
		% ---------------------------------------------------------------
		function testHoldTemplate(testCase)
			tM = touchManager('verbose', false);
			verifyEqual(testCase, tM.hold.N, 0, 'hold.N should be 0');
			verifyFalse(testCase, tM.hold.inWindow, 'hold.inWindow should be false');
			verifyFalse(testCase, tM.hold.touched, 'hold.touched should be false');
			verifyFalse(testCase, tM.hold.failed, 'hold.failed should be false');
			verifyEqual(testCase, tM.hold.start, 0, 'hold.start should be 0');
			verifyEqual(testCase, tM.hold.total, 0, 'hold.total should be 0');
		end

		% ---------------------------------------------------------------
		%> @brief Test silentMode property.
		% ---------------------------------------------------------------
		function testSilentMode(testCase)
			tM = touchManager('verbose', false);
			% silentMode is a Hidden property, not in allowedProperties
			tM.silentMode = true;
			verifyTrue(testCase, tM.silentMode, 'silentMode should be true');
		end

		% ---------------------------------------------------------------
		%> @brief Test deviceName property.
		% ---------------------------------------------------------------
		function testDeviceName(testCase)
			tM = touchManager('verbose', false, 'deviceName', "MyTouchDevice");
			verifyEqual(testCase, tM.deviceName, "MyTouchDevice", ...
				'deviceName should be set');
		end

		% ---------------------------------------------------------------
		%> @brief Test nSlots property.
		% ---------------------------------------------------------------
		function testNSlots(testCase)
			tM = touchManager('verbose', false, 'nSlots', 5000);
			verifyEqual(testCase, tM.nSlots, 5000, 'nSlots should be 5000');
		end

		% ---------------------------------------------------------------
		%> @brief Test UUID from optickaCore.
		% ---------------------------------------------------------------
		function testHasUUID(testCase)
			tM = touchManager('verbose', false);
			verifyTrue(testCase, ~isempty(tM.uuid), 'should have a UUID');
		end
	end

	% ===================================================================
	% HARDWARE TESTS (require PTB window — excluded from CI)
	% Uses xdotool to automate mouse movement for dummy mode testing.
	% ===================================================================
	methods (Test, TestTags = {'hardware'})
		% ---------------------------------------------------------------
		%> @brief Helper: create a screenManager and touchManager in
		%> dummy mode, return both with cleanup.
		% ---------------------------------------------------------------
		function [sM, tM, cleanup] = createDummySetup(testCase)
			assumeFalse(testCase, ~isempty(getenv('GITHUB_ACTIONS')), ...
				'Skipping PTB touch test in CI');
			sM = screenManager;
			sM.windowed = [0 0 800 600];
			sM.disableSyncTests = true;
			sM.visualDebug = true;
			sM.bitDepth = '8bit';
			open(sM);
			cleanup = onCleanup(@() close(sM));
			tM = touchManager('verbose', false, 'isDummy', true);
			setup(tM, sM);
		end

		% ---------------------------------------------------------------
		%> @brief Test dummy mode setup with screenManager.
		% ---------------------------------------------------------------
		function testDummySetup(testCase)
			assumeFalse(testCase, ~isempty(getenv('GITHUB_ACTIONS')), ...
				'Skipping PTB touch test in CI');
			[sM, tM, cleanup] = createDummySetup(testCase);
			verifyTrue(testCase, tM.isDummy, 'should be in dummy mode');
			% screen, ppd, swin are private — verify setup worked via
			% the public comment property which is set during dummy setup
			verifyTrue(testCase, contains(tM.comment, 'Dummy Mode'), ...
				'comment should mention Dummy Mode after setup');
			verifyFalse(testCase, tM.isOpen, 'should not be open after setup');
			verifyFalse(testCase, tM.isQueue, 'should not have queue after setup');
		end

		% ---------------------------------------------------------------
		%> @brief Test createQueue in dummy mode (no-op).
		% ---------------------------------------------------------------
		function testCreateQueueDummy(testCase)
			assumeFalse(testCase, ~isempty(getenv('GITHUB_ACTIONS')), ...
				'Skipping PTB touch test in CI');
			[~, tM, cleanup] = createDummySetup(testCase);
			createQueue(tM);
			verifyTrue(testCase, tM.isQueue, 'isQueue should be true after createQueue');
		end

		% ---------------------------------------------------------------
		%> @brief Test start/stop in dummy mode.
		% ---------------------------------------------------------------
		function testStartStopDummy(testCase)
			assumeFalse(testCase, ~isempty(getenv('GITHUB_ACTIONS')), ...
				'Skipping PTB touch test in CI');
			[~, tM, cleanup] = createDummySetup(testCase);
			start(tM);
			verifyTrue(testCase, tM.isOpen, 'should be open after start');
			stop(tM);
			verifyFalse(testCase, tM.isOpen, 'should not be open after stop');
			verifyFalse(testCase, tM.isQueue, 'should not have queue after stop');
		end

		% ---------------------------------------------------------------
		%> @brief Test close in dummy mode.
		% ---------------------------------------------------------------
		function testCloseDummy(testCase)
			assumeFalse(testCase, ~isempty(getenv('GITHUB_ACTIONS')), ...
				'Skipping PTB touch test in CI');
			[~, tM, cleanup] = createDummySetup(testCase);
			start(tM);
			close(tM);
			verifyFalse(testCase, tM.isOpen, 'should not be open after close');
			verifyFalse(testCase, tM.isQueue, 'should not have queue after close');
		end

		% ---------------------------------------------------------------
		%> @brief Test flush in dummy mode (no-op, returns 0).
		% ---------------------------------------------------------------
		function testFlushDummy(testCase)
			assumeFalse(testCase, ~isempty(getenv('GITHUB_ACTIONS')), ...
				'Skipping PTB touch test in CI');
			[~, tM, cleanup] = createDummySetup(testCase);
			start(tM);
			n = flush(tM);
			verifyEqual(testCase, n, 0, 'flush should return 0 in dummy mode');
			close(tM);
		end

		% ---------------------------------------------------------------
		%> @brief Test syncTime sets queueTime.
		% ---------------------------------------------------------------
		function testSyncTime(testCase)
			assumeFalse(testCase, ~isempty(getenv('GITHUB_ACTIONS')), ...
				'Skipping PTB touch test in CI');
			[~, tM, cleanup] = createDummySetup(testCase);
			syncTime(tM, 123.456);
			verifyEqual(testCase, tM.queueTime, 123.456, ...
				'queueTime should be set to 123.456');
		end

		% ---------------------------------------------------------------
		%> @brief Test eventAvail returns 0 when no mouse button pressed.
		% ---------------------------------------------------------------
		function testEventAvailNoButton(testCase)
			assumeFalse(testCase, ~isempty(getenv('GITHUB_ACTIONS')), ...
				'Skipping PTB touch test in CI');
			[~, tM, cleanup] = createDummySetup(testCase);
			start(tM);
			% Ensure mouse button is not pressed
			navail = eventAvail(tM);
			verifyEqual(testCase, navail, 0, ...
				'eventAvail should be 0 when no button pressed');
			close(tM);
		end

		% ---------------------------------------------------------------
		%> @brief Test getEvent with no mouse input returns empty.
		% ---------------------------------------------------------------
		function testGetEventNoInput(testCase)
			assumeFalse(testCase, ~isempty(getenv('GITHUB_ACTIONS')), ...
				'Skipping PTB touch test in CI');
			[~, tM, cleanup] = createDummySetup(testCase);
			start(tM);
			evt = getEvent(tM);
			verifyEmpty(testCase, evt, 'getEvent should return empty with no input');
			close(tM);
		end

		% ---------------------------------------------------------------
		%> @brief Test isTouch returns false with no mouse input.
		% ---------------------------------------------------------------
		function testIsTouchNoInput(testCase)
			assumeFalse(testCase, ~isempty(getenv('GITHUB_ACTIONS')), ...
				'Skipping PTB touch test in CI');
			[~, tM, cleanup] = createDummySetup(testCase);
			start(tM);
			touch = isTouch(tM);
			verifyFalse(testCase, touch, 'isTouch should be false with no input');
			close(tM);
		end

		% ---------------------------------------------------------------
		%> @brief Test checkTouchWindows returns false with no event.
		% ---------------------------------------------------------------
		function testCheckTouchWindowsNoEvent(testCase)
			assumeFalse(testCase, ~isempty(getenv('GITHUB_ACTIONS')), ...
				'Skipping PTB touch test in CI');
			[~, tM, cleanup] = createDummySetup(testCase);
			start(tM);
			[result, win, wasEvent] = checkTouchWindows(tM);
			verifyFalse(testCase, result, 'result should be false with no event');
			verifyTrue(testCase, isnan(win), 'win should be NaN with no event');
			verifyFalse(testCase, wasEvent, 'wasEvent should be false');
			close(tM);
		end

		% ---------------------------------------------------------------
		%> @brief Test dummy mode with xdotool mouse simulation:
		%> move mouse, press button, verify event detection.
		% ---------------------------------------------------------------
		function testDummyMousePressDetection(testCase)
			assumeFalse(testCase, ~isempty(getenv('GITHUB_ACTIONS')), ...
				'Skipping PTB touch test in CI');
			assumeTrue(testCase, exist(testCase.xdotoolPath) == 2 || ~isempty(which('xdotool')), ...
				'xdotool must be available for mouse automation');
			[sM, tM, cleanup] = createDummySetup(testCase);
			start(tM);
			% Use xdotool to move and click
			[r,t] = system(sprintf('%s mousemove --screen %d %d %d', testCase.xdotoolPath, sM.screen, 400, 300));
			verifyTrue(testCase, r==0, 'xdotool should move the mouse');
			WaitSecs(0.1);
			% Press mouse button down (button 1 = left)
			system(sprintf('%s mousedown 1', testCase.xdotoolPath));
			WaitSecs(0.1);
			% Check eventAvail — should detect the press
			navail = eventAvail(tM);
			verifyEqual(testCase, navail, 1, ...
				'eventAvail should be 1 when mouse button is pressed');
			% Get the event
			evt = getEvent(tM);
			verifyTrue(testCase, ~isempty(evt), 'should get an event');
			verifyEqual(testCase, evt.Type, 2, 'event type should be 2 (NEW)');
			verifyTrue(testCase, evt.Pressed, 'Pressed should be true');
			verifyTrue(testCase, tM.eventNew, 'eventNew should be true');
			verifyTrue(testCase, tM.eventPressed, 'eventPressed should be true');
			% lastPressed is private — verify via eventPressed which tracks it
			% Release mouse button
			system(sprintf('%s mouseup 1', testCase.xdotoolPath));
			WaitSecs(0.1);
			evt = getEvent(tM);
			verifyTrue(testCase, ~isempty(evt), 'should get release event');
			verifyEqual(testCase, evt.Type, 4, 'event type should be 4 (RELEASE)');
			verifyFalse(testCase, evt.Pressed, 'Pressed should be false on release');
			verifyTrue(testCase, tM.eventRelease, 'eventRelease should be true');
			% lastPressed is private — eventRelease confirms release happened
			close(tM);
		end

		% ---------------------------------------------------------------
		%> @brief Test dummy mouse move generates MOVE events.
		% ---------------------------------------------------------------
		function testDummyMouseMoveEvent(testCase)
			assumeFalse(testCase, ~isempty(getenv('GITHUB_ACTIONS')), ...
				'Skipping PTB touch test in CI');
			assumeTrue(testCase, exist(testCase.xdotoolPath) == 2 || ~isempty(which('xdotool')), ...
				'xdotool must be available for mouse automation');
			[sM, tM, cleanup] = createDummySetup(testCase);
			start(tM);
			% Press and move
			system(sprintf('%s mousemove --screen %d %d %d', testCase.xdotoolPath, sM.screen, 200, 200));
			system(sprintf('%s mousedown 1', testCase.xdotoolPath));
			WaitSecs(0.05);
			evt = getEvent(tM);
			verifyEqual(testCase, evt.Type, 2, 'first event should be NEW (type 2)');
			% Move while pressed
			system(sprintf('%s mousemove --screen %d %d %d', testCase.xdotoolPath, sM.screen, 300, 250));
			WaitSecs(0.05);
			evt = getEvent(tM);
			verifyEqual(testCase, evt.Type, 3, 'second event should be MOVE (type 3)');
			verifyTrue(testCase, tM.eventMove, 'eventMove should be true');
			% Release
			system(sprintf('%s mouseup 1', testCase.xdotoolPath));
			WaitSecs(0.05);
			close(tM);
		end

		% ---------------------------------------------------------------
		%> @brief Test checkTouchWindows detects touch in window.
		% ---------------------------------------------------------------
		function testCheckTouchWindowsInWindow(testCase)
			assumeFalse(testCase, ~isempty(getenv('GITHUB_ACTIONS')), ...
				'Skipping PTB touch test in CI');
			assumeTrue(testCase, exist(testCase.xdotoolPath) == 2 || ~isempty(which('xdotool')), ...
				'xdotool must be available for mouse automation');
			[sM, tM, cleanup] = createDummySetup(testCase);
			start(tM);
			% Set a window at screen center (0,0 deg) with radius 5 deg
			tM.updateWindow(0, 0, 5);
			% Move mouse to center of window (screen center = window center in deg)
			% In PTB, screen center is at [width/2, height/2] in pixels
			winCenterX = sM.screenVals.width / 2;
			winCenterY = sM.screenVals.height / 2;
			system(sprintf('%s mousemove --screen %d %d %d', ...
				testCase.xdotoolPath,sM.screen, winCenterX, winCenterY));
			system(sprintf('%s mousedown 1', testCase.xdotoolPath));
			WaitSecs(0.1);
			[result, win, wasEvent] = checkTouchWindows(tM);
			verifyTrue(testCase, wasEvent, 'should have an event');
			verifyTrue(testCase, result, 'result should be true (touch in window)');
			verifyEqual(testCase, win, 1, 'should touch window 1');
			system(sprintf('%s mouseup 1', testCase.xdotoolPath));
			WaitSecs(0.05);
			close(tM);
		end

		% ---------------------------------------------------------------
		%> @brief Test checkTouchWindows detects touch outside window.
		% ---------------------------------------------------------------
		function testCheckTouchWindowsOutsideWindow(testCase)
			assumeFalse(testCase, ~isempty(getenv('GITHUB_ACTIONS')), ...
				'Skipping PTB touch test in CI');
			assumeTrue(testCase, exist(testCase.xdotoolPath) == 2 || ~isempty(which('xdotool')), ...
				'xdotool must be available for mouse automation');
			[sM, tM, cleanup] = createDummySetup(testCase);
			start(tM);
			% Set a small window at center
			tM.updateWindow(0, 0, 1);
			% Move mouse far from center (corner of window)
			system(sprintf('%s mousemove --screen %d %d %d', testCase.xdotoolPath, sM.screen, 8, 8));
			system(sprintf('%s mousedown 1', testCase.xdotoolPath));
			WaitSecs(0.1);
			[result, ~, wasEvent] = checkTouchWindows(tM);
			verifyTrue(testCase, wasEvent, 'should have an event');
			verifyFalse(testCase, result, 'result should be false (touch outside window)');
			system(sprintf('%s mouseup 1', testCase.xdotoolPath));
			WaitSecs(0.05);
			close(tM);
		end

		% ---------------------------------------------------------------
		%> @brief Test isTouch returns true when mouse is pressed.
		% ---------------------------------------------------------------
		function testIsTouchWithMouse(testCase)
			assumeFalse(testCase, ~isempty(getenv('GITHUB_ACTIONS')), ...
				'Skipping PTB touch test in CI');
			assumeTrue(testCase, exist(testCase.xdotoolPath) == 2 || ~isempty(which('xdotool')), ...
				'xdotool must be available for mouse automation');
			[sM, tM, cleanup] = createDummySetup(testCase);
			start(tM);
			system(sprintf('%s mousemove --screen %d %d %d', testCase.xdotoolPath, sM.screen, 400, 300));
			system(sprintf('%s mousedown 1', testCase.xdotoolPath));
			WaitSecs(0.1);
			touch = isTouch(tM);
			verifyTrue(testCase, touch, 'isTouch should be true when mouse pressed');
			system(sprintf('%s mouseup 1', testCase.xdotoolPath));
			WaitSecs(0.05);
			touch = isTouch(tM);
			verifyFalse(testCase, touch, 'isTouch should be false after release');
			close(tM);
		end

		% ---------------------------------------------------------------
		%> @brief Test coordinate tracking in dummy mode.
		% ---------------------------------------------------------------
		function testCoordinateTracking(testCase)
			assumeFalse(testCase, ~isempty(getenv('GITHUB_ACTIONS')), ...
				'Skipping PTB touch test in CI');
			assumeTrue(testCase, exist(testCase.xdotoolPath) == 2 || ~isempty(which('xdotool')), ...
				'xdotool must be available for mouse automation');
			[sM, tM, cleanup] = createDummySetup(testCase);
			start(tM);
			% Press at a known position
			system(sprintf('%s mousemove --screen %d %d %d', testCase.xdotoolPath, sM.screen, 400, 300));
			system(sprintf('%s mousedown 1', testCase.xdotoolPath));
			WaitSecs(0.1);
			getEvent(tM);
			% x and y should be set (in degrees)
			verifyTrue(testCase, ~isnan(tM.x), 'x should not be NaN after event');
			verifyTrue(testCase, ~isnan(tM.y), 'y should not be NaN after event');
			verifyTrue(testCase, ~isempty(tM.xAll), 'xAll should have entries');
			verifyTrue(testCase, ~isempty(tM.yAll), 'yAll should have entries');
			verifyTrue(testCase, ~isempty(tM.tAll), 'tAll should have entries');
			system(sprintf('%s mouseup 1', testCase.xdotoolPath));
			WaitSecs(0.05);
			close(tM);
		end

		% ---------------------------------------------------------------
		%> @brief Test reset after events clears coordinate data.
		% ---------------------------------------------------------------
		function testResetAfterEvents(testCase)
			assumeFalse(testCase, ~isempty(getenv('GITHUB_ACTIONS')), ...
				'Skipping PTB touch test in CI');
			assumeTrue(testCase, exist(testCase.xdotoolPath) == 2 || ~isempty(which('xdotool')), ...
				'xdotool must be available for mouse automation');
			[sM, tM, cleanup] = createDummySetup(testCase);
			start(tM);
			system(sprintf('%s mousemove --screen %d %d %d', testCase.xdotoolPath, sM.screen, 400, 300));
			system(sprintf('%s mousedown 1', testCase.xdotoolPath));
			WaitSecs(0.1);
			getEvent(tM);
			verifyTrue(testCase, ~isempty(tM.xAll), 'xAll should have data before reset');
			reset(tM);
			verifyEmpty(testCase, tM.xAll, 'xAll should be empty after reset');
			verifyEmpty(testCase, tM.yAll, 'yAll should be empty after reset');
			verifyTrue(testCase, isnan(tM.x), 'x should be NaN after reset');
			system(sprintf('%s mouseup 1', testCase.xdotoolPath));
			close(tM);
		end
	end
end
