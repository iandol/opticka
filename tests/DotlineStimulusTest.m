% ========================================================================
%> @class DotlineStimulusTest
%> @brief Class-based unit tests for dotlineStimulus.
%>
%> Tests construction, property defaults, type/interpMethod lists,
%> itemSize, itemDistance, phase, direction, forceOrthogonal, useEven,
%> colour2, contrast, filter, and the standard stimulus API (show/hide,
%> reset, UUID). CI-safe tests run without PTB; hardware-tagged tests
%> exercise setup/draw/animate/update/run with a real PTB window.
%>
%> Run with:
%>   >> runtests('tests/DotlineStimulusTest.m')
%>   >> runtests('tests/DotlineStimulusTest.m', '-ExcludeTag', 'hardware')
%>
%> Copyright (c) 2026 Ian Max Andolina — LGPL3, see LICENCE.md
% ========================================================================
classdef DotlineStimulusTest < matlab.unittest.TestCase

	methods (TestClassSetup)
		
	end

	% ===================================================================
	% CI-SAFE TESTS (no PTB window required)
	% ===================================================================
	methods (Test, TestTags = {'CI'})
		% ---------------------------------------------------------------
		%> @brief Test construction with defaults.
		% ---------------------------------------------------------------
		function testConstructionDefaults(testCase)
			dl = dotlineStimulus('verbose', false);
			verifyEqual(testCase, dl.type, 'circle', 'default type should be circle');
			verifyEqual(testCase, dl.family, 'texture', 'family should be texture');
			verifyEqual(testCase, dl.itemSize, 0.8, 'default itemSize should be 0.8');
			verifyEqual(testCase, dl.itemDistance, 1, 'default itemDistance should be 1');
			verifyEqual(testCase, dl.phase, 0, 'default phase should be 0');
			verifyEqual(testCase, dl.direction, 0, 'default direction should be 0');
			verifyFalse(testCase, dl.forceOrthogonal, 'default forceOrthogonal false');
			verifyFalse(testCase, dl.useEven, 'default useEven false');
			verifyEqual(testCase, dl.colour2, [0 0 0 1], 'default colour2');
			verifyEqual(testCase, dl.contrast, 1, 'default contrast should be 1');
			verifyEqual(testCase, dl.filter, 1, 'default filter should be 1');
			verifyEqual(testCase, dl.precision, 0, 'default precision should be 0');
			verifyEmpty(testCase, dl.specialFlags, 'default specialFlags empty');
			verifyEqual(testCase, dl.name, 'DotLine', 'default name should be DotLine');
			verifyEqual(testCase, dl.size, 10, 'default size should be 10');
			verifyTrue(testCase, dl.isRect, 'should be rect-based');
		end

		% ---------------------------------------------------------------
		%> @brief Test typeList contains expected values.
		% ---------------------------------------------------------------
		function testTypeList(testCase)
			dl = dotlineStimulus('verbose', false);
			verifyEqual(testCase, dl.typeList, {'circle','square'}, ...
				'typeList should be {circle,square}');
		end

		% ---------------------------------------------------------------
		%> @brief Test interpMethodList.
		% ---------------------------------------------------------------
		function testInterpMethodList(testCase)
			dl = dotlineStimulus('verbose', false);
			verifyEqual(testCase, dl.interpMethodList, ...
				{'nearest','linear','spline','cubic'}, ...
				'interpMethodList should match');
		end

		% ---------------------------------------------------------------
		%> @brief Test custom properties on construction.
		% ---------------------------------------------------------------
		function testCustomProperties(testCase)
			dl = dotlineStimulus('verbose', false, ...
				'type', 'square', 'itemSize', 1.5, ...
				'itemDistance', 2, 'phase', 90, ...
				'direction', 45, 'forceOrthogonal', true, ...
				'useEven', true, 'contrast', 0.5, ...
				'filter', 3);
			verifyEqual(testCase, dl.type, 'square', 'type should be square');
			verifyEqual(testCase, dl.itemSize, 1.5, 'itemSize should be 1.5');
			verifyEqual(testCase, dl.itemDistance, 2, 'itemDistance should be 2');
			verifyEqual(testCase, dl.phase, 90, 'phase should be 90');
			verifyEqual(testCase, dl.direction, 45, 'direction should be 45');
			verifyTrue(testCase, dl.forceOrthogonal, 'forceOrthogonal should be true');
			verifyTrue(testCase, dl.useEven, 'useEven should be true');
			verifyEqual(testCase, dl.contrast, 0.5, 'contrast should be 0.5');
			verifyEqual(testCase, dl.filter, 3, 'filter should be 3');
		end

		% ---------------------------------------------------------------
		%> @brief Test colour2 property.
		% ---------------------------------------------------------------
		function testColour2Property(testCase)
			dl = dotlineStimulus('verbose', false, 'colour2', [0.8 0.2 0.2 1]);
			verifyEqual(testCase, dl.colour2, [0.8 0.2 0.2 1], 'colour2 should be set');
		end

		% ---------------------------------------------------------------
		%> @brief Test colour set method.
		% ---------------------------------------------------------------
		function testColourSetRGB(testCase)
			dl = dotlineStimulus('verbose', false);
			dl.colour = [0.5 0.5 0.5];
			verifyEqual(testCase, dl.colour(1:3), [0.5 0.5 0.5], 'RGB set');
			verifyEqual(testCase, dl.alpha, 1, 'alpha should remain 1');
		end

		% ---------------------------------------------------------------
		%> @brief Test alpha clamping.
		% ---------------------------------------------------------------
		function testAlphaClamping(testCase)
			dl = dotlineStimulus('verbose', false);
			dl.alpha = 10;
			verifyEqual(testCase, dl.alpha, 1, 'alpha clamps to 1');
			dl.alpha = -5;
			verifyEqual(testCase, dl.alpha, 0, 'alpha clamps to 0');
		end

		% ---------------------------------------------------------------
		%> @brief Test show/hide methods.
		% ---------------------------------------------------------------
		function testShowHide(testCase)
			dl = dotlineStimulus('verbose', false);
			verifyTrue(testCase, dl.isVisible, 'should be visible by default');
			hide(dl);
			verifyFalse(testCase, dl.isVisible, 'should be hidden after hide');
			show(dl);
			verifyTrue(testCase, dl.isVisible, 'should be visible after show');
		end

		% ---------------------------------------------------------------
		%> @brief Test setOffTime and setDelayTime.
		% ---------------------------------------------------------------
		function testSetOffAndDelayTime(testCase)
			dl = dotlineStimulus('verbose', false);
			setOffTime(dl, 3.0);
			verifyEqual(testCase, dl.offTime, 3.0, 'offTime should be 3.0');
			setDelayTime(dl, 0.75);
			verifyEqual(testCase, dl.delayTime, 0.75, 'delayTime should be 0.75');
		end

		% ---------------------------------------------------------------
		%> @brief Test UUID from optickaCore.
		% ---------------------------------------------------------------
		function testHasUUID(testCase)
			dl = dotlineStimulus('verbose', false);
			verifyTrue(testCase, ~isempty(dl.uuid), 'should have a UUID');
		end

		% ---------------------------------------------------------------
		%> @brief Test fullName.
		% ---------------------------------------------------------------
		function testFullName(testCase)
			dl = dotlineStimulus('verbose', false, 'name', 'TestDotLine');
			verifyTrue(testCase, contains(dl.fullName, 'TestDotLine'), ...
				'fullName should contain name');
			verifyTrue(testCase, contains(dl.fullName, 'dotlineStimulus'), ...
				'fullName should contain class name');
		end

		% ---------------------------------------------------------------
		%> @brief Test reset before setup is safe.
		% ---------------------------------------------------------------
		function testResetBeforeSetup(testCase)
			dl = dotlineStimulus('verbose', false);
			reset(dl);
			verifyFalse(testCase, dl.isSetup, 'should not be setup after reset');
		end

		% ---------------------------------------------------------------
		%> @brief Test scale default.
		% ---------------------------------------------------------------
		function testScaleDefault(testCase)
			dl = dotlineStimulus('verbose', false);
			verifyEqual(testCase, dl.scale, 1, 'default scale should be 1');
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
			dl = dotlineStimulus('verbose', false);
			setup(dl, sM);
			verifyTrue(testCase, dl.isSetup, 'should be setup');
			verifyTrue(testCase, ~isempty(dl.texture), 'texture should be created');
			verifyTrue(testCase, dl.texture > 0, 'texture pointer should be positive');
			verifyGreaterThan(testCase, dl.width, 0, 'width should be positive');
			verifyGreaterThan(testCase, dl.height, 0, 'height should be positive');
			reset(dl);
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
			dl = dotlineStimulus('verbose', false);
			setup(dl, sM);
			draw(dl);
			verifyEqual(testCase, dl.drawTick, 1, 'drawTick should be 1 after one draw');
			reset(dl);
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
			dl = dotlineStimulus('verbose', false);
			setup(dl, sM);
			animate(dl);
			verifyEqual(testCase, dl.tick, 0, 'tick should be 0 (draw not called)');
			reset(dl);
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
			dl = dotlineStimulus('verbose', false);
			setup(dl, sM);
			update(dl);
			verifyTrue(testCase, true, 'update completed without error');
			reset(dl);
		end

		% ---------------------------------------------------------------
		%> @brief Test the run method.
		% ---------------------------------------------------------------
		function testRunMethod(testCase)
			assumeFalse(testCase, ~isempty(getenv('GITHUB_ACTIONS')), ...
				'Skipping PTB run test in CI');
			dl = dotlineStimulus('verbose', false);
			run(dl, false, 1);
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
			dl = dotlineStimulus('verbose', false);
			setup(dl, sM);
			reset(dl);
			verifyFalse(testCase, dl.isSetup, 'isSetup should be false after reset');
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
			dl = dotlineStimulus('verbose', false);
			setup(dl, sM);
			draw(dl);
			animate(dl);
			draw(dl);
			verifyEqual(testCase, dl.drawTick, 2, 'drawTick should be 2 after two draws');
			reset(dl);
		end
	end
end
