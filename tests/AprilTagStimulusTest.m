% ========================================================================
%> @class AprilTagStimulusTest
%> @brief Class-based unit tests for aprilTagStimulus.
%>
%> Tests construction, property defaults, tag constants, binary matrix
%> generation, patternMatrix handling, colour assignment, cellSize scaling,
%> custom properties, and the standard stimulus API (show/hide, reset, UUID).
%> CI-safe tests run without PTB; hardware-tagged tests exercise setup/draw/
%> animate/update/run with a real PTB window.
%>
%> Run with:
%>   >> runtests('tests/AprilTagStimulusTest.m')
%>   >> runtests('tests/AprilTagStimulusTest.m', '-ExcludeTag', 'hardware')
%>
%> Copyright (c) 2026 Ian Max Andolina — LGPL3, see LICENCE.md
% ========================================================================
classdef AprilTagStimulusTest < matlab.unittest.TestCase

	methods (TestClassSetup)
		
	end

	% ===================================================================
	% CI-SAFE TESTS (no PTB window required)
	% ===================================================================
	methods (Test, TestTags = {'CI'})
		% ---------------------------------------------------------------
		%> @brief Test construction with defaults.
		% ---------------------------------------------------------------
		function testConstructionDefaults(testCase)
			at = aprilTagStimulus('verbose', false);
			verifyEqual(testCase, at.type, 'aprilTag', 'type should be aprilTag');
			verifyEqual(testCase, at.family, 'texture', 'family should be texture');
			verifyEqual(testCase, at.rows, 6, 'default rows should be 6');
			verifyEqual(testCase, at.columns, 6, 'default columns should be 6');
			verifyEqual(testCase, at.cellSize, 24, 'default cellSize should be 24');
			verifyEqual(testCase, at.colour, [0 0 0 1], 'default colour should be black');
			verifyEqual(testCase, at.colour2, [1 1 1 1], 'default colour2 should be white');
			verifyEqual(testCase, at.filter, 0, 'default filter should be 0');
			verifyEqual(testCase, at.precision, 0, 'default precision should be 0');
			verifyTrue(testCase, at.randomisePattern, 'default randomisePattern should be true');
			verifyTrue(testCase, at.isRect, 'should be rect-based');
			verifyEqual(testCase, at.name, 'AprilTag', 'default name should be AprilTag');
			verifyEqual(testCase, at.size, 5, 'default size should be 5');
		end

		% ---------------------------------------------------------------
		%> @brief Test built-in tag constants exist and are valid.
		% ---------------------------------------------------------------
		function testTagConstantsExist(testCase)
			verifyTrue(testCase, ~isempty(aprilTagStimulus.tag36_11), ...
				'tag36_11 should exist');
			verifyEqual(testCase, size(aprilTagStimulus.tag36_11), [10 10], ...
				'tag36_11 should be 10x10');
			verifyTrue(testCase, all(ismember(aprilTagStimulus.tag36_11(:), [0 1])), ...
				'tag36_11 should be binary');
		end

		% ---------------------------------------------------------------
		%> @brief Test all built-in tag constants.
		% ---------------------------------------------------------------
		function testAllTagConstants(testCase)
			tags = {'tag36_11','tag36_20','tag36_34','tag36_46','tag36_52','tag36_65'};
			for i = 1:length(tags)
				tag = aprilTagStimulus.(tags{i});
				verifyEqual(testCase, size(tag), [10 10], ...
					sprintf('%s should be 10x10', tags{i}));
				verifyTrue(testCase, all(ismember(tag(:), [0 1])), ...
					sprintf('%s should be binary', tags{i}));
				% Border should be all 1s (solid border)
				verifyTrue(testCase, all(tag(1,:) == 1), 'top border should be 1');
				verifyTrue(testCase, all(tag(end,:) == 1), 'bottom border should be 1');
				verifyTrue(testCase, all(tag(:,1) == 1), 'left border should be 1');
				verifyTrue(testCase, all(tag(:,end) == 1), 'right border should be 1');
			end
		end

		% ---------------------------------------------------------------
		%> @brief Test that tag constants are distinct.
		% ---------------------------------------------------------------
		function testTagConstantsAreDistinct(testCase)
			t1 = aprilTagStimulus.tag36_11;
			t2 = aprilTagStimulus.tag36_20;
			verifyTrue(testCase, ~isequal(t1, t2), 'different tags should differ');
		end

		% ---------------------------------------------------------------
		%> @brief Test custom properties on construction.
		% ---------------------------------------------------------------
		function testCustomProperties(testCase)
			at = aprilTagStimulus('verbose', false, 'rows', 4, 'columns', 4, ...
				'cellSize', 32, 'colour', [0.1 0.2 0.3 1], ...
				'colour2', [0.9 0.8 0.7 1], 'filter', 1, 'precision', 1, ...
				'randomisePattern', false);
			verifyEqual(testCase, at.rows, 4, 'rows should be 4');
			verifyEqual(testCase, at.columns, 4, 'columns should be 4');
			verifyEqual(testCase, at.cellSize, 32, 'cellSize should be 32');
			verifyEqual(testCase, at.colour, [0.1 0.2 0.3 1], 'colour should be set');
			verifyEqual(testCase, at.colour2, [0.9 0.8 0.7 1], 'colour2 should be set');
			verifyEqual(testCase, at.filter, 1, 'filter should be 1');
			verifyEqual(testCase, at.precision, 1, 'precision should be 1');
			verifyFalse(testCase, at.randomisePattern, 'randomisePattern should be false');
		end

		% ---------------------------------------------------------------
		%> @brief Test construction with a patternMatrix.
		% ---------------------------------------------------------------
		function testPatternMatrixConstruction(testCase)
			pm = aprilTagStimulus.tag36_11;
			at = aprilTagStimulus('verbose', false, 'patternMatrix', pm, ...
				'randomisePattern', false);
			verifyEqual(testCase, at.patternMatrix, pm, ...
				'patternMatrix should be the tag');
		end

		% ---------------------------------------------------------------
		%> @brief Test typeList contains expected values.
		% ---------------------------------------------------------------
		function testTypeList(testCase)
			at = aprilTagStimulus('verbose', false);
			verifyEqual(testCase, at.typeList, {'aprilTag'}, ...
				'typeList should be {aprilTag}');
		end

		% ---------------------------------------------------------------
		%> @brief Test show/hide methods from baseStimulus.
		% ---------------------------------------------------------------
		function testShowHide(testCase)
			at = aprilTagStimulus('verbose', false);
			verifyTrue(testCase, at.isVisible, 'should be visible by default');
			hide(at);
			verifyFalse(testCase, at.isVisible, 'should be hidden after hide()');
			show(at);
			verifyTrue(testCase, at.isVisible, 'should be visible after show()');
		end

		% ---------------------------------------------------------------
		%> @brief Test setOffTime and setDelayTime.
		% ---------------------------------------------------------------
		function testSetOffAndDelayTime(testCase)
			at = aprilTagStimulus('verbose', false);
			setOffTime(at, 3.0);
			verifyEqual(testCase, at.offTime, 3.0, 'offTime should be 3.0');
			setDelayTime(at, 0.75);
			verifyEqual(testCase, at.delayTime, 0.75, 'delayTime should be 0.75');
		end

		% ---------------------------------------------------------------
		%> @brief Test colour assignment.
		% ---------------------------------------------------------------
		function testColourSetRGB(testCase)
			at = aprilTagStimulus('verbose', false);
			at.colour = [0.5 0.5 0.5];
			verifyEqual(testCase, at.colour(1:3), [0.5 0.5 0.5], 'RGB should be set');
			verifyEqual(testCase, at.alpha, 1, 'alpha should remain 1');
		end

		% ---------------------------------------------------------------
		%> @brief Test colour2 assignment.
		% ---------------------------------------------------------------
		function testColour2Property(testCase)
			at = aprilTagStimulus('verbose', false, 'colour2', [0.8 0.2 0.2 1]);
			verifyEqual(testCase, at.colour2, [0.8 0.2 0.2 1], 'colour2 should be set');
		end

		% ---------------------------------------------------------------
		%> @brief Test alpha clamping.
		% ---------------------------------------------------------------
		function testAlphaClamping(testCase)
			at = aprilTagStimulus('verbose', false);
			at.alpha = 10;
			verifyEqual(testCase, at.alpha, 1, 'alpha should clamp to 1');
			at.alpha = -5;
			verifyEqual(testCase, at.alpha, 0, 'alpha should clamp to 0');
		end

		% ---------------------------------------------------------------
		%> @brief Test UUID from optickaCore.
		% ---------------------------------------------------------------
		function testHasUUID(testCase)
			at = aprilTagStimulus('verbose', false);
			verifyTrue(testCase, ~isempty(at.uuid), 'should have a UUID');
			verifyTrue(testCase, isstr(at.uuid), 'UUID should be a string');
		end

		% ---------------------------------------------------------------
		%> @brief Test fullName combines name and UUID.
		% ---------------------------------------------------------------
		function testFullName(testCase)
			at = aprilTagStimulus('verbose', false, 'name', 'TestTag');
			verifyTrue(testCase, contains(at.fullName, 'TestTag'), ...
				'fullName should contain the name');
			verifyTrue(testCase, contains(at.fullName, 'aprilTagStimulus'), ...
				'fullName should contain class name');
		end

		% ---------------------------------------------------------------
		%> @brief Test reset before setup is safe.
		% ---------------------------------------------------------------
		function testResetBeforeSetup(testCase)
			at = aprilTagStimulus('verbose', false);
			reset(at);
			verifyFalse(testCase, at.isSetup, 'should not be setup after reset');
		end

		% ---------------------------------------------------------------
		%> @brief Test default direction inherits from angle.
		% ---------------------------------------------------------------
		function testDirectionDefaults(testCase)
			at = aprilTagStimulus('verbose', false, 'angle', 45);
			verifyEqual(testCase, at.direction, 45, ...
				'direction should default to angle');
		end

		% ---------------------------------------------------------------
		%> @brief Test size in degrees.
		% ---------------------------------------------------------------
		function testSizeProperty(testCase)
			at = aprilTagStimulus('verbose', false, 'size', 8);
			verifyEqual(testCase, at.size, 8, 'size should be 8');
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
			at = aprilTagStimulus('verbose', false);
			at.patternMatrix = at.tag36_11;
			setup(at, sM);
			verifyTrue(testCase, at.isSetup, 'should be setup');
			verifyTrue(testCase, ~isempty(at.texture), 'texture should be created');
			verifyTrue(testCase, at.texture > 0, 'texture pointer should be positive');
			verifyTrue(testCase, ~isempty(at.matrix), 'matrix should be created');
			verifyTrue(testCase, ~isempty(at.binaryMatrix), 'binaryMatrix should be created');
			verifyEqual(testCase, at.binaryMatrix, at.patternMatrix, ...
				'patternMatrix should be set from binaryMatrix');
			reset(at);
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
			at = aprilTagStimulus('verbose', false);
			setup(at, sM);
			draw(at);
			verifyEqual(testCase, at.drawTick, 1, 'drawTick should be 1 after one draw');
			reset(at);
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
			at = aprilTagStimulus('verbose', false);
			setup(at, sM);
			animate(at);
			verifyEqual(testCase, at.tick, 0, 'tick should be 0 (draw not called)');
			reset(at);
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
			at = aprilTagStimulus('verbose', false);
			setup(at, sM);
			update(at);
			verifyTrue(testCase, true, 'update completed without error');
			reset(at);
		end

		% ---------------------------------------------------------------
		%> @brief Test the run method.
		% ---------------------------------------------------------------
		function testRunMethod(testCase)
			assumeFalse(testCase, ~isempty(getenv('GITHUB_ACTIONS')), ...
				'Skipping PTB run test in CI');
			at = aprilTagStimulus('verbose', false);
			run(at, false, 1);
			verifyTrue(testCase, true, 'run() completed without error');
		end

		% ---------------------------------------------------------------
		%> @brief Test reset after setup clears texture.
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
			at = aprilTagStimulus('verbose', false);
			setup(at, sM);
			verifyTrue(testCase, ~isempty(at.texture), 'should have texture');
			reset(at);
			verifyFalse(testCase, at.isSetup, 'isSetup should be false after reset');
			verifyTrue(testCase, isempty(at.matrix), 'matrix should be empty after reset');
			verifyTrue(testCase, isempty(at.binaryMatrix), 'binaryMatrix should be empty after reset');
		end

		% ---------------------------------------------------------------
		%> @brief Test setup with a tag constant as patternMatrix.
		% ---------------------------------------------------------------
		function testSetupWithTagConstant(testCase)
			assumeFalse(testCase, ~isempty(getenv('GITHUB_ACTIONS')), ...
				'Skipping PTB tag test in CI');
			sM = screenManager;
			sM.windowed = [0 0 800 600];
			sM.disableSyncTests = true;
			sM.visualDebug = true;
			sM.bitDepth = '8bit';
			open(sM);
			cleanup = onCleanup(@() close(sM));
			at = aprilTagStimulus('verbose', false, ...
				'patternMatrix', aprilTagStimulus.tag36_65, ...
				'randomisePattern', false);
			setup(at, sM);
			verifyTrue(testCase, at.isSetup, 'should be setup');
			verifyEqual(testCase, size(at.matrix), ...
				[10*at.cellSize, 10*at.cellSize, 4], ...
				'matrix should be cellSize * tagSize with RGBA');
			% matrix should be populated (black and white cells from the tag)
			rgbSlice = at.matrix(:,:,1:3);
			uniqueVals = unique(rgbSlice(:));
			verifyEqual(testCase, length(uniqueVals), 2, ...
				'should have exactly 2 unique RGB values (black + white)');
			reset(at);
		end

		% ---------------------------------------------------------------
		%> @brief Test setup with custom rows/columns generates matrix.
		% ---------------------------------------------------------------
		function testSetupCustomSize(testCase)
			assumeFalse(testCase, ~isempty(getenv('GITHUB_ACTIONS')), ...
				'Skipping PTB custom size test in CI');
			sM = screenManager;
			sM.windowed = [0 0 800 600];
			sM.disableSyncTests = true;
			sM.visualDebug = true;
			sM.bitDepth = '8bit';
			open(sM);
			cleanup = onCleanup(@() close(sM));
			at = aprilTagStimulus('verbose', false, 'rows', 3, 'columns', 3, 'cellSize', 16);
			setup(at, sM);
			verifyTrue(testCase, at.isSetup, 'should be setup');
			verifyEqual(testCase, size(at.matrix), [48 48 4], ...
				'matrix should be rows*cellSize x columns*cellSize x 4');
			reset(at);
		end
	end
end
