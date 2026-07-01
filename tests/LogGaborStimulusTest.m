% ========================================================================
%> @class LogGaborStimulusTest
%> @brief Class-based unit tests for logGaborStimulus.
%>
%> Tests construction, property defaults, type list, sf/sfSigma,
%> angleSigma, contrast, seed, mask properties. CI-safe tests run
%> without PTB; hardware-tagged tests exercise setup/draw/animate/update
%> with a real PTB window.
%>
%> Run with:
%>   >> runtests('tests/LogGaborStimulusTest.m')
%>   >> runtests('tests/LogGaborStimulusTest.m', '-ExcludeTag', 'hardware')
%>
%> Copyright (c) 2026 Ian Max Andolina — LGPL3, see LICENCE.md
% ========================================================================
classdef LogGaborStimulusTest < matlab.unittest.TestCase

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
			l = logGaborStimulus('verbose', false);
			verifyEqual(testCase, l.type, 'image', 'default type should be image');
			verifyEqual(testCase, l.family, 'texture', 'family should be texture');
			verifyEqual(testCase, l.sf, 1, 'default sf');
			verifyEqual(testCase, l.sfSigma, 0.01, 'default sfSigma');
			verifyEqual(testCase, l.angleSigma, 10, 'default angleSigma');
			verifyEqual(testCase, l.contrast, 1, 'default contrast');
			verifyEqual(testCase, l.direction, 0, 'default direction');
			verifyEmpty(testCase, l.lockAngle, 'default lockAngle');
			verifyTrue(testCase, l.mask, 'default mask');
			verifyEmpty(testCase, l.maskColour, 'default maskColour');
			verifyEqual(testCase, l.maskSmoothing, 55, 'default maskSmoothing');
			verifyTrue(testCase, l.regenerateTexture, 'regenerateTexture');
			verifyEqual(testCase, l.phaseReverseTime, 0, 'phaseReverseTime');
		end

		% ---------------------------------------------------------------
		%> @brief Test typeList.
		% ---------------------------------------------------------------
		function testTypeList(testCase)
			l = logGaborStimulus('verbose', false);
			verifyEqual(testCase, l.typeList, {'image','logGabor'}, 'typeList');
		end

		% ---------------------------------------------------------------
		%> @brief Test custom properties for logGabor mode.
		% ---------------------------------------------------------------
		function testCustomLogGaborProperties(testCase)
			l = logGaborStimulus('verbose', false, ...
				'type', 'logGabor', 'sf', 2, 'sfSigma', 0.05, ...
				'angleSigma', 20, 'contrast', 0.8, ...
				'mask', false, 'direction', 45, ...
				'lockAngle', 0, 'regenerateTexture', false);
			verifyEqual(testCase, l.type, 'logGabor', 'type');
			verifyEqual(testCase, l.sf, 2, 'sf');
			verifyEqual(testCase, l.sfSigma, 0.05, 'sfSigma');
			verifyEqual(testCase, l.angleSigma, 20, 'angleSigma');
			verifyEqual(testCase, l.contrast, 0.8, 'contrast');
			verifyFalse(testCase, l.mask, 'mask');
			verifyEqual(testCase, l.direction, 45, 'direction');
			verifyEqual(testCase, l.lockAngle, 0, 'lockAngle');
			verifyFalse(testCase, l.regenerateTexture, 'regenerateTexture');
		end

		% ---------------------------------------------------------------
		%> @brief Test seed property ensures reproducibility.
		% ---------------------------------------------------------------
		function testSeedProperty(testCase)
			l = logGaborStimulus('verbose', false, 'seed', uint32(12345));
			verifyEqual(testCase, l.seed, uint32(12345), 'seed should be set');
		end

		% ---------------------------------------------------------------
		%> @brief Test mask properties.
		% ---------------------------------------------------------------
		function testMaskProperties(testCase)
			l = logGaborStimulus('verbose', false, ...
				'mask', true, 'maskSmoothing', 30, ...
				'maskColour', [0.5 0.5 0.5]);
			verifyTrue(testCase, l.mask, 'mask');
			verifyEqual(testCase, l.maskSmoothing, 30, 'maskSmoothing');
			verifyEqual(testCase, l.maskColour, [0.5 0.5 0.5], 'maskColour');
		end

		% ---------------------------------------------------------------
		%> @brief Test modulateColour property.
		% ---------------------------------------------------------------
		function testModulateColour(testCase)
			l = logGaborStimulus('verbose', false, ...
				'modulateColour', [0.8 0.2 0.2]);
			verifyEqual(testCase, l.modulateColour, [0.8 0.2 0.2], ...
				'modulateColour');
		end

		% ---------------------------------------------------------------
		%> @brief Test colour set.
		% ---------------------------------------------------------------
		function testColourSetRGB(testCase)
			l = logGaborStimulus('verbose', false);
			l.colour = [0.3 0.6 0.9];
			verifyEqual(testCase, l.colour(1:3), [0.3 0.6 0.9], 'RGB');
		end

		% ---------------------------------------------------------------
		%> @brief Test alpha clamping.
		% ---------------------------------------------------------------
		function testAlphaClamping(testCase)
			l = logGaborStimulus('verbose', false);
			l.alpha = 5;
			verifyEqual(testCase, l.alpha, 1, 'alpha clamps to 1');
			l.alpha = -2;
			verifyEqual(testCase, l.alpha, 0, 'alpha clamps to 0');
		end

		% ---------------------------------------------------------------
		%> @brief Test show/hide.
		% ---------------------------------------------------------------
		function testShowHide(testCase)
			l = logGaborStimulus('verbose', false);
			verifyTrue(testCase, l.isVisible, 'visible');
			hide(l);
			verifyFalse(testCase, l.isVisible, 'hidden');
			show(l);
			verifyTrue(testCase, l.isVisible, 'visible');
		end

		% ---------------------------------------------------------------
		%> @brief Test setOff and delay.
		% ---------------------------------------------------------------
		function testSetOffAndDelayTime(testCase)
			l = logGaborStimulus('verbose', false);
			setOffTime(l, 2.0);
			verifyEqual(testCase, l.offTime, 2.0, 'offTime');
			setDelayTime(l, 0.25);
			verifyEqual(testCase, l.delayTime, 0.25, 'delayTime');
		end

		% ---------------------------------------------------------------
		%> @brief Test UUID.
		% ---------------------------------------------------------------
		function testUUID(testCase)
			l = logGaborStimulus('verbose', false);
			verifyTrue(testCase, ~isempty(l.uuid), 'UUID');
		end

		% ---------------------------------------------------------------
		%> @brief Test fullName.
		% ---------------------------------------------------------------
		function testFullName(testCase)
			l = logGaborStimulus('verbose', false, 'name', 'TestLG');
			verifyTrue(testCase, contains(l.fullName, 'TestLG'), ...
				'fullName contains name');
			verifyTrue(testCase, contains(l.fullName, 'logGaborStimulus'), ...
				'fullName contains class');
		end

		% ---------------------------------------------------------------
		%> @brief Test reset before setup.
		% ---------------------------------------------------------------
		function testResetBeforeSetup(testCase)
			l = logGaborStimulus('verbose', false);
			reset(l);
			verifyTrue(testCase, true, 'reset completed');
		end

		% ---------------------------------------------------------------
		%> @brief Test scale default.
		% ---------------------------------------------------------------
		function testScaleDefault(testCase)
			l = logGaborStimulus('verbose', false);
			verifyEqual(testCase, l.scale, 1, 'scale should be 1');
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
			l = logGaborStimulus('verbose', false);
			setup(l, sM);
			verifyTrue(testCase, l.isSetup, 'should be setup');
			reset(l);
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
			l = logGaborStimulus('verbose', false);
			setup(l, sM);
			draw(l);
			verifyEqual(testCase, l.drawTick, 1, 'drawTick');
			reset(l);
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
			l = logGaborStimulus('verbose', false);
			setup(l, sM);
			animate(l);
			verifyTrue(testCase, true, 'animate completed');
			reset(l);
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
			l = logGaborStimulus('verbose', false);
			setup(l, sM);
			update(l);
			verifyTrue(testCase, true, 'update completed');
			reset(l);
		end

		% ---------------------------------------------------------------
		%> @brief Test run method.
		% ---------------------------------------------------------------
		function testRunMethod(testCase)
			assumeFalse(testCase, ~isempty(getenv('GITHUB_ACTIONS')), ...
				'Skipping PTB run test in CI');
			l = logGaborStimulus('verbose', false);
			run(l, false, 1);
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
			l = logGaborStimulus('verbose', false);
			setup(l, sM);
			verifyTrue(testCase, l.isSetup, 'should be setup');
			reset(l);
			verifyFalse(testCase, l.isSetup, 'isSetup false after reset');
		end
	end
end
