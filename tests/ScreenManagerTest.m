% ========================================================================
%> @class ScreenManagerTest
%> @brief Class-based unit tests for screenManager.
%>
%> Tests construction, property defaults, set methods for all public
%> properties, coordinate conversion (toPixels/toDegrees), and static
%> utility methods. CI-safe tests run without PTB; hardware-tagged
%> tests exercise open/close, flip, and drawing commands via a windowed
%> PTB screen.
%>
%> Run with:
%>   >> runtests('tests/ScreenManagerTest.m')
%>   >> runtests('tests/ScreenManagerTest.m', '-ExcludeTag', 'hardware')
%>
%> Copyright (c) 2026 Ian Max Andolina — LGPL3, see LICENCE.md
% ========================================================================
classdef ScreenManagerTest < matlab.unittest.TestCase

	methods (TestClassSetup)
		function setupPath(testCase)
			addOptickaToPath;
		end
	end

	% ===================================================================
	% CI-SAFE TESTS
	% ===================================================================
	methods (Test)

		% --- construction defaults ---
		function testConstructionDefaults(testCase)
			sM = screenManager('verbose', false);
			verifyEqual(testCase, sM.pixelsPerCm, 36, 'default pixelsPerCm');
			verifyEqual(testCase, sM.distance, 57.3, 'default distance');
			verifyEqual(testCase, sM.windowed, false, 'default windowed');
			verifyEqual(testCase, sM.backgroundColour, [0.5 0.5 0.5 1.0], 'default backgroundColour');
			verifyEqual(testCase, sM.bitDepth, '8Bit', 'default bitDepth');
			verifyEqual(testCase, sM.antiAlias, 0, 'default antiAlias');
			verifyEqual(testCase, sM.blend, true, 'default blend');
			verifyEqual(testCase, sM.visualDebug, false, 'default visualDebug');
			verifyEqual(testCase, sM.debug, false, 'default debug');
			verifyEqual(testCase, sM.stereoMode, 0, 'default stereoMode');
			verifyEqual(testCase, sM.screenXOffset, 0, 'default screenXOffset');
			verifyEqual(testCase, sM.screenYOffset, 0, 'default screenYOffset');
			verifyEqual(testCase, sM.verbosityLevel, 3, 'default verbosityLevel');
			verifyEqual(testCase, sM.srcMode, 'GL_SRC_ALPHA', 'default srcMode');
			verifyEqual(testCase, sM.dstMode, 'GL_ONE_MINUS_SRC_ALPHA', 'default dstMode');
		end

		% --- isPTB / isOpen initial state ---
		function testInitialOpenState(testCase)
			sM = screenManager('verbose', false);
			verifyFalse(testCase, sM.isOpen, 'screen should not be open on construction');
		end

		% --- UUID and fullName from optickaCore ---
		function testUUID(testCase)
			sM = screenManager('verbose', false, 'name', 'MyScreen');
			verifyTrue(testCase, ~isempty(sM.uuid), 'UUID should not be empty');
			sM2 = screenManager('verbose', false);
			verifyNotEqual(testCase, sM.uuid, sM2.uuid, 'UUIDs should be unique');
		end

		function testFullName(testCase)
			sM = screenManager('verbose', false, 'name', 'TestScreen');
			verifyTrue(testCase, contains(sM.fullName, 'TestScreen'), 'fullName should contain name');
			verifyTrue(testCase, contains(sM.fullName, 'screenManager'), 'fullName should contain class');
		end

		% --- ppd calculation ---
		function testPpdCalculation(testCase)
			sM = screenManager('verbose', false);
			expectedPPD = sM.pixelsPerCm * (sM.distance / 57.3);
			verifyEqual(testCase, sM.ppd, expectedPPD, 'ppd should match formula');
		end

		function testPpdWithRetina(testCase)
			sM = screenManager('verbose', false);
			sM.useRetina = true;
			expectedPPD = (sM.pixelsPerCm * 2) * (sM.distance / 57.3);
			verifyEqual(testCase, sM.ppd, expectedPPD, 'ppd should double with retina');
		end

		function testPpdWithCustomValues(testCase)
			sM = screenManager('verbose', false, 'pixelsPerCm', 40, 'distance', 60);
			expectedPPD = 40 * (60 / 57.3);
			verifyEqual(testCase, sM.ppd, expectedPPD, 'AbsTol', 1e-10, 'ppd with custom values');
		end

		% --- backgroundColour set method ---
		function testBackgroundColourSingleValue(testCase)
			sM = screenManager('verbose', false);
			sM.backgroundColour = 0.3;
			verifyEqual(testCase, sM.backgroundColour, [0.3 0.3 0.3 1], 'single value should expand');
		end

		function testBackgroundColourRGB(testCase)
			sM = screenManager('verbose', false);
			sM.backgroundColour = [0.1 0.2 0.3];
			verifyEqual(testCase, sM.backgroundColour, [0.1 0.2 0.3 1], 'RGB should set with alpha 1');
		end

		function testBackgroundColourRGBA(testCase)
			sM = screenManager('verbose', false);
			sM.backgroundColour = [0.1 0.2 0.3 0.8];
			verifyEqual(testCase, sM.backgroundColour, [0.1 0.2 0.3 0.8], 'RGBA should be preserved');
		end

		% --- bitDepth set method ---
		function testBitDepthValid(testCase)
			sM = screenManager('verbose', false);
			sM.bitDepth = 'HDR';
			verifyEqual(testCase, sM.bitDepth, 'HDR', 'bitDepth should be HDR');
			sM.bitDepth = 'FloatingPoint32BitIfPossible';
			verifyEqual(testCase, sM.bitDepth, 'FloatingPoint32BitIfPossible', 'bitDepth 32bit');
		end

		function testBitDepthInvalidFallsback(testCase)
			sM = screenManager('verbose', false);
			try sM.bitDepth = 'InvalidMode'; catch, end
			verifyEqual(testCase, sM.bitDepth, '8Bit', ...
				'invalid bitDepth keeps default (mustBeMember validates)');
		end

		% --- windowed set method ---
		function testWindowedLogicalTrue(testCase)
			sM = screenManager('verbose', false);
			sM.windowed = true;
			verifyTrue(testCase, islogical(sM.windowed) && sM.windowed, 'logical true');
		end

		function testWindowedLogicalFalse(testCase)
			sM = screenManager('verbose', false);
			sM.windowed = false;
			verifyEqual(testCase, sM.windowed, false, 'logical false');
		end

		function testWindowedNumericWidthHeight(testCase)
			sM = screenManager('verbose', false);
			sM.windowed = [800 600];
			verifyEqual(testCase, sM.windowed, [0 0 800 600], 'numeric [w h] -> [0 0 w h]');
		end

		function testWindowedNumericRect(testCase)
			sM = screenManager('verbose', false);
			sM.windowed = [100 100 900 700];
			verifyEqual(testCase, sM.windowed, [100 100 900 700], 'numeric rect preserved');
		end

		function testWindowedNumericOne(testCase)
			sM = screenManager('verbose', false);
			sM.windowed = 1;
			verifyTrue(testCase, islogical(sM.windowed) && sM.windowed, 'value 1 -> true');
		end

		function testWindowedNumericZero(testCase)
			sM = screenManager('verbose', false);
			sM.windowed = 0;
			verifyEqual(testCase, sM.windowed, false, 'value 0 -> false');
		end

		% --- srcMode / dstMode set methods ---
		function testSrcModeValid(testCase)
			sM = screenManager('verbose', false);
			sM.srcMode = 'GL_ONE';
			verifyEqual(testCase, sM.srcMode, 'GL_ONE', 'srcMode set to GL_ONE');
		end

		function testDstModeValid(testCase)
			sM = screenManager('verbose', false);
			sM.dstMode = 'GL_ZERO';
			verifyEqual(testCase, sM.dstMode, 'GL_ZERO', 'dstMode set to GL_ZERO');
		end

		function testBlendModesInvalidKeepsPrevious(testCase)
			sM = screenManager('verbose', false);
			sM.srcMode = 'GL_ONE';
			try sM.srcMode = 'InvalidMode'; catch, end
			verifyEqual(testCase, sM.srcMode, 'GL_ONE', ...
				'invalid srcMode keeps previous (mustBeMember validates)');
			sM.dstMode = 'GL_ZERO';
			try sM.dstMode = 'InvalidMode'; catch, end
			verifyEqual(testCase, sM.dstMode, 'GL_ZERO', ...
				'invalid dstMode keeps previous (mustBeMember validates)');
		end

		% --- distance set method ---
		function testDistanceValid(testCase)
			sM = screenManager('verbose', false);
			sM.distance = 100;
			verifyEqual(testCase, sM.distance, 100, 'distance should update');
		end

		function testDistanceInvalid(testCase)
			sM = screenManager('verbose', false);
			verifyError(testCase, @() setProp(sM, 'distance', 0), ...
				'', 'distance=0 should error');
			verifyError(testCase, @() setProp(sM, 'distance', -10), ...
				'', 'negative distance should error');
		end

		% --- pixelsPerCm set method ---
		function testPixelsPerCmValid(testCase)
			sM = screenManager('verbose', false);
			sM.pixelsPerCm = 50;
			verifyEqual(testCase, sM.pixelsPerCm, 50, 'pixelsPerCm should update');
		end

