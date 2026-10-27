% ========================================================================
%> @class LissajousPathTest
%> @brief Class-based unit tests for lissajousPath.
%>
%> Tests construction/defaults, amplitude and size handling, fps capture
%> from a screenManager-like struct, constant arc-length (uniform speed)
%> placement, closed-curve frame counts, totalTime mode, stepping/wrapping,
%> seeking, direction of travel, error handling and offline generation.
%> All tests except the hardware-tagged PTB animation test run without a
%> display or Psychtoolbox window.
%>
%> Run with:
%>   >> runtests('tests/LissajousPathTest.m')
%>   >> addpath('tests')
%>   >> runOptickaTests('LissajousPathTest', 'excludeTag', 'hardware')
%>
%> Copyright (c) 2026 Ian Max Andolina — LGPL3, see LICENCE.md
% ========================================================================
classdef LissajousPathTest < matlab.unittest.TestCase

	methods (TestClassSetup)
		function setupPath(testCase)
			addOptickaToPath;
		end
	end

	methods (Access = private)
		% ===================================================================
		%> @brief makePath creates a path and generates it offline at 60Hz
		% ===================================================================
		function p = makePath(~,varargin)
			p = lissajousPath(varargin{:},'verbose',false);
			setup(p,struct('fps',60));
		end
	end

	% ===================================================================
	% CONSTRUCTION
	% ===================================================================
	methods (Test, TestTags = {'CI'})
		function testConstructionDefaults(testCase)
			p = lissajousPath('verbose',false);
			verifyEqual(testCase,p.a,1,'default a');
			verifyEqual(testCase,p.b,2,'default b');
			verifyEqual(testCase,p.delta,pi/2,'default delta');
			verifyEqual(testCase,p.size,10,'default size');
			verifyEqual(testCase,p.speed,10,'default speed');
			verifyEqual(testCase,p.nPeriods,1,'default nPeriods');
			verifyTrue(testCase,p.flipY,'default flipY');
			verifyTrue(testCase,p.useScreenFPS,'default useScreenFPS');
			verifyFalse(testCase,p.orientStimulus,'default orientStimulus');
			verifyEmpty(testCase,p.totalTime,'default totalTime');
			verifyEmpty(testCase,p.xSize,'default xSize');
			verifyEmpty(testCase,p.fps,'default fps');
			verifyEqual(testCase,p.nFrames,0,'no frames before setup');
			verifyFalse(testCase,p.isSetup,'not setup');
			verifyEqual(testCase,p.tick,0,'tick starts at 0');
		end

		function testCustomConstruction(testCase)
			p = lissajousPath('a',3,'b',4,'delta',pi/4,'size',12, ...
				'speed',8,'xPosition',2,'yPosition',-3,'totalTime',2, ...
				'nPeriods',2,'flipY',false,'fps',90,'useScreenFPS',false, ...
				'verbose',false);
			verifyEqual(testCase,p.a,3);
			verifyEqual(testCase,p.b,4);
			verifyEqual(testCase,p.delta,pi/4);
			verifyEqual(testCase,p.size,12);
			verifyEqual(testCase,p.speed,8);
			verifyEqual(testCase,p.xPosition,2);
			verifyEqual(testCase,p.yPosition,-3);
			verifyEqual(testCase,p.totalTime,2);
			verifyEqual(testCase,p.nPeriods,2);
			verifyFalse(testCase,p.flipY);
			verifyEqual(testCase,p.fps,90);
		end

		function testAmplitudesFollowSize(testCase)
			p = lissajousPath('size',10,'verbose',false);
			verifyEqual(testCase,p.xAmplitude,5,'xAmplitude = size/2');
			verifyEqual(testCase,p.yAmplitude,5,'yAmplitude = size/2');
			p.xSize = 8;
			p.ySize = 6;
			verifyEqual(testCase,p.xAmplitude,4,'xAmplitude = xSize/2');
			verifyEqual(testCase,p.yAmplitude,3,'yAmplitude = ySize/2');
			p.xSize = [];
			verifyEqual(testCase,p.xAmplitude,5,'xAmplitude falls back to size');
		end

		function testInvalidPropertiesRejected(testCase)
			p = lissajousPath('verbose',false);
			verifyError(testCase,@() setProp(p,'a',0), ...
				'MATLAB:validators:mustBePositive','a must be positive');
			verifyError(testCase,@() setProp(p,'size',-1), ...
				'MATLAB:validators:mustBePositive','size must be positive');
			verifyError(testCase,@() setProp(p,'nPeriods',0), ...
				'MATLAB:validators:mustBePositive','nPeriods must be positive');
		end
	end

	% ===================================================================
	% SETUP / FPS
	% ===================================================================
	methods (Test, TestTags = {'CI'})
		function testSetupReadsFPSFromStruct(testCase)
			p = lissajousPath('a',1,'b',1,'delta',pi/2,'size',10, ...
				'speed',10,'verbose',false);
			setup(p,struct('fps',120,'ppd',50));
			verifyEqual(testCase,p.fps,120,'fps read from struct');
			verifyEqual(testCase,p.ifi,1/120,'ifi from fps');
			verifyEqual(testCase,p.ppd,50,'ppd read from struct');
			verifyTrue(testCase,p.isSetup,'isSetup true');
		end

		function testSetupReadsFPSFromScreenVals(testCase)
			p = lissajousPath('a',1,'b',1,'size',10,'speed',10,'verbose',false);
			setup(p,struct('screenVals',struct('fps',90,'ifi',1/90)));
			verifyEqual(testCase,p.fps,90,'fps read from screenVals');
		end

		function testSetupWithoutScreenDefaultsTo60Hz(testCase)
			p = lissajousPath('a',1,'b',1,'size',10,'speed',10,'verbose',false);
			setup(p);
			verifyEqual(testCase,p.fps,60,'fallback fps');
			verifyGreaterThan(testCase,p.nFrames,0,'path generated');
		end

		function testUseScreenFPSFalseKeepsProperty(testCase)
			p = lissajousPath('fps',144,'useScreenFPS',false, ...
				'size',10,'speed',10,'verbose',false);
			setup(p,struct('fps',60));
			verifyEqual(testCase,p.fps,144,'explicit fps preserved');
			verifyEqual(testCase,p.ifi,1/144,'ifi uses explicit fps');
		end
	end

	% ===================================================================
	% GEOMETRY
	% ===================================================================
	methods (Test, TestTags = {'CI'})
		function testOneFullCurveFrameCount(testCase)
			p = testCase.makePath('a',1,'b',1,'delta',pi/2,'size',10,'speed',10);
			verifyEqual(testCase,p.arcLength,pi*10,'RelTol',1e-4, ...
				'1:1 circle circumference = pi*size');
			%> one full curve in frames: L / (speed * ifi), rounded
			expected = round(pi*10 / (10/60));
			verifyEqual(testCase,p.nFrames,expected,'frame count for one curve');
			verifyEqual(testCase,p.duration,p.nFrames/60,'duration = frames/fps');
			verifyEqual(testCase,p.speedActual,10,'RelTol',0.01, ...
				'actual speed close to requested');
		end

		function testCircleGeometry(testCase)
			p = testCase.makePath('a',1,'b',1,'delta',pi/2,'size',10,'speed',10, ...
				'xPosition',2,'yPosition',-3);
			r = hypot(p.x-2,p.y+3);
			verifyLessThan(testCase,max(abs(r-5)),1e-3, ...
				'all frames lie on a circle of radius size/2');
			verifyEqual(testCase,min(p.x),-3,'AbsTol',0.01,'left extent');
			verifyEqual(testCase,max(p.x),7,'AbsTol',0.01,'right extent');
			verifyEqual(testCase,min(p.y),-8,'AbsTol',0.01,'top extent');
			verifyEqual(testCase,max(p.y),2,'AbsTol',0.01,'bottom extent');
		end

		function testZeroPhaseIsDiagonal(testCase)
			p = testCase.makePath('a',1,'b',1,'delta',0,'size',10,'speed',10);
			verifyLessThan(testCase,max(abs(p.y+p.x)),1e-9, ...
				'delta=0 gives the rising diagonal y = -x');
		end

		function testHalfPhaseIsCircle(testCase)
			p = testCase.makePath('a',1,'b',1,'delta',pi/2,'size',10,'speed',10);
			r = hypot(p.x,p.y);
			verifyLessThan(testCase,max(abs(r-5)),1e-3, ...
				'delta=pi/2 gives a circle');
		end

		function testEllipseWithXYSizes(testCase)
			p = testCase.makePath('a',1,'b',1,'delta',pi/2,'xSize',20,'ySize',10, ...
				'speed',10);
			verifyEqual(testCase,max(p.x),10,'AbsTol',0.01,'x semi-axis');
			verifyEqual(testCase,min(p.x),-10,'AbsTol',0.01,'x semi-axis');
			verifyEqual(testCase,max(p.y),5,'AbsTol',0.01,'y semi-axis');
			verifyEqual(testCase,min(p.y),-5,'AbsTol',0.01,'y semi-axis');
		end

		function testHighOrderFigureExtents(testCase)
			p = testCase.makePath('a',5,'b',6,'delta',pi/4,'size',10,'speed',5);
			verifyEqual(testCase,max(p.x),5,'AbsTol',0.12,'5:6 fills box in X');
			verifyEqual(testCase,max(p.y),5,'AbsTol',0.12,'5:6 fills box in Y');
			verifyEqual(testCase,min(p.x),-5,'AbsTol',0.12,'5:6 fills box in X');
			verifyEqual(testCase,min(p.y),-5,'AbsTol',0.12,'5:6 fills box in Y');
		end

		function testFlipYFalseKeepsOptickaDirection(testCase)
			p = testCase.makePath('a',1,'b',1,'delta',pi/2,'size',10,'speed',10, ...
				'flipY',false);
			%> unflipped, y = +A.sin(t) so the first frame is at (A, 0) and
			%> the path moves downwards with increasing tau
			verifyEqual(testCase,p.x(1),5,'AbsTol',1e-9,'starts at +X');
			verifyEqual(testCase,p.y(1),0,'AbsTol',1e-9,'starts at centre Y');
			verifyEqual(testCase,p.direction(1),90,'AbsTol',1, ...
				'unflipped path moves down (+Y) at the start');
		end
	end

	% ===================================================================
	% CONSTANT SPEED / ARC LENGTH
	% ===================================================================
	methods (Test, TestTags = {'CI'})
		function testUniformSpeedOnCircle(testCase)
			p = testCase.makePath('a',1,'b',1,'delta',pi/2,'size',10,'speed',12);
			d = hypot(diff([p.x p.x(1)]),diff([p.y p.y(1)]));
			expected = abs(p.speedActual) * p.ifi;
			verifyLessThan(testCase,max(abs(d-expected)),0.001*expected, ...
				'frame-to-frame distance constant including the loop wrap');
		end

		function testPositionsLieOnCurve(testCase)
			%> every frame must satisfy the analytic Lissajous equations;
			%> this checks both the geometry and the arc-length parameter
			cases = {{3,4,pi/4,12},{5,6,pi/4,10},{2,3,0,10},{1,3,pi/2,8}};
			for i = 1:numel(cases)
				c = cases{i};
				p = testCase.makePath('a',c{1},'b',c{2},'delta',c{3}, ...
					'size',c{4},'speed',10,'xPosition',1,'yPosition',-2);
				xExpected = 1 + p.xAmplitude .* sin(c{1}.*p.tau + c{3});
				yExpected = -2 - p.yAmplitude .* sin(c{2}.*p.tau);
				%> residual comes from linear interpolation of the dense
				%> arc-length table, worst case <0.001° at cusps
				verifyLessThan(testCase,max(abs(p.x-xExpected)),5e-4, ...
					sprintf('%g:%g X on curve',c{1},c{2}));
				verifyLessThan(testCase,max(abs(p.y-yExpected)),5e-4, ...
					sprintf('%g:%g Y on curve',c{1},c{2}));
			end
		end

		function testArcLengthSpacingIsUniform(testCase)
			p = testCase.makePath('a',3,'b',4,'delta',pi/4,'size',12,'speed',15);
			verifyEqual(testCase,p.dS,p.arcLength/p.nFrames,'RelTol',1e-12, ...
				'one full curve split into equal arc-length steps');
			%> constant arc-length steps; chords shorten only at cusps
			d = hypot(diff(p.x),diff(p.y));
			verifyEqual(testCase,median(d),abs(p.speedActual)*p.ifi, ...
				'RelTol',0.01,'median step matches the requested speed');
			verifyLessThan(testCase,max(abs(d-median(d))),0.05*median(d), ...
				'chords deviate only at high-curvature cusps');
		end

		function testAngularRateIsUniformOnCircle(testCase)
			p = testCase.makePath('a',1,'b',1,'delta',pi/2,'size',10,'speed',10);
			theta = unwrap(atan2(p.y,p.x));
			dTheta = diff(theta);
			verifyLessThan(testCase,max(abs(dTheta-median(dTheta))), ...
				0.01*abs(median(dTheta)),'constant angular rate on a circle');
		end
	end

	% ===================================================================
	% TOTAL TIME
	% ===================================================================
	methods (Test, TestTags = {'CI'})
		function testTotalTimeSetsFrameCount(testCase)
			p = testCase.makePath('a',3,'b',4,'delta',pi/4,'size',12,'speed',8, ...
				'totalTime',2);
			verifyEqual(testCase,p.nFrames,120,'2s at 60Hz = 120 frames');
			verifyEqual(testCase,p.duration,2,'AbsTol',1e-12,'duration = totalTime');
			verifyEqual(testCase,p.speedActual,8,'AbsTol',1e-9, ...
				'speed preserved in totalTime mode');
		end

		function testTotalTimeLongerThanCurveWraps(testCase)
			base = testCase.makePath('a',1,'b',1,'delta',pi/2,'size',10,'speed',10);
			period = base.duration;
			p = testCase.makePath('a',1,'b',1,'delta',pi/2,'size',10,'speed',10, ...
				'totalTime',period*3);
			verifyGreaterThan(testCase,p.nFrames,base.nFrames,'path repeats');
			r = hypot(p.x,p.y);
			verifyLessThan(testCase,max(abs(r-5)),1e-3, ...
				'repeated circles stay on the same radius');
			verifyEqual(testCase,min(p.x),-5,'AbsTol',0.01,'still spans the figure');
			verifyEqual(testCase,max(p.x),5,'AbsTol',0.01,'still spans the figure');
		end

		function testTotalTimeShorterThanCurve(testCase)
			base = testCase.makePath('a',1,'b',1,'delta',pi/2,'size',10,'speed',10);
			p = testCase.makePath('a',1,'b',1,'delta',pi/2,'size',10,'speed',10, ...
				'totalTime',base.duration/4);
			verifyEqual(testCase,p.nFrames,round(base.nFrames/4), ...
				'quarter curve frames');
			%> a quarter of the first period is the first quadrant only
			verifyGreaterThan(testCase,min(p.x),0,'x stays positive');
			verifyLessThan(testCase,max(p.x),5.001,'x stays within the figure');
		end
	end

	% ===================================================================
	% RUNTIME API
	% ===================================================================
	methods (Test, TestTags = {'CI'})
		function testStepAdvancesAndWraps(testCase)
			p = testCase.makePath('a',1,'b',1,'delta',pi/2,'size',10,'speed',10);
			p.rewind;
			[x1,y1] = step(p);
			verifyEqual(testCase,p.tick,1,'first step is frame 1');
			verifyEqual(testCase,[x1 y1],[p.x(1) p.y(1)],'first position');
			for i = 2:p.nFrames
				step(p);
			end
			verifyEqual(testCase,p.tick,p.nFrames,'last frame reached');
			[x2,y2] = step(p);
			verifyEqual(testCase,p.tick,1,'wraps back to frame 1');
			verifyEqual(testCase,[x2 y2],[p.x(1) p.y(1)],'wrapped position');
		end

		function testStepBeforeSetupErrors(testCase)
			p = lissajousPath('verbose',false);
			verifyError(testCase,@() step(p),'lissajousPath:notSetup', ...
				'step before setup errors');
		end

		function testZeroSpeedErrors(testCase)
			p = lissajousPath('speed',0,'verbose',false);
			verifyError(testCase,@() setup(p,struct('fps',60)), ...
				'lissajousPath:speed','zero speed errors');
		end

		function testGetPositionWraps(testCase)
			p = testCase.makePath('a',1,'b',1,'delta',pi/2,'size',10,'speed',10);
			[x1,y1] = p.getPosition(1);
			verifyEqual(testCase,[x1 y1],[p.x(1) p.y(1)],'frame 1');
			[x2,~] = p.getPosition(p.nFrames+1);
			verifyEqual(testCase,x2,p.x(1),'frame nFrames+1 wraps to 1');
			[x3,~] = p.getPosition(0);
			verifyEqual(testCase,x3,p.x(p.nFrames),'frame 0 wraps to last');
		end

		function testSeek(testCase)
			p = testCase.makePath('a',1,'b',1,'delta',pi/2,'size',10,'speed',10);
			p.seek(0);
			verifyEqual(testCase,p.tick,1,'seek(0) is frame 1');
			p.seek(p.duration/2);
			expected = mod(round(p.duration/2*p.fps),p.nFrames)+1;
			verifyEqual(testCase,p.tick,expected,'seek by time');
			p.seek(5,true);
			verifyEqual(testCase,p.tick,5,'seek by frame');
		end

		function testRewindKeepsPath(testCase)
			p = testCase.makePath('a',1,'b',1,'delta',pi/2,'size',10,'speed',10);
			n = p.nFrames;
			for i = 1:10; step(p); end
			p.rewind;
			verifyEqual(testCase,p.tick,0,'tick reset');
			verifyEqual(testCase,p.nFrames,n,'path retained');
			verifyTrue(testCase,p.isSetup,'still setup');
		end

		function testResetClearsPath(testCase)
			p = testCase.makePath('a',1,'b',1,'delta',pi/2,'size',10,'speed',10);
			p.reset;
			verifyEqual(testCase,p.nFrames,0,'no frames after reset');
			verifyFalse(testCase,p.isSetup,'isSetup false after reset');
			verifyEmpty(testCase,p.arcLength,'arc length cleared');
		end

		function testUpdateRebuilds(testCase)
			p = testCase.makePath('a',1,'b',1,'delta',pi/2,'size',10,'speed',10);
			oldLength = p.arcLength;
			p.a = 3; p.b = 4; p.speed = 20; p.size = 12;
			p.update;
			verifyEqual(testCase,p.a,3);
			verifyEqual(testCase,p.b,4);
			verifyNotEqual(testCase,p.arcLength,oldLength,'path rebuilt');
			verifyGreaterThan(testCase,p.nFrames,0,'frames generated');
			verifyEqual(testCase,p.speedActual,20,'RelTol',0.01,'new speed');
		end

		function testGetData(testCase)
			p = testCase.makePath('a',1,'b',1,'delta',pi/2,'size',10,'speed',10);
			d = p.getData;
			verifySize(testCase,d.frame,[p.nFrames 1],'one row per frame');
			verifyEqual(testCase,d.x(1),p.x(1),'x matches');
			verifyEqual(testCase,d.y(end),p.y(end),'y matches');
			verifyEqual(testCase,d.speed,p.speedActual,'speed logged');
			verifyEqual(testCase,d.a,1,'a logged');
			verifyEqual(testCase,d.delta,pi/2,'delta logged');
		end
	end

	% ===================================================================
	% HARDWARE INTEGRATION (real PTB window)
	% ===================================================================
	methods (Test, TestTags = {'hardware'})
		function testAnimateStimulusAlongPath(testCase)
			assumeFalse(testCase,isempty(getenv('DISPLAY')), ...
				'no X display available');
			s = screenManager('windowed',true,'disableSyncTests',true, ...
				'verbose',false);
			try
				open(s);
			catch ME
				assumeTrue(testCase,false, ...
					sprintf('PTB window unavailable: %s',ME.message));
			end
			testCase.addTeardown(@() close(s));

			disc = discStimulus('size',1.2,'colour',[1 0 0 1]);
			setup(disc,s);
			testCase.addTeardown(@() reset(disc));

			p = lissajousPath('a',1,'b',1,'delta',pi/2,'size',8, ...
				'speed',6,'verbose',false);
			setup(p,s);
			verifyEqual(testCase,p.fps,s.screenVals.fps,'fps from screenManager');

			for i = 1:25
				step(p,disc);
				verifyEqual(testCase,disc.xFinalD,p.x(p.tick), ...
					'RelTol',1e-9,'stimulus X follows the path');
				verifyEqual(testCase,disc.yFinalD,p.y(p.tick), ...
					'RelTol',1e-9,'stimulus Y follows the path');
			end
		end

		function testOrientStimulusToTangent(testCase)
			assumeFalse(testCase,isempty(getenv('DISPLAY')), ...
				'no X display available');
			s = screenManager('windowed',true,'disableSyncTests',true, ...
				'verbose',false);
			try
				open(s);
			catch ME
				assumeTrue(testCase,false, ...
					sprintf('PTB window unavailable: %s',ME.message));
			end
			testCase.addTeardown(@() close(s));

			g = gratingStimulus('size',4);
			setup(g,s);
			testCase.addTeardown(@() reset(g));

			p = lissajousPath('a',1,'b',1,'delta',pi/2,'size',8, ...
				'speed',6,'orientStimulus',true,'verbose',false);
			setup(p,s);
			step(p,g);
			verifyEqual(testCase,g.getP('angle'),p.direction(1), ...
				'RelTol',1e-9,'stimulus angle follows the tangent');
		end
	end
end

% ========================================================================
%> @brief setProp triggers a property setter for validation tests
% ========================================================================
function setProp(obj,prop,value)
	obj.(prop) = value;
end
