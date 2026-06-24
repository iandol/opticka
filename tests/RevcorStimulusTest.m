% ========================================================================
%> @class RevcorStimulusTest
%> @brief Class-based unit tests for revcorStimulus.
%>
%> Tests construction, property defaults, typeList, pixelScale,
%> frameTime, trialLength, interpolation, and the standard stimulus
%> API (show/hide, reset, UUID). CI-safe tests run without PTB;
%> hardware-tagged tests exercise setup/draw/animate/update/run with a
%> real PTB window.
%>
%> Run with:
%>   >> runtests('tests/RevcorStimulusTest.m')
%>   >> runtests('tests/RevcorStimulusTest.m', '-ExcludeTag', 'hardware')
%>
%> Copyright (c) 2026 Ian Max Andolina — LGPL3, see LICENCE.md
% ========================================================================
classdef RevcorStimulusTest < matlab.unittest.TestCase

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
			rc = revcorStimulus('verbose', false);
			verifyEqual(testCase, rc.type, 'trinary', 'default type should be trinary');
			verifyEqual(testCase, rc.family, 'revcor', 'family should be revcor');
			verifyEqual(testCase, rc.pixelScale, 1, 'default pixelScale should be 1');
			verifyEqual(testCase, rc.frameTime, 64, 'default frameTime should be 64');
			verifyEqual(testCase, rc.trialLength, 2, 'default trialLength should be 2');
			verifyEqual(testCase, rc.interpolation, 0, 'default interpolation should be 0');
			verifyEqual(testCase, rc.name, 'RevCor', 'default name should be RevCor');
			verifyEqual(testCase, rc.size, 10, 'default size should be 10');
			verifyEqual(testCase, rc.speed, 0, 'default speed should be 0');
			verifyTrue(testCase, rc.isRect, 'should be rect-based');
		end

		% ---------------------------------------------------------------
		%> @brief Test typeList contains expected values.
		% ---------------------------------------------------------------
		function testTypeList(testCase)
			rc = revcorStimulus('verbose', false);
			verifyEqual(testCase, rc.typeList, {'trinary','binary'}, ...
				'typeList should be {trinary,binary}');
		end

		% ---------------------------------------------------------------
		%> @brief Test custom properties on construction.
		% ---------------------------------------------------------------
		function testCustomProperties(testCase)
			rc = revcorStimulus('verbose', false, ...
				'type', 'binary', 'pixelScale', 2, ...
				'frameTime', 32, 'trialLength', 5, ...
				'interpolation', 1);
			verifyEqual(testCase, rc.type, 'binary', 'type should be binary');
			verifyEqual(testCase, rc.pixelScale, 2, 'pixelScale should be 2');
			verifyEqual(testCase, rc.frameTime, 32, 'frameTime should be 32');
			verifyEqual(testCase, rc.trialLength, 5, 'trialLength should be 5');
			verifyEqual(testCase, rc.interpolation, 1, 'interpolation should be 1');
		end

		% ---------------------------------------------------------------
		%> @brief Test colour set method.
		% ---------------------------------------------------------------
		function testColourSetRGB(testCase)
			rc = revcorStimulus('verbose', false);
			rc.colour = [0.5 0.5 0.5];
			verifyEqual(testCase, rc.colour(1:3), [0.5 0.5 0.5], 'RGB set');
			verifyEqual(testCase, rc.alpha, 1, 'alpha should remain 1');
		end

		% ---------------------------------------------------------------
		%> @brief Test alpha clamping.
		% ---------------------------------------------------------------
		function testAlphaClamping(testCase)
			rc = revcorStimulus('verbose', false);
			rc.alpha = 10;
			verifyEqual(testCase, rc.alpha, 1, 'alpha clamps to 1');
			rc.alpha = -5;
			verifyEqual(testCase, rc.alpha, 0, 'alpha clamps to 0');
		end

		% ---------------------------------------------------------------
		%> @brief Test show/hide methods.
		% ---------------------------------------------------------------
		function testShowHide(testCase)
			rc = revcorStimulus('verbose', false);
			verifyTrue(testCase, rc.isVisible, 'should be visible by default');
			hide(rc);
			verifyFalse(testCase, rc.isVisible, 'should be hidden after hide');
			show(rc);
			verifyTrue(testCase, rc.isVisible, 'should be visible after show');
		end

		% ---------------------------------------------------------------
		%> @brief Test setOffTime and setDelayTime.
		% ---------------------------------------------------------------
		function testSetOffAndDelayTime(testCase)
			rc = revcorStimulus('verbose', false);
			setOffTime(rc, 3.0);
			verifyEqual(testCase, rc.offTime, 3.0, 'offTime should be 3.0');
			setDelayTime(rc, 0.75);
			verifyEqual(testCase, rc.delayTime, 0.75, 'delayTime should be 0.75');
		end

		% ---------------------------------------------------------------
		%> @brief Test UUID from optickaCore.
		% ---------------------------------------------------------------
		function testHasUUID(testCase)
			rc = revcorStimulus('verbose', false);
			verifyTrue(testCase, ~isempty(rc.uuid), 'should have a UUID');
		end

		% ---------------------------------------------------------------
		%> @brief Test fullName.
		% ---------------------------------------------------------------
		function testFullName(testCase)
			rc = revcorStimulus('verbose', false, 'name', 'TestRevcor');
			verifyTrue(testCase, contains(rc.fullName, 'TestRevcor'), ...
				'fullName should contain name');
			verifyTrue(testCase, contains(rc.fullName, 'revcorStimulus'), ...
				'fullName should contain class name');
		end

		% ---------------------------------------------------------------
		%> @brief Test reset before setup is safe.
		% ---------------------------------------------------------------
		function testResetBeforeSetup(testCase)
			rc = revcorStimulus('verbose', false);
			reset(rc);
			verifyFalse(testCase, rc.isSetup, 'should not be setup after reset');
		end

		% ---------------------------------------------------------------
		%> @brief Test trialTick starts at 0.
		% ---------------------------------------------------------------
		function testTrialTickDefault(testCase)
			rc = revcorStimulus('verbose', false);
			verifyEqual(testCase, rc.trialTick, 0, 'trialTick should be 0');
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
			rc = revcorStimulus('verbose', false);
			setup(rc, sM);
			verifyTrue(testCase, rc.isSetup, 'should be setup');
			verifyTrue(testCase, ~isempty(rc.texture), 'texture should be created');
			verifyTrue(testCase, ismatrix(rc.texture), 'texture pointer should be positive');
			reset(rc);
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
			rc = revcorStimulus('verbose', false);
			setup(rc, sM);
			draw(rc);
			verifyEqual(testCase, rc.drawTick, 1, 'drawTick should be 1 after one draw');
			reset(rc);
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
			rc = revcorStimulus('verbose', false);
			setup(rc, sM);
			animate(rc);
			verifyEqual(testCase, rc.tick, 0, 'tick should be 0 (draw not called)');
			reset(rc);
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
			rc = revcorStimulus('verbose', false);
			setup(rc, sM);
			update(rc);
			verifyTrue(testCase, true, 'update completed without error');
			reset(rc);
		end

		% ---------------------------------------------------------------
		%> @brief Test the run method.
		% ---------------------------------------------------------------
		function testRunMethod(testCase)
			assumeFalse(testCase, ~isempty(getenv('GITHUB_ACTIONS')), ...
				'Skipping PTB run test in CI');
			rc = revcorStimulus('verbose', false);
			run(rc, false, 1);
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
			rc = revcorStimulus('verbose', false);
			setup(rc, sM);
			reset(rc);
			verifyFalse(testCase, rc.isSetup, 'isSetup should be false after reset');
		end
	end
end
