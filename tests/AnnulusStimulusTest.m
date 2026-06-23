% ========================================================================
%> @class AnnulusStimulusTest
%> @brief Class-based unit tests for annulusStimulus.
%>
%> Tests construction, property defaults, dual spatial/temporal
%> frequencies, angles, phases, contrasts, method, and the standard
%> stimulus API (show/hide, reset, UUID). CI-safe tests run without
%> PTB; hardware-tagged tests exercise setup/draw/animate/update/run
%> with a real PTB window.
%>
%> Run with:
%>   >> runtests('tests/AnnulusStimulusTest.m')
%>   >> runtests('tests/AnnulusStimulusTest.m', '-ExcludeTag', 'hardware')
%>
%> Copyright (c) 2026 Ian Max Andolina — LGPL3, see LICENCE.md
% ========================================================================
classdef AnnulusStimulusTest < matlab.unittest.TestCase

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
			an = annulusStimulus('verbose', false);
			verifyEqual(testCase, an.family, 'annulus', 'family should be annulus');
			verifyEqual(testCase, an.method, 'procedural', 'default method should be procedural');
			verifyEqual(testCase, an.sf1, 0.01, 'default sf1 should be 0.01');
			verifyEqual(testCase, an.sf2, 0.01, 'default sf2 should be 0.01');
			verifyEqual(testCase, an.tf1, 0.01, 'default tf1 should be 0.01');
			verifyEqual(testCase, an.tf2, 0.01, 'default tf2 should be 0.01');
			verifyEqual(testCase, an.angle1, 0, 'default angle1 should be 0');
			verifyEqual(testCase, an.angle2, 0, 'default angle2 should be 0');
			verifyEqual(testCase, an.phase1, 0, 'default phase1 should be 0');
			verifyEqual(testCase, an.phase2, 0, 'default phase2 should be 0');
			verifyEqual(testCase, an.contrast1, 0.36, 'default contrast1 should be 0.36');
			verifyEqual(testCase, an.contrast2, 0.36, 'default contrast2 should be 0.36');
			verifyEmpty(testCase, an.texid, 'default texid should be empty');
		end

		% ---------------------------------------------------------------
		%> @brief Test custom properties on construction.
		% ---------------------------------------------------------------
		function testCustomProperties(testCase)
			an = annulusStimulus('verbose', false, ...
				'method', 'texture', 'sf1', 0.5, 'sf2', 0.3, ...
				'tf1', 2, 'tf2', 4, 'angle1', 45, 'angle2', 90, ...
				'phase1', 0.5, 'phase2', 1.0, ...
				'contrast1', 0.8, 'contrast2', 0.6);
			verifyEqual(testCase, an.method, 'texture', 'method should be texture');
			verifyEqual(testCase, an.sf1, 0.5, 'sf1 should be 0.5');
			verifyEqual(testCase, an.sf2, 0.3, 'sf2 should be 0.3');
			verifyEqual(testCase, an.tf1, 2, 'tf1 should be 2');
			verifyEqual(testCase, an.tf2, 4, 'tf2 should be 4');
			verifyEqual(testCase, an.angle1, 45, 'angle1 should be 45');
			verifyEqual(testCase, an.angle2, 90, 'angle2 should be 90');
			verifyEqual(testCase, an.phase1, 0.5, 'phase1 should be 0.5');
			verifyEqual(testCase, an.phase2, 1.0, 'phase2 should be 1.0');
			verifyEqual(testCase, an.contrast1, 0.8, 'contrast1 should be 0.8');
			verifyEqual(testCase, an.contrast2, 0.6, 'contrast2 should be 0.6');
		end

		% ---------------------------------------------------------------
		%> @brief Test colour set method.
		% ---------------------------------------------------------------
		function testColourSetRGB(testCase)
			an = annulusStimulus('verbose', false);
			an.colour = [0.5 0.5 0.5];
			verifyEqual(testCase, an.colour(1:3), [0.5 0.5 0.5], 'RGB set');
			verifyEqual(testCase, an.alpha, 1, 'alpha should remain 1');
		end

		% ---------------------------------------------------------------
		%> @brief Test alpha clamping.
		% ---------------------------------------------------------------
		function testAlphaClamping(testCase)
			an = annulusStimulus('verbose', false);
			an.alpha = 10;
			verifyEqual(testCase, an.alpha, 1, 'alpha clamps to 1');
			an.alpha = -5;
			verifyEqual(testCase, an.alpha, 0, 'alpha clamps to 0');
		end

		% ---------------------------------------------------------------
		%> @brief Test show/hide methods.
		% ---------------------------------------------------------------
		function testShowHide(testCase)
			an = annulusStimulus('verbose', false);
			verifyTrue(testCase, an.isVisible, 'should be visible by default');
			hide(an);
			verifyFalse(testCase, an.isVisible, 'should be hidden after hide');
			show(an);
			verifyTrue(testCase, an.isVisible, 'should be visible after show');
		end

		% ---------------------------------------------------------------
		%> @brief Test setOffTime and setDelayTime.
		% ---------------------------------------------------------------
		function testSetOffAndDelayTime(testCase)
			an = annulusStimulus('verbose', false);
			setOffTime(an, 3.0);
			verifyEqual(testCase, an.offTime, 3.0, 'offTime should be 3.0');
			setDelayTime(an, 0.75);
			verifyEqual(testCase, an.delayTime, 0.75, 'delayTime should be 0.75');
		end

		% ---------------------------------------------------------------
		%> @brief Test UUID from optickaCore.
		% ---------------------------------------------------------------
		function testHasUUID(testCase)
			an = annulusStimulus('verbose', false);
			verifyTrue(testCase, ~isempty(an.uuid), 'should have a UUID');
		end

		% ---------------------------------------------------------------
		%> @brief Test fullName.
		% ---------------------------------------------------------------
		function testFullName(testCase)
			an = annulusStimulus('verbose', false, 'name', 'TestAnnulus');
			verifyTrue(testCase, contains(an.fullName, 'TestAnnulus'), ...
				'fullName should contain name');
			verifyTrue(testCase, contains(an.fullName, 'annulusStimulus'), ...
				'fullName should contain class name');
		end

		% ---------------------------------------------------------------
		%> @brief Test reset before setup is safe.
		% ---------------------------------------------------------------
		function testResetBeforeSetup(testCase)
			an = annulusStimulus('verbose', false);
			reset(an);
			verifyFalse(testCase, an.isSetup, 'should not be setup after reset');
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
			an = annulusStimulus('verbose', false);
			setup(an, sM);
			verifyTrue(testCase, an.isSetup, 'should be setup');
			reset(an);
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
			an = annulusStimulus('verbose', false);
			setup(an, sM);
			draw(an);
			verifyEqual(testCase, an.drawTick, 1, 'drawTick should be 1 after one draw');
			reset(an);
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
			an = annulusStimulus('verbose', false);
			setup(an, sM);
			animate(an);
			verifyEqual(testCase, an.tick, 0, 'tick should be 0 (draw not called)');
			reset(an);
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
			an = annulusStimulus('verbose', false);
			setup(an, sM);
			update(an);
			verifyTrue(testCase, true, 'update completed without error');
			reset(an);
		end

		% ---------------------------------------------------------------
		%> @brief Test the run method.
		% ---------------------------------------------------------------
		function testRunMethod(testCase)
			assumeFalse(testCase, ~isempty(getenv('GITHUB_ACTIONS')), ...
				'Skipping PTB run test in CI');
			an = annulusStimulus('verbose', false);
			run(an, false, 1);
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
			an = annulusStimulus('verbose', false);
			setup(an, sM);
			reset(an);
			verifyFalse(testCase, an.isSetup, 'isSetup should be false after reset');
		end
	end
end
