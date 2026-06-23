% ========================================================================
%> @class ApparentMotionStimulusTest
%> @brief Class-based unit tests for apparentMotionStimulus.
%>
%> Tests construction, property defaults, type/interpMethod lists,
%> bar geometry, timing, direction, contrast, and the standard stimulus
%> API (show/hide, reset, UUID). CI-safe tests run without PTB;
%> hardware-tagged tests exercise setup/draw/animate/update/run with a
%> real PTB window.
%>
%> Run with:
%>   >> runtests('tests/ApparentMotionStimulusTest.m')
%>   >> runtests('tests/ApparentMotionStimulusTest.m', '-ExcludeTag', 'hardware')
%>
%> Copyright (c) 2026 Ian Max Andolina — LGPL3, see LICENCE.md
% ========================================================================
classdef ApparentMotionStimulusTest < matlab.unittest.TestCase

	methods (TestClassSetup)
		function setupPath(testCase)
			%> Add Opticka to MATLAB path once for all tests.
			addOptickaToPath;
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
			am = apparentMotionStimulus('verbose', false);
			verifyEqual(testCase, am.type, 'solid', 'default type should be solid');
			verifyEqual(testCase, am.family, 'apparentMotion', 'family should be apparentMotion');
			verifyEqual(testCase, am.barWidth, 1, 'default barWidth should be 1');
			verifyEqual(testCase, am.barHeight, 4, 'default barHeight should be 4');
			verifyEqual(testCase, am.nBars, 4, 'default nBars should be 4');
			verifyEqual(testCase, am.barSpacing, 3, 'default barSpacing should be 3');
			verifyEqual(testCase, am.timing, [0.2 0.1], 'default timing should be [0.2 0.1]');
			verifyEqual(testCase, am.direction, 'right', 'default direction should be right');
			verifyEqual(testCase, am.contrast, 1, 'default contrast should be 1');
			verifyEqual(testCase, am.scale, 1, 'default scale should be 1');
			verifyEqual(testCase, am.interpMethod, 'nearest', 'default interpMethod');
			verifyEqual(testCase, am.textureAspect, 1, 'default textureAspect');
			verifyEqual(testCase, am.size, 0, 'default size should be 0');
			verifyEqual(testCase, am.speed, 0, 'default speed should be 0');
			verifyEqual(testCase, am.pixelScale, 1, 'default pixelScale should be 1');
			verifyEmpty(testCase, am.modulateColour, 'default modulateColour empty');
		end

		% ---------------------------------------------------------------
		%> @brief Test typeList contains expected values.
		% ---------------------------------------------------------------
		function testTypeList(testCase)
			am = apparentMotionStimulus('verbose', false);
			verifyEqual(testCase, am.typeList, ...
				{'solid','random','randomColour','randomN','randomBW'}, ...
				'typeList should match expected values');
		end

		% ---------------------------------------------------------------
		%> @brief Test interpMethodList.
		% ---------------------------------------------------------------
		function testInterpMethodList(testCase)
			am = apparentMotionStimulus('verbose', false);
			verifyEqual(testCase, am.interpMethodList, ...
				{'nearest','linear','spline','cubic'}, ...
				'interpMethodList should match');
		end

		% ---------------------------------------------------------------
		%> @brief Test custom properties on construction.
		% ---------------------------------------------------------------
		function testCustomProperties(testCase)
			am = apparentMotionStimulus('verbose', false, ...
				'type', 'random', 'barWidth', 2, 'barHeight', 6, ...
				'nBars', 6, 'barSpacing', 4, 'timing', [0.1 0.2], ...
				'direction', 'left', 'contrast', 0.5);
			verifyEqual(testCase, am.type, 'random', 'type should be random');
			verifyEqual(testCase, am.barWidth, 2, 'barWidth should be 2');
			verifyEqual(testCase, am.barHeight, 6, 'barHeight should be 6');
			verifyEqual(testCase, am.nBars, 6, 'nBars should be 6');
			verifyEqual(testCase, am.barSpacing, 4, 'barSpacing should be 4');
			verifyEqual(testCase, am.timing, [0.1 0.2], 'timing should be [0.1 0.2]');
			verifyEqual(testCase, am.direction, 'left', 'direction should be left');
			verifyEqual(testCase, am.contrast, 0.5, 'contrast should be 0.5');
		end

		% ---------------------------------------------------------------
		%> @brief Test colour set method.
		% ---------------------------------------------------------------
		function testColourSetRGB(testCase)
			am = apparentMotionStimulus('verbose', false);
			am.colour = [0.5 0.5 0.5];
			verifyEqual(testCase, am.colour(1:3), [0.5 0.5 0.5], 'RGB set');
			verifyEqual(testCase, am.alpha, 1, 'alpha should remain 1');
		end

		% ---------------------------------------------------------------
		%> @brief Test colour with RGBA.
		% ---------------------------------------------------------------
		function testColourSetRGBA(testCase)
			am = apparentMotionStimulus('verbose', false);
			am.colour = [0.2 0.4 0.6 0.8];
			verifyEqual(testCase, am.colour(1:3), [0.2 0.4 0.6], 'RGB set');
			verifyEqual(testCase, am.alpha, 0.8, 'alpha from RGBA');
		end

		% ---------------------------------------------------------------
		%> @brief Test alpha clamping.
		% ---------------------------------------------------------------
		function testAlphaClamping(testCase)
			am = apparentMotionStimulus('verbose', false);
			am.alpha = 10;
			verifyEqual(testCase, am.alpha, 1, 'alpha clamps to 1');
			am.alpha = -5;
			verifyEqual(testCase, am.alpha, 0, 'alpha clamps to 0');
		end

		% ---------------------------------------------------------------
		%> @brief Test show/hide methods.
		% ---------------------------------------------------------------
		function testShowHide(testCase)
			am = apparentMotionStimulus('verbose', false);
			verifyTrue(testCase, am.isVisible, 'should be visible by default');
			hide(am);
			verifyFalse(testCase, am.isVisible, 'should be hidden after hide');
			show(am);
			verifyTrue(testCase, am.isVisible, 'should be visible after show');
		end

		% ---------------------------------------------------------------
		%> @brief Test setOffTime and setDelayTime.
		% ---------------------------------------------------------------
		function testSetOffAndDelayTime(testCase)
			am = apparentMotionStimulus('verbose', false);
			setOffTime(am, 3.0);
			verifyEqual(testCase, am.offTime, 3.0, 'offTime should be 3.0');
			setDelayTime(am, 0.75);
			verifyEqual(testCase, am.delayTime, 0.75, 'delayTime should be 0.75');
		end

		% ---------------------------------------------------------------
		%> @brief Test UUID from optickaCore.
		% ---------------------------------------------------------------
		function testHasUUID(testCase)
			am = apparentMotionStimulus('verbose', false);
			verifyTrue(testCase, ~isempty(am.uuid), 'should have a UUID');
		end

		% ---------------------------------------------------------------
		%> @brief Test fullName.
		% ---------------------------------------------------------------
		function testFullName(testCase)
			am = apparentMotionStimulus('verbose', false, 'name', 'TestAM');
			verifyTrue(testCase, contains(am.fullName, 'TestAM'), ...
				'fullName should contain name');
			verifyTrue(testCase, contains(am.fullName, 'apparentMotionStimulus'), ...
				'fullName should contain class name');
		end

		% ---------------------------------------------------------------
		%> @brief Test reset before setup is safe.
		% ---------------------------------------------------------------
		function testResetBeforeSetup(testCase)
			am = apparentMotionStimulus('verbose', false);
			reset(am);
			verifyFalse(testCase, am.isSetup, 'should not be setup after reset');
		end

		% ---------------------------------------------------------------
		%> @brief Test modulateColour property.
		% ---------------------------------------------------------------
		function testModulateColour(testCase)
			am = apparentMotionStimulus('verbose', false);
			am.modulateColour = [0.5 0.5 0.5 1];
			verifyEqual(testCase, am.modulateColour, [0.5 0.5 0.5 1], ...
				'modulateColour should be set');
		end

		% ---------------------------------------------------------------
		%> @brief Test interpMethod property.
		% ---------------------------------------------------------------
		function testInterpMethod(testCase)
			am = apparentMotionStimulus('verbose', false, 'interpMethod', 'linear');
			verifyEqual(testCase, am.interpMethod, 'linear', ...
				'interpMethod should be linear');
		end
	end

	% ===================================================================
	% HARDWARE TESTS (require PTB window — excluded from CI)
	% ===================================================================
	methods (Test, TestTags = {'hardware'})
		% ---------------------------------------------------------------
		%> @brief Test setup with a real PTB screenManager.
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
			am = apparentMotionStimulus('verbose', false);
			setup(am, sM);
			verifyTrue(testCase, am.isSetup, 'should be setup');
			verifyTrue(testCase, ~isempty(am.texture), 'texture should be created');
			verifyTrue(testCase, am.texture > 0, 'texture pointer should be positive');
			verifyTrue(testCase, ~isempty(am.matrix), 'matrix should be created');
			verifyTrue(testCase, ~isempty(am.mvRects), 'mvRects should be computed');
			verifyTrue(testCase, ~isempty(am.frameTimes), 'frameTimes should be computed');
			reset(am);
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
			am = apparentMotionStimulus('verbose', false);
			setup(am, sM);
			draw(am);
			verifyEqual(testCase, am.drawTick, 1, 'drawTick should be 1 after one draw');
			reset(am);
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
			am = apparentMotionStimulus('verbose', false);
			setup(am, sM);
			animate(am);
			verifyEqual(testCase, am.tick, 0, 'tick should be 0 (draw not called)');
			reset(am);
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
			am = apparentMotionStimulus('verbose', false);
			setup(am, sM);
			update(am);
			verifyTrue(testCase, true, 'update completed without error');
			reset(am);
		end

		% ---------------------------------------------------------------
		%> @brief Test the run method.
		% ---------------------------------------------------------------
		function testRunMethod(testCase)
			assumeFalse(testCase, ~isempty(getenv('GITHUB_ACTIONS')), ...
				'Skipping PTB run test in CI');
			am = apparentMotionStimulus('verbose', false);
			run(am, false, 1);
			verifyTrue(testCase, true, 'run() completed without error');
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
			am = apparentMotionStimulus('verbose', false);
			setup(am, sM);
			reset(am);
			verifyFalse(testCase, am.isSetup, 'isSetup should be false after reset');
		end

		% ---------------------------------------------------------------
		%> @brief Test multiple draws increment drawTick.
		% ---------------------------------------------------------------
		function testMultipleDraws(testCase)
			assumeFalse(testCase, ~isempty(getenv('GITHUB_ACTIONS')), ...
				'Skipping PTB multi-draw test in CI');
			sM = screenManager;
			sM.windowed = [0 0 800 600];
			sM.disableSyncTests = true;
			sM.visualDebug = true;
			sM.bitDepth = '8bit';
			open(sM);
			cleanup = onCleanup(@() close(sM));
			am = apparentMotionStimulus('verbose', false);
			setup(am, sM);
			draw(am);
			animate(am);
			draw(am);
			verifyEqual(testCase, am.drawTick, 2, 'drawTick should be 2 after two draws');
			reset(am);
		end
	end
end