function testPixelsPerCmInvalid(testCase)
			sM = screenManager('verbose', false);
			verifyError(testCase, @() setProp(sM, 'pixelsPerCm', 0), ...
				'', 'pixelsPerCm=0 should error');
			verifyError(testCase, @() setProp(sM, 'pixelsPerCm', -5), ...
				'', 'negative pixelsPerCm should error');
		end

		% --- screenXOffset / screenYOffset set methods ---
		function testScreenXOffset(testCase)
			sM = screenManager('verbose', false);
			sM.screenXOffset = 5;
			verifyEqual(testCase, sM.screenXOffset, 5, 'screenXOffset');
		end

		function testScreenYOffset(testCase)
			sM = screenManager('verbose', false);
			sM.screenYOffset = -3;
			verifyEqual(testCase, sM.screenYOffset, -3, 'screenYOffset');
		end

		% --- verbosityLevel set method ---
		function testVerbosityLevel(testCase)
			sM = screenManager('verbose', false);
			sM.verbosityLevel = 0;
			verifyEqual(testCase, sM.verbosityLevel, 0, 'verbosityLevel 0');
			sM.verbosityLevel = 10;
			verifyEqual(testCase, sM.verbosityLevel, 10, 'verbosityLevel 10');
		end

		% --- font set method ---
		function testFontSet(testCase)
			sM = screenManager('verbose', false);
			newFont = struct('TextSize', 24, 'TextColor', [1 0 0 1], ...
				'TextBackgroundColor', [0 0 0 1], 'TextRenderer', 1, ...
				'FontName', 'Courier New');
			sM.font = newFont;
			verifyEqual(testCase, sM.font.TextSize, 24, 'font TextSize updated');
			verifyEqual(testCase, sM.font.FontName, 'Courier New', 'font name updated');
		end

		% --- toPixels / toDegrees conversion ---
		function testToPixels(testCase)
			sM = screenManager('verbose', false);
			deg = 5;
			expectedPx = deg * sM.ppd + sM.xCenter;
			result = toPixels(sM, deg);
			verifyEqual(testCase, result, expectedPx, 'AbsTol', 1e-10, 'toPixels x');
		end

		function testToDegrees(testCase)
			sM = screenManager('verbose', false);
			px = 500;
			expectedDeg = (px - sM.xCenter) / sM.ppd;
			result = toDegrees(sM, px);
			verifyEqual(testCase, result, expectedDeg, 'AbsTol', 1e-10, 'toDegrees x');
		end

		function testToPixelsXY(testCase)
			sM = screenManager('verbose', false);
			in = [2 3];
			expectedX = (in(1) * sM.ppd) + sM.xCenter;
			expectedY = (in(2) * sM.ppd) + sM.yCenter;
			out = toPixels(sM, in, 'xy');
			verifyEqual(testCase, out(1), expectedX, 'AbsTol', 1e-10, 'toPixels xy x');
			verifyEqual(testCase, out(2), expectedY, 'AbsTol', 1e-10, 'toPixels xy y');
		end

		function testToDegreesXY(testCase)
			sM = screenManager('verbose', false);
			in = [sM.xCenter + 100, sM.yCenter + 200];
			expectedX = (in(1) - sM.xCenter) / sM.ppd;
			expectedY = (in(2) - sM.yCenter) / sM.ppd;
			out = toDegrees(sM, in, 'xy');
			verifyEqual(testCase, out(1), expectedX, 'AbsTol', 1e-10, 'toDegrees xy x');
			verifyEqual(testCase, out(2), expectedY, 'AbsTol', 1e-10, 'toDegrees xy y');
		end

		function testToPixelsRect(testCase)
			sM = screenManager('verbose', false);
			in = [1 2 3 4];
			out = toPixels(sM, in, 'rect');
			verifyEqual(testCase, out(1), (1*sM.ppd)+sM.xCenter, 'AbsTol', 1e-10);
			verifyEqual(testCase, out(2), (2*sM.ppd)+sM.yCenter, 'AbsTol', 1e-10);
			verifyEqual(testCase, out(3), (3*sM.ppd)+sM.xCenter, 'AbsTol', 1e-10);
			verifyEqual(testCase, out(4), (4*sM.ppd)+sM.yCenter, 'AbsTol', 1e-10);
		end

		function testToDegreesRect(testCase)
			sM = screenManager('verbose', false);
			in = [sM.xCenter+50, sM.yCenter+60, sM.xCenter+150, sM.yCenter+200];
			out = toDegrees(sM, in, 'rect');
			verifyEqual(testCase, out(1), 50/sM.ppd, 'AbsTol', 1e-10);
			verifyEqual(testCase, out(2), 60/sM.ppd, 'AbsTol', 1e-10);
			verifyEqual(testCase, out(3), 150/sM.ppd, 'AbsTol', 1e-10);
			verifyEqual(testCase, out(4), 200/sM.ppd, 'AbsTol', 1e-10);
		end

		function testPixelsDegreesRoundtrip(testCase)
			sM = screenManager('verbose', false);
			original = [2.5 -3.1];
			pixels = toPixels(sM, original, 'xy');
			deg = toDegrees(sM, pixels, 'xy');
			verifyEqual(testCase, deg, original, 'AbsTol', 1e-10, 'pixels<->degrees roundtrip');
		end

		% --- static methods ---
		function testEquidistantPoints(testCase)
			pts = screenManager.equidistantPoints(4, 10, 0, 360, [0 0]);
			verifyEqual(testCase, size(pts), [2 4], '4 points in 2xN matrix');
			% Each point should be ~10 from origin
			for i = 1:4
				dist = sqrt(pts(1,i)^2 + pts(2,i)^2);
				verifyEqual(testCase, dist, 10, 'AbsTol', 0.01, 'point distance from origin');
			end
		end

		function testEquidistantPointsZero(testCase)
			verifyError(testCase, @() screenManager.equidistantPoints(0, 10, 0, 360), ...
				'MATLAB:validators:mustBePositive', 'n=0 should error');
		end

		function testEquidistantPointsWithCenter(testCase)
			pts = screenManager.equidistantPoints(3, 5, 0, 360, [100 200]);
			for i = 1:3
				dist = sqrt((pts(1,i)-100)^2 + (pts(2,i)-200)^2);
				verifyEqual(testCase, dist, 5, 'AbsTol', 0.01, 'point distance from custom center');
			end
		end

		function testPolarToCartesianPoints(testCase)
			[x, y] = screenManager.polarToCartesianPoints(0, 0, 0, 10);
			verifyEqual(testCase, x, 10, 'AbsTol', 0.001, '0 deg -> +x');
			verifyEqual(testCase, y, 0, 'AbsTol', 0.001, '0 deg -> y=0');
		end

		function testPolarToCartesian90Deg(testCase)
			[x, y] = screenManager.polarToCartesianPoints(0, 0, 90, 10);
			verifyEqual(testCase, x, 0, 'AbsTol', 0.001, '90 deg -> x=0');
			verifyEqual(testCase, y, 10, 'AbsTol', 0.001, '90 deg -> +y');
		end

		function testPolarToCartesianScalarArrays(testCase)
			angles = [0 90 180];
			dist = 5;
			[x, y] = screenManager.polarToCartesianPoints(0, 0, angles, dist);
			verifyEqual(testCase, size(x), size(angles), 'output matches angle size');
			verifyEqual(testCase, x(2), 0, 'AbsTol', 0.001);
			verifyEqual(testCase, y(1), 0, 'AbsTol', 0.001);
		end

		function testPolarToCartesianEmpty(testCase)
			[x, y] = screenManager.polarToCartesianPoints(0, 0, [], 10);
			verifyTrue(testCase, isempty(x), 'empty angle -> empty output');
			verifyTrue(testCase, isempty(y), 'empty angle -> empty output');
		end

		function testRectToPos(testCase)
			pos = screenManager.rectToPos([100 200 300 400]);
			verifyEqual(testCase, pos.X, 200, 'center X');
			verifyEqual(testCase, pos.Y, 300, 'center Y');
			verifyEqual(testCase, pos.radius, [100 100], 'radius');
		end

		function testPosToRect(testCase)
			pos = struct('X', 200, 'Y', 300, 'radius', 50);
			rect = screenManager.posToRect(pos);
			verifyEqual(testCase, rect(3), 250, 'right = 2*radius');
			verifyEqual(testCase, rect(4), 350, 'bottom = 2*radius');
		end

		function testPosToRectInvalid(testCase)
			rect = screenManager.posToRect('notastruct');
			verifyTrue(testCase, isempty(rect), 'non-struct returns empty');
		end

		% --- constructor with custom properties ---
		function testConstructorCustomProperties(testCase)
			sM = screenManager('verbose', false, 'pixelsPerCm', 40, ...
				'distance', 80, 'windowed', [800 600], 'backgroundColour', [0 0 0 1], ...
				'bitDepth', 'FloatingPoint32BitIfPossible');
			verifyEqual(testCase, sM.pixelsPerCm, 40, 'custom pixelsPerCm');
			verifyEqual(testCase, sM.distance, 80, 'custom distance');
			verifyEqual(testCase, sM.windowed, [0 0 800 600], 'custom windowed');
			verifyEqual(testCase, sM.backgroundColour, [0 0 0 1], 'custom backgroundColour');
			verifyEqual(testCase, sM.bitDepth, 'FloatingPoint32BitIfPossible', 'custom bitDepth');
		end

		% --- screenVals defaults ---
		function testScreenValsDefaults(testCase)
			sM = screenManager('verbose', false);
			verifyEqual(testCase, sM.screenVals.ifi, 1/60, 'default ifi');
			verifyEqual(testCase, sM.screenVals.fps, 60, 'default fps');
			verifyEqual(testCase, sM.screenVals.white, 1, 'white is 1');
			verifyEqual(testCase, sM.screenVals.black, 0, 'black is 0');
		end

		% --- movieSettings defaults ---
		function testMovieSettingsDefaults(testCase)
			sM = screenManager('verbose', false);
			verifyFalse(testCase, sM.movieSettings.record, 'default record false');
			verifyEqual(testCase, sM.movieSettings.type, 1, 'default type 1');
			verifyEqual(testCase, sM.movieSettings.quality, 0.7, 'default quality');
		end

		% --- constants ---
		function testBitDepthsConstant(testCase)
			verifyTrue(testCase, ~isempty(screenManager.bitDepths), 'bitDepths not empty');
			verifyTrue(testCase, any(contains(screenManager.bitDepths, '8Bit')), 'contains 8Bit');
			verifyTrue(testCase, any(contains(screenManager.bitDepths, 'HDR')), 'contains HDR');
		end

		function testBlendModesConstant(testCase)
			verifyTrue(testCase, ~isempty(screenManager.blendModes), 'blendModes not empty');
			verifyTrue(testCase, any(contains(screenManager.blendModes, 'GL_SRC_ALPHA')), ...
				'contains GL_SRC_ALPHA');
		end

		% --- clone method ---
		function testClone(testCase)
			sM = screenManager('verbose', false, 'name', 'Original');
			sM2 = sM.clone;
			verifyEqual(testCase, sM2.name, 'Original', 'cloned name should match');
			verifyNotEqual(testCase, sM2.uuid, sM.uuid, 'clone should have different UUID');
			verifyEqual(testCase, sM2.pixelsPerCm, sM.pixelsPerCm, 'clone should copy pixelsPerCm');
			verifyEqual(testCase, sM2.distance, sM.distance, 'clone should copy distance');
		end

		% --- disableSyncTests hidden property ---
		function testDisableSyncTests(testCase)
			sM = screenManager('verbose', false);
			sM.disableSyncTests = true;
			verifyTrue(testCase, sM.disableSyncTests, 'hidden disableSyncTests');
		end

		% --- switchChannel does not error when closed ---
		function testSwitchChannelWhenClosed(testCase)
			sM = screenManager('verbose', false);
			switchChannel(sM, 0);
			verifyTrue(testCase, true, 'switchChannel on closed screen is no-op');
		end

		% --- testWindowOpen when closed ---
		function testWindowOpenWhenClosed(testCase)
			sM = screenManager('verbose', false);
			verifyFalse(testCase, checkWindowValid(sM), 'checkWindowValid false when closed');
		end

		% --- hideScreenFlash when closed ---
		function testHideScreenFlashNoOpWhenClosed(testCase)
			sM = screenManager('verbose', false);
			sM.hideFlash = true;
			hideScreenFlash(sM);
			verifyTrue(testCase, true, 'hideScreenFlash on closed screen is no-op');
		end

		% --- resetScreenGamma when closed ---
		function testResetScreenGammaNoOpWhenClosed(testCase)
			sM = screenManager('verbose', false);
			resetScreenGamma(sM);
			verifyTrue(testCase, true, 'resetScreenGamma on closed screen is no-op');
		end
	end

	% ===================================================================
	% HARDWARE TESTS (need PTB screen)
	% ===================================================================
	methods (Test, TestTags = {'hardware'})

		% --- open / close basic ---
		function testOpenAndClose(testCase)
			assumeFalse(testCase, ~isempty(getenv('GITHUB_ACTIONS')), 'Skip in CI');
			sM = screenManager; sM.windowed = [0 0 800 600];
			sM.disableSyncTests = true; sM.visualDebug = true; sM.bitDepth = '8Bit';
			sM.verbose = false;
			open(sM);
			verifyTrue(testCase, sM.isOpen, 'screen should be open');
			verifyFalse(testCase, isempty(sM.win), 'win handle should be set');
			close(sM);
			verifyFalse(testCase, sM.isOpen, 'screen should be closed');
		end

		% --- double open is no-op ---
		function testDoubleOpenIsNoOp(testCase)
			assumeFalse(testCase, ~isempty(getenv('GITHUB_ACTIONS')), 'Skip in CI');
			sM = screenManager; sM.windowed = [0 0 800 600];
			sM.disableSyncTests = true; sM.visualDebug = true; sM.bitDepth = '8Bit';
			sM.verbose = false;
			open(sM); cleanup = onCleanup(@() close(sM));
			firstWin = sM.win;
			open(sM);
			verifyEqual(testCase, sM.win, firstWin, 'second open should not change win');
		end

		% --- screenVals populated after open ---
		function testScreenValsAfterOpen(testCase)
			assumeFalse(testCase, ~isempty(getenv('GITHUB_ACTIONS')), 'Skip in CI');
			sM = screenManager; sM.windowed = [0 0 800 600];
			sM.disableSyncTests = true; sM.visualDebug = true; sM.bitDepth = '8Bit';
			sM.verbose = false;
			open(sM); cleanup = onCleanup(@() close(sM));
			verifyTrue(testCase, ~isempty(sM.screenVals.winRect), 'winRect populated');
			verifyTrue(testCase, sM.screenVals.ifi > 0, 'ifi populated');
			verifyTrue(testCase, sM.screenVals.fps > 0, 'fps populated');
			verifyTrue(testCase, ~isempty(sM.screenVals.white), 'white populated');
			verifyTrue(testCase, ~isempty(sM.screenVals.black), 'black populated');
		end

		% --- flip after open ---
		function testFlipAfterOpen(testCase)
			assumeFalse(testCase, ~isempty(getenv('GITHUB_ACTIONS')), 'Skip in CI');
			sM = screenManager; sM.windowed = [0 0 800 600];
			sM.disableSyncTests = true; sM.visualDebug = true; sM.bitDepth = '8Bit';
			sM.verbose = false;
			open(sM); cleanup = onCleanup(@() close(sM));
			vbl = flip(sM);
			verifyTrue(testCase, vbl > 0, 'flip should return positive VBL timestamp');
		end

		% --- drawBackground + flip ---
		function testDrawBackground(testCase)
			assumeFalse(testCase, ~isempty(getenv('GITHUB_ACTIONS')), 'Skip in CI');
			sM = screenManager; sM.windowed = [0 0 800 600];
			sM.disableSyncTests = true; sM.visualDebug = true; sM.bitDepth = '8Bit';
			sM.verbose = false;
			open(sM); cleanup = onCleanup(@() close(sM));
			drawBackground(sM, [0 0 0]);
			vbl = flip(sM);
			verifyTrue(testCase, vbl > 0, 'flip after drawBackground');
		end

		function testDrawBackgroundDefault(testCase)
			assumeFalse(testCase, ~isempty(getenv('GITHUB_ACTIONS')), 'Skip in CI');
			sM = screenManager; sM.windowed = [0 0 800 600];
			sM.disableSyncTests = true; sM.visualDebug = true; sM.bitDepth = '8Bit';
			sM.verbose = false;
			open(sM); cleanup = onCleanup(@() close(sM));
			drawBackground(sM);
			vbl = flip(sM);
			verifyTrue(testCase, vbl > 0, 'drawBackground without args uses default');
		end

		% --- drawSpot ---
		function testDrawSpot(testCase)
			assumeFalse(testCase, ~isempty(getenv('GITHUB_ACTIONS')), 'Skip in CI');
			sM = screenManager; sM.windowed = [0 0 800 600];
			sM.disableSyncTests = true; sM.visualDebug = true; sM.bitDepth = '8Bit';
			sM.verbose = false;
			open(sM); cleanup = onCleanup(@() close(sM));
			drawSpot(sM, 2, [1 1 1], 0, 0);
			flip(sM);
			verifyTrue(testCase, true, 'drawSpot completed');
		end

		% --- drawCross ---
		function testDrawCross(testCase)
			assumeFalse(testCase, ~isempty(getenv('GITHUB_ACTIONS')), 'Skip in CI');
			sM = screenManager; sM.windowed = [0 0 800 600];
			sM.disableSyncTests = true; sM.visualDebug = true; sM.bitDepth = '8Bit';
			sM.verbose = false;
			open(sM); cleanup = onCleanup(@() close(sM));
			drawCross(sM, 1, [1 1 1], 0, 0, 0.1, true);
			flip(sM);
			verifyTrue(testCase, true, 'drawCross completed');
		end

		% --- drawSimpleCross ---
		function testDrawSimpleCross(testCase)
			assumeFalse(testCase, ~isempty(getenv('GITHUB_ACTIONS')), 'Skip in CI');
			sM = screenManager; sM.windowed = [0 0 800 600];
			sM.disableSyncTests = true; sM.visualDebug = true; sM.bitDepth = '8Bit';
			sM.verbose = false;
			open(sM); cleanup = onCleanup(@() close(sM));
			drawSimpleCross(sM, 0.5, [1 1 1], 0, 0, 2);
			flip(sM);
			verifyTrue(testCase, true, 'drawSimpleCross completed');
		end

		% --- drawGrid ---
		function testDrawGrid(testCase)
			assumeFalse(testCase, ~isempty(getenv('GITHUB_ACTIONS')), 'Skip in CI');
			sM = screenManager; sM.windowed = [0 0 800 600];
			sM.disableSyncTests = true; sM.visualDebug = true; sM.bitDepth = '8Bit';
			sM.verbose = false;
			open(sM); cleanup = onCleanup(@() close(sM));
			drawGrid(sM);
			flip(sM);
			verifyTrue(testCase, true, 'drawGrid completed');
		end

		% --- drawText ---
		function testDrawText(testCase)
			assumeFalse(testCase, ~isempty(getenv('GITHUB_ACTIONS')), 'Skip in CI');
			sM = screenManager; sM.windowed = [0 0 800 600];
			sM.disableSyncTests = true; sM.visualDebug = true; sM.bitDepth = '8Bit';
			sM.verbose = false;
			open(sM); cleanup = onCleanup(@() close(sM));
			drawText(sM, 'Hello Opticka', 0, 0);
			flip(sM);
			verifyTrue(testCase, true, 'drawText completed');
		end

		% --- drawTextNow ---
		function testDrawTextNow(testCase)
			assumeFalse(testCase, ~isempty(getenv('GITHUB_ACTIONS')), 'Skip in CI');
			sM = screenManager; sM.windowed = [0 0 800 600];
			sM.disableSyncTests = true; sM.visualDebug = true; sM.bitDepth = '8Bit';
			sM.verbose = false;
			open(sM); cleanup = onCleanup(@() close(sM));
			flipTime = drawTextNow(sM, 'Test drawTextNow');
			verifyTrue(testCase, flipTime > 0, 'drawTextNow returns VBL');
		end

		% --- drawTextWrapped ---
		function testDrawTextWrapped(testCase)
			assumeFalse(testCase, ~isempty(getenv('GITHUB_ACTIONS')), 'Skip in CI');
			sM = screenManager; sM.windowed = [0 0 800 600];
			sM.disableSyncTests = true; sM.visualDebug = true; sM.bitDepth = '8Bit';
			sM.verbose = false;
			open(sM); cleanup = onCleanup(@() close(sM));
			drawTextWrapped(sM, 'Line1\nLine2\nLine3', 40, 0, 0);
			flip(sM);
			verifyTrue(testCase, true, 'drawTextWrapped completed');
		end

		% --- drawLines ---
		function testDrawLines(testCase)
			assumeFalse(testCase, ~isempty(getenv('GITHUB_ACTIONS')), 'Skip in CI');
			sM = screenManager; sM.windowed = [0 0 800 600];
			sM.disableSyncTests = true; sM.visualDebug = true; sM.bitDepth = '8Bit';
			sM.verbose = false;
			open(sM); cleanup = onCleanup(@() close(sM));
			xy = [0 5 0; 0 0 5];
			drawLines(sM, xy, 0.1, [1 1 0]);
			flip(sM);
			verifyTrue(testCase, true, 'drawLines completed');
		end

		% --- drawBox ---
		function testDrawBox(testCase)
			assumeFalse(testCase, ~isempty(getenv('GITHUB_ACTIONS')), 'Skip in CI');
			sM = screenManager; sM.windowed = [0 0 800 600];
			sM.disableSyncTests = true; sM.visualDebug = true; sM.bitDepth = '8Bit';
			sM.verbose = false;
			open(sM); cleanup = onCleanup(@() close(sM));
			drawBox(sM, [0; 0], 2, [1 0 0]);
			flip(sM);
			verifyTrue(testCase, true, 'drawBox completed');
		end

		% --- drawBoxPx ---
		function testDrawBoxPx(testCase)
			assumeFalse(testCase, ~isempty(getenv('GITHUB_ACTIONS')), 'Skip in CI');
			sM = screenManager; sM.windowed = [0 0 800 600];
			sM.disableSyncTests = true; sM.visualDebug = true; sM.bitDepth = '8Bit';
			sM.verbose = false;
			open(sM); cleanup = onCleanup(@() close(sM));
			drawBoxPx(sM, [400; 300], 100, [1 0 0]);
			flip(sM);
			verifyTrue(testCase, true, 'drawBoxPx completed');
		end

		% --- drawRect ---
		function testDrawRect(testCase)
			assumeFalse(testCase, ~isempty(getenv('GITHUB_ACTIONS')), 'Skip in CI');
			sM = screenManager; sM.windowed = [0 0 800 600];
			sM.disableSyncTests = true; sM.visualDebug = true; sM.bitDepth = '8Bit';
			sM.verbose = false;
			open(sM); cleanup = onCleanup(@() close(sM));
			drawRect(sM, [-1 -1 1 1], [0 1 0]);
			flip(sM);
			verifyTrue(testCase, true, 'drawRect completed');
		end

		% --- drawDots ---
		function testDrawDots(testCase)
			assumeFalse(testCase, ~isempty(getenv('GITHUB_ACTIONS')), 'Skip in CI');
			sM = screenManager; sM.windowed = [0 0 800 600];
			sM.disableSyncTests = true; sM.visualDebug = true; sM.bitDepth = '8Bit';
			sM.verbose = false;
			open(sM); cleanup = onCleanup(@() close(sM));
			xy = [0 -2 2; 0 2 -2];
			drawDots(sM, xy, 0.3, [1 1 1]);
			flip(sM);
			verifyTrue(testCase, true, 'drawDots completed');
		end

		% --- drawDotsDegs ---
		function testDrawDotsDegs(testCase)
			assumeFalse(testCase, ~isempty(getenv('GITHUB_ACTIONS')), 'Skip in CI');
			sM = screenManager; sM.windowed = [0 0 800 600];
			sM.disableSyncTests = true; sM.visualDebug = true; sM.bitDepth = '8Bit';
			sM.verbose = false;
			open(sM); cleanup = onCleanup(@() close(sM));
			xy = [0 -2 2; 0 2 -2];
			drawDotsDegs(sM, xy, 0.3, [1 1 1]);
			flip(sM);
			verifyTrue(testCase, true, 'drawDotsDegs completed');
		end

		% --- drawScreenCenter ---
		function testDrawScreenCenter(testCase)
			assumeFalse(testCase, ~isempty(getenv('GITHUB_ACTIONS')), 'Skip in CI');
			sM = screenManager; sM.windowed = [0 0 800 600];
			sM.disableSyncTests = true; sM.visualDebug = true; sM.bitDepth = '8Bit';
			sM.verbose = false;
			open(sM); cleanup = onCleanup(@() close(sM));
			drawScreenCenter(sM);
			flip(sM);
			verifyTrue(testCase, true, 'drawScreenCenter completed');
		end

		% --- drawPhotoDiodeSquare ---
		function testDrawPhotoDiodeSquare(testCase)
			assumeFalse(testCase, ~isempty(getenv('GITHUB_ACTIONS')), 'Skip in CI');
			sM = screenManager; sM.windowed = [0 0 800 600];
			sM.disableSyncTests = true; sM.visualDebug = true; sM.bitDepth = '8Bit';
			sM.verbose = false;
			open(sM); cleanup = onCleanup(@() close(sM));
			drawPhotoDiodeSquare(sM, [1 1 1]);
			flip(sM);
			verifyTrue(testCase, true, 'drawPhotoDiodeSquare completed');
		end

		% --- finishDrawing ---
		function testFinishDrawing(testCase)
			assumeFalse(testCase, ~isempty(getenv('GITHUB_ACTIONS')), 'Skip in CI');
			sM = screenManager; sM.windowed = [0 0 800 600];
			sM.disableSyncTests = true; sM.visualDebug = true; sM.bitDepth = '8Bit';
			sM.verbose = false;
			open(sM); cleanup = onCleanup(@() close(sM));
			drawBackground(sM);
			finishDrawing(sM);
			flip(sM);
			verifyTrue(testCase, true, 'finishDrawing + flip completed');
		end

		% --- mousePosition ---
		function testMousePosition(testCase)
			assumeFalse(testCase, ~isempty(getenv('GITHUB_ACTIONS')), 'Skip in CI');
			sM = screenManager; sM.windowed = [0 0 800 600];
			sM.disableSyncTests = true; sM.visualDebug = true; sM.bitDepth = '8Bit';
			sM.verbose = false;
			open(sM); cleanup = onCleanup(@() close(sM));
			[x, y] = mousePosition(sM);
			verifyTrue(testCase, ~isempty(x), 'mousePosition should return x');
			verifyTrue(testCase, ~isempty(y), 'mousePosition should return y');
		end

		% --- checkWindowValid ---
		function testCheckWindowValidAfterOpen(testCase)
			assumeFalse(testCase, ~isempty(getenv('GITHUB_ACTIONS')), 'Skip in CI');
			sM = screenManager; sM.windowed = [0 0 800 600];
			sM.disableSyncTests = true; sM.visualDebug = true; sM.bitDepth = '8Bit';
			sM.verbose = false;
			open(sM); cleanup = onCleanup(@() close(sM));
			verifyTrue(testCase, checkWindowValid(sM), 'window should be valid after open');
		end

		% --- toDegrees / toPixels roundtrip with real win ---
		function testConversionWithRealWindow(testCase)
			assumeFalse(testCase, ~isempty(getenv('GITHUB_ACTIONS')), 'Skip in CI');
			sM = screenManager; sM.windowed = [0 0 800 600];
			sM.disableSyncTests = true; sM.visualDebug = true; sM.bitDepth = '8Bit';
			sM.verbose = false;
			open(sM); cleanup = onCleanup(@() close(sM));
			original = [2.5 -3.1];
			pixels = toPixels(sM, original, 'xy');
			deg = toDegrees(sM, pixels, 'xy');
			verifyEqual(testCase, deg, original, 'AbsTol', 1e-10, 'roundtrip with real window');
		end

		% --- green / red spot ---
		function testDrawGreenSpot(testCase)
			assumeFalse(testCase, ~isempty(getenv('GITHUB_ACTIONS')), 'Skip in CI');
			sM = screenManager; sM.windowed = [0 0 800 600];
			sM.disableSyncTests = true; sM.visualDebug = true; sM.bitDepth = '8Bit';
			sM.verbose = false;
			open(sM); cleanup = onCleanup(@() close(sM));
			drawGreenSpot(sM, 1);
			flip(sM);
			verifyTrue(testCase, true, 'drawGreenSpot completed');
		end

		function testDrawRedSpot(testCase)
			assumeFalse(testCase, ~isempty(getenv('GITHUB_ACTIONS')), 'Skip in CI');
			sM = screenManager; sM.windowed = [0 0 800 600];
			sM.disableSyncTests = true; sM.visualDebug = true; sM.bitDepth = '8Bit';
			sM.verbose = false;
			open(sM); cleanup = onCleanup(@() close(sM));
			drawRedSpot(sM, 1);
			flip(sM);
			verifyTrue(testCase, true, 'drawRedSpot completed');
		end

		% --- delete method closes screen ---
		function testDeleteClosesScreen(testCase)
			assumeFalse(testCase, ~isempty(getenv('GITHUB_ACTIONS')), 'Skip in CI');
			sM = screenManager; sM.windowed = [0 0 800 600];
			sM.disableSyncTests = true; sM.visualDebug = true; sM.bitDepth = '8Bit';
			sM.verbose = false;
			open(sM);
			verifyTrue(testCase, sM.isOpen, 'screen open before delete');
			delete(sM);
			% sM is now invalid — just verify we got here without error
			verifyTrue(testCase, true, 'delete completed without error');
		end

		% --- open with non-windowed (fullscreen) debug mode ---
		function testOpenWithDebugMode(testCase)
			assumeFalse(testCase, ~isempty(getenv('GITHUB_ACTIONS')), 'Skip in CI');
			sM = screenManager; sM.windowed = [0 0 800 600];
			sM.debug = true; sM.bitDepth = '8Bit'; sM.verbose = false;
			open(sM); cleanup = onCleanup(@() close(sM));
			verifyTrue(testCase, sM.isOpen, 'screen opens in debug mode');
			verifyTrue(testCase, sM.visualDebug, 'debug=true sets visualDebug true');
		end

		% --- xCenter / yCenter computed after open ---
		function testCentersComputed(testCase)
			assumeFalse(testCase, ~isempty(getenv('GITHUB_ACTIONS')), 'Skip in CI');
			sM = screenManager; sM.windowed = [0 0 800 600];
			sM.disableSyncTests = true; sM.visualDebug = true; sM.bitDepth = '8Bit';
			sM.verbose = false;
			open(sM); cleanup = onCleanup(@() close(sM));
			verifyEqual(testCase, sM.xCenter, 400, 'xCenter should be half width');
			verifyEqual(testCase, sM.yCenter, 300, 'yCenter should be half height');
		end

		% --- font update applies when window open ---
		function testFontUpdateWhenOpen(testCase)
			assumeFalse(testCase, ~isempty(getenv('GITHUB_ACTIONS')), 'Skip in CI');
			sM = screenManager; sM.windowed = [0 0 800 600];
			sM.disableSyncTests = true; sM.visualDebug = true; sM.bitDepth = '8Bit';
			sM.verbose = false;
			open(sM); cleanup = onCleanup(@() close(sM));
			newFont = sM.font;
			newFont.TextSize = 20;
			sM.font = newFont;
			verifyEqual(testCase, sM.font.TextSize, 20, 'font TextSize updated when open');
		end

		% --- captureScreen ---
		function testCaptureScreen(testCase)
			assumeFalse(testCase, ~isempty(getenv('GITHUB_ACTIONS')), 'Skip in CI');
			sM = screenManager; sM.windowed = [0 0 800 600];
			sM.disableSyncTests = true; sM.visualDebug = true; sM.bitDepth = '8Bit';
			sM.verbose = false;
			open(sM); cleanup = onCleanup(@() close(sM));
			drawBackground(sM, [0.5 0.5 0.5]);
			flip(sM);
			tmpFile = fullfile(tempdir, 'screenManagerTestCapture.png');
			captureScreen(sM, tmpFile);
			verifyTrue(testCase, exist(tmpFile, 'file') == 2, 'captureScreen should create file');
			delete(tmpFile);
		end

		% --- timedSpot basic ---
		function testDrawTimedSpot(testCase)
			assumeFalse(testCase, ~isempty(getenv('GITHUB_ACTIONS')), 'Skip in CI');
			sM = screenManager; sM.windowed = [0 0 800 600];
			sM.disableSyncTests = true; sM.visualDebug = true; sM.bitDepth = '8Bit';
			sM.verbose = false;
			open(sM); cleanup = onCleanup(@() close(sM));
			drawTimedSpot(sM, 1, [1 1 1], 0.1, true);
			drawBackground(sM);
			drawTimedSpot(sM);
			flip(sM);
			verifyTrue(testCase, true, 'drawTimedSpot completed');
		end

		% --- switchChannel after open (no-op if not stereo) ---
		function testSwitchChannelAfterOpen(testCase)
			assumeFalse(testCase, ~isempty(getenv('GITHUB_ACTIONS')), 'Skip in CI');
			sM = screenManager; sM.windowed = [0 0 800 600];
			sM.disableSyncTests = true; sM.visualDebug = true; sM.bitDepth = '8Bit';
			sM.verbose = false;
			open(sM); cleanup = onCleanup(@() close(sM));
			switchChannel(sM, 0);
			verifyTrue(testCase, true, 'switchChannel after open');
		end

		% --- async flip basics ---
		function testAsyncFlip(testCase)
			assumeFalse(testCase, ~isempty(getenv('GITHUB_ACTIONS')), 'Skip in CI');
			sM = screenManager; sM.windowed = [0 0 800 600];
			sM.disableSyncTests = true; sM.visualDebug = true; sM.bitDepth = '8Bit';
			sM.verbose = false;
			open(sM); cleanup = onCleanup(@() close(sM));
			drawBackground(sM, [0 0 0]);
			finishDrawing(sM);
			vbl = asyncFlip(sM);
			verifyTrue(testCase, ~isempty(vbl) || vbl == 0, 'asyncFlip returned');
			% end async state
			asyncEnd(sM);
		end

		% --- asyncCheck ---
		function testAsyncCheck(testCase)
			assumeFalse(testCase, ~isempty(getenv('GITHUB_ACTIONS')), 'Skip in CI');
			sM = screenManager; sM.windowed = [0 0 800 600];
			sM.disableSyncTests = true; sM.visualDebug = true; sM.bitDepth = '8Bit';
			sM.verbose = false;
			open(sM); cleanup = onCleanup(@() close(sM));
			verifyFalse(testCase, asyncCheck(sM), 'asyncCheck false when not in async');
		end
	end
end

% ===================================================================
% Local helper functions
% ===================================================================
function setProp(obj, prop, value)
	%> Trigger a property setter for testing validation errors
	obj.(prop) = value;
end