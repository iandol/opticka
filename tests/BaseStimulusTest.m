% ========================================================================
%> @class BaseStimulusTest
%> @brief Class-based unit tests for baseStimulus base class behaviours.
%>
%> Tests the shared baseStimulus methods (colour, alpha, show/hide,
%> setOffTime, setDelayTime, fullName, UUID, updatePosition, getP)
%> using a concrete subclass (discStimulus) as a proxy, since
%> baseStimulus is abstract. CI-safe tests run without PTB; hardware-
%> tagged tests exercise delta/dX/dY dependent properties that need
%> a screenManager.
%>
%> Run with:
%>   >> runtests('tests/BaseStimulusTest.m')
%>   >> runtests('tests/BaseStimulusTest.m', '-ExcludeTag', 'hardware')
%>
%> Copyright (c) 2026 Ian Max Andolina — LGPL3, see LICENCE.md
% ========================================================================
classdef BaseStimulusTest < matlab.unittest.TestCase

	methods (TestClassSetup)
		function setupPath(testCase)
			addOptickaToPath(true);
		end
	end

	% ===================================================================
	% CI-SAFE TESTS
	% ===================================================================
	methods (Test, TestTags = {'CI'})
		% --- colour set method ---
		function testColourSetSingleValue(testCase)
			d = discStimulus('verbose', false);
			d.colour = 0.5;
			verifyEqual(testCase, d.colour, [0.5 0.5 0.5 1], ...
				'single value should expand to RGB with alpha 1');
		end

		function testColourSetRGB(testCase)
			d = discStimulus('verbose', false);
			d.colour = [0.2 0.4 0.6];
			verifyEqual(testCase, d.colour(1:3), [0.2 0.4 0.6], 'RGB set');
			verifyEqual(testCase, d.alpha, 1, 'alpha preserved');
		end

		function testColourSetRGBA(testCase)
			d = discStimulus('verbose', false);
			d.colour = [0.2 0.4 0.6 0.8];
			verifyEqual(testCase, d.colour(1:3), [0.2 0.4 0.6], 'RGB set');
			verifyEqual(testCase, d.alpha, 0.8, 'alpha from RGBA');
		end

		function testColourClamping(testCase)
			d = discStimulus('verbose', false);
			d.colour = [1.5 -0.5 0.5];
			verifyEqual(testCase, d.colour(1), 1, 'R should clamp to 1');
			verifyEqual(testCase, d.colour(2), 0, 'G should clamp to 0');
			verifyEqual(testCase, d.colour(3), 0.5, 'B should stay 0.5');
		end

		% --- alpha set method ---
		function testAlphaSetUpdatesColour(testCase)
			d = discStimulus('verbose', false);
			d.colour = [0.5 0.5 0.5];
			d.alpha = 0.3;
			verifyEqual(testCase, d.alpha, 0.3, 'alpha should be 0.3');
			verifyEqual(testCase, d.colour(4), 0.3, 'colour(4) should reflect alpha');
		end

		function testAlphaClamping(testCase)
			d = discStimulus('verbose', false);
			d.alpha = 10;
			verifyEqual(testCase, d.alpha, 1, 'alpha clamps to 1');
			d.alpha = -5;
			verifyEqual(testCase, d.alpha, 0, 'alpha clamps to 0');
		end

		% --- show/hide ---
		function testShowHide(testCase)
			d = discStimulus('verbose', false);
			verifyTrue(testCase, d.isVisible, 'default visible');
			hide(d);
			verifyFalse(testCase, d.isVisible, 'hidden after hide');
			show(d);
			verifyTrue(testCase, d.isVisible, 'visible after show');
		end

		% --- setOffTime / setDelayTime ---
		function testSetOffTime(testCase)
			d = discStimulus('verbose', false);
			setOffTime(d, 5.0);
			verifyEqual(testCase, d.offTime, 5.0, 'offTime should be 5.0');
		end

		function testSetDelayTime(testCase)
			d = discStimulus('verbose', false);
			setDelayTime(d, 0.5);
			verifyEqual(testCase, d.delayTime, 0.5, 'delayTime should be 0.5');
		end

		% --- defaults from baseStimulus ---
		function testBaseDefaults(testCase)
			d = discStimulus('verbose', false);
			verifyEqual(testCase, d.xPosition, 0, 'default xPosition');
			verifyEqual(testCase, d.yPosition, 0, 'default yPosition');
			verifyEqual(testCase, d.size, 4, 'default size');
			verifyEqual(testCase, d.alpha, 1, 'default alpha');
			verifyEqual(testCase, d.angle, 0, 'default angle');
			verifyEqual(testCase, d.speed, 0, 'default speed');
			verifyEqual(testCase, d.startPosition, 0, 'default startPosition');
			verifyEqual(testCase, d.delayTime, 0, 'default delayTime');
			verifyEqual(testCase, d.offTime, Inf, 'default offTime should be Inf');
			verifyTrue(testCase, d.isVisible, 'default isVisible');
			verifyFalse(testCase, d.mouseOverride, 'default mouseOverride');
		end

		% --- fullName and UUID from optickaCore ---
		function testFullName(testCase)
			d = discStimulus('verbose', false, 'name', 'MyDisc');
			verifyTrue(testCase, contains(d.fullName, 'MyDisc'), 'fullName contains name');
			verifyTrue(testCase, contains(d.fullName, 'discStimulus'), 'fullName contains class');
		end

		function testUUID(testCase)
			d = discStimulus('verbose', false);
			verifyTrue(testCase, ~isempty(d.uuid), 'UUID not empty');
			d2 = discStimulus('verbose', false);
			verifyNotEqual(testCase, d.uuid, d2.uuid, 'UUIDs should be unique');
		end

		% --- tick / drawTick ---
		function testTickDefaults(testCase)
			d = discStimulus('verbose', false);
			verifyEqual(testCase, d.tick, 0, 'default tick');
			verifyEqual(testCase, d.drawTick, 0, 'default drawTick');
		end

		% --- isRect ---
		function testIsRect(testCase)
			d = discStimulus('verbose', false);
			% discStimulus sets isRect = true in its constructor
			verifyTrue(testCase, d.isRect, 'disc uses rect for drawing');
		end

		function testIsRectImage(testCase)
			im = imageStimulus('verbose', false);
			verifyTrue(testCase, im.isRect, 'image is rect-based');
		end

		% --- ppd default ---
		function testPpdDefault(testCase)
			d = discStimulus('verbose', false);
			verifyEqual(testCase, d.ppd, 36, 'default ppd should be 36');
		end

		% --- screenVals default ---
		function testScreenValsDefault(testCase)
			d = discStimulus('verbose', false);
			verifyEqual(testCase, d.screenVals.ifi, 1/60, 'default ifi');
			verifyEqual(testCase, d.screenVals.fps, 60, 'default fps');
		end

		% --- getP method (gets the "Out" copy or base value) ---
		function testGetPReturnsBase(testCase)
			d = discStimulus('verbose', false);
			% Before setup, getP should return the base property value
			val = d.getP('size');
			verifyEqual(testCase, val, 4, 'getP(size) should return 4 before setup');
		end

		% --- clone method ---
		function testClone(testCase)
			d = discStimulus('verbose', false, 'name', 'Original');
			d2 = d.clone;
			verifyEqual(testCase, d2.name, 'Original', 'cloned name should match');
			verifyNotEqual(testCase, d2.uuid, d.uuid, 'clone should have different UUID');
		end
	end

	% ===================================================================
	% HARDWARE TESTS
	% ===================================================================
	methods (Test, TestTags = {'hardware'})
		function testDeltaDependent(testCase)
			assumeFalse(testCase, ~isempty(getenv('GITHUB_ACTIONS')), 'Skip in CI');
			sM = screenManager; sM.windowed = [0 0 800 600];
			sM.disableSyncTests = true; sM.visualDebug = true; sM.bitDepth = '8bit';
			open(sM); cleanup = onCleanup(@() close(sM));
			g = gratingStimulus('verbose', false, 'speed', 2, 'angle', 0);
			setup(g, sM);
			% delta = speed * ppd * ifi
			expectedDelta = 2 * sM.ppd * sM.screenVals.ifi;
			verifyEqual(testCase, g.delta, expectedDelta, 'AbsTol', 1e-10, ...
				'delta should match speed*ppd*ifi');
			reset(g);
		end

		function testDXDYDependent(testCase)
			assumeFalse(testCase, ~isempty(getenv('GITHUB_ACTIONS')), 'Skip in CI');
			sM = screenManager; sM.windowed = [0 0 800 600];
			sM.disableSyncTests = true; sM.visualDebug = true; sM.bitDepth = '8bit';
			open(sM); cleanup = onCleanup(@() close(sM));
			g = gratingStimulus('verbose', false, 'speed', 10, 'direction', 0);
			setup(g, sM);
			% direction 0 means motion in +X direction
			verifyGreaterThan(testCase, abs(g.dX), 0, 'dX should be non-zero');
			verifyEqual(testCase, g.dY, 0, 'AbsTol', 1e-10, 'dY should be ~0 at angle 0');
			reset(g);
		end

		function testDXDYAt90Degrees(testCase)
			assumeFalse(testCase, ~isempty(getenv('GITHUB_ACTIONS')), 'Skip in CI');
			sM = screenManager; sM.windowed = [0 0 800 600];
			sM.disableSyncTests = true; sM.visualDebug = true; sM.bitDepth = '8bit';
			open(sM); cleanup = onCleanup(@() close(sM));
			g = gratingStimulus('verbose', false, 'speed', 10, 'direction', 90);
			setup(g, sM);
			% direction 90 means motion in +Y direction
			verifyEqual(testCase, g.dX, 0, 'AbsTol', 1e-10, 'dX should be ~0 at direction 90');
			verifyGreaterThan(testCase, abs(g.dY), 0, 'dY should be non-zero at direction 90');
			reset(g);
		end

		function testGetPAfterSetup(testCase)
			assumeFalse(testCase, ~isempty(getenv('GITHUB_ACTIONS')), 'Skip in CI');
			sM = screenManager; sM.windowed = [0 0 800 600];
			sM.disableSyncTests = true; sM.visualDebug = true; sM.bitDepth = '8bit';
			open(sM); cleanup = onCleanup(@() close(sM));
			d = discStimulus('verbose', false, 'size', 6);
			setup(d, sM);
			val = d.getP('size');
			% getP converts degrees to pixels using ppd
			verifyEqual(testCase, val, 6 * sM.ppd, 'AbsTol', 1, ...
				'getP(size) should return size in pixels (6 deg * ppd) after setup');
			reset(d);
		end

		function testResetTicks(testCase)
			assumeFalse(testCase, ~isempty(getenv('GITHUB_ACTIONS')), 'Skip in CI');
			sM = screenManager; sM.windowed = [0 0 800 600];
			sM.disableSyncTests = true; sM.visualDebug = true; sM.bitDepth = '8bit';
			open(sM); cleanup = onCleanup(@() close(sM));
			d = discStimulus('verbose', false);
			setup(d, sM);
			% tick and drawTick are SetAccess=protected, so we simulate
			% by calling draw() a few times (which increments them)
			% First verify they start at 0
			verifyEqual(testCase, d.tick, 0, 'tick should start at 0');
			verifyEqual(testCase, d.drawTick, 0, 'drawTick should start at 0');
			% Call animate+draw to increment ticks
			show(d);
			animate(d);
			draw(d);
			verifyGreaterThan(testCase, d.tick, 0, 'tick should be >0 after draw');
			verifyGreaterThan(testCase, d.drawTick, 0, 'drawTick should be >0 after draw');
			% resetTicks should zero them
			resetTicks(d);
			verifyEqual(testCase, d.tick, 0, 'tick should be 0 after resetTicks');
			verifyEqual(testCase, d.drawTick, 0, 'drawTick should be 0 after resetTicks');
			reset(d);
		end
	end
end
