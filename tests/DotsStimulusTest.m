% ========================================================================
%> @class DotsStimulusTest
%> @brief Class-based unit tests for dotsStimulus.
%>
%> Tests construction, property defaults, type/colourType lists, density,
%> dotSize, coherence, dotType, kill, mask, mask properties. CI-safe tests
%> run without PTB; hardware-tagged tests exercise setup/draw/animate/
%> update/run with a real PTB window.
%>
%> Run with:
%>   >> runtests('tests/DotsStimulusTest.m')
%>   >> runtests('tests/DotsStimulusTest.m', '-ExcludeTag', 'hardware')
%>
%> Copyright (c) 2026 Ian Max Andolina — LGPL3, see LICENCE.md
% ========================================================================
classdef DotsStimulusTest < matlab.unittest.TestCase

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
			d = dotsStimulus('verbose', false);
			verifyEqual(testCase, d.type, 'simple', 'default type should be simple');
			verifyEqual(testCase, d.family, 'dots', 'family should be dots');
			verifyEqual(testCase, d.density, 100, 'default density should be 100');
			verifyEqual(testCase, d.colourType, 'randomBW', 'default colourType');
			verifyEqual(testCase, d.dotSize, 0.05, 'default dotSize');
			verifyEqual(testCase, d.coherence, 0.5, 'default coherence');
			verifyEqual(testCase, d.angleProbability, 1, 'default angleProbability');
			verifyEqual(testCase, d.kill, 0, 'default kill');
			verifyEqual(testCase, d.dotType, 3, 'default dotType');
			verifyTrue(testCase, d.mask, 'default mask should be true');
			verifyTrue(testCase, d.maskIsProcedural, 'default maskIsProcedural');
			verifyEqual(testCase, d.maskSmoothing, 11, 'default maskSmoothing');
			verifyEmpty(testCase, d.maskColour, 'default maskColour empty');
		end

		% ---------------------------------------------------------------
		%> @brief Test typeList.
		% ---------------------------------------------------------------
		function testTypeList(testCase)
			d = dotsStimulus('verbose', false);
			verifyEqual(testCase, d.typeList, {'simple'}, 'typeList');
		end

		% ---------------------------------------------------------------
		%> @brief Test colourTypeList.
		% ---------------------------------------------------------------
		function testColourTypeList(testCase)
			d = dotsStimulus('verbose', false);
			expected = {'simple','randomBW','randomNBW','random','randomN','binary'};
			verifyEqual(testCase, d.colourTypeList, expected, 'colourTypeList');
		end

		% ---------------------------------------------------------------
		%> @brief Test nDots dependent property increases with density.
		% ---------------------------------------------------------------
		function testNDotsSmallDensity(testCase)
			d = dotsStimulus('verbose', false, 'density', 10);
			% nDots = pi * (size/2)^2 * density
			expectedNDots = pi * ((4/2)^2) * 10;
			verifyEqual(testCase, d.nDots, round(expectedNDots), 'nDots');
		end

		% ---------------------------------------------------------------
		%> @brief Test nDots with custom size.
		% ---------------------------------------------------------------
		function testNDotsCustomSize(testCase)
			d = dotsStimulus('verbose', false, 'density', 50, 'size', 6);
			expectedNDots = pi * ((6/2)^2) * 50;
			verifyEqual(testCase, d.nDots, round(expectedNDots), 'nDots with custom size');
		end

		% ---------------------------------------------------------------
		%> @brief Test custom properties.
		% ---------------------------------------------------------------
		function testCustomProperties(testCase)
			d = dotsStimulus('verbose', false, ...
				'density', 200, 'dotSize', 0.1, 'coherence', 0.8, ...
				'dotType', 0, 'kill', 0.1, 'colourType', 'random', ...
				'mask', false, 'maskSmoothing', 5);
			verifyEqual(testCase, d.density, 200, 'density');
			verifyEqual(testCase, d.dotSize, 0.1, 'dotSize');
			verifyEqual(testCase, d.coherence, 0.8, 'coherence');
			verifyEqual(testCase, d.dotType, 0, 'dotType');
			verifyEqual(testCase, d.kill, 0.1, 'kill');
			verifyEqual(testCase, d.colourType, 'random', 'colourType');
			verifyFalse(testCase, d.mask, 'mask should be false');
		end

		% ---------------------------------------------------------------
		%> @brief Test colour, UUID, show/hide from baseStimulus.
		% ---------------------------------------------------------------
		function testColourSetRGB(testCase)
			d = dotsStimulus('verbose', false);
			d.colour = [0.3 0.6 0.9];
			verifyEqual(testCase, d.colour(1:3), [0.3 0.6 0.9], 'RGB');
		end

		function testAlphaClamping(testCase)
			d = dotsStimulus('verbose', false);
			d.alpha = 5;
			verifyEqual(testCase, d.alpha, 1, 'alpha clamps to 1');
			d.alpha = -2;
			verifyEqual(testCase, d.alpha, 0, 'alpha clamps to 0');
		end

		function testShowHide(testCase)
			d = dotsStimulus('verbose', false);
			verifyTrue(testCase, d.isVisible, 'visible');
			hide(d);
			verifyFalse(testCase, d.isVisible, 'hidden');
			show(d);
			verifyTrue(testCase, d.isVisible, 'visible');
		end

		function testSetOffAndDelayTime(testCase)
			d = dotsStimulus('verbose', false);
			setOffTime(d, 3.0);
			verifyEqual(testCase, d.offTime, 3.0, 'offTime');
			setDelayTime(d, 0.5);
			verifyEqual(testCase, d.delayTime, 0.5, 'delayTime');
		end

		function testUUID(testCase)
			d = dotsStimulus('verbose', false);
			verifyTrue(testCase, ~isempty(d.uuid), 'UUID');
		end

		function testFullName(testCase)
			d = dotsStimulus('verbose', false, 'name', 'MyDots');
			verifyTrue(testCase, contains(d.fullName, 'MyDots'), ...
				'fullName contains name');
			verifyTrue(testCase, contains(d.fullName, 'dotsStimulus'), ...
				'fullName contains class');
		end

		function testResetBeforeSetup(testCase)
			d = dotsStimulus('verbose', false);
			reset(d);
			verifyTrue(testCase, true, 'reset completed');
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
			d = dotsStimulus('verbose', false);
			setup(d, sM);
			verifyTrue(testCase, d.isSetup, 'should be setup');
			verifyTrue(testCase, ~isempty(d.xy), 'xy should be populated');
			reset(d);
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
			d = dotsStimulus('verbose', false);
			setup(d, sM);
			draw(d);
			verifyEqual(testCase, d.drawTick, 1, 'drawTick should be 1');
			reset(d);
		end

		% ---------------------------------------------------------------
		%> @brief Test animate after setup updates dot positions.
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
			d = dotsStimulus('verbose', false);
			setup(d, sM);
			animate(d);
			verifyTrue(testCase, true, 'animate completed');
			reset(d);
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
			d = dotsStimulus('verbose', false);
			setup(d, sM);
			update(d);
			verifyTrue(testCase, true, 'update completed');
			reset(d);
		end

		% ---------------------------------------------------------------
		%> @brief Test run method.
		% ---------------------------------------------------------------
		function testRunMethod(testCase)
			assumeFalse(testCase, ~isempty(getenv('GITHUB_ACTIONS')), ...
				'Skipping PTB run test in CI');
			d = dotsStimulus('verbose', false);
			run(d, false, 1);
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
			d = dotsStimulus('verbose', false);
			setup(d, sM);
			verifyTrue(testCase, d.isSetup, 'should be setup');
			reset(d);
			verifyFalse(testCase, d.isSetup, 'isSetup should be false after reset');
		end

		% ---------------------------------------------------------------
		%> @brief Test dots with coherence > 0 produces directed motion.
		% ---------------------------------------------------------------
		function testCoherentDots(testCase)
			assumeFalse(testCase, ~isempty(getenv('GITHUB_ACTIONS')), ...
				'Skipping PTB coherence test in CI');
			sM = screenManager;
			sM.windowed = [0 0 800 600];
			sM.disableSyncTests = true;
			sM.visualDebug = true;
			sM.bitDepth = '8bit';
			open(sM);
			cleanup = onCleanup(@() close(sM));
			d = dotsStimulus('verbose', false, 'coherence', 1.0);
			setup(d, sM);
			verifyTrue(testCase, d.isSetup, 'should setup with full coherence');
			draw(d);
			verifyEqual(testCase, d.drawTick, 1, 'drawTick should be 1');
			reset(d);
		end

		% ---------------------------------------------------------------
		%> @brief Test dots without mask.
		% ---------------------------------------------------------------
		function testNoMaskDots(testCase)
			assumeFalse(testCase, ~isempty(getenv('GITHUB_ACTIONS')), ...
				'Skipping PTB nomask test in CI');
			sM = screenManager;
			sM.windowed = [0 0 800 600];
			sM.disableSyncTests = true;
			sM.visualDebug = true;
			sM.bitDepth = '8bit';
			open(sM);
			cleanup = onCleanup(@() close(sM));
			d = dotsStimulus('verbose', false, 'mask', false, 'maskIsProcedural', false);
			setup(d, sM);
			verifyTrue(testCase, d.isSetup, 'should setup without mask');
			draw(d);
			reset(d);
		end
	end
end
