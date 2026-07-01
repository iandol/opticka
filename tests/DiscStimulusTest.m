% ========================================================================
%> @class DiscStimulusTest
%> @brief Class-based unit tests for discStimulus.
%>
%> Tests construction, property defaults, flash type, contrast/sigma
%> properties, colour handling. CI-safe tests run without PTB;
%> hardware-tagged tests exercise setup/draw/animate/update/run.
%>
%> Run with:
%>   >> runtests('tests/DiscStimulusTest.m')
%>   >> runtests('tests/DiscStimulusTest.m', '-ExcludeTag', 'hardware')
%>
%> Copyright (c) 2026 Ian Max Andolina — LGPL3, see LICENCE.md
% ========================================================================
classdef DiscStimulusTest < matlab.unittest.TestCase

	methods (TestClassSetup)
		function setupPath(testCase)
			addOptickaToPath;
		end
	end

	% ===================================================================
	% CI-SAFE TESTS
	% ===================================================================
	methods (Test, TestTags = {'CI'})
		function testConstructionDefaults(testCase)
			d = discStimulus('verbose', false);
			verifyEqual(testCase, d.type, 'simple', 'default type should be simple');
			verifyEqual(testCase, d.family, 'disc', 'family should be disc');
			verifyEqual(testCase, d.contrast, 1, 'default contrast should be 1');
			verifyEqual(testCase, d.sigma, 31.0, 'default sigma should be 31');
			verifyTrue(testCase, d.useAlpha, 'default useAlpha should be true');
			verifyEqual(testCase, d.smoothMethod, 1, 'default smoothMethod should be 1 (hermite)');
			verifyTrue(testCase, d.flashOn, 'default flashOn should be true');
			verifyEqual(testCase, d.flashTime, [0.25 0.25], 'default flashTime');
		end

		function testTypeList(testCase)
			d = discStimulus('verbose', false);
			verifyEqual(testCase, d.typeList, {'simple','flash'}, 'typeList');
		end

		function testCustomProperties(testCase)
			d = discStimulus('verbose', false, 'contrast', 0.5, ...
				'sigma', 20, 'useAlpha', false, 'smoothMethod', 2);
			verifyEqual(testCase, d.contrast, 0.5, 'contrast should be 0.5');
			verifyEqual(testCase, d.sigma, 20, 'sigma should be 20');
			verifyFalse(testCase, d.useAlpha, 'useAlpha should be false');
			verifyEqual(testCase, d.smoothMethod, 2, 'smoothMethod should be 2');
		end

		function testFlashType(testCase)
			d = discStimulus('verbose', false, 'type', 'flash', ...
				'flashTime', [0.1 0.2], 'flashOn', false);
			verifyEqual(testCase, d.type, 'flash', 'type should be flash');
			verifyEqual(testCase, d.flashTime, [0.1 0.2], 'flashTime should be [0.1 0.2]');
			verifyFalse(testCase, d.flashOn, 'flashOn should be false');
		end

		function testFlashColour(testCase)
			d = discStimulus('verbose', false, 'flashColour', [0.8 0.2 0.2]);
			verifyEqual(testCase, d.flashColour, [0.8 0.2 0.2], 'flashColour should be set');
		end

		function testColourSetRGB(testCase)
			d = discStimulus('verbose', false);
			d.colour = [0.3 0.6 0.9];
			verifyEqual(testCase, d.colour(1:3), [0.3 0.6 0.9], 'RGB should be set');
		end

		function testAlphaClamping(testCase)
			d = discStimulus('verbose', false);
			d.alpha = 5;
			verifyEqual(testCase, d.alpha, 1, 'alpha should clamp to 1');
			d.alpha = -2;
			verifyEqual(testCase, d.alpha, 0, 'alpha should clamp to 0');
		end

		function testShowHide(testCase)
			d = discStimulus('verbose', false);
			verifyTrue(testCase, d.isVisible, 'should be visible');
			hide(d);
			verifyFalse(testCase, d.isVisible, 'should be hidden');
			show(d);
			verifyTrue(testCase, d.isVisible, 'should be visible');
		end

		function testSetOffAndDelayTime(testCase)
			d = discStimulus('verbose', false);
			setOffTime(d, 1.5);
			verifyEqual(testCase, d.offTime, 1.5, 'offTime should be 1.5');
			setDelayTime(d, 0.2);
			verifyEqual(testCase, d.delayTime, 0.2, 'delayTime should be 0.2');
		end

		function testUUID(testCase)
			d = discStimulus('verbose', false);
			verifyTrue(testCase, ~isempty(d.uuid), 'should have UUID');
		end

		function testFullName(testCase)
			d = discStimulus('verbose', false, 'name', 'TestDisc');
			verifyTrue(testCase, contains(d.fullName, 'TestDisc'), 'fullName contains name');
		end
	end

	% ===================================================================
	% HARDWARE TESTS
	% ===================================================================
	methods (Test, TestTags = {'hardware'})
		function testSetupWithScreen(testCase)
			assumeFalse(testCase, ~isempty(getenv('GITHUB_ACTIONS')), 'Skip in CI');
			sM = screenManager; sM.windowed = [0 0 800 600];
			sM.disableSyncTests = true; sM.visualDebug = true; sM.bitDepth = '8bit';
			open(sM); cleanup = onCleanup(@() close(sM));
			d = discStimulus('verbose', false);
			setup(d, sM);
			verifyTrue(testCase, d.isSetup, 'should be setup');
			reset(d);
		end

		function testDrawAfterSetup(testCase)
			assumeFalse(testCase, ~isempty(getenv('GITHUB_ACTIONS')), 'Skip in CI');
			sM = screenManager; sM.windowed = [0 0 800 600];
			sM.disableSyncTests = true; sM.visualDebug = true; sM.bitDepth = '8bit';
			open(sM); cleanup = onCleanup(@() close(sM));
			d = discStimulus('verbose', false);
			setup(d, sM);
			draw(d);
			verifyEqual(testCase, d.drawTick, 1, 'drawTick should be 1');
			reset(d);
		end

		function testAnimateAfterSetup(testCase)
			assumeFalse(testCase, ~isempty(getenv('GITHUB_ACTIONS')), 'Skip in CI');
			sM = screenManager; sM.windowed = [0 0 800 600];
			sM.disableSyncTests = true; sM.visualDebug = true; sM.bitDepth = '8bit';
			open(sM); cleanup = onCleanup(@() close(sM));
			d = discStimulus('verbose', false);
			setup(d, sM);
			animate(d);
			verifyTrue(testCase, true, 'animate completed');
			reset(d);
		end

		function testUpdateAfterSetup(testCase)
			assumeFalse(testCase, ~isempty(getenv('GITHUB_ACTIONS')), 'Skip in CI');
			sM = screenManager; sM.windowed = [0 0 800 600];
			sM.disableSyncTests = true; sM.visualDebug = true; sM.bitDepth = '8bit';
			open(sM); cleanup = onCleanup(@() close(sM));
			d = discStimulus('verbose', false);
			setup(d, sM);
			update(d);
			verifyTrue(testCase, true, 'update completed');
			reset(d);
		end

		function testRunMethod(testCase)
			assumeFalse(testCase, ~isempty(getenv('GITHUB_ACTIONS')), 'Skip in CI');
			d = discStimulus('verbose', false);
			run(d, false, 1);
			verifyTrue(testCase, true, 'run() completed');
		end

		function testFlashDiscSetup(testCase)
			assumeFalse(testCase, ~isempty(getenv('GITHUB_ACTIONS')), 'Skip in CI');
			sM = screenManager; sM.windowed = [0 0 800 600];
			sM.disableSyncTests = true; sM.visualDebug = true; sM.bitDepth = '8bit';
			open(sM); cleanup = onCleanup(@() close(sM));
			d = discStimulus('verbose', false, 'type', 'flash', 'flashTime', [0.1 0.1]);
			setup(d, sM);
			verifyTrue(testCase, d.isSetup, 'flash disc should setup');
			draw(d);
			verifyEqual(testCase, d.drawTick, 1, 'drawTick should be 1');
			reset(d);
		end

		function testResetAfterSetup(testCase)
			assumeFalse(testCase, ~isempty(getenv('GITHUB_ACTIONS')), 'Skip in CI');
			sM = screenManager; sM.windowed = [0 0 800 600];
			sM.disableSyncTests = true; sM.visualDebug = true; sM.bitDepth = '8bit';
			open(sM); cleanup = onCleanup(@() close(sM));
			d = discStimulus('verbose', false);
			setup(d, sM);
			reset(d);
			verifyFalse(testCase, d.isSetup, 'isSetup should be false after reset');
		end
	end
end
