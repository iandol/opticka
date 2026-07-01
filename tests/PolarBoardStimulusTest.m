% ========================================================================
%> @class PolarBoardStimulusTest
%> @brief Class-based unit tests for polarBoardStimulus.
%>
%> Tests construction, property defaults, type list, custom properties,
%> sf/sf2 spatial frequency, colour/colour2, contrast, mask, phase,
%> direction, visibleRate, show/hide, setOff/setDelay, UUID, fullName,
%> and reset before setup. CI-safe tests run without PTB; hardware-tagged
%> tests exercise setup/draw/animate/update/run with a real PTB window.
%>
%> Run with:
%>   >> runtests('tests/PolarBoardStimulusTest.m')
%>   >> runtests('tests/PolarBoardStimulusTest.m', '-ExcludeTag', 'hardware')
%>
%> Copyright (c) 2026 Ian Max Andolina — LGPL3, see LICENCE.md
% ========================================================================
classdef PolarBoardStimulusTest < matlab.unittest.TestCase

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
			p = polarBoardStimulus('verbose', false);
			verifyEqual(testCase, p.type, '', 'default type');
			verifyEqual(testCase, p.family, 'checkerboard', 'family');
			verifyEqual(testCase, p.name, 'polar-board', 'default name');
			verifyTrue(testCase, p.isRect, 'isRect default true');
			verifyEqual(testCase, p.sf, 1, 'default sf');
			verifyEqual(testCase, p.tf, 1, 'default tf');
			verifyEqual(testCase, p.sf2, 20, 'default sf2');
			verifyEqual(testCase, p.sigma, -1, 'default sigma');
			verifyEqual(testCase, p.phase, 0, 'default phase');
			verifyEqual(testCase, p.contrast, 0.5, 'default contrast');
			verifyTrue(testCase, p.rotateTexture, 'rotateTexture default true');
			verifyTrue(testCase, p.mask, 'mask default true');
			verifyFalse(testCase, p.reverseDirection, 'reverseDirection default false');
			verifyEqual(testCase, p.direction, 0, 'default direction');
			verifyFalse(testCase, p.correctBaseColour, 'correctBaseColour default false');
			verifyEqual(testCase, p.phaseReverseTime, 0, 'default phaseReverseTime');
			verifyEqual(testCase, p.phaseOfReverse, 180, 'default phaseOfReverse');
			verifyEmpty(testCase, p.visibleRate, 'default visibleRate empty');
			verifyEmpty(testCase, p.baseColour, 'default baseColour empty');
			verifyEqual(testCase, p.arcValue, [0 0], 'default arcValue');
			verifyFalse(testCase, p.arcSymmetry, 'default arcSymmetry false');
			verifyEqual(testCase, p.centerMask, 0, 'default centerMask');
			% colour default is [1 1 1 1] (white with alpha 1)
			verifyEqual(testCase, p.colour(1:3), [1 1 1], 'default colour RGB');
			verifyEqual(testCase, p.colour(4), 1, 'default colour alpha');
			% colour2 default is [0 0 0 1] (black with alpha 1)
			verifyEqual(testCase, p.colour2(1:3), [0 0 0], 'default colour2 RGB');
			verifyEqual(testCase, p.colour2(4), 1, 'default colour2 alpha');
		end

		% ---------------------------------------------------------------
		%> @brief Test typeList (Constant property).
		% ---------------------------------------------------------------
		function testTypeList(testCase)
			p = polarBoardStimulus('verbose', false);
			verifyEqual(testCase, p.typeList, {'';'randdrift';'spiraldrift';'sine'}, ...
				'typeList');
		end

		% ---------------------------------------------------------------
		%> @brief Test custom properties.
		% ---------------------------------------------------------------
		function testCustomProperties(testCase)
			p = polarBoardStimulus('verbose', false, ...
				'sf', 2, 'tf', 3, 'sf2', 30, 'contrast', 0.8, ...
				'phase', 0.25, 'mask', false, 'rotateTexture', false, ...
				'colour2', [1 0 0 0.8], 'reverseDirection', true, ...
				'direction', 45, 'sigma', 5);
			verifyEqual(testCase, p.sf, 2, 'sf');
			verifyEqual(testCase, p.tf, 3, 'tf');
			verifyEqual(testCase, p.sf2, 30, 'sf2');
			verifyEqual(testCase, p.contrast, 0.8, 'contrast');
			verifyEqual(testCase, p.phase, 0.25, 'phase');
			verifyFalse(testCase, p.mask, 'mask');
			verifyFalse(testCase, p.rotateTexture, 'rotateTexture');
			verifyEqual(testCase, p.colour2(1:3), [1 0 0], 'colour2 RGB');
			verifyEqual(testCase, p.colour2(4), 0.8, 'colour2 alpha');
			verifyTrue(testCase, p.reverseDirection, 'reverseDirection');
			verifyEqual(testCase, p.direction, 45, 'direction');
			verifyEqual(testCase, p.sigma, 5, 'sigma');
		end

		% ---------------------------------------------------------------
		%> @brief Test sf2 (radial spatial frequency) property.
		% ---------------------------------------------------------------
		function testSf2Property(testCase)
			p = polarBoardStimulus('verbose', false, 'sf2', 16);
			verifyEqual(testCase, p.sf2, 16, 'sf2 should be 16');
			p.sf2 = 24;
			verifyEqual(testCase, p.sf2, 24, 'sf2 should be 24 after set');
		end

		% ---------------------------------------------------------------
		%> @brief Test direction defaults to angle (both default to 0).
		% ---------------------------------------------------------------
		function testDirectionDefaultsToAngle(testCase)
			p = polarBoardStimulus('verbose', false);
			verifyEqual(testCase, p.direction, p.angle, ...
				'direction should default to angle');
			verifyEqual(testCase, p.direction, 0, 'direction default is 0');
			% setting direction independently
			p2 = polarBoardStimulus('verbose', false, 'direction', 90);
			verifyEqual(testCase, p2.direction, 90, 'direction set to 90');
		end

		% ---------------------------------------------------------------
		%> @brief Test colour set method.
		% ---------------------------------------------------------------
		function testColourSetRGB(testCase)
			p = polarBoardStimulus('verbose', false);
			p.colour = [0.2 0.4 0.6];
			verifyEqual(testCase, p.colour(1:3), [0.2 0.4 0.6], 'RGB');
		end

		% ---------------------------------------------------------------
		%> @brief Test alpha clamping.
		% ---------------------------------------------------------------
		function testAlphaClamping(testCase)
			p = polarBoardStimulus('verbose', false);
			p.alpha = 5;
			verifyEqual(testCase, p.alpha, 1, 'alpha clamps to 1');
			p.alpha = -2;
			verifyEqual(testCase, p.alpha, 0, 'alpha clamps to 0');
		end

		% ---------------------------------------------------------------
		%> @brief Test show/hide.
		% ---------------------------------------------------------------
		function testShowHide(testCase)
			p = polarBoardStimulus('verbose', false);
			verifyTrue(testCase, p.isVisible, 'visible');
			hide(p);
			verifyFalse(testCase, p.isVisible, 'hidden');
			show(p);
			verifyTrue(testCase, p.isVisible, 'visible');
		end

		% ---------------------------------------------------------------
		%> @brief Test setOffTime and setDelayTime.
		% ---------------------------------------------------------------
		function testSetOffAndDelayTime(testCase)
			p = polarBoardStimulus('verbose', false);
			setOffTime(p, 2.0);
			verifyEqual(testCase, p.offTime, 2.0, 'offTime');
			setDelayTime(p, 0.3);
			verifyEqual(testCase, p.delayTime, 0.3, 'delayTime');
		end

		% ---------------------------------------------------------------
		%> @brief Test UUID.
		% ---------------------------------------------------------------
		function testUUID(testCase)
			p = polarBoardStimulus('verbose', false);
			verifyTrue(testCase, ~isempty(p.uuid), 'UUID');
		end

		% ---------------------------------------------------------------
		%> @brief Test fullName.
		% ---------------------------------------------------------------
		function testFullName(testCase)
			p = polarBoardStimulus('verbose', false, 'name', 'MyPolar');
			verifyTrue(testCase, contains(p.fullName, 'MyPolar'), ...
				'fullName contains name');
			verifyTrue(testCase, contains(p.fullName, 'polarBoardStimulus'), ...
				'fullName contains class');
		end

		% ---------------------------------------------------------------
		%> @brief Test reset before setup.
		% ---------------------------------------------------------------
		function testResetBeforeSetup(testCase)
			p = polarBoardStimulus('verbose', false);
			reset(p);
			verifyFalse(testCase, p.isSetup, 'should not be setup after reset');
		end

		% ---------------------------------------------------------------
		%> @brief Test visibleRate property.
		% ---------------------------------------------------------------
		function testVisibleRate(testCase)
			p = polarBoardStimulus('verbose', false, 'visibleRate', 8);
			verifyEqual(testCase, p.visibleRate, 8, 'visibleRate');
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
			p = polarBoardStimulus('verbose', false);
			setup(p, sM);
			verifyTrue(testCase, p.isSetup, 'should be setup');
			verifyTrue(testCase, ~isempty(p.texture) && p.texture > 0, ...
				'texture should exist');
			reset(p);
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
			p = polarBoardStimulus('verbose', false);
			setup(p, sM);
			draw(p);
			verifyEqual(testCase, p.drawTick, 1, 'drawTick');
			reset(p);
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
			p = polarBoardStimulus('verbose', false, 'tf', 2);
			setup(p, sM);
			animate(p);
			verifyTrue(testCase, true, 'animate completed');
			reset(p);
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
			p = polarBoardStimulus('verbose', false);
			setup(p, sM);
			update(p);
			verifyTrue(testCase, true, 'update completed');
			reset(p);
		end

		% ---------------------------------------------------------------
		%> @brief Test run method.
		% ---------------------------------------------------------------
		function testRunMethod(testCase)
			assumeFalse(testCase, ~isempty(getenv('GITHUB_ACTIONS')), ...
				'Skipping PTB run test in CI');
			p = polarBoardStimulus('verbose', false);
			run(p, false, 1);
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
			p = polarBoardStimulus('verbose', false);
			setup(p, sM);
			verifyTrue(testCase, p.isSetup, 'should be setup');
			reset(p);
			verifyFalse(testCase, p.isSetup, 'isSetup false after reset');
		end
	end
end
