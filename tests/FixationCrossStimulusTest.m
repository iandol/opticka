% ========================================================================
%> @class FixationCrossStimulusTest
%> @brief Class-based unit tests for fixationCrossStimulus.
%>
%> Tests construction, property defaults, type list validation, colour
%> handling, alpha2, lineWidth, showDisk, flash/pulse modes, colour2
%> properties. CI-safe tests run without PTB; hardware-tagged tests
%> exercise setup/draw/animate/update/run with a real PTB window.
%>
%> Run with:
%>   >> runtests('tests/FixationCrossStimulusTest.m')
%>   >> runtests('tests/FixationCrossStimulusTest.m', '-ExcludeTag', 'hardware')
%>
%> Copyright (c) 2026 Ian Max Andolina — LGPL3, see LICENCE.md
% ========================================================================
classdef FixationCrossStimulusTest < matlab.unittest.TestCase

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
			f = fixationCrossStimulus('verbose', false);
			verifyEqual(testCase, f.type, 'simple', 'default type should be simple');
			verifyEqual(testCase, f.family, 'fixationcross', 'family should be fixationcross');
			verifyEqual(testCase, f.lineWidth, 0.1, 'default lineWidth should be 0.1');
			verifyEqual(testCase, f.alpha2, 1, 'default alpha2 should be 1');
			verifyEqual(testCase, f.colour2(1:3), [0 0 0], 'default colour2 should be black');
			verifyTrue(testCase, f.showDisk, 'default showDisk should be true');
			verifyEqual(testCase, f.flashTime, [0.25 0.1], 'default flashTime');
			verifyTrue(testCase, f.flashOn, 'default flashOn should be true');
			verifyEqual(testCase, f.pulseFrequency, 2, 'default pulseFrequency should be 2');
			verifyEqual(testCase, f.pulseRange, 50, 'default pulseRange should be 50');
			verifyEqual(testCase, f.size, 0.8, 'default size should be 0.8');
			verifyFalse(testCase, f.isRect, 'isRect should be false');
		end

		% ---------------------------------------------------------------
		%> @brief Test typeList contains expected values.
		% ---------------------------------------------------------------
		function testTypeList(testCase)
			f = fixationCrossStimulus('verbose', false);
			verifyEqual(testCase, f.typeList, {'simple','pulse','flash'}, 'typeList should match');
		end

		% ---------------------------------------------------------------
		%> @brief Test construction with custom properties.
		% ---------------------------------------------------------------
		function testCustomProperties(testCase)
			f = fixationCrossStimulus('verbose', false, ...
				'type', 'flash', 'flashTime', [0.1 0.2], 'flashOn', false, ...
				'lineWidth', 0.3, 'alpha2', 0.5, 'showDisk', false, ...
				'colour2', [1 0 0 0.8]);
			verifyEqual(testCase, f.type, 'flash', 'type should be flash');
			verifyEqual(testCase, f.flashTime, [0.1 0.2], 'flashTime should be [0.1 0.2]');
			verifyFalse(testCase, f.flashOn, 'flashOn should be false');
			verifyEqual(testCase, f.lineWidth, 0.3, 'lineWidth should be 0.3');
			verifyFalse(testCase, f.showDisk, 'showDisk should be false');
			verifyEqual(testCase, f.colour2(1:3), [1 0 0], 'colour2 RGB should be set');
			verifyEqual(testCase, f.colour2(4), 0.8, 'colour2 alpha should be 0.8');
			verifyEqual(testCase, f.alpha2, 0.8, 'alpha2 should be 0.8 overridden by colour2');
		end

		% ---------------------------------------------------------------
		%> @brief Test pulse mode properties.
		% ---------------------------------------------------------------
		function testPulseMode(testCase)
			f = fixationCrossStimulus('verbose', false, ...
				'type', 'pulse', 'pulseFrequency', 5, 'pulseRange', 75);
			verifyEqual(testCase, f.type, 'pulse', 'type should be pulse');
			verifyEqual(testCase, f.pulseFrequency, 5, 'pulseFrequency should be 5');
			verifyEqual(testCase, f.pulseRange, 75, 'pulseRange should be 75');
		end

		% ---------------------------------------------------------------
		%> @brief Test flashColour property.
		% ---------------------------------------------------------------
		function testFlashColour(testCase)
			f = fixationCrossStimulus('verbose', false, ...
				'flashColour', [0.5 0.5 0.5 1]);
			verifyEqual(testCase, f.flashColour(1:3), [0.5 0.5 0.5], ...
				'flashColour RGB should be set');
		end

		% ---------------------------------------------------------------
		%> @brief Test colour set method (inherited from baseStimulus).
		% ---------------------------------------------------------------
		function testColourSetRGB(testCase)
			f = fixationCrossStimulus('verbose', false);
			f.colour = [0.5 0.5 0.5];
			verifyEqual(testCase, f.colour(1:3), [0.5 0.5 0.5], 'RGB should be set');
		end

		% ---------------------------------------------------------------
		%> @brief Test alpha clamping.
		% ---------------------------------------------------------------
		function testAlphaClamping(testCase)
			f = fixationCrossStimulus('verbose', false);
			f.alpha = 5;
			verifyEqual(testCase, f.alpha, 1, 'alpha should clamp to 1');
			f.alpha = -3;
			verifyEqual(testCase, f.alpha, 0, 'alpha should clamp to 0');
		end

		% ---------------------------------------------------------------
		%> @brief Test show/hide.
		% ---------------------------------------------------------------
		function testShowHide(testCase)
			f = fixationCrossStimulus('verbose', false);
			verifyTrue(testCase, f.isVisible, 'visible by default');
			hide(f);
			verifyFalse(testCase, f.isVisible, 'hidden after hide');
			show(f);
			verifyTrue(testCase, f.isVisible, 'visible after show');
		end

		% ---------------------------------------------------------------
		%> @brief Test setOffTime and setDelayTime.
		% ---------------------------------------------------------------
		function testSetOffAndDelayTime(testCase)
			f = fixationCrossStimulus('verbose', false);
			setOffTime(f, 3.0);
			verifyEqual(testCase, f.offTime, 3.0, 'offTime should be 3.0');
			setDelayTime(f, 0.5);
			verifyEqual(testCase, f.delayTime, 0.5, 'delayTime should be 0.5');
		end

		% ---------------------------------------------------------------
		%> @brief Test UUID from optickaCore.
		% ---------------------------------------------------------------
		function testUUID(testCase)
			f = fixationCrossStimulus('verbose', false);
			verifyTrue(testCase, ~isempty(f.uuid), 'should have UUID');
			f2 = fixationCrossStimulus('verbose', false);
			verifyNotEqual(testCase, f.uuid, f2.uuid, 'UUIDs should be unique');
		end

		% ---------------------------------------------------------------
		%> @brief Test fullName combines name and class.
		% ---------------------------------------------------------------
		function testFullName(testCase)
			f = fixationCrossStimulus('verbose', false, 'name', 'MyFix');
			verifyTrue(testCase, contains(f.fullName, 'MyFix'), ...
				'fullName should contain name');
			verifyTrue(testCase, contains(f.fullName, 'fixationCrossStimulus'), ...
				'fullName should contain class name');
		end

		% ---------------------------------------------------------------
		%> @brief Test reset before setup does not error.
		% ---------------------------------------------------------------
		function testResetBeforeSetup(testCase)
			f = fixationCrossStimulus('verbose', false);
			reset(f);
			verifyTrue(testCase, true, 'reset completed without error');
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
			f = fixationCrossStimulus('verbose', false);
			setup(f, sM);
			verifyTrue(testCase, f.isSetup, 'should be setup');
			reset(f);
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
			f = fixationCrossStimulus('verbose', false);
			setup(f, sM);
			draw(f);
			verifyEqual(testCase, f.drawTick, 1, 'drawTick should be 1 after draw');
			reset(f);
		end

		% ---------------------------------------------------------------
		%> @brief Test animate after setup (no motion).
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
			f = fixationCrossStimulus('verbose', false);
			setup(f, sM);
			animate(f);
			verifyTrue(testCase, true, 'animate completed without error');
			reset(f);
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
			f = fixationCrossStimulus('verbose', false);
			setup(f, sM);
			update(f);
			verifyTrue(testCase, true, 'update completed without error');
			reset(f);
		end

		% ---------------------------------------------------------------
		%> @brief Test the run method.
		% ---------------------------------------------------------------
		function testRunMethod(testCase)
			assumeFalse(testCase, ~isempty(getenv('GITHUB_ACTIONS')), ...
				'Skipping PTB run test in CI');
			f = fixationCrossStimulus('verbose', false);
			run(f, false, 1);
			verifyTrue(testCase, true, 'run() completed without error');
		end

		% ---------------------------------------------------------------
		%> @brief Test flash type animation flips between flash states.
		% ---------------------------------------------------------------
		function testFlashModeAnimation(testCase)
			assumeFalse(testCase, ~isempty(getenv('GITHUB_ACTIONS')), ...
				'Skipping PTB flash test in CI');
			sM = screenManager;
			sM.windowed = [0 0 800 600];
			sM.disableSyncTests = true;
			sM.visualDebug = true;
			sM.bitDepth = '8bit';
			open(sM);
			cleanup = onCleanup(@() close(sM));
			f = fixationCrossStimulus('verbose', false, 'type', 'flash');
			setup(f, sM);
			% Multiple animate calls should toggle flash state
			for i = 1:10
				animate(f);
			end
			verifyTrue(testCase, true, 'flash mode animate completed');
			reset(f);
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
			f = fixationCrossStimulus('verbose', false);
			setup(f, sM);
			verifyTrue(testCase, f.isSetup, 'should be setup before reset');
			reset(f);
			verifyFalse(testCase, f.isSetup, 'isSetup should be false after reset');
		end
	end
end
