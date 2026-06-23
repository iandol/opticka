% ========================================================================
%> @class BarStimulusTest
%> @brief Class-based unit tests for barStimulus.
%>
%> Tests construction, property defaults, type list, bar dimensions,
%> contrast, interpMethod validation, colour handling. CI-safe tests
%> run without PTB; hardware-tagged tests exercise setup/draw/animate/
%> update/run.
%>
%> Run with:
%>   >> runtests('tests/BarStimulusTest.m')
%>   >> runtests('tests/BarStimulusTest.m', '-ExcludeTag', 'hardware')
%>
%> Copyright (c) 2026 Ian Max Andolina — LGPL3, see LICENCE.md
% ========================================================================
classdef BarStimulusTest < matlab.unittest.TestCase

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
			b = barStimulus('verbose', false);
			verifyEqual(testCase, b.type, 'solid', 'default type should be solid');
			verifyEqual(testCase, b.family, 'bar', 'family should be bar');
			verifyEqual(testCase, b.barWidth, 1, 'default barWidth should be 1');
			verifyEqual(testCase, b.barHeight, 4, 'default barHeight should be 4');
			verifyEqual(testCase, b.contrast, 1, 'default contrast should be 1');
			verifyEqual(testCase, b.sf, 1, 'default sf should be 1');
			verifyEqual(testCase, b.interpMethod, 'nearest', 'default interpMethod');
			verifyTrue(testCase, b.regenerateTexture, 'default regenerateTexture should be true');
			verifyEqual(testCase, b.scaleTexture, 1, 'default scaleTexture should be 1');
			verifyEqual(testCase, b.phaseReverseTime, 0, 'default phaseReverseTime');
		end

		function testTypeList(testCase)
			b = barStimulus('verbose', false);
			verifyEqual(testCase, b.typeList, ...
				{'solid','checkerboard','random','randomColour','randomN','randomBW'}, ...
				'typeList should match');
		end

		function testCustomProperties(testCase)
			b = barStimulus('verbose', false, 'type', 'checkerboard', ...
				'barWidth', 2, 'barHeight', 6, 'contrast', 0.5, 'sf', 2);
			verifyEqual(testCase, b.type, 'checkerboard', 'type should be checkerboard');
			verifyEqual(testCase, b.barWidth, 2, 'barWidth should be 2');
			verifyEqual(testCase, b.barHeight, 6, 'barHeight should be 6');
			verifyEqual(testCase, b.contrast, 0.5, 'contrast should be 0.5');
			verifyEqual(testCase, b.sf, 2, 'sf should be 2');
		end

		function testInterpMethodValidation(testCase)
			b = barStimulus('verbose', false, 'interpMethod', 'cubic');
			verifyEqual(testCase, b.interpMethod, 'cubic', 'interpMethod should be cubic');
		end

		function testColour2(testCase)
			b = barStimulus('verbose', false, 'colour2', [0.1 0.2 0.3 1]);
			verifyEqual(testCase, b.colour2(1:3), [0.1 0.2 0.3], 'colour2 RGB');
		end

		function testModulateColour(testCase)
			b = barStimulus('verbose', false, 'modulateColour', [0.5 0.5 0.5]);
			verifyEqual(testCase, b.modulateColour, [0.5 0.5 0.5], 'modulateColour');
		end

		function testVisibleRate(testCase)
			b = barStimulus('verbose', false, 'visibleRate', 4);
			verifyEqual(testCase, b.visibleRate, 4, 'visibleRate should be 4');
		end

		function testColourSetRGB(testCase)
			b = barStimulus('verbose', false);
			b.colour = [0.5 0.5 0.5];
			verifyEqual(testCase, b.colour(1:3), [0.5 0.5 0.5], 'RGB');
		end

		function testAlphaClamping(testCase)
			b = barStimulus('verbose', false);
			b.alpha = 5;
			verifyEqual(testCase, b.alpha, 1, 'alpha should clamp to 1');
			b.alpha = -2;
			verifyEqual(testCase, b.alpha, 0, 'alpha should clamp to 0');
		end

		function testShowHide(testCase)
			b = barStimulus('verbose', false);
			verifyTrue(testCase, b.isVisible, 'visible');
			hide(b);
			verifyFalse(testCase, b.isVisible, 'hidden');
			show(b);
			verifyTrue(testCase, b.isVisible, 'visible');
		end

		function testUUID(testCase)
			b = barStimulus('verbose', false);
			verifyTrue(testCase, ~isempty(b.uuid), 'should have UUID');
		end

		function testFullName(testCase)
			b = barStimulus('verbose', false, 'name', 'TestBar');
			verifyTrue(testCase, contains(b.fullName, 'TestBar'), 'fullName contains name');
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
			b = barStimulus('verbose', false);
			setup(b, sM);
			verifyTrue(testCase, b.isSetup, 'should be setup');
			reset(b);
		end

		function testDrawAfterSetup(testCase)
			assumeFalse(testCase, ~isempty(getenv('GITHUB_ACTIONS')), 'Skip in CI');
			sM = screenManager; sM.windowed = [0 0 800 600];
			sM.disableSyncTests = true; sM.visualDebug = true; sM.bitDepth = '8bit';
			open(sM); cleanup = onCleanup(@() close(sM));
			b = barStimulus('verbose', false);
			setup(b, sM);
			draw(b);
			verifyEqual(testCase, b.drawTick, 1, 'drawTick should be 1');
			reset(b);
		end

		function testCheckerboardSetup(testCase)
			assumeFalse(testCase, ~isempty(getenv('GITHUB_ACTIONS')), 'Skip in CI');
			sM = screenManager; sM.windowed = [0 0 800 600];
			sM.disableSyncTests = true; sM.visualDebug = true; sM.bitDepth = '8bit';
			open(sM); cleanup = onCleanup(@() close(sM));
			b = barStimulus('verbose', false, 'type', 'checkerboard');
			setup(b, sM);
			verifyTrue(testCase, b.isSetup, 'checkerboard should setup');
			draw(b);
			verifyEqual(testCase, b.drawTick, 1, 'drawTick should be 1');
			reset(b);
		end

		function testUpdateAfterSetup(testCase)
			assumeFalse(testCase, ~isempty(getenv('GITHUB_ACTIONS')), 'Skip in CI');
			sM = screenManager; sM.windowed = [0 0 800 600];
			sM.disableSyncTests = true; sM.visualDebug = true; sM.bitDepth = '8bit';
			open(sM); cleanup = onCleanup(@() close(sM));
			b = barStimulus('verbose', false);
			setup(b, sM);
			update(b);
			verifyTrue(testCase, true, 'update completed');
			reset(b);
		end

		function testRunMethod(testCase)
			assumeFalse(testCase, ~isempty(getenv('GITHUB_ACTIONS')), 'Skip in CI');
			b = barStimulus('verbose', false);
			run(b, false, 1);
			verifyTrue(testCase, true, 'run() completed');
		end

		function testResetAfterSetup(testCase)
			assumeFalse(testCase, ~isempty(getenv('GITHUB_ACTIONS')), 'Skip in CI');
			sM = screenManager; sM.windowed = [0 0 800 600];
			sM.disableSyncTests = true; sM.visualDebug = true; sM.bitDepth = '8bit';
			open(sM); cleanup = onCleanup(@() close(sM));
			b = barStimulus('verbose', false);
			setup(b, sM);
			reset(b);
			verifyFalse(testCase, b.isSetup, 'isSetup should be false after reset');
		end
	end
end
