% ========================================================================
%> @class PolarGratingStimulusTest
%> @brief Class-based unit tests for polarGratingStimulus.
%>
%> Tests construction, property defaults, type list validation, custom
%> properties, colour2/baseColour handling, spiral/arc parameters, and
%> phase/TF/SF properties. CI-safe tests run without PTB; hardware-tagged
%> tests exercise setup/draw/animate/update/run with a real PTB window.
%>
%> Run with:
%>   >> runtests('tests/PolarGratingStimulusTest.m')
%>   >> runtests('tests/PolarGratingStimulusTest.m', '-ExcludeTag', 'hardware')
%>
%> Copyright (c) 2026 Ian Max Andolina — LGPL3, see LICENCE.md
% ========================================================================
classdef PolarGratingStimulusTest < matlab.unittest.TestCase

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
			p = polarGratingStimulus('verbose', false);
			verifyEqual(testCase, p.type, 'radial', 'default type should be radial');
			verifyEqual(testCase, p.family, 'grating', 'family should be grating');
			verifyEqual(testCase, p.sf, 1, 'default sf should be 1');
			verifyEqual(testCase, p.tf, 1, 'default tf should be 1');
			verifyEqual(testCase, p.phase, 0, 'default phase should be 0');
			verifyEqual(testCase, p.contrast, 0.5, 'default contrast should be 0.5');
			verifyEqual(testCase, p.sigma, -1, 'default sigma should be -1');
			verifyTrue(testCase, p.mask, 'default mask should be true');
			verifyTrue(testCase, p.rotateTexture, 'default rotateTexture should be true');
			verifyFalse(testCase, p.reverseDirection, 'default reverseDirection should be false');
			verifyFalse(testCase, p.correctPhase, 'default correctPhase should be false');
			verifyEqual(testCase, p.direction, 0, 'default direction should be 0');
			verifyEqual(testCase, p.aspectRatio, 1, 'default aspectRatio should be 1');
			verifyEqual(testCase, p.spiralFactor, 1, 'default spiralFactor should be 1');
			verifyEqual(testCase, p.arcValue, [0 0], 'default arcValue should be [0 0]');
			verifyFalse(testCase, p.arcSymmetry, 'default arcSymmetry should be false');
			verifyEqual(testCase, p.centerMask, 0, 'default centerMask should be 0');
			verifyEqual(testCase, p.phaseReverseTime, 0, 'default phaseReverseTime should be 0');
			verifyEqual(testCase, p.phaseOfReverse, 180, 'default phaseOfReverse should be 180');
			verifyTrue(testCase, isempty(p.baseColour), 'default baseColour should be empty');
			verifyTrue(testCase, isempty(p.visibleRate), 'default visibleRate should be empty');
			verifyTrue(testCase, p.isRect, 'isRect should be true');
			% colour2 default is [0 0 0 1] (set by constructor addDefaults)
			verifyEqual(testCase, p.colour2(1:3), [0 0 0], 'default colour2 RGB');
			verifyEqual(testCase, p.colour2(4), 1, 'default colour2 alpha');
			% colour default is [1 1 1 1] (set by constructor addDefaults)
			verifyEqual(testCase, p.colour(1:3), [1 1 1], 'default colour RGB');
			verifyEqual(testCase, p.colour(4), 1, 'default colour alpha');
			verifyEqual(testCase, p.name, 'polar-grating', 'default name should be polar-grating');
		end

		% ---------------------------------------------------------------
		%> @brief Test typeList constant.
		% ---------------------------------------------------------------
		function testTypeList(testCase)
			p = polarGratingStimulus('verbose', false);
			verifyEqual(testCase, p.typeList, {'radial';'circular';'spiral'}, 'typeList');
		end

		% ---------------------------------------------------------------
		%> @brief Test custom properties set at construction.
		% ---------------------------------------------------------------
		function testCustomProperties(testCase)
			p = polarGratingStimulus('verbose', false, ...
				'type', 'spiral', 'sf', 2, 'tf', 4, ...
				'contrast', 0.8, 'phase', 0.5, 'mask', false, ...
				'rotateTexture', false, 'aspectRatio', 2, ...
				'spiralFactor', 3, 'arcValue', [45 90], ...
				'arcSymmetry', true, 'centerMask', 0.5, ...
				'direction', 90, 'sigma', 10, ...
				'colour2', [1 0 0 0.8], 'reverseDirection', true, ...
				'correctPhase', true, 'phaseReverseTime', 2, ...
				'phaseOfReverse', 90);
			verifyEqual(testCase, p.type, 'spiral', 'type should be spiral');
			verifyEqual(testCase, p.sf, 2, 'sf should be 2');
			verifyEqual(testCase, p.tf, 4, 'tf should be 4');
			verifyEqual(testCase, p.contrast, 0.8, 'contrast should be 0.8');
			verifyEqual(testCase, p.phase, 0.5, 'phase should be 0.5');
			verifyFalse(testCase, p.mask, 'mask should be false');
			verifyFalse(testCase, p.rotateTexture, 'rotateTexture should be false');
			verifyEqual(testCase, p.aspectRatio, 2, 'aspectRatio should be 2');
			verifyEqual(testCase, p.spiralFactor, 3, 'spiralFactor should be 3');
			verifyEqual(testCase, p.arcValue, [45 90], 'arcValue should be [45 90]');
			verifyTrue(testCase, p.arcSymmetry, 'arcSymmetry should be true');
			verifyEqual(testCase, p.centerMask, 0.5, 'centerMask should be 0.5');
			verifyEqual(testCase, p.direction, 90, 'direction should be 90');
			verifyEqual(testCase, p.sigma, 10, 'sigma should be 10');
			verifyEqual(testCase, p.colour2(1:3), [1 0 0], 'colour2 RGB should be red');
			verifyEqual(testCase, p.colour2(4), 0.8, 'colour2 alpha should be 0.8');
			verifyTrue(testCase, p.reverseDirection, 'reverseDirection should be true');
			verifyTrue(testCase, p.correctPhase, 'correctPhase should be true');
			verifyEqual(testCase, p.phaseReverseTime, 2, 'phaseReverseTime should be 2');
			verifyEqual(testCase, p.phaseOfReverse, 90, 'phaseOfReverse should be 90');
		end

		% ---------------------------------------------------------------
		%> @brief Test show/hide visibility toggling.
		% ---------------------------------------------------------------
		function testShowHide(testCase)
			p = polarGratingStimulus('verbose', false);
			verifyTrue(testCase, p.isVisible, 'should be visible by default');
			hide(p);
			verifyFalse(testCase, p.isVisible, 'should be hidden after hide');
			show(p);
			verifyTrue(testCase, p.isVisible, 'should be visible after show');
		end

		% ---------------------------------------------------------------
		%> @brief Test setOffTime and setDelayTime.
		% ---------------------------------------------------------------
		function testSetOffAndDelayTime(testCase)
			p = polarGratingStimulus('verbose', false);
			setOffTime(p, 3.0);
			verifyEqual(testCase, p.offTime, 3.0, 'offTime should be 3.0');
			setDelayTime(p, 0.3);
			verifyEqual(testCase, p.delayTime, 0.3, 'delayTime should be 0.3');
		end

		% ---------------------------------------------------------------
		%> @brief Test colour set and alpha clamping.
		% ---------------------------------------------------------------
		function testColourAndAlpha(testCase)
			p = polarGratingStimulus('verbose', false);
			p.colour = [0.2 0.4 0.6];
			verifyEqual(testCase, p.colour(1:3), [0.2 0.4 0.6], 'colour RGB should be set');
			% colour2 set with 3 values forces alpha override
			p.colour2 = [0.5 0.5 0.5];
			verifyEqual(testCase, p.colour2(1:3), [0.5 0.5 0.5], 'colour2 RGB should be set');
			% alpha clamping
			p.alpha = 5;
			verifyEqual(testCase, p.alpha, 1, 'alpha should clamp to 1');
			p.alpha = -3;
			verifyEqual(testCase, p.alpha, 0, 'alpha should clamp to 0');
		end

		% ---------------------------------------------------------------
		%> @brief Test UUID is generated.
		% ---------------------------------------------------------------
		function testUUID(testCase)
			p = polarGratingStimulus('verbose', false);
			verifyTrue(testCase, ~isempty(p.uuid), 'should have a non-empty UUID');
		end

		% ---------------------------------------------------------------
		%> @brief Test fullName contains name and class.
		% ---------------------------------------------------------------
		function testFullName(testCase)
			p = polarGratingStimulus('verbose', false, 'name', 'MyPolar');
			verifyTrue(testCase, contains(p.fullName, 'MyPolar'), ...
				'fullName should contain the name');
			verifyTrue(testCase, contains(p.fullName, 'polarGratingStimulus'), ...
				'fullName should contain the class name');
		end

		% ---------------------------------------------------------------
		%> @brief Test reset before setup completes without error.
		% ---------------------------------------------------------------
		function testResetBeforeSetup(testCase)
			p = polarGratingStimulus('verbose', false);
			reset(p);
			verifyTrue(testCase, true, 'reset before setup should complete');
		end

		% ---------------------------------------------------------------
		%> @brief Test direction defaults to angle (both 0 by default).
		% ---------------------------------------------------------------
		function testDirectionDefaultsToAngle(testCase)
			p = polarGratingStimulus('verbose', false);
			verifyEqual(testCase, p.direction, p.angle, ...
				'direction should equal angle by default (both 0)');
		end

		% ---------------------------------------------------------------
		%> @brief Test sf clamping when set to non-positive.
		% ---------------------------------------------------------------
		function testSfClamping(testCase)
			p = polarGratingStimulus('verbose', false);
			p.sf = 0;
			verifyEqual(testCase, p.sf, 0.05, 'sf should clamp to 0.05 when set to 0');
			p.sf = -5;
			verifyEqual(testCase, p.sf, 0.05, 'sf should clamp to 0.05 when set to negative');
		end

		% ---------------------------------------------------------------
		%> @brief Test baseColour set with RGB values.
		% ---------------------------------------------------------------
		function testBaseColourSet(testCase)
			p = polarGratingStimulus('verbose', false);
			p.baseColour = [0.3 0.3 0.3];
			verifyEqual(testCase, p.baseColour(1:3), [0.3 0.3 0.3], ...
				'baseColour RGB should be set');
		end
	end

	% ===================================================================
	% HARDWARE TESTS
	% ===================================================================
	methods (Test, TestTags = {'hardware'})
		% ---------------------------------------------------------------
		%> @brief Test setup with a PTB window via screenManager.
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
			p = polarGratingStimulus('verbose', false);
			setup(p, sM);
			verifyTrue(testCase, p.isSetup, 'should be setup');
			verifyTrue(testCase, ~isempty(p.texture) && p.texture > 0, ...
				'texture should exist');
			reset(p);
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
			p = polarGratingStimulus('verbose', false);
			setup(p, sM);
			draw(p);
			verifyEqual(testCase, p.drawTick, 1, 'drawTick should be 1');
			reset(p);
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
			p = polarGratingStimulus('verbose', false, 'tf', 2);
			setup(p, sM);
			animate(p);
			verifyTrue(testCase, true, 'animate completed without error');
			reset(p);
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
			p = polarGratingStimulus('verbose', false);
			setup(p, sM);
			update(p);
			verifyTrue(testCase, true, 'update completed without error');
			reset(p);
		end

		% ---------------------------------------------------------------
		%> @brief Test run method.
		% ---------------------------------------------------------------
		function testRunMethod(testCase)
			assumeFalse(testCase, ~isempty(getenv('GITHUB_ACTIONS')), ...
				'Skipping PTB run test in CI');
			p = polarGratingStimulus('verbose', false);
			run(p, false, 1);
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
			p = polarGratingStimulus('verbose', false);
			setup(p, sM);
			verifyTrue(testCase, p.isSetup, 'should be setup');
			reset(p);
			verifyFalse(testCase, p.isSetup, 'isSetup should be false after reset');
			verifyEqual(testCase, p.scale, 1, 'scale should be 1 after reset');
		end
	end
end
