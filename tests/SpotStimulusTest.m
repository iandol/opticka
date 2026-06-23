% ========================================================================
%> @class SpotStimulusTest
%> @brief Class-based unit tests for spotStimulus.
%>
%> Tests construction, property defaults, type list, flash mode, contrast,
%> colour handling. CI-safe tests run without PTB; hardware-tagged tests
%> exercise setup/draw/animate/update/run with a real PTB window.
%>
%> Run with:
%>   >> runtests('tests/SpotStimulusTest.m')
%>   >> runtests('tests/SpotStimulusTest.m', '-ExcludeTag', 'hardware')
%>
%> Copyright (c) 2026 Ian Max Andolina — LGPL3, see LICENCE.md
% ========================================================================
classdef SpotStimulusTest < matlab.unittest.TestCase

	methods (TestClassSetup)
		function setupPath(testCase)
			addOptickaToPath;
		end
	end

	% ===================================================================
	% CI-SAFE TESTS
	% ===================================================================
	methods (Test)
		% ---------------------------------------------------------------
		%> @brief Test construction with defaults.
		% ---------------------------------------------------------------
		function testConstructionDefaults(testCase)
			s = spotStimulus('verbose', false);
			verifyEqual(testCase, s.type, 'simple', 'default type should be simple');
			verifyEqual(testCase, s.family, 'spot', 'family should be spot');
			verifyEqual(testCase, s.contrast, 1, 'default contrast should be 1');
			verifyEqual(testCase, s.flashTime, [0.25 0.25], 'default flashTime');
			verifyTrue(testCase, s.flashOn, 'default flashOn should be true');
			verifyEmpty(testCase, s.flashColour, 'default flashColour should be empty');
			verifyEqual(testCase, s.colour(1:3), [1 1 0], 'default colour should be yellow');
			verifyEqual(testCase, s.colour(4), 1, 'default alpha should be 1');
		end

		% ---------------------------------------------------------------
		%> @brief Test typeList.
		% ---------------------------------------------------------------
		function testTypeList(testCase)
			s = spotStimulus('verbose', false);
			verifyEqual(testCase, s.typeList, {'simple','flash'}, 'typeList');
		end

		% ---------------------------------------------------------------
		%> @brief Test custom properties.
		% ---------------------------------------------------------------
		function testCustomProperties(testCase)
			s = spotStimulus('verbose', false, ...
				'type', 'flash', 'flashTime', [0.1 0.2], ...
				'flashOn', false, 'contrast', 0.5, ...
				'flashColour', [0.5 0.5 0.5 1]);
			verifyEqual(testCase, s.type, 'flash', 'type should be flash');
			verifyEqual(testCase, s.flashTime, [0.1 0.2], 'flashTime');
			verifyFalse(testCase, s.flashOn, 'flashOn should be false');
			verifyEqual(testCase, s.contrast, 0.5, 'contrast should be 0.5');
			verifyEqual(testCase, s.flashColour(1:3), [0.5 0.5 0.5], ...
				'flashColour RGB');
		end

		% ---------------------------------------------------------------
		%> @brief Test colour set method.
		% ---------------------------------------------------------------
		function testColourSetRGB(testCase)
			s = spotStimulus('verbose', false);
			s.colour = [0.2 0.4 0.6];
			verifyEqual(testCase, s.colour(1:3), [0.2 0.4 0.6], 'RGB');
		end

		% ---------------------------------------------------------------
		%> @brief Test alpha clamping.
		% ---------------------------------------------------------------
		function testAlphaClamping(testCase)
			s = spotStimulus('verbose', false);
			s.alpha = 5;
			verifyEqual(testCase, s.alpha, 1, 'alpha should clamp to 1');
			s.alpha = -2;
			verifyEqual(testCase, s.alpha, 0, 'alpha should clamp to 0');
		end

		% ---------------------------------------------------------------
		%> @brief Test show/hide.
		% ---------------------------------------------------------------
		function testShowHide(testCase)
			s = spotStimulus('verbose', false);
			verifyTrue(testCase, s.isVisible, 'visible by default');
			hide(s);
			verifyFalse(testCase, s.isVisible, 'hidden after hide');
			show(s);
			verifyTrue(testCase, s.isVisible, 'visible after show');
		end

		% ---------------------------------------------------------------
		%> @brief Test setOffTime and setDelayTime.
		% ---------------------------------------------------------------
		function testSetOffAndDelayTime(testCase)
			s = spotStimulus('verbose', false);
			setOffTime(s, 2.0);
			verifyEqual(testCase, s.offTime, 2.0, 'offTime');
			setDelayTime(s, 0.25);
			verifyEqual(testCase, s.delayTime, 0.25, 'delayTime');
		end

		% ---------------------------------------------------------------
		%> @brief Test UUID.
		% ---------------------------------------------------------------
		function testUUID(testCase)
			s = spotStimulus('verbose', false);
			verifyTrue(testCase, ~isempty(s.uuid), 'should have UUID');
		end

		% ---------------------------------------------------------------
		%> @brief Test fullName.
		% ---------------------------------------------------------------
		function testFullName(testCase)
			s = spotStimulus('verbose', false, 'name', 'MySpot');
			verifyTrue(testCase, contains(s.fullName, 'MySpot'), ...
				'fullName contains name');
			verifyTrue(testCase, contains(s.fullName, 'spotStimulus'), ...
				'fullName contains class');
		end

		% ---------------------------------------------------------------
		%> @brief Test reset before setup.
		% ---------------------------------------------------------------
		function testResetBeforeSetup(testCase)
			s = spotStimulus('verbose', false);
			reset(s);
			verifyTrue(testCase, true, 'reset completed');
		end

		% ---------------------------------------------------------------
		%> @brief Test isRect is false.
		% ---------------------------------------------------------------
		function testIsRect(testCase)
			s = spotStimulus('verbose', false);
			verifyFalse(testCase, s.isRect, 'isRect should be false');
		end
	end

	% ===================================================================
	% HARDWARE TESTS
	% ===================================================================
	methods (Test, TestTags = {'hardware'})
		% ---------------------------------------------------------------
		%> @brief Test setup with PTB window.
		% ---------------------------------------------------------------
		function testSetupWithScreen(testCase)
			assumeFalse(testCase, ~isempty(getenv('GITHUB_ACTIONS')), ...
				'Skip PTB setup test in CI');
			sM = screenManager;
			sM.windowed = [0 0 800 600];
			sM.disableSyncTests = true;
			sM.visualDebug = true;
			sM.bitDepth = '8bit';
			open(sM);
			cleanup = onCleanup(@() close(sM));
			s = spotStimulus('verbose', false);
			setup(s, sM);
			verifyTrue(testCase, s.isSetup, 'should be setup');
			reset(s);
		end

		% ---------------------------------------------------------------
		%> @brief Test draw after setup.
		% ---------------------------------------------------------------
		function testDrawAfterSetup(testCase)
			assumeFalse(testCase, ~isempty(getenv('GITHUB_ACTIONS')), ...
				'Skip PTB draw test in CI');
			sM = screenManager;
			sM.windowed = [0 0 800 600];
			sM.disableSyncTests = true;
			sM.visualDebug = true;
			sM.bitDepth = '8bit';
			open(sM);
			cleanup = onCleanup(@() close(sM));
			s = spotStimulus('verbose', false);
			setup(s, sM);
			draw(s);
			verifyEqual(testCase, s.drawTick, 1, 'drawTick should be 1');
			reset(s);
		end

		% ---------------------------------------------------------------
		%> @brief Test animate after setup.
		% ---------------------------------------------------------------
		function testAnimateAfterSetup(testCase)
			assumeFalse(testCase, ~isempty(getenv('GITHUB_ACTIONS')), ...
				'Skip PTB animate test in CI');
			sM = screenManager;
			sM.windowed = [0 0 800 600];
			sM.disableSyncTests = true;
			sM.visualDebug = true;
			sM.bitDepth = '8bit';
			open(sM);
			cleanup = onCleanup(@() close(sM));
			s = spotStimulus('verbose', false);
			setup(s, sM);
			animate(s);
			verifyTrue(testCase, true, 'animate completed');
			reset(s);
		end

		% ---------------------------------------------------------------
		%> @brief Test update after setup.
		% ---------------------------------------------------------------
		function testUpdateAfterSetup(testCase)
			assumeFalse(testCase, ~isempty(getenv('GITHUB_ACTIONS')), ...
				'Skip PTB update test in CI');
			sM = screenManager;
			sM.windowed = [0 0 800 600];
			sM.disableSyncTests = true;
			sM.visualDebug = true;
			sM.bitDepth = '8bit';
			open(sM);
			cleanup = onCleanup(@() close(sM));
			s = spotStimulus('verbose', false);
			setup(s, sM);
			update(s);
			verifyTrue(testCase, true, 'update completed');
			reset(s);
		end

		% ---------------------------------------------------------------
		%> @brief Test run method.
		% ---------------------------------------------------------------
		function testRunMethod(testCase)
			assumeFalse(testCase, ~isempty(getenv('GITHUB_ACTIONS')), ...
				'Skip PTB run test in CI');
			s = spotStimulus('verbose', false);
			run(s, false, 1);
			verifyTrue(testCase, true, 'run() completed');
		end

		% ---------------------------------------------------------------
		%> @brief Test reset after setup clears state.
		% ---------------------------------------------------------------
		function testResetAfterSetup(testCase)
			assumeFalse(testCase, ~isempty(getenv('GITHUB_ACTIONS')), ...
				'Skip PTB reset test in CI');
			sM = screenManager;
			sM.windowed = [0 0 800 600];
			sM.disableSyncTests = true;
			sM.visualDebug = true;
			sM.bitDepth = '8bit';
			open(sM);
			cleanup = onCleanup(@() close(sM));
			s = spotStimulus('verbose', false);
			setup(s, sM);
			verifyTrue(testCase, s.isSetup, 'should be setup');
			reset(s);
			verifyFalse(testCase, s.isSetup, 'isSetup should be false after reset');
		end

		% ---------------------------------------------------------------
		%> @brief Test flash type setup and draw.
		% ---------------------------------------------------------------
		function testFlashModeSetup(testCase)
			assumeFalse(testCase, ~isempty(getenv('GITHUB_ACTIONS')), ...
				'Skip PTB flash test in CI');
			sM = screenManager;
			sM.windowed = [0 0 800 600];
			sM.disableSyncTests = true;
			sM.visualDebug = true;
			sM.bitDepth = '8bit';
			open(sM);
			cleanup = onCleanup(@() close(sM));
			s = spotStimulus('verbose', false, 'type', 'flash', ...
				'flashTime', [0.1 0.1]);
			setup(s, sM);
			verifyTrue(testCase, s.isSetup, 'flash spot should setup');
			draw(s);
			verifyEqual(testCase, s.drawTick, 1, 'drawTick should be 1');
			reset(s);
		end
	end
end
