% ========================================================================
%> @class GratingStimulusTest
%> @brief Class-based unit tests for gratingStimulus.
%>
%> Tests construction, property defaults, type list validation, contrast
%> clamping, colour handling, and phase/TF/SF properties. CI-safe tests
%> run without PTB; hardware-tagged tests exercise setup/draw/animate/
%> update/run with a real PTB window.
%>
%> Run with:
%>   >> runtests('tests/GratingStimulusTest.m')
%>   >> runtests('tests/GratingStimulusTest.m', '-ExcludeTag', 'hardware')
%>
%> Copyright (c) 2026 Ian Max Andolina — LGPL3, see LICENCE.md
% ========================================================================
classdef GratingStimulusTest < matlab.unittest.TestCase

	methods (TestClassSetup)
		function setupPath(testCase)
			addOptickaToPath;
		end
	end

	% ===================================================================
	% CI-SAFE TESTS
	% ===================================================================
	methods (Test)
		function testConstructionDefaults(testCase)
			g = gratingStimulus('verbose', false);
			verifyEqual(testCase, g.type, 'sinusoid', 'default type should be sinusoid');
			verifyEqual(testCase, g.family, 'grating', 'family should be grating');
			verifyEqual(testCase, g.sf, 1, 'default sf should be 1');
			verifyEqual(testCase, g.tf, 1, 'default tf should be 1');
			verifyEqual(testCase, g.phase, 0, 'default phase should be 0');
			verifyEqual(testCase, g.contrast, 0.5, 'default contrast should be 0.5');
			verifyTrue(testCase, g.mask, 'default mask should be true');
			verifyTrue(testCase, g.rotateTexture, 'default rotateTexture should be true');
			verifyFalse(testCase, g.reverseDirection, 'default reverseDirection should be false');
			verifyFalse(testCase, g.correctPhase, 'default correctPhase should be false');
			verifyEqual(testCase, g.aspectRatio, 1, 'default aspectRatio should be 1');
			verifyEqual(testCase, g.contrastMult, 0.5, 'default contrastMult should be 0.5');
		end

		function testTypeList(testCase)
			g = gratingStimulus('verbose', false);
			verifyEqual(testCase, g.typeList, {'sinusoid';'square'}, 'typeList');
		end

		function testCustomProperties(testCase)
			g = gratingStimulus('verbose', false, 'sf', 2, 'tf', 4, ...
				'contrast', 0.8, 'phase', 0.5, 'mask', false, 'aspectRatio', 2);
			verifyEqual(testCase, g.sf, 2, 'sf should be 2');
			verifyEqual(testCase, g.tf, 4, 'tf should be 4');
			verifyEqual(testCase, g.contrast, 0.8, 'contrast should be 0.8');
			verifyEqual(testCase, g.phase, 0.5, 'phase should be 0.5');
			verifyFalse(testCase, g.mask, 'mask should be false');
			verifyEqual(testCase, g.aspectRatio, 2, 'aspectRatio should be 2');
		end

		function testReverseDirection(testCase)
			g = gratingStimulus('verbose', false, 'reverseDirection', true);
			verifyTrue(testCase, g.reverseDirection, 'reverseDirection should be true');
		end

		function testCorrectPhase(testCase)
			g = gratingStimulus('verbose', false, 'correctPhase', true);
			verifyTrue(testCase, g.correctPhase, 'correctPhase should be true');
		end

		function testPhaseReverseTime(testCase)
			g = gratingStimulus('verbose', false, 'phaseReverseTime', 2, 'phaseOfReverse', 90);
			verifyEqual(testCase, g.phaseReverseTime, 2, 'phaseReverseTime should be 2');
			verifyEqual(testCase, g.phaseOfReverse, 90, 'phaseOfReverse should be 90');
		end

		function testSigmaAndUseAlpha(testCase)
			g = gratingStimulus('verbose', false, 'sigma', 10, 'useAlpha', false, 'smoothMethod', double(0));
			verifyEqual(testCase, g.sigma, 10, 'sigma should be 10');
			verifyFalse(testCase, g.useAlpha, 'useAlpha should be false');
			verifyEqual(testCase, double(g.smoothMethod), double(0), 'smoothMethod should be 0 (cosine)');
		end

		function testColourSetRGB(testCase)
			g = gratingStimulus('verbose', false);
			g.colour = [0.5 0.5 0.5];
			verifyEqual(testCase, g.colour(1:3), [0.5 0.5 0.5], 'RGB should be set');
		end

		function testAlphaClamping(testCase)
			g = gratingStimulus('verbose', false);
			g.alpha = 5;
			verifyEqual(testCase, g.alpha, 1, 'alpha should clamp to 1');
			g.alpha = -3;
			verifyEqual(testCase, g.alpha, 0, 'alpha should clamp to 0');
		end

		function testShowHide(testCase)
			g = gratingStimulus('verbose', false);
			verifyTrue(testCase, g.isVisible, 'should be visible by default');
			hide(g);
			verifyFalse(testCase, g.isVisible, 'should be hidden');
			show(g);
			verifyTrue(testCase, g.isVisible, 'should be visible');
		end

		function testSetOffAndDelayTime(testCase)
			g = gratingStimulus('verbose', false);
			setOffTime(g, 3.0);
			verifyEqual(testCase, g.offTime, 3.0, 'offTime should be 3.0');
			setDelayTime(g, 0.3);
			verifyEqual(testCase, g.delayTime, 0.3, 'delayTime should be 0.3');
		end

		function testUUID(testCase)
			g = gratingStimulus('verbose', false);
			verifyTrue(testCase, ~isempty(g.uuid), 'should have UUID');
		end

		function testFullName(testCase)
			g = gratingStimulus('verbose', false, 'name', 'TestGrating');
			verifyTrue(testCase, contains(g.fullName, 'TestGrating'), 'fullName contains name');
			verifyTrue(testCase, contains(g.fullName, 'gratingStimulus'), 'fullName contains class');
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
			g = gratingStimulus('verbose', false);
			setup(g, sM);
			verifyTrue(testCase, g.isSetup, 'should be setup');
			verifyTrue(testCase, ~isempty(g.texture) || g.texture > 0, 'texture should exist');
			reset(g);
		end

		function testDrawAfterSetup(testCase)
			assumeFalse(testCase, ~isempty(getenv('GITHUB_ACTIONS')), 'Skip in CI');
			sM = screenManager; sM.windowed = [0 0 800 600];
			sM.disableSyncTests = true; sM.visualDebug = true; sM.bitDepth = '8bit';
			open(sM); cleanup = onCleanup(@() close(sM));
			g = gratingStimulus('verbose', false);
			setup(g, sM);
			draw(g);
			verifyEqual(testCase, g.drawTick, 1, 'drawTick should be 1');
			reset(g);
		end

		function testAnimateAfterSetup(testCase)
			assumeFalse(testCase, ~isempty(getenv('GITHUB_ACTIONS')), 'Skip in CI');
			sM = screenManager; sM.windowed = [0 0 800 600];
			sM.disableSyncTests = true; sM.visualDebug = true; sM.bitDepth = '8bit';
			open(sM); cleanup = onCleanup(@() close(sM));
			g = gratingStimulus('verbose', false, 'tf', 2);
			setup(g, sM);
			animate(g);
			verifyTrue(testCase, true, 'animate completed without error');
			reset(g);
		end

		function testUpdateAfterSetup(testCase)
			assumeFalse(testCase, ~isempty(getenv('GITHUB_ACTIONS')), 'Skip in CI');
			sM = screenManager; sM.windowed = [0 0 800 600];
			sM.disableSyncTests = true; sM.visualDebug = true; sM.bitDepth = '8bit';
			open(sM); cleanup = onCleanup(@() close(sM));
			g = gratingStimulus('verbose', false);
			setup(g, sM);
			update(g);
			verifyTrue(testCase, true, 'update completed without error');
			reset(g);
		end

		function testRunMethod(testCase)
			assumeFalse(testCase, ~isempty(getenv('GITHUB_ACTIONS')), 'Skip in CI');
			g = gratingStimulus('verbose', false);
			run(g, false, 1);
			verifyTrue(testCase, true, 'run() completed without error');
		end

		function testRunBenchmark(testCase)
			assumeFalse(testCase, ~isempty(getenv('GITHUB_ACTIONS')), 'Skip in CI');
			g = gratingStimulus('verbose', false);
			run(g, true, 1);
			verifyTrue(testCase, true, 'benchmark run completed without error');
		end

		function testResetAfterSetup(testCase)
			assumeFalse(testCase, ~isempty(getenv('GITHUB_ACTIONS')), 'Skip in CI');
			sM = screenManager; sM.windowed = [0 0 800 600];
			sM.disableSyncTests = true; sM.visualDebug = true; sM.bitDepth = '8bit';
			open(sM); cleanup = onCleanup(@() close(sM));
			g = gratingStimulus('verbose', false);
			setup(g, sM);
			reset(g);
			verifyFalse(testCase, g.isSetup, 'isSetup should be false after reset');
			verifyEqual(testCase, g.scale, 1, 'scale should be 1 after reset');
		end

		function testSquareWaveGrating(testCase)
			assumeFalse(testCase, ~isempty(getenv('GITHUB_ACTIONS')), 'Skip in CI');
			sM = screenManager; sM.windowed = [0 0 800 600];
			sM.disableSyncTests = true; sM.visualDebug = true; sM.bitDepth = '8bit';
			open(sM); cleanup = onCleanup(@() close(sM));
			g = gratingStimulus('verbose', false, 'type', 'square');
			setup(g, sM);
			verifyTrue(testCase, g.isSetup, 'square wave grating should setup');
			draw(g);
			verifyEqual(testCase, g.drawTick, 1, 'drawTick should be 1');
			reset(g);
		end
	end
end
