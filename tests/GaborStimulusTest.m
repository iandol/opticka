% ========================================================================
%> @class GaborStimulusTest
%> @brief Class-based unit tests for gaborStimulus.
%>
%> Tests construction, property defaults, type list, spatial/temporal
%> frequency, contrast, phase, driftDirection, aspectRatio, sigma,
%> rotationMethod, correctPhase, phaseReverseTime. CI-safe tests run
%> without PTB; hardware-tagged tests exercise setup/draw/animate/update/
%> run with a real PTB window.
%>
%> Run with:
%>   >> runtests('tests/GaborStimulusTest.m')
%>   >> runtests('tests/GaborStimulusTest.m', '-ExcludeTag', 'hardware')
%>
%> Copyright (c) 2026 Ian Max Andolina — LGPL3, see LICENCE.md
% ========================================================================
classdef GaborStimulusTest < matlab.unittest.TestCase

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
			g = gaborStimulus('verbose', false);
			verifyEqual(testCase, g.type, 'procedural', 'default type should be procedural');
			verifyEqual(testCase, g.family, 'gabor', 'family should be gabor');
			verifyEqual(testCase, g.sf, 1, 'default sf should be 1');
			verifyEqual(testCase, g.tf, 1, 'default tf should be 1');
			verifyEqual(testCase, g.phase, 0, 'default phase should be 0');
			verifyEqual(testCase, g.contrast, 0.5, 'default contrast should be 0.5');
			verifyTrue(testCase, g.disableNorm, 'disableNorm should be true');
			verifyEqual(testCase, g.spatialConstant, 10, 'default spatialConstant');
			verifyEqual(testCase, g.contrastMult, 0.5, 'default contrastMult');
			verifyEqual(testCase, g.aspectRatio, 1, 'default aspectRatio');
			verifyFalse(testCase, g.driftDirection, 'default driftDirection false');
			verifyEqual(testCase, g.direction, 0, 'default direction 0');
			verifyFalse(testCase, g.correctPhase, 'default correctPhase false');
			verifyEqual(testCase, g.phaseReverseTime, 0, 'default phaseReverseTime');
			verifyEqual(testCase, g.phaseOfReverse, 180, 'default phaseOfReverse');
		end

		% ---------------------------------------------------------------
		%> @brief Test typeList.
		% ---------------------------------------------------------------
		function testTypeList(testCase)
			g = gaborStimulus('verbose', false);
			verifyEqual(testCase, g.typeList, {'procedural'}, 'typeList');
		end

		% ---------------------------------------------------------------
		%> @brief Test custom properties.
		% ---------------------------------------------------------------
		function testCustomProperties(testCase)
			g = gaborStimulus('verbose', false, ...
				'sf', 2, 'tf', 4, 'contrast', 0.8, 'phase', 0.25, ...
				'aspectRatio', 2, 'spatialConstant', 15, ...
				'driftDirection', true, 'direction', 45, ...
				'correctPhase', true, 'phaseReverseTime', 1, 'phaseOfReverse', 90);
			verifyEqual(testCase, g.sf, 2, 'sf should be 2');
			verifyEqual(testCase, g.tf, 4, 'tf should be 4');
			verifyEqual(testCase, g.contrast, 0.8, 'contrast should be 0.8');
			verifyEqual(testCase, g.phase, 0.25, 'phase should be 0.25');
			verifyEqual(testCase, g.aspectRatio, 2, 'aspectRatio should be 2');
			verifyEqual(testCase, g.spatialConstant, 15, 'spatialConstant should be 15');
			verifyTrue(testCase, g.driftDirection, 'driftDirection should be true');
			verifyEqual(testCase, g.direction, 45, 'direction should be 45');
			verifyTrue(testCase, g.correctPhase, 'correctPhase should be true');
			verifyEqual(testCase, g.phaseReverseTime, 1, 'phaseReverseTime should be 1');
			verifyEqual(testCase, g.phaseOfReverse, 90, 'phaseOfReverse should be 90');
		end

		% ---------------------------------------------------------------
		%> @brief Test sigma setting via baseStimulus.
		% ---------------------------------------------------------------
		function testSigmaProperty(testCase)
			g = gaborStimulus('verbose', false, 'sigma', 8);
			verifyEqual(testCase, g.sigma, 8, 'sigma should be 8');
		end

		% ---------------------------------------------------------------
		%> @brief Test rotationMethod property.
		% ---------------------------------------------------------------
		function testRotationMethod(testCase)
			g = gaborStimulus('verbose', false, 'rotationMethod', false);
			verifyFalse(testCase, g.rotationMethod, 'rotationMethod should be false');
		end

		% ---------------------------------------------------------------
		%> @brief Test colour set method.
		% ---------------------------------------------------------------
		function testColourSetRGB(testCase)
			g = gaborStimulus('verbose', false);
			g.colour = [0.5 0.5 0.5];
			verifyEqual(testCase, g.colour(1:3), [0.5 0.5 0.5], 'RGB should be set');
		end

		% ---------------------------------------------------------------
		%> @brief Test alpha clamping.
		% ---------------------------------------------------------------
		function testAlphaClamping(testCase)
			g = gaborStimulus('verbose', false);
			g.alpha = 5;
			verifyEqual(testCase, g.alpha, 1, 'alpha should clamp to 1');
			g.alpha = -2;
			verifyEqual(testCase, g.alpha, 0, 'alpha should clamp to 0');
		end

		% ---------------------------------------------------------------
		%> @brief Test show/hide.
		% ---------------------------------------------------------------
		function testShowHide(testCase)
			g = gaborStimulus('verbose', false);
			verifyTrue(testCase, g.isVisible, 'visible by default');
			hide(g);
			verifyFalse(testCase, g.isVisible, 'hidden after hide');
			show(g);
			verifyTrue(testCase, g.isVisible, 'visible after show');
		end

		% ---------------------------------------------------------------
		%> @brief Test setOffTime and setDelayTime.
		% ---------------------------------------------------------------
		function testSetOffAndDelayTime(testCase)
			g = gaborStimulus('verbose', false);
			setOffTime(g, 2.5);
			verifyEqual(testCase, g.offTime, 2.5, 'offTime');
			setDelayTime(g, 0.3);
			verifyEqual(testCase, g.delayTime, 0.3, 'delayTime');
		end

		% ---------------------------------------------------------------
		%> @brief Test UUID.
		% ---------------------------------------------------------------
		function testUUID(testCase)
			g = gaborStimulus('verbose', false);
			verifyTrue(testCase, ~isempty(g.uuid), 'should have UUID');
		end

		% ---------------------------------------------------------------
		%> @brief Test fullName.
		% ---------------------------------------------------------------
		function testFullName(testCase)
			g = gaborStimulus('verbose', false, 'name', 'TestGabor');
			verifyTrue(testCase, contains(g.fullName, 'TestGabor'), ...
				'fullName contains name');
			verifyTrue(testCase, contains(g.fullName, 'gaborStimulus'), ...
				'fullName contains class');
		end

		% ---------------------------------------------------------------
		%> @brief Test reset before setup does not error.
		% ---------------------------------------------------------------
		function testResetBeforeSetup(testCase)
			g = gaborStimulus('verbose', false);
			reset(g);
			verifyTrue(testCase, true, 'reset completed');
		end

		% ---------------------------------------------------------------
		%> @brief Test that scale is 1 by default.
		% ---------------------------------------------------------------
		function testScaleDefault(testCase)
			g = gaborStimulus('verbose', false);
			verifyEqual(testCase, g.scale, 1, 'scale should be 1');
		end
	end

	% ===================================================================
	% HARDWARE TESTS
	% ===================================================================
	methods (Test, TestTags = {'hardware'})
		% ---------------------------------------------------------------
		%> @brief Test setup with a real PTB window.
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
			g = gaborStimulus('verbose', false);
			setup(g, sM);
			verifyTrue(testCase, g.isSetup, 'should be setup');
			verifyTrue(testCase, ~isempty(g.texture) || g.texture > 0, ...
				'texture should exist');
			reset(g);
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
			g = gaborStimulus('verbose', false);
			setup(g, sM);
			draw(g);
			verifyEqual(testCase, g.drawTick, 1, 'drawTick should be 1');
			reset(g);
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
			g = gaborStimulus('verbose', false, 'tf', 2);
			setup(g, sM);
			animate(g);
			verifyTrue(testCase, true, 'animate completed without error');
			reset(g);
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
			g = gaborStimulus('verbose', false);
			setup(g, sM);
			update(g);
			verifyTrue(testCase, true, 'update completed');
			reset(g);
		end

		% ---------------------------------------------------------------
		%> @brief Test run method.
		% ---------------------------------------------------------------
		function testRunMethod(testCase)
			assumeFalse(testCase, ~isempty(getenv('GITHUB_ACTIONS')), ...
				'Skipping PTB run test in CI');
			g = gaborStimulus('verbose', false);
			run(g, false, 1);
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
			g = gaborStimulus('verbose', false);
			setup(g, sM);
			verifyTrue(testCase, g.isSetup, 'should be setup');
			reset(g);
			verifyFalse(testCase, g.isSetup, 'isSetup should be false after reset');
			verifyEqual(testCase, g.scale, 1, 'scale should be 1 after reset');
		end

		% ---------------------------------------------------------------
		%> @brief Test with speed and direction for drifting gabor.
		% ---------------------------------------------------------------
		function testDriftingGabor(testCase)
			assumeFalse(testCase, ~isempty(getenv('GITHUB_ACTIONS')), ...
				'Skipping PTB drift test in CI');
			sM = screenManager;
			sM.windowed = [0 0 800 600];
			sM.disableSyncTests = true;
			sM.visualDebug = true;
			sM.bitDepth = '8bit';
			open(sM);
			cleanup = onCleanup(@() close(sM));
			g = gaborStimulus('verbose', false, 'speed', 5, 'direction', 45);
			setup(g, sM);
			verifyTrue(testCase, g.isSetup, 'drifting gabor should setup');
			draw(g);
			verifyEqual(testCase, g.drawTick, 1, 'drawTick should be 1');
			reset(g);
		end
	end
end
