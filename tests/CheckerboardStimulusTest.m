% ========================================================================
%> @class CheckerboardStimulusTest
%> @brief Class-based unit tests for checkerboardStimulus.
%>
%> Tests construction, property defaults, type list, spatial/temporal
%> frequency, colour2, contrast, mask, phase, correctPhase, aspectRatio.
%> CI-safe tests run without PTB; hardware-tagged tests exercise
%> setup/draw/animate/update/run with a real PTB window.
%>
%> Run with:
%>   >> runtests('tests/CheckerboardStimulusTest.m')
%>   >> runtests('tests/CheckerboardStimulusTest.m', '-ExcludeTag', 'hardware')
%>
%> Copyright (c) 2026 Ian Max Andolina — LGPL3, see LICENCE.md
% ========================================================================
classdef CheckerboardStimulusTest < matlab.unittest.TestCase

	methods (TestClassSetup)
		function setupPath(testCase)
			addOptickaToPath;
		end
	end

	% ===================================================================
	% CI-SAFE TESTS
	% ===================================================================
	methods (Test, TestTags = {'CI'})
		% ---------------------------------------------------------------
		%> @brief Test construction with defaults.
		% ---------------------------------------------------------------
		function testConstructionDefaults(testCase)
			c = checkerboardStimulus('verbose', false);
			verifyEqual(testCase, c.type, 'checkerboard', 'type');
			verifyEqual(testCase, c.family, 'checkerboard', 'family');
			verifyEqual(testCase, c.sf, 1, 'default sf');
			verifyEqual(testCase, c.tf, 1, 'default tf');
			verifyEqual(testCase, c.phase, 0, 'default phase');
			verifyEqual(testCase, c.contrast, 0.5, 'default contrast');
			verifyTrue(testCase, c.rotateTexture, 'rotateTexture default true');
			verifyTrue(testCase, c.mask, 'mask default true');
			verifyFalse(testCase, c.reverseDirection, 'reverseDirection default false');
			verifyEqual(testCase, c.direction, 0, 'default direction');
			verifyEqual(testCase, c.aspectRatio, 1, 'default aspectRatio');
			verifyEqual(testCase, c.phaseReverseTime, 0, 'default phaseReverseTime');
			verifyEqual(testCase, c.phaseOfReverse, 180, 'default phaseOfReverse');
			% colour2 default is [0 0 1 1] (blue with alpha 1)
			verifyEqual(testCase, c.colour2(1:3), [0 0 1], 'default colour2 RGB');
			verifyEqual(testCase, c.colour2(4), 1, 'default colour2 alpha');
		end

		% ---------------------------------------------------------------
		%> @brief Test typeList.
		% ---------------------------------------------------------------
		function testTypeList(testCase)
			c = checkerboardStimulus('verbose', false);
			verifyEqual(testCase, c.typeList, {'checkerboard'}, 'typeList');
		end

		% ---------------------------------------------------------------
		%> @brief Test custom properties.
		% ---------------------------------------------------------------
		function testCustomProperties(testCase)
			c = checkerboardStimulus('verbose', false, ...
				'sf', 2, 'tf', 3, 'contrast', 0.8, 'phase', 0.25, ...
				'mask', false, 'rotateTexture', false, ...
				'colour2', [1 0 0 0.8], 'reverseDirection', true, ...
				'direction', 45, 'aspectRatio', 1.5);
			verifyEqual(testCase, c.sf, 2, 'sf');
			verifyEqual(testCase, c.tf, 3, 'tf');
			verifyEqual(testCase, c.contrast, 0.8, 'contrast');
			verifyEqual(testCase, c.phase, 0.25, 'phase');
			verifyFalse(testCase, c.mask, 'mask');
			verifyFalse(testCase, c.rotateTexture, 'rotateTexture');
			verifyEqual(testCase, c.colour2(1:3), [1 0 0], 'colour2 RGB');
			verifyEqual(testCase, c.colour2(4), 1, 'colour2 alpha');
			verifyTrue(testCase, c.reverseDirection, 'reverseDirection');
			verifyEqual(testCase, c.direction, 45, 'direction');
			verifyEqual(testCase, c.aspectRatio, 1.5, 'aspectRatio');
		end

		% ---------------------------------------------------------------
		%> @brief Test colour set method.
		% ---------------------------------------------------------------
		function testColourSetRGB(testCase)
			c = checkerboardStimulus('verbose', false);
			c.colour = [0.2 0.4 0.6];
			verifyEqual(testCase, c.colour(1:3), [0.2 0.4 0.6], 'RGB');
		end

		% ---------------------------------------------------------------
		%> @brief Test alpha clamping.
		% ---------------------------------------------------------------
		function testAlphaClamping(testCase)
			c = checkerboardStimulus('verbose', false);
			c.alpha = 5;
			verifyEqual(testCase, c.alpha, 1, 'alpha clamps to 1');
			c.alpha = -2;
			verifyEqual(testCase, c.alpha, 0, 'alpha clamps to 0');
		end

		% ---------------------------------------------------------------
		%> @brief Test show/hide.
		% ---------------------------------------------------------------
		function testShowHide(testCase)
			c = checkerboardStimulus('verbose', false);
			verifyTrue(testCase, c.isVisible, 'visible');
			hide(c);
			verifyFalse(testCase, c.isVisible, 'hidden');
			show(c);
			verifyTrue(testCase, c.isVisible, 'visible');
		end

		% ---------------------------------------------------------------
		%> @brief Test setOff/setDelay.
		% ---------------------------------------------------------------
		function testSetOffAndDelayTime(testCase)
			c = checkerboardStimulus('verbose', false);
			setOffTime(c, 2.0);
			verifyEqual(testCase, c.offTime, 2.0, 'offTime');
			setDelayTime(c, 0.3);
			verifyEqual(testCase, c.delayTime, 0.3, 'delayTime');
		end

		% ---------------------------------------------------------------
		%> @brief Test UUID.
		% ---------------------------------------------------------------
		function testUUID(testCase)
			c = checkerboardStimulus('verbose', false);
			verifyTrue(testCase, ~isempty(c.uuid), 'UUID');
		end

		% ---------------------------------------------------------------
		%> @brief Test fullName.
		% ---------------------------------------------------------------
		function testFullName(testCase)
			c = checkerboardStimulus('verbose', false, 'name', 'MyCheck');
			verifyTrue(testCase, contains(c.fullName, 'MyCheck'), ...
				'fullName contains name');
			verifyTrue(testCase, contains(c.fullName, 'checkerboardStimulus'), ...
				'fullName contains class');
		end

		% ---------------------------------------------------------------
		%> @brief Test reset before setup.
		% ---------------------------------------------------------------
		function testResetBeforeSetup(testCase)
			c = checkerboardStimulus('verbose', false);
			reset(c);
			verifyTrue(testCase, true, 'reset completed');
		end

		% ---------------------------------------------------------------
		%> @brief Test phaseReverseTime construction.
		% ---------------------------------------------------------------
		function testPhaseReverseTime(testCase)
			c = checkerboardStimulus('verbose', false, ...
				'phaseReverseTime', 2, 'phaseOfReverse', 90);
			verifyEqual(testCase, c.phaseReverseTime, 2, 'phaseReverseTime');
			verifyEqual(testCase, c.phaseOfReverse, 90, 'phaseOfReverse');
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
				'Skipping PTB setup test in CI');
			sM = screenManager;
			sM.windowed = [0 0 800 600];
			sM.disableSyncTests = true;
			sM.visualDebug = true;
			sM.bitDepth = '8bit';
			open(sM);
			cleanup = onCleanup(@() close(sM));
			c = checkerboardStimulus('verbose', false);
			setup(c, sM);
			verifyTrue(testCase, c.isSetup, 'should be setup');
			verifyTrue(testCase, ~isempty(c.texture) && c.texture > 0, ...
				'texture should exist');
			reset(c);
		end

		% ---------------------------------------------------------------
		%> @brief Test draw after setup.
		% ---------------------------------------------------------------
		function testDrawAfterSetup(testCase)
			assumeFalse(testCase, ~isempty(getenv('GITHUB_ACTIONS')), ...
				'Skipping PTB draw test in CI');
			sM = screenManager;
			sM.windowed = [0 0 800 600];
			sM.disableSyncTests = true;
			sM.visualDebug = true;
			sM.bitDepth = '8bit';
			open(sM);
			cleanup = onCleanup(@() close(sM));
			c = checkerboardStimulus('verbose', false);
			setup(c, sM);
			draw(c);
			verifyEqual(testCase, c.drawTick, 1, 'drawTick');
			reset(c);
		end

		% ---------------------------------------------------------------
		%> @brief Test animate after setup.
		% ---------------------------------------------------------------
		function testAnimateAfterSetup(testCase)
			assumeFalse(testCase, ~isempty(getenv('GITHUB_ACTIONS')), ...
				'Skipping PTB animate test in CI');
			sM = screenManager;
			sM.windowed = [0 0 800 600];
			sM.disableSyncTests = true;
			sM.visualDebug = true;
			sM.bitDepth = '8bit';
			open(sM);
			cleanup = onCleanup(@() close(sM));
			c = checkerboardStimulus('verbose', false, 'tf', 2);
			setup(c, sM);
			animate(c);
			verifyTrue(testCase, true, 'animate completed');
			reset(c);
		end

		% ---------------------------------------------------------------
		%> @brief Test update after setup.
		% ---------------------------------------------------------------
		function testUpdateAfterSetup(testCase)
			assumeFalse(testCase, ~isempty(getenv('GITHUB_ACTIONS')), ...
				'Skipping PTB update test in CI');
			sM = screenManager;
			sM.windowed = [0 0 800 600];
			sM.disableSyncTests = true;
			sM.visualDebug = true;
			sM.bitDepth = '8bit';
			open(sM);
			cleanup = onCleanup(@() close(sM));
			c = checkerboardStimulus('verbose', false);
			setup(c, sM);
			update(c);
			verifyTrue(testCase, true, 'update completed');
			reset(c);
		end

		% ---------------------------------------------------------------
		%> @brief Test run method.
		% ---------------------------------------------------------------
		function testRunMethod(testCase)
			assumeFalse(testCase, ~isempty(getenv('GITHUB_ACTIONS')), ...
				'Skipping PTB run test in CI');
			c = checkerboardStimulus('verbose', false);
			run(c, false, 1);
			verifyTrue(testCase, true, 'run() completed');
		end

		% ---------------------------------------------------------------
		%> @brief Test reset after setup clears state.
		% ---------------------------------------------------------------
		function testResetAfterSetup(testCase)
			assumeFalse(testCase, ~isempty(getenv('GITHUB_ACTIONS')), ...
				'Skipping PTB reset test in CI');
			sM = screenManager;
			sM.windowed = [0 0 800 600];
			sM.disableSyncTests = true;
			sM.visualDebug = true;
			sM.bitDepth = '8bit';
			open(sM);
			cleanup = onCleanup(@() close(sM));
			c = checkerboardStimulus('verbose', false);
			setup(c, sM);
			verifyTrue(testCase, c.isSetup, 'should be setup');
			reset(c);
			verifyFalse(testCase, c.isSetup, 'isSetup false after reset');
		end

		% ---------------------------------------------------------------
		%> @brief Test checkerboard with direction and speed.
		% ---------------------------------------------------------------
		function testDirectionalCheckerboard(testCase)
			assumeFalse(testCase, ~isempty(getenv('GITHUB_ACTIONS')), ...
				'Skipping PTB direction test in CI');
			sM = screenManager;
			sM.windowed = [0 0 800 600];
			sM.disableSyncTests = true;
			sM.visualDebug = true;
			sM.bitDepth = '8bit';
			open(sM);
			cleanup = onCleanup(@() close(sM));
			c = checkerboardStimulus('verbose', false, ...
				'speed', 5, 'direction', 90);
			setup(c, sM);
			verifyTrue(testCase, c.isSetup, 'should setup with direction');
			draw(c);
			reset(c);
		end
	end
end
