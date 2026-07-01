% ========================================================================
%> @class NDotsStimulusTest
%> @brief Class-based unit tests for ndotsStimulus.
%>
%> Tests construction, property defaults, type/msrcMode/mdstMode lists,
%> custom properties, show/hide, off/delay time, colour/alpha, UUID,
%> fullName, and reset before setup. CI-safe tests run without PTB;
%> hardware-tagged tests exercise setup/draw/animate/update/run/reset
%> with a real PTB window.
%>
%> Run with:
%>   >> runtests('tests/NDotsStimulusTest.m')
%>   >> runtests('tests/NDotsStimulusTest.m', '-ExcludeTag', 'hardware')
%>
%> Copyright (c) 2026 Ian Max Andolina — LGPL3, see LICENCE.md
% ========================================================================
classdef NDotsStimulusTest < matlab.unittest.TestCase

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
			d = ndotsStimulus('verbose', false);
			verifyEqual(testCase, d.type, 'simple', 'default type should be simple');
			verifyEqual(testCase, d.family, 'ndots', 'family should be ndots');
			verifyEqual(testCase, d.dotSize, 4, 'default dotSize');
			verifyEqual(testCase, d.dotType, 2, 'default dotType');
			verifyEqual(testCase, d.coherence, 0.5, 'default coherence');
			verifyEqual(testCase, d.density, 200, 'default density');
			verifyEqual(testCase, d.directionWeights, 1, 'default directionWeights');
			verifyEqual(testCase, d.drunkenWalk, 0, 'default drunkenWalk');
			verifyEqual(testCase, d.interleaving, 1, 'default interleaving');
			verifyTrue(testCase, d.isMovingAsHerd, 'default isMovingAsHerd');
			verifyFalse(testCase, d.isFlickering, 'default isFlickering');
			verifyTrue(testCase, d.isWrapping, 'default isWrapping');
			verifyTrue(testCase, d.isLimitedLifetime, 'default isLimitedLifetime');
			verifyFalse(testCase, d.mask, 'default mask should be false');
			verifyEqual(testCase, d.msrcMode, 'GL_SRC_ALPHA', 'default msrcMode');
			verifyEqual(testCase, d.mdstMode, 'GL_ONE_MINUS_SRC_ALPHA', 'default mdstMode');
			verifyEqual(testCase, d.name, 'n-dots', 'default name');
			verifyEqual(testCase, d.colour, [1 1 1 1], 'default colour');
			verifyEqual(testCase, d.speed, 2, 'default speed');
		end

		% ---------------------------------------------------------------
		%> @brief Test custom properties.
		% ---------------------------------------------------------------
		function testCustomProperties(testCase)
			d = ndotsStimulus('verbose', false, ...
				'density', 400, 'dotSize', 8, 'coherence', 0.8, ...
				'dotType', 0, 'drunkenWalk', 5, 'interleaving', 2, ...
				'isMovingAsHerd', false, 'isFlickering', true, ...
				'isWrapping', false, 'isLimitedLifetime', false, ...
				'mask', true, 'speed', 4);
			verifyEqual(testCase, d.density, 400, 'density');
			verifyEqual(testCase, d.dotSize, 8, 'dotSize');
			verifyEqual(testCase, d.coherence, 0.8, 'coherence');
			verifyEqual(testCase, d.dotType, 0, 'dotType');
			verifyEqual(testCase, d.drunkenWalk, 5, 'drunkenWalk');
			verifyEqual(testCase, d.interleaving, 2, 'interleaving');
			verifyFalse(testCase, d.isMovingAsHerd, 'isMovingAsHerd');
			verifyTrue(testCase, d.isFlickering, 'isFlickering');
			verifyFalse(testCase, d.isWrapping, 'isWrapping');
			verifyFalse(testCase, d.isLimitedLifetime, 'isLimitedLifetime');
			verifyTrue(testCase, d.mask, 'mask should be true');
			verifyEqual(testCase, d.speed, 4, 'speed');
		end

		% ---------------------------------------------------------------
		%> @brief Test typeList.
		% ---------------------------------------------------------------
		function testTypeList(testCase)
			d = ndotsStimulus('verbose', false);
			verifyEqual(testCase, d.typeList, {'simple'}, 'typeList');
		end

		% ---------------------------------------------------------------
		%> @brief Test msrcModeList.
		% ---------------------------------------------------------------
		function testMsrcModeList(testCase)
			d = ndotsStimulus('verbose', false);
			expected = {'GL_ZERO','GL_ONE','GL_DST_COLOR','GL_ONE_MINUS_DST_COLOR', ...
				'GL_SRC_ALPHA','GL_ONE_MINUS_SRC_ALPHA'};
			verifyEqual(testCase, d.msrcModeList, expected, 'msrcModeList');
		end

		% ---------------------------------------------------------------
		%> @brief Test mdstModeList.
		% ---------------------------------------------------------------
		function testMdstModeList(testCase)
			d = ndotsStimulus('verbose', false);
			expected = {'GL_ZERO','GL_ONE','GL_DST_COLOR','GL_ONE_MINUS_DST_COLOR', ...
				'GL_SRC_ALPHA','GL_ONE_MINUS_SRC_ALPHA'};
			verifyEqual(testCase, d.mdstModeList, expected, 'mdstModeList');
		end

		% ---------------------------------------------------------------
		%> @brief Test show/hide from baseStimulus.
		% ---------------------------------------------------------------
		function testShowHide(testCase)
			d = ndotsStimulus('verbose', false);
			verifyTrue(testCase, d.isVisible, 'visible');
			hide(d);
			verifyFalse(testCase, d.isVisible, 'hidden');
			show(d);
			verifyTrue(testCase, d.isVisible, 'visible');
		end

		% ---------------------------------------------------------------
		%> @brief Test setOffTime and setDelayTime from baseStimulus.
		% ---------------------------------------------------------------
		function testSetOffAndDelayTime(testCase)
			d = ndotsStimulus('verbose', false);
			setOffTime(d, 3.0);
			verifyEqual(testCase, d.offTime, 3.0, 'offTime');
			setDelayTime(d, 0.5);
			verifyEqual(testCase, d.delayTime, 0.5, 'delayTime');
		end

		% ---------------------------------------------------------------
		%> @brief Test colour and alpha from baseStimulus.
		% ---------------------------------------------------------------
		function testColourSetRGB(testCase)
			d = ndotsStimulus('verbose', false);
			d.colour = [0.3 0.6 0.9];
			verifyEqual(testCase, d.colour(1:3), [0.3 0.6 0.9], 'RGB');
		end

		function testAlphaClamping(testCase)
			d = ndotsStimulus('verbose', false);
			d.alpha = 5;
			verifyEqual(testCase, d.alpha, 1, 'alpha clamps to 1');
			d.alpha = -2;
			verifyEqual(testCase, d.alpha, 0, 'alpha clamps to 0');
		end

		% ---------------------------------------------------------------
		%> @brief Test UUID from baseStimulus.
		% ---------------------------------------------------------------
		function testUUID(testCase)
			d = ndotsStimulus('verbose', false);
			verifyTrue(testCase, ~isempty(d.uuid), 'UUID');
		end

		% ---------------------------------------------------------------
		%> @brief Test fullName from baseStimulus.
		% ---------------------------------------------------------------
		function testFullName(testCase)
			d = ndotsStimulus('verbose', false, 'name', 'MyNDots');
			verifyTrue(testCase, contains(d.fullName, 'MyNDots'), ...
				'fullName contains name');
			verifyTrue(testCase, contains(d.fullName, 'ndotsStimulus'), ...
				'fullName contains class');
		end

		% ---------------------------------------------------------------
		%> @brief Test reset before setup completes without error.
		% ---------------------------------------------------------------
		function testResetBeforeSetup(testCase)
			d = ndotsStimulus('verbose', false);
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
			d = ndotsStimulus('verbose', false);
			setup(d, sM);
			verifyTrue(testCase, d.isSetup, 'should be setup');
			verifyTrue(testCase, ~isempty(d.pixelXY), 'pixelXY should be populated');
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
			d = ndotsStimulus('verbose', false);
			setup(d, sM);
			draw(d);
			verifyEqual(testCase, d.drawTick, 1, 'drawTick should be 1');
			reset(d);
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
			d = ndotsStimulus('verbose', false);
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
			d = ndotsStimulus('verbose', false);
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
			d = ndotsStimulus('verbose', false);
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
			d = ndotsStimulus('verbose', false);
			setup(d, sM);
			verifyTrue(testCase, d.isSetup, 'should be setup');
			reset(d);
			verifyFalse(testCase, d.isSetup, 'isSetup should be false after reset');
		end
	end
end
