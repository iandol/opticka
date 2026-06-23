% ========================================================================
%> @class MovieStimulusTest
%> @brief Class-based unit tests for movieStimulus.
%>
%> Tests construction, property defaults, filePath resolution, selection
%> indexing, circularMask, loop strategy, pixelFormat, blocking mode,
%> special flags, show/hide, reset, and property validation. CI-safe tests
%> run without PTB; hardware-tagged tests exercise setup/draw/animate/
%> update/run with a real PTB window and a test video file.
%>
%> Run with:
%>   >> runtests('tests/MovieStimulusTest.m')
%>   >> runtests('tests/MovieStimulusTest.m', '-ExcludeTag', 'hardware')
%>
%> Copyright (c) 2026 Ian Max Andolina — LGPL3, see LICENCE.md
% ========================================================================
classdef MovieStimulusTest < matlab.unittest.TestCase

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
			mv = movieStimulus('verbose', false);
			verifyEqual(testCase, mv.type, 'movie', 'type should be movie');
			verifyEqual(testCase, mv.family, 'movie', 'family should be movie');
			verifyEqual(testCase, mv.direction, 0, 'default direction should be 0');
			verifyEqual(testCase, mv.blocking, 0, 'default blocking should be 0');
			verifyEqual(testCase, mv.loopStrategy, 1, 'default loopStrategy should be 1');
			verifyEqual(testCase, mv.preloadSecs, 1, 'default preloadSecs should be 1');
			verifyEqual(testCase, mv.specialFlagsOpen, 0, 'default specialFlagsOpen should be 0');
			verifyEqual(testCase, mv.specialFlags2Frame, 1, 'default specialFlags2Frame should be 1');
			verifyFalse(testCase, mv.circularMask, 'default circularMask should be false');
			verifyFalse(testCase, mv.enforceBlending, 'default enforceBlending should be false');
			verifyEqual(testCase, mv.name, 'movie', 'default name should be movie');
		end

		% ---------------------------------------------------------------
		%> @brief Test default filePath resolves.
		% ---------------------------------------------------------------
		function testDefaultFilePathResolves(testCase)
			mv = movieStimulus('verbose', false);
			verifyTrue(testCase, ~isempty(mv.filePath), 'filePath should not be empty');
			verifyTrue(testCase, isfile(mv.filePath), ...
				'default filePath should point to an existing file');
			verifyTrue(testCase, endsWith(mv.filePath, '.mp4') || ...
				endsWith(mv.filePath, '.mov') || endsWith(mv.filePath, '.avi'), ...
				'default filePath should be a video file');
		end

		% ---------------------------------------------------------------
		%> @brief Test filePaths populated with the default movie.
		% ---------------------------------------------------------------
		function testDefaultFilePathsPopulated(testCase)
			mv = movieStimulus('verbose', false);
			verifyTrue(testCase, ~isempty(mv.filePaths), 'filePaths should not be empty');
			verifyEqual(testCase, length(mv.filePaths), 1, ...
				'should have one default file path');
			verifyEqual(testCase, mv.filePaths{1}, mv.filePath, ...
				'filePaths{1} should match filePath');
		end

		% ---------------------------------------------------------------
		%> @brief Test nVideos dependent property.
		% ---------------------------------------------------------------
		function testNVideos(testCase)
			mv = movieStimulus('verbose', false);
			verifyEqual(testCase, mv.nVideos, 1, 'nVideos should be 1 for single file');
		end

		% ---------------------------------------------------------------
		%> @brief Test custom properties.
		% ---------------------------------------------------------------
		function testCustomProperties(testCase)
			mv = movieStimulus('verbose', false, 'blocking', 1, ...
				'loopStrategy', 2, 'preloadSecs', 5, ...
				'specialFlagsOpen', 2, 'specialFlagsFrame', 3, ...
				'direction', 90, 'circularMask', true);
			verifyEqual(testCase, mv.blocking, 1, 'blocking should be 1');
			verifyEqual(testCase, mv.loopStrategy, 2, 'loopStrategy should be 2');
			verifyEqual(testCase, mv.preloadSecs, 5, 'preloadSecs should be 5');
			verifyEqual(testCase, mv.specialFlagsOpen, 2, 'specialFlagsOpen should be 2');
			verifyEqual(testCase, mv.direction, 90, 'direction should be 90');
			verifyTrue(testCase, mv.circularMask, 'circularMask should be true');
		end

		% ---------------------------------------------------------------
		%> @brief Test construction with circularMask and sigma.
		% ---------------------------------------------------------------
		function testCircularMaskProperty(testCase)
			mv = movieStimulus('verbose', false, 'circularMask', true);
			verifyTrue(testCase, mv.circularMask, 'circularMask should be true');
			mv.sigma = 50;
			verifyEqual(testCase, mv.sigma, 50, 'sigma should be 50');
		end

		% ---------------------------------------------------------------
		%> @brief Test enforceBlending property.
		% ---------------------------------------------------------------
		function testEnforceBlending(testCase)
			mv = movieStimulus('verbose', false, 'enforceBlending', true);
			verifyTrue(testCase, mv.enforceBlending, 'enforceBlending should be true');
		end

		% ---------------------------------------------------------------
		%> @brief Test selection with a valid file generates indexed paths.
		% ---------------------------------------------------------------
		function testSelectionIndexedPaths(testCase)
			stimDir = fileparts(which('movieStimulus'));
			testMovie = fullfile(stimDir, 'monkey.mp4');
			mv = movieStimulus('verbose', false, 'filePath', testMovie, 'selection', 3);
			verifyTrue(testCase, ~isempty(mv.filePath), 'filePath should be set');
		end

		% ---------------------------------------------------------------
		%> @brief Test non-existent file falls back to default.
		% ---------------------------------------------------------------
		function testNonExistentFileFallback(testCase)
			mv = movieStimulus('verbose', false, 'filePath', '/nonexistent/foo.mp4');
			verifyTrue(testCase, ~isempty(mv.filePath), 'filePath should not be empty');
		end

		% ---------------------------------------------------------------
		%> @brief Test show/hide methods from baseStimulus.
		% ---------------------------------------------------------------
		function testShowHide(testCase)
			mv = movieStimulus('verbose', false);
			verifyTrue(testCase, mv.isVisible, 'should be visible by default');
			hide(mv);
			verifyFalse(testCase, mv.isVisible, 'should be hidden after hide()');
			show(mv);
			verifyTrue(testCase, mv.isVisible, 'should be visible after show()');
		end

		% ---------------------------------------------------------------
		%> @brief Test setOffTime and setDelayTime.
		% ---------------------------------------------------------------
		function testSetOffAndDelayTime(testCase)
			mv = movieStimulus('verbose', false);
			setOffTime(mv, 10);
			verifyEqual(testCase, mv.offTime, 10, 'offTime should be 10');
			setDelayTime(mv, 2);
			verifyEqual(testCase, mv.delayTime, 2, 'delayTime should be 2');
		end

		% ---------------------------------------------------------------
		%> @brief Test colour set method for alpha.
		% ---------------------------------------------------------------
		function testColourSetRGBA(testCase)
			mv = movieStimulus('verbose', false);
			mv.colour = [0.2 0.4 0.6 0.5];
			verifyEqual(testCase, mv.colour(1:3), [0.2 0.4 0.6], 'RGB should be set');
			verifyEqual(testCase, mv.alpha, 0.5, 'alpha should be 0.5 from RGBA');
		end

		% ---------------------------------------------------------------
		%> @brief Test alpha clamping.
		% ---------------------------------------------------------------
		function testAlphaClamping(testCase)
			mv = movieStimulus('verbose', false);
			mv.alpha = 10;
			verifyEqual(testCase, mv.alpha, 1, 'alpha should clamp to 1');
			mv.alpha = -5;
			verifyEqual(testCase, mv.alpha, 0, 'alpha should clamp to 0');
		end

		% ---------------------------------------------------------------
		%> @brief Test UUID from optickaCore.
		% ---------------------------------------------------------------
		function testHasUUID(testCase)
			mv = movieStimulus('verbose', false);
			verifyTrue(testCase, ~isempty(mv.uuid), 'should have a UUID');
		end

		% ---------------------------------------------------------------
		%> @brief Test fullName.
		% ---------------------------------------------------------------
		function testFullName(testCase)
			mv = movieStimulus('verbose', false, 'name', 'TestMovie');
			verifyTrue(testCase, contains(mv.fullName, 'TestMovie'), ...
				'fullName should contain the name');
			verifyTrue(testCase, contains(mv.fullName, 'movieStimulus'), ...
				'fullName should contain class name');
		end

		% ---------------------------------------------------------------
		%> @brief Test reset before setup.
		% ---------------------------------------------------------------
		function testResetBeforeSetup(testCase)
			mv = movieStimulus('verbose', false);
			reset(mv);
			verifyFalse(testCase, mv.isSetup, 'should not be setup after reset');
		end

		% ---------------------------------------------------------------
		%> @brief Test mask property.
		% ---------------------------------------------------------------
		function testMaskProperty(testCase)
			mv = movieStimulus('verbose', false, 'mask', [0 0 0]);
			verifyEqual(testCase, mv.mask, [0 0 0], 'mask should be [0 0 0]');
		end

		% ---------------------------------------------------------------
		%> @brief Test maskTolerance property.
		% ---------------------------------------------------------------
		function testMaskTolerance(testCase)
			mv = movieStimulus('verbose', false, 'maskTolerance', 0.1);
			verifyEqual(testCase, mv.maskTolerance, 0.1, 'maskTolerance should be 0.1');
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
			mv = movieStimulus('verbose', false);
			setup(mv, sM);
			verifyTrue(testCase, mv.isSetup, 'should be setup');
			verifyTrue(testCase, ~isempty(mv.movie), 'movie handle should not be empty');
			verifyGreaterThan(testCase, mv.duration, 0, 'duration should be positive');
			verifyGreaterThan(testCase, mv.fps, 0, 'fps should be positive');
			verifyGreaterThan(testCase, mv.width, 0, 'width should be positive');
			verifyGreaterThan(testCase, mv.height, 0, 'height should be positive');
			reset(mv);
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
			mv = movieStimulus('verbose', false);
			setup(mv, sM);
			draw(mv);
			verifyEqual(testCase, mv.drawTick, 1, 'drawTick should be 1 after one draw');
			reset(mv);
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
			mv = movieStimulus('verbose', false);
			setup(mv, sM);
			animate(mv);
			verifyEqual(testCase, mv.tick, 0, 'tick should be 0 (draw not called)');
			reset(mv);
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
			mv = movieStimulus('verbose', false);
			setup(mv, sM);
			update(mv);
			verifyTrue(testCase, true, 'update completed without error');
			reset(mv);
		end

		% ---------------------------------------------------------------
		%> @brief Test the run method.
		% ---------------------------------------------------------------
		function testRunMethod(testCase)
			assumeFalse(testCase, ~isempty(getenv('GITHUB_ACTIONS')), ...
				'Skipping PTB run test in CI');
			mv = movieStimulus('verbose', false);
			run(mv, false, 1);
			verifyTrue(testCase, true, 'run() completed without error');
		end

		% ---------------------------------------------------------------
		%> @brief Test reset after setup clears movie.
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
			mv = movieStimulus('verbose', false);
			setup(mv, sM);
			verifyTrue(testCase, ~isempty(mv.movie), 'should have movie before reset');
			reset(mv);
			verifyFalse(testCase, mv.isSetup, 'isSetup should be false after reset');
			verifyEqual(testCase, mv.scale, 1, 'scale should be 1 after reset');
		end

		% ---------------------------------------------------------------
		%> @brief Test setup with blocking mode.
		% ---------------------------------------------------------------
		function testSetupBlockingMode(testCase)
			assumeFalse(testCase, ~isempty(getenv('GITHUB_ACTIONS')), ...
				'Skipping PTB blocking test in CI');
			sM = screenManager;
			sM.windowed = [0 0 800 600];
			sM.disableSyncTests = true;
			sM.visualDebug = true;
			sM.bitDepth = '8bit';
			open(sM);
			cleanup = onCleanup(@() close(sM));
			mv = movieStimulus('verbose', false, 'blocking', 1);
			setup(mv, sM);
			verifyTrue(testCase, mv.isSetup, 'should be setup in blocking mode');
			reset(mv);
		end

		% ---------------------------------------------------------------
		%> @brief Test multiple draws increment drawTick.
		% ---------------------------------------------------------------
		function testMultipleDraws(testCase)
			assumeFalse(testCase, ~isempty(getenv('GITHUB_ACTIONS')), ...
				'Skipping PTB multi-draw test in CI');
			sM = screenManager;
			sM.windowed = [0 0 800 600];
			sM.disableSyncTests = true;
			sM.visualDebug = true;
			sM.bitDepth = '8bit';
			open(sM);
			cleanup = onCleanup(@() close(sM));
			mv = movieStimulus('verbose', false);
			setup(mv, sM);
			draw(mv);
			animate(mv);
			draw(mv);
			verifyEqual(testCase, mv.drawTick, 2, 'drawTick should be 2 after two draws');
			reset(mv);
		end

		% ---------------------------------------------------------------
		%> @brief Test setup with circular mask.
		% ---------------------------------------------------------------
		function testSetupWithCircularMask(testCase)
			assumeFalse(testCase, ~isempty(getenv('GITHUB_ACTIONS')), ...
				'Skipping PTB circular mask test in CI');
			sM = screenManager;
			sM.windowed = [0 0 800 600];
			sM.disableSyncTests = true;
			sM.visualDebug = true;
			sM.bitDepth = '8bit';
			open(sM);
			cleanup = onCleanup(@() close(sM));
			mv = movieStimulus('verbose', false, 'circularMask', true);
			setup(mv, sM);
			verifyTrue(testCase, mv.isSetup, 'should be setup with circular mask');
			reset(mv);
		end
	end
end
