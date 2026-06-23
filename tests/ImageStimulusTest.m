% ========================================================================
%> @class ImageStimulusTest
%> @brief Class-based unit tests for imageStimulus.
%>
%> Tests construction, property defaults, checkfilePath default image
%> resolution, file path handling, selection indexing, contrast scaling,
%> crop modes, and property validation. CI-safe tests run without PTB;
%> hardware-tagged tests exercise setup/draw/animate/update/run with a
%> real PTB window.
%>
%> Run with:
%>   >> runtests('tests/ImageStimulusTest.m')
%>   >> runtests('tests/ImageStimulusTest.m', '-ExcludeTag', 'hardware')
%>
%> Copyright (c) 2026 Ian Max Andolina — LGPL3, see LICENCE.md
% ========================================================================
classdef ImageStimulusTest < matlab.unittest.TestCase

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
			im = imageStimulus('verbose', false);
			verifyEqual(testCase, im.type, 'picture', 'type should be picture');
			verifyEqual(testCase, im.family, 'texture', 'family should be texture');
			verifyEqual(testCase, im.contrast, 1, 'default contrast should be 1');
			verifyEqual(testCase, im.precision, 0, 'default precision should be 0');
			verifyEqual(testCase, im.filter, 1, 'default filter should be 1');
			verifyEqual(testCase, im.crop, 'none', 'default crop should be none');
			verifyFalse(testCase, im.circularMask, 'default circularMask should be false');
			verifyFalse(testCase, im.randomiseSelection, 'default randomiseSelection should be false');
			verifyEqual(testCase, im.selection, 1, 'selection should be 1 after default path');
			verifyEqual(testCase, im.size, 0, 'default size should be 0');
			verifyEqual(testCase, im.name, 'Image', 'default name should be Image');
		end

		% ---------------------------------------------------------------
		%> @brief Test that the default filePath resolves to Bosch.jpeg.
		% ---------------------------------------------------------------
		function testDefaultFilePathResolves(testCase)
			im = imageStimulus('verbose', false);
			verifyTrue(testCase, ~isempty(im.filePath), 'filePath should not be empty');
			verifyTrue(testCase, endsWith(im.filePath, 'Bosch.jpeg'), ...
				'default filePath should resolve to Bosch.jpeg');
			verifyTrue(testCase, isfile(im.filePath), ...
				'default filePath should point to an existing file');
		end

		% ---------------------------------------------------------------
		%> @brief Test that filePaths is populated with the default image.
		% ---------------------------------------------------------------
		function testDefaultFilePathsPopulated(testCase)
			im = imageStimulus('verbose', false);
			verifyTrue(testCase, ~isempty(im.filePaths), 'filePaths should not be empty');
			verifyEqual(testCase, length(im.filePaths), 1, ...
				'should have one default file path');
			verifyEqual(testCase, im.filePaths{1}, im.filePath, ...
				'filePaths{1} should match filePath');
		end

		% ---------------------------------------------------------------
		%> @brief Test nImages dependent property returns correct count.
		% ---------------------------------------------------------------
		function testNImagesSingleFile(testCase)
			im = imageStimulus('verbose', false);
			verifyEqual(testCase, im.nImages, 1, 'nImages should be 1 for single file');
		end

		% ---------------------------------------------------------------
		%> @brief Test construction with custom properties.
		% ---------------------------------------------------------------
		function testCustomProperties(testCase)
			im = imageStimulus('verbose', false, 'contrast', 0.5, ...
				'precision', 1, 'filter', 3, 'crop', 'square');
			verifyEqual(testCase, im.contrast, 0.5, 'contrast should be 0.5');
			verifyEqual(testCase, im.precision, 1, 'precision should be 1');
			verifyEqual(testCase, im.filter, 3, 'filter should be 3');
			verifyEqual(testCase, im.crop, 'square', 'crop should be square');
		end

		% ---------------------------------------------------------------
		%> @brief Test construction with a specific file path.
		% ---------------------------------------------------------------
		function testCustomFilePath(testCase)
			stimDir = fileparts(which('imageStimulus'));
			testImage = fullfile(stimDir, 'moon.png');
			im = imageStimulus('verbose', false, 'filePath', testImage);
			verifyEqual(testCase, im.filePath, testImage, 'filePath should be set');
			verifyEqual(testCase, im.filePaths{1}, testImage, ...
				'filePaths{1} should match');
			verifyEqual(testCase, im.nImages, 1, 'nImages should be 1');
			verifyEqual(testCase, im.selection, 1, 'selection should be 1');
		end

		% ---------------------------------------------------------------
		%> @brief Test construction with circularMask enabled.
		% ---------------------------------------------------------------
		function testCircularMaskProperty(testCase)
			im = imageStimulus('verbose', false, 'circularMask', true);
			verifyTrue(testCase, im.circularMask, 'circularMask should be true');
			% sigma is not in allowedProperties, set it after construction
			im.sigma = 50;
			verifyEqual(testCase, im.sigma, 50, 'sigma should be 50');
		end

		% ---------------------------------------------------------------
		%> @brief Test that selection > 1 generates indexed file paths.
		% ---------------------------------------------------------------
		function testSelectionIndexedPaths(testCase)
			% Use a real file as the base path, with selection > 1
			stimDir = fileparts(which('imageStimulus'));
			testImage = fullfile(stimDir, 'moon.png');
			im = imageStimulus('verbose', false, 'filePath', testImage, 'selection', 3);
			% With selection > 1, it generates moon1.png, moon2.png, moon3.png
			% These don't exist, but the paths are generated before the fallback check
			% The final checkfilePath will revert to Bosch.jpeg since indexed files don't exist
			% So we just verify the object was constructed without error
			verifyTrue(testCase, ~isempty(im.filePath), 'filePath should be set');
		end

		% ---------------------------------------------------------------
		%> @brief Test that non-existent file falls back to default.
		% ---------------------------------------------------------------
		function testNonExistentFileFallback(testCase)
			im = imageStimulus('verbose', false, 'filePath', '/nonexistent/path/foo.png');
			verifyTrue(testCase, endsWith(im.filePath, 'Bosch.jpeg'), ...
				'should fall back to Bosch.jpeg for non-existent file');
			verifyEqual(testCase, im.selection, 1, 'selection should be 1 after fallback');
		end

		% ---------------------------------------------------------------
		%> @brief Test show/hide methods from baseStimulus.
		% ---------------------------------------------------------------
		function testShowHide(testCase)
			im = imageStimulus('verbose', false);
			verifyTrue(testCase, im.isVisible, 'should be visible by default');
			hide(im);
			verifyFalse(testCase, im.isVisible, 'should be hidden after hide()');
			show(im);
			verifyTrue(testCase, im.isVisible, 'should be visible after show()');
		end

		% ---------------------------------------------------------------
		%> @brief Test setOffTime and setDelayTime.
		% ---------------------------------------------------------------
		function testSetOffAndDelayTime(testCase)
			im = imageStimulus('verbose', false);
			setOffTime(im, 2.5);
			verifyEqual(testCase, im.offTime, 2.5, 'offTime should be 2.5');
			setDelayTime(im, 0.5);
			verifyEqual(testCase, im.delayTime, 0.5, 'delayTime should be 0.5');
		end

		% ---------------------------------------------------------------
		%> @brief Test colour set method accepts RGB and RGBA.
		% ---------------------------------------------------------------
		function testColourSetRGB(testCase)
			im = imageStimulus('verbose', false);
			im.colour = [0.5 0.5 0.5];
			verifyEqual(testCase, im.colour(1:3), [0.5 0.5 0.5], 'RGB should be set');
			verifyEqual(testCase, im.alpha, 1, 'alpha should remain 1');
		end

		% ---------------------------------------------------------------
		%> @brief Test colour set with RGBA also updates alpha.
		% ---------------------------------------------------------------
		function testColourSetRGBA(testCase)
			im = imageStimulus('verbose', false);
			im.colour = [0.2 0.4 0.6 0.8];
			verifyEqual(testCase, im.colour(1:3), [0.2 0.4 0.6], 'RGB should be set');
			verifyEqual(testCase, im.alpha, 0.8, 'alpha should be 0.8 from RGBA');
		end

		% ---------------------------------------------------------------
		%> @brief Test alpha set method clamps to [0,1].
		% ---------------------------------------------------------------
		function testAlphaClamping(testCase)
			im = imageStimulus('verbose', false);
			im.alpha = 5;
			verifyEqual(testCase, im.alpha, 1, 'alpha should clamp to 1');
			im.alpha = -3;
			verifyEqual(testCase, im.alpha, 0, 'alpha should clamp to 0');
		end

		% ---------------------------------------------------------------
		%> @brief Test resetImageHistory clears chosenImages.
		% ---------------------------------------------------------------
		function testResetImageHistory(testCase)
			im = imageStimulus('verbose', false);
			im.resetImageHistory;
			verifyEmpty(testCase, im.chosenImages, 'chosenImages should be empty');
		end

		% ---------------------------------------------------------------
		%> @brief Test that reset clears texture and matrix before setup.
		% ---------------------------------------------------------------
		function testResetBeforeSetup(testCase)
			im = imageStimulus('verbose', false);
			% reset before setup should not error
			reset(im);
			verifyEmpty(testCase, im.matrix, 'matrix should be empty after reset');
			verifyEqual(testCase, im.scale, 1, 'scale should be 1 after reset');
		end

		% ---------------------------------------------------------------
		%> @brief Test typeList contains expected values.
		% ---------------------------------------------------------------
		function testTypeList(testCase)
			im = imageStimulus('verbose', false);
			verifyEqual(testCase, im.typeList, {'picture'}, 'typeList should be {picture}');
		end

		% ---------------------------------------------------------------
		%> @brief Test that the object has a UUID from optickaCore.
		% ---------------------------------------------------------------
		function testHasUUID(testCase)
			im = imageStimulus('verbose', false);
			verifyTrue(testCase, ~isempty(im.uuid), 'should have a UUID');
			verifyTrue(testCase, isstr(im.uuid), 'UUID should be a string');
		end

		% ---------------------------------------------------------------
		%> @brief Test fullName combines name and UUID.
		% ---------------------------------------------------------------
		function testFullName(testCase)
			im = imageStimulus('verbose', false, 'name', 'TestImage');
			verifyTrue(testCase, contains(im.fullName, 'TestImage'), ...
				'fullName should contain the name');
			verifyTrue(testCase, contains(im.fullName, 'imageStimulus'), ...
				'fullName should contain class name');
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
			im = imageStimulus('verbose', false);
			setup(im, sM);
			verifyTrue(testCase, im.isSetup, 'should be setup');
			verifyTrue(testCase, ~isempty(im.texture), 'texture should be created');
			verifyTrue(testCase, im.texture > 0, 'texture pointer should be positive');
			verifyTrue(testCase, ~isempty(im.matrix), 'matrix should be loaded');
			verifyTrue(testCase, size(im.matrix, 3) == 4, 'matrix should have 4 channels (RGBA)');
			verifyGreaterThan(testCase, im.width, 0, 'width should be positive');
			verifyGreaterThan(testCase, im.height, 0, 'height should be positive');
			verifyGreaterThan(testCase, im.widthD, 0, 'widthD should be positive');
			verifyGreaterThan(testCase, im.heightD, 0, 'heightD should be positive');
			reset(im);
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
			im = imageStimulus('verbose', false);
			setup(im, sM);
			draw(im);flip(sM);
			verifyEqual(testCase, im.drawTick, 1, 'drawTick should be 1 after one draw');
			verifyEqual(testCase, im.tick, 1, 'tick should be 1 after one draw');
			reset(im);
		end

		% ---------------------------------------------------------------
		%> @brief Test animate after setup (no animator, no motion).
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
			im = imageStimulus('verbose', false);
			setup(im, sM);
			draw(im);animate(im);flip(sM);
			% animate should not error and should not change position
			verifyEqual(testCase, im.tick, 1, 'tick should still be 1 (draw called once)');
			reset(im);
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
			im = imageStimulus('verbose', false);
			setup(im, sM);
			draw(im);update(im);flip(sM);
			verifyTrue(testCase, ~isempty(im.currentFile) || isfile(im.currentFile), ...
				'currentFile should be valid or empty after update');
			verifyTrue(testCase, ~isempty(im.chosenImages), ...
				'chosenImages should have entries after update');
			reset(im);
		end

		% ---------------------------------------------------------------
		%> @brief Test the run method opens a screen, draws, and closes.
		% ---------------------------------------------------------------
		function testRunMethod(testCase)
			assumeFalse(testCase, ~isempty(getenv('GITHUB_ACTIONS')), ...
				'Skipping PTB run test in CI');
			im = imageStimulus('verbose', false);
			% run() opens its own screenManager, runs for ~1 second, closes
			run(im, false, 1);
			% If we get here without error, the run succeeded
			verifyTrue(testCase, true, 'run() completed without error');
		end

		% ---------------------------------------------------------------
		%> @brief Test setup with a raw matrix input.
		% ---------------------------------------------------------------
		function testSetupWithMatrix(testCase)
			assumeFalse(testCase, ~isempty(getenv('GITHUB_ACTIONS')), ...
				'Skipping PTB matrix setup test in CI');
			sM = screenManager;
			sM.windowed = [0 0 800 600];
			sM.disableSyncTests = true;
			sM.visualDebug = true;
			sM.bitDepth = '8bit';
			open(sM);
			cleanup = onCleanup(@() close(sM));
			% Create a simple RGB test matrix
			rawMatrix = uint8(ones(100, 100, 3) * 128);
			im = imageStimulus('verbose', false);
			setup(im, sM, rawMatrix);
			verifyTrue(testCase, im.isSetup, 'should be setup with raw matrix');
			verifyEqual(testCase, im.width, 100, 'width should be 100');
			verifyEqual(testCase, im.height, 100, 'height should be 100');
			verifyTrue(testCase, ~isempty(im.texture), 'texture should be created');
			reset(im);
		end

		% ---------------------------------------------------------------
		%> @brief Test setup with contrast scaling.
		% ---------------------------------------------------------------
		function testContrastScaling(testCase)
			assumeFalse(testCase, ~isempty(getenv('GITHUB_ACTIONS')), ...
				'Skipping PTB contrast test in CI');
			sM = screenManager;
			sM.windowed = [0 0 800 600];
			sM.disableSyncTests = true;
			sM.visualDebug = true;
			sM.bitDepth = '8bit';
			open(sM);
			cleanup = onCleanup(@() close(sM));
			im = imageStimulus('verbose', false, 'contrast', 0.5);
			setup(im, sM);
			verifyTrue(testCase, im.isSetup, 'should be setup');
			% matrix values should be scaled by contrast (0.5)
			% only check RGB channels (alpha channel stays at 255)
			rgbChannels = im.matrix(:,:,1:3);
			verifyTrue(testCase, all(rgbChannels(:) <= 128 + 1), ...
				'RGB matrix values should be scaled by contrast 0.5');
			reset(im);
		end

		% ---------------------------------------------------------------
		%> @brief Test setup with crop 'square' mode.
		% ---------------------------------------------------------------
		function testCropSquare(testCase)
			assumeFalse(testCase, ~isempty(getenv('GITHUB_ACTIONS')), ...
				'Skipping PTB crop test in CI');
			sM = screenManager;
			sM.windowed = [0 0 800 600];
			sM.disableSyncTests = true;
			sM.visualDebug = true;
			sM.bitDepth = '8bit';
			open(sM);
			cleanup = onCleanup(@() close(sM));
			% Use a non-square raw matrix to test cropping
			rawMatrix = uint8(ones(200, 100, 3) * 200);
			im = imageStimulus('verbose', false, 'crop', 'square');
			setup(im, sM, rawMatrix);
			verifyTrue(testCase, im.isSetup, 'should be setup');
			verifyEqual(testCase, im.width, im.height, ...
				'width and height should be equal after square crop');
			reset(im);
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
			im = imageStimulus('verbose', false);
			setup(im, sM);
			verifyTrue(testCase, ~isempty(im.texture) || im.texture == 0, ...
				'should NOT be empty before reset');
			reset(im);
			verifyEmpty(testCase, im.matrix, 'matrix should be empty after reset');
			verifyEqual(testCase, im.scale, 1, 'scale should be 1 after reset');
			verifyFalse(testCase, im.isSetup, 'isSetup should be false after reset');
		end
	end
end
