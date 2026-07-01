% ========================================================================
%> @class ColourGratingStimulusTest
%> @brief Class-based unit tests for colourGratingStimulus.
%>
%> Tests construction, property defaults, type list validation, colour
%> and colour2 handling, contrast, correctBaseColour, phase, mask,
%> correctPhase. CI-safe tests run without PTB; hardware-tagged tests
%> exercise setup/draw/animate/update/run with a real PTB window.
%>
%> Run with:
%>   >> runtests('tests/ColourGratingStimulusTest.m')
%>   >> runtests('tests/ColourGratingStimulusTest.m', '-ExcludeTag', 'hardware')
%>
%> Copyright (c) 2026 Ian Max Andolina — LGPL3, see LICENCE.md
% ========================================================================
classdef ColourGratingStimulusTest < matlab.unittest.TestCase

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
			c = colourGratingStimulus('verbose', false);
			verifyEqual(testCase, c.type, 'sinusoid', 'default type');
			verifyEqual(testCase, c.family, 'grating', 'family should be grating');
			verifyEqual(testCase, c.sf, 1, 'default sf');
			verifyEqual(testCase, c.tf, 1, 'default tf');
			verifyEqual(testCase, c.phase, 0, 'default phase');
			verifyEqual(testCase, c.contrast, 0.5, 'default contrast');
			verifyTrue(testCase, c.rotateTexture, 'rotateTexture default true');
			verifyTrue(testCase, c.mask, 'mask default true');
			verifyFalse(testCase, c.reverseDirection, 'reverseDirection default false');
			verifyFalse(testCase, c.correctPhase, 'correctPhase default false');
			verifyFalse(testCase, c.correctBaseColour, 'correctBaseColour default false');
			verifyEqual(testCase, c.aspectRatio, 1, 'aspectRatio');
			verifyEmpty(testCase, c.baseColour, 'baseColour default empty');
			% colour2 default: [0 1 0 1] (green, alpha 1)
			verifyEqual(testCase, c.colour2(1:3), [0 1 0], 'default colour2 RGB');
			verifyEqual(testCase, c.colour2(4), 1, 'default colour2 alpha');
		end

		% ---------------------------------------------------------------
		%> @brief Test typeList (Constant property).
		% ---------------------------------------------------------------
		function testTypeList(testCase)
			c = colourGratingStimulus('verbose', false);
			verifyEqual(testCase, c.typeList, {'sinusoid';'square'}, 'typeList');
		end

		% ---------------------------------------------------------------
		%> @brief Test custom properties.
		% ---------------------------------------------------------------
		function testCustomProperties(testCase)
			c = colourGratingStimulus('verbose', false, ...
				'sf', 3, 'tf', 2, 'contrast', 0.75, 'phase', 0.5, ...
				'mask', false, 'rotateTexture', false, ...
				'colour2', [1 0 1 0.8], 'reverseDirection', true, ...
				'correctPhase', true, 'correctBaseColour', true, ...
				'direction', 90, 'aspectRatio', 1.5, ...
				'type', 'square', 'sigma', 5);
			verifyEqual(testCase, c.sf, 3, 'sf');
			verifyEqual(testCase, c.tf, 2, 'tf');
			verifyEqual(testCase, c.contrast, 0.75, 'contrast');
			verifyEqual(testCase, c.phase, 0.5, 'phase');
			verifyFalse(testCase, c.mask, 'mask');
			verifyFalse(testCase, c.rotateTexture, 'rotateTexture');
			verifyEqual(testCase, c.colour2(1:3), [1 0 1], 'colour2 RGB');
			verifyEqual(testCase, c.colour2(4), 0.8, 'colour2 alpha');
			verifyTrue(testCase, c.reverseDirection, 'reverseDirection');
			verifyTrue(testCase, c.correctPhase, 'correctPhase');
			verifyTrue(testCase, c.correctBaseColour, 'correctBaseColour');
			verifyEqual(testCase, c.direction, 90, 'direction');
			verifyEqual(testCase, c.aspectRatio, 1.5, 'aspectRatio');
			verifyEqual(testCase, c.type, 'square', 'type');
			verifyEqual(testCase, c.sigma, 5, 'sigma');
		end

		% ---------------------------------------------------------------
		%> @brief Test colour set method.
		% ---------------------------------------------------------------
		function testColourSetRGB(testCase)
			c = colourGratingStimulus('verbose', false);
			c.colour = [0.2 0.4 0.6];
			verifyEqual(testCase, c.colour(1:3), [0.2 0.4 0.6], 'RGB');
		end

		% ---------------------------------------------------------------
		%> @brief Test alpha clamping.
		% ---------------------------------------------------------------
		function testAlphaClamping(testCase)
			c = colourGratingStimulus('verbose', false);
			c.alpha = 5;
			verifyEqual(testCase, c.alpha, 1, 'alpha clamps to 1');
			c.alpha = -2;
			verifyEqual(testCase, c.alpha, 0, 'alpha clamps to 0');
		end

		% ---------------------------------------------------------------
		%> @brief Test show/hide.
		% ---------------------------------------------------------------
		function testShowHide(testCase)
			c = colourGratingStimulus('verbose', false);
			verifyTrue(testCase, c.isVisible, 'visible');
			hide(c);
			verifyFalse(testCase, c.isVisible, 'hidden');
			show(c);
			verifyTrue(testCase, c.isVisible, 'visible');
		end

		% ---------------------------------------------------------------
		%> @brief Test setOff and delay.
		% ---------------------------------------------------------------
		function testSetOffAndDelayTime(testCase)
			c = colourGratingStimulus('verbose', false);
			setOffTime(c, 2.5);
			verifyEqual(testCase, c.offTime, 2.5, 'offTime');
			setDelayTime(c, 0.4);
			verifyEqual(testCase, c.delayTime, 0.4, 'delayTime');
		end

		% ---------------------------------------------------------------
		%> @brief Test UUID.
		% ---------------------------------------------------------------
		function testUUID(testCase)
			c = colourGratingStimulus('verbose', false);
			verifyTrue(testCase, ~isempty(c.uuid), 'UUID');
		end

		% ---------------------------------------------------------------
		%> @brief Test fullName.
		% ---------------------------------------------------------------
		function testFullName(testCase)
			c = colourGratingStimulus('verbose', false, 'name', 'TestCG');
			verifyTrue(testCase, contains(c.fullName, 'TestCG'), ...
				'fullName contains name');
			verifyTrue(testCase, contains(c.fullName, 'colourGratingStimulus'), ...
				'fullName contains class');
		end

		% ---------------------------------------------------------------
		%> @brief Test reset before setup.
		% ---------------------------------------------------------------
		function testResetBeforeSetup(testCase)
			c = colourGratingStimulus('verbose', false);
			reset(c);
			verifyTrue(testCase, true, 'reset completed');
		end

		% ---------------------------------------------------------------
		%> @brief Test phaseReverseTime.
		% ---------------------------------------------------------------
		function testPhaseReverseTime(testCase)
			c = colourGratingStimulus('verbose', false, ...
				'phaseReverseTime', 1.5, 'phaseOfReverse', 90);
			verifyEqual(testCase, c.phaseReverseTime, 1.5, 'phaseReverseTime');
			verifyEqual(testCase, c.phaseOfReverse, 90, 'phaseOfReverse');
		end

		% ---------------------------------------------------------------
		%> @brief Test visibleRate property.
		% ---------------------------------------------------------------
		function testVisibleRate(testCase)
			c = colourGratingStimulus('verbose', false, 'visibleRate', 8);
			verifyEqual(testCase, c.visibleRate, 8, 'visibleRate');
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
			c = colourGratingStimulus('verbose', false);
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
			c = colourGratingStimulus('verbose', false);
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
			c = colourGratingStimulus('verbose', false, 'tf', 2);
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
			c = colourGratingStimulus('verbose', false);
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
			c = colourGratingStimulus('verbose', false);
			run(c, false, 1);
			verifyTrue(testCase, true, 'run() completed');
		end

		% ---------------------------------------------------------------
		%> @brief Test reset after setup.
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
			c = colourGratingStimulus('verbose', false);
			setup(c, sM);
			verifyTrue(testCase, c.isSetup, 'should be setup');
			reset(c);
			verifyFalse(testCase, c.isSetup, 'isSetup false after reset');
		end

		% ---------------------------------------------------------------
		%> @brief Test square wave grating setup and draw.
		% ---------------------------------------------------------------
		function testSquareWave(testCase)
			assumeFalse(testCase, ~isempty(getenv('GITHUB_ACTIONS')), ...
				'Skipping PTB square test in CI');
			sM = screenManager;
			sM.windowed = [0 0 800 600];
			sM.disableSyncTests = true;
			sM.visualDebug = true;
			sM.bitDepth = '8bit';
			open(sM);
			cleanup = onCleanup(@() close(sM));
			c = colourGratingStimulus('verbose', false, ...
				'type', 'square', 'sigma', 5);
			setup(c, sM);
			verifyTrue(testCase, c.isSetup, 'square wave should setup');
			draw(c);
			verifyEqual(testCase, c.drawTick, 1, 'drawTick');
			reset(c);
		end
	end
end
