% ========================================================================
%> @class AnimationManagerTest
%> @brief Class-based unit tests for animationManager.
%>
%> Tests construction, property defaults, body management (addBody,
%> getBody), nBodies/nObstacles dependent properties, massType
%> initialization, and boundsCheck. CI-safe tests run without PTB;
%> hardware-tagged tests exercise setup/step with a real PTB window
%> and a stimulus object.
%>
%> Note: animationManager requires the dyn4j Java library (bundled in
%> stimuli/lib/dyn4j-6.0.0.jar). The constructor calls javaaddpath (only
%> when the jar is not already on the class path), so Java must be
%> available. CI-safe tests will be skipped (assumed) if Java is not
%> available.
%>
%> Run with:
%>   >> runtests('tests/AnimationManagerTest.m')
%>   >> addpath('tests')
%>   >> runOptickaTests('AnimationManagerTest', 'excludeTag', 'hardware')
%>
%> Copyright (c) 2026 Ian Max Andolina — LGPL3, see LICENCE.md
% ========================================================================
classdef AnimationManagerTest < matlab.unittest.TestCase

	methods (TestClassSetup)
		function setupPath(testCase)
			addOptickaToPath;
		end
	end

	% ===================================================================
	% Helper: try to construct an animationManager, assume-skip on Java
	% failure.
	% ===================================================================
	methods (Access = private)
		function am = makeAM(testCase, varargin)
			try
				am = animationManager(varargin{:}, 'verbose', false);
			catch ME
				assumeTrue(testCase, false, ...
					sprintf('Java/dyn4j not available: %s', ME.message));
			end
		end

		% ===================================================================
		%> @brief makeLissajous a 1:1 circle path animation, setup at 60Hz
		% ===================================================================
		function am = makeLissajous(testCase, varargin)
			am = makeAM(testCase, 'type', 'lissajous', varargin{:});
			am.lissajous.a = 1;
			am.lissajous.b = 1;
			am.lissajous.delta = pi/2;
			am.lissajous.size = 10;
			am.lissajous.speed = 10;
			setup(am, struct('fps', 60, 'ppd', 40));
		end

		% ===================================================================
		%> @brief makeStubScreen construct (do not open) a screenManager
		% ===================================================================
		function sM = makeStubScreen(testCase)
			try
				sM = screenManager('verbose', false);
			catch ME
				assumeTrue(testCase, false, ...
					sprintf('screenManager unavailable: %s', ME.message));
			end
		end

		% ===================================================================
		%> @brief makeRigidWorld a world with one 2 degree ball at the origin
		%>
		%> No PTB window is needed: step(am, 1, false) advances the physics
		%> without touching the stimuli, so the engine itself can be tested
		%> in CI.
		% ===================================================================
		function [am, ball] = makeRigidWorld(testCase, gravity)
			if ~exist('gravity', 'var') || isempty(gravity)
				gravity = [0 0];
			end
			am = makeAM(testCase, 'timeDelta', 1/60);
			am.rigidParams.gravity = gravity;
			ball = discStimulus('verbose', false, 'name', 'ball', 'size', 72);
			ball.xPosition = 0;
			ball.yPosition = 0;
			addBody(am, ball, 'Circle', 'normal', 1, 0.2, 0.5);
			setup(am, struct('fps', 60, 'ppd', 36));
		end

		% ===================================================================
		%> @brief makeStubImage imageStimulus primed for animate() without
		%> opening a window (no texture, runtime properties added manually)
		% ===================================================================
		function img = makeStubImage(~, sM, am)
			img = imageStimulus('filePath', 'moon.png', 'size', 2, ...
				'verbose', false);
			setP(img, 'ppd', sM.ppd);
			setP(img, 'sM', sM);
			setP(img, 'isSetup', true);
			img.addprop('angleOut');
			p = img.addprop('xPositionOut');
			p.SetMethod = @setXOutPixels;
			p = img.addprop('yPositionOut');
			p.SetMethod = @setYOutPixels;
			img.addprop('doAnimator');
			img.doAnimator = true;
			img.animator = am;
		end
	end

	% ===================================================================
	% CI-SAFE TESTS
	% ===================================================================
	methods (Test, TestTags = {'CI'})
		function testConstructionDefaults(testCase)
			am = makeAM(testCase);
			verifyEqual(testCase, am.type, 'rigid', 'default type should be rigid');
			verifyEqual(testCase, am.boundsCheck, 'bounce', 'default boundsCheck');
			verifyEqual(testCase, am.timeToEnd, 10, 'default timeToEnd should be 10');
			verifyEmpty(testCase, am.bodies, 'default bodies should be empty');
			verifyEqual(testCase, am.nBodies, 0, 'nBodies should be 0');
			verifyEqual(testCase, am.tick, 0, 'default tick should be 0');
			verifyEqual(testCase, am.timeStep, 0, 'default timeStep should be 0');
			verifyEqual(testCase, am.angle, 0, 'default angle should be 0');
			verifyEmpty(testCase, am.x, 'default x should be empty');
			verifyEmpty(testCase, am.y, 'default y should be empty');
		end

		function testRigidParams(testCase)
			am = makeAM(testCase);
			verifyEqual(testCase, am.rigidParams.gravity, [0 -9.8], 'gravity');
			verifyEqual(testCase, am.rigidParams.linearDamping, 0.05, 'linearDamping');
			verifyEqual(testCase, am.rigidParams.angularDamping, 0.075, 'angularDamping');
			verifyFalse(testCase, am.rigidParams.screenBounds, 'screenBounds should be false');
		end

		function testCustomType(testCase)
			am = makeAM(testCase, 'type', 'linear');
			verifyEqual(testCase, am.type, 'linear', 'type should be linear');
		end

		function testCustomBoundsCheck(testCase)
			am = makeAM(testCase, 'boundsCheck', 'wrap');
			verifyEqual(testCase, am.boundsCheck, 'wrap', 'boundsCheck should be wrap');
		end

		function testCustomTimeToEnd(testCase)
			am = makeAM(testCase, 'timeToEnd', 5);
			verifyEqual(testCase, am.timeToEnd, 5, 'timeToEnd should be 5');
		end

		function testCustomTimeDelta(testCase)
			am = makeAM(testCase, 'timeDelta', 0.016);
			verifyEqual(testCase, am.timeDelta, 0.016, 'timeDelta should be 0.016');
		end

		function testMassTypeInitialized(testCase)
			am = makeAM(testCase);
			verifyTrue(testCase, ~isempty(am.massType.NORMAL), 'NORMAL massType should be set');
			verifyTrue(testCase, ~isempty(am.massType.INFINITE), 'INFINITE massType should be set');
			verifyTrue(testCase, ~isempty(am.massType.FIXED_ANGULAR_VELOCITY), ...
				'FIXED_ANGULAR_VELOCITY should be set');
			verifyTrue(testCase, ~isempty(am.massType.FIXED_LINEAR_VELOCITY), ...
				'FIXED_LINEAR_VELOCITY should be set');
		end

		%> @brief a second animationManager must not re-add the dyn4j jar;
		%> doing so made MATLAB try to `clear java` and warn while the
		%> first manager's MassType objects were alive.
		function testRepeatedConstructionWarningFree(testCase)
			first = makeAM(testCase);
			verifyTrue(testCase, ~isempty(first.massType.NORMAL), 'first NORMAL set');
			second = testCase.verifyWarningFree(@() makeAM(testCase));
			verifyTrue(testCase, ~isempty(second.massType.NORMAL), 'second NORMAL set');
		end

		function testAddBody(testCase)
			am = makeAM(testCase);
			d = discStimulus('verbose', false, 'size', 4, 'name', 'testDisc');
			body = addBody(am, d);
			verifyEqual(testCase, am.nBodies, 1, 'nBodies should be 1');
			verifyEqual(testCase, body.name, 'testDisc', 'body name should match');
			verifyEqual(testCase, body.shape, 'Circle', 'default shape should be Circle');
			verifyEqual(testCase, body.type, 'normal', 'default type should be normal');
			verifyEqual(testCase, body.density, 1, 'default density should be 1');
			verifyEqual(testCase, body.friction, 0.2, 'default friction should be 0.2');
			verifyEqual(testCase, body.elasticity, 0.75, 'default elasticity should be 0.75');
		end

		function testAddBodyRectangle(testCase)
			am = makeAM(testCase);
			b = barStimulus('verbose', false, 'barWidth', 2, 'barHeight', 6, 'name', 'bar');
			body = addBody(am, b, 'Rectangle');
			verifyEqual(testCase, body.shape, 'Rectangle', 'shape should be Rectangle');
			verifyEqual(testCase, am.nBodies, 1, 'nBodies should be 1');
		end

		function testAddMultipleBodies(testCase)
			am = makeAM(testCase);
			d1 = discStimulus('verbose', false, 'name', 'd1');
			d2 = discStimulus('verbose', false, 'name', 'd2');
			d3 = discStimulus('verbose', false, 'name', 'd3');
			addBody(am, d1);
			addBody(am, d2);
			addBody(am, d3);
			verifyEqual(testCase, am.nBodies, 3, 'nBodies should be 3');
		end

		function testGetBodyByName(testCase)
			am = makeAM(testCase);
			d1 = discStimulus('verbose', false, 'name', 'alpha');
			d2 = discStimulus('verbose', false, 'name', 'beta');
			addBody(am, d1);
			addBody(am, d2);
			[body, ~, idx] = getBody(am, 'beta');
			verifyTrue(testCase, ~isempty(body), 'should find body "beta"');
			verifyEqual(testCase, idx, 2, 'beta should be at index 2');
		end

		function testGetBodyByIndex(testCase)
			am = makeAM(testCase);
			d1 = discStimulus('verbose', false, 'name', 'first');
			d2 = discStimulus('verbose', false, 'name', 'second');
			addBody(am, d1);
			addBody(am, d2);
			body = getBody(am, 1, 'struct');
			verifyEqual(testCase, body.name, 'first', 'body 1 name should be "first"');
			body = getBody(am, 1, 'native');
			verifyEqual(testCase, class(body), 'org.dyn4j.dynamics.Body', 'body 1 native should be "dyn4j" object');
			body = getBody(am, 1);
			verifyEqual(testCase, class(body), 'org.dyn4j.dynamics.Body', 'body 1 default should be "dyn4j" object');
		end

		function testGetBodyNotFound(testCase)
			am = makeAM(testCase);
			d1 = discStimulus('verbose', false, 'name', 'real');
			addBody(am, d1);
			body = getBody(am, 'nonexistent');
			verifyEmpty(testCase, body, 'should return empty for non-existent body');
		end

		function testAddBodyBulletType(testCase)
			am = makeAM(testCase);
			d = discStimulus('verbose', false, 'name', 'bullet');
			body = addBody(am, d, 'Circle', 'bullet');
			verifyEqual(testCase, body.type, 'normal', 'bullet type should map to normal');
			verifyTrue(testCase, body.isBullet, 'isBullet should be true');
		end

		function testUUID(testCase)
			am = makeAM(testCase);
			verifyTrue(testCase, ~isempty(am.uuid), 'should have UUID');
		end

		function testFullName(testCase)
			am = makeAM(testCase, 'name', 'MyAnim');
			verifyTrue(testCase, contains(am.fullName, 'MyAnim'), 'fullName contains name');
			verifyTrue(testCase, contains(am.fullName, 'animationManager'), 'fullName contains class');
		end

		function testPpdDefault(testCase)
			am = makeAM(testCase);
			verifyEqual(testCase, am.ppd, 36, 'default ppd should be 36');
		end
	end

	% ===================================================================
	% LISSAJOUS PATH ANIMATION
	% ===================================================================
	methods (Test, TestTags = {'CI'})
		function testLissajousTypeDefaults(testCase)
			am = makeAM(testCase, 'type', 'lissajous');
			verifyEqual(testCase, am.type, 'lissajous', 'type should be lissajous');
			verifyTrue(testCase, isa(am.lissajous, 'lissajousPath'), ...
				'a lissajousPath object should be created');
			verifyFalse(testCase, am.orientToPath, 'orientation off by default');
			verifyEmpty(testCase, am.x, 'x empty before setup');
			verifyEqual(testCase, am.nFrames, 0, 'no frames before setup');
		end

		function testLissajousTypeValidated(testCase)
			%> construction goes through parseArgs, which warns instead of
			%> throwing on an invalid value, so test the setter directly
			am = makeAM(testCase);
			threw = false;
			try
				am.type = 'lissajous2';
			catch ME
				threw = true;
				verifyEqual(testCase, ME.identifier, ...
					'MATLAB:validators:mustBeMember', 'validator error');
			end
			verifyTrue(testCase, threw, 'invalid type assignment rejected');
			verifyEqual(testCase, am.type, 'rigid', 'type unchanged');
		end

		function testLissajousSetupHeadless(testCase)
			am = makeLissajous(testCase);
			verifyTrue(testCase, am.isSetup, 'setup true');
			verifyEqual(testCase, am.timeDelta, 1/60, 'AbsTol', 1e-12, ...
				'timeDelta from fps');
			verifyEqual(testCase, am.ppd, 40, 'ppd from screen struct');
			%> 10° circle at 10°/s, 60Hz = one full curve in 188 frames
			verifyEqual(testCase, am.nFrames, 188, 'frame count for one curve');
			verifyEqual(testCase, am.nFrames, am.lissajous.nFrames, ...
				'nFrames proxies the path');
			verifyEqual(testCase, am.x, am.lissajous.x(1), 'x at first frame');
			verifyEqual(testCase, am.y, am.lissajous.y(1), 'y at first frame');
			verifyEqual(testCase, am.tick, 0, 'tick starts at 0');
		end

		function testLissajousAnimateAdvances(testCase)
			am = makeLissajous(testCase);
			animate(am);
			verifyEqual(testCase, am.tick, 1, 'first animate is frame 1');
			verifyEqual(testCase, am.x, am.lissajous.x(1), 'x frame 1');
			verifyEqual(testCase, am.y, am.lissajous.y(1), 'y frame 1');
			verifyEqual(testCase, am.timeStep, 0, 'timeStep frame 1');
			animate(am);
			verifyEqual(testCase, am.tick, 2, 'second frame');
			verifyEqual(testCase, am.x, am.lissajous.x(2), 'x frame 2');
			verifyEqual(testCase, am.timeStep, am.timeDelta, 'AbsTol', 1e-12, ...
				'timeStep advances by timeDelta');
		end

		function testLissajousLoopsAndWraps(testCase)
			am = makeLissajous(testCase);
			for i = 1:am.nFrames
				animate(am);
			end
			verifyEqual(testCase, am.tick, am.nFrames, 'reached last frame');
			animate(am);
			verifyEqual(testCase, am.tick, 1, 'wraps to frame 1');
			verifyEqual(testCase, am.x, am.lissajous.x(1), 'wrapped position');
		end

		function testLissajousTracksCircle(testCase)
			am = makeLissajous(testCase);
			x = nan(1, am.nFrames);
			y = nan(1, am.nFrames);
			for i = 1:am.nFrames
				animate(am);
				x(i) = am.x;
				y(i) = am.y;
			end
			verifyEqual(testCase, x, am.lissajous.x, 'all X positions match path');
			verifyEqual(testCase, y, am.lissajous.y, 'all Y positions match path');
			r = hypot(x, y);
			verifyLessThan(testCase, max(abs(r - 5)), 1e-3, ...
				'animated positions lie on the circle');
		end

		function testLissajousOrientation(testCase)
			am = makeLissajous(testCase, 'orientToPath', true);
			animate(am);
			verifyEqual(testCase, am.angle, ...
				deg2rad(am.lissajous.direction(am.tick)), 'AbsTol', 1e-12, ...
				'angle follows the path tangent');
			am2 = makeLissajous(testCase);
			animate(am2);
			verifyEqual(testCase, am2.angle, 0, 'upright by default');
		end

		function testLissajousStepMultiple(testCase)
			am = makeLissajous(testCase);
			step(am, 5);
			verifyEqual(testCase, am.tick, 5, 'advanced 5 frames');
			verifyEqual(testCase, am.x, am.lissajous.x(5), 'position frame 5');
		end

		function testLissajousRewindKeepsPath(testCase)
			am = makeLissajous(testCase);
			for i = 1:10; animate(am); end
			am.rewind();
			verifyEqual(testCase, am.tick, 0, 'tick reset');
			verifyTrue(testCase, am.isSetup, 'still setup');
			verifyEqual(testCase, am.nFrames, 188, 'path retained');
			verifyEqual(testCase, am.x, am.lissajous.x(1), 'x back at path start');
			verifyEqual(testCase, am.y, am.lissajous.y(1), 'y back at path start');
		end

		function testLissajousResetClearsPath(testCase)
			am = makeLissajous(testCase);
			animate(am);
			reset(am);
			verifyFalse(testCase, am.isSetup, 'not setup after reset');
			verifyEqual(testCase, am.nFrames, 0, 'path cleared');
			verifyEmpty(testCase, am.x, 'x cleared');
		end

		function testLissajousAnimateBeforeSetupErrors(testCase)
			am = makeAM(testCase, 'type', 'lissajous');
			verifyError(testCase, @() animate(am), ...
				'animationManager:notSetup', 'animate before setup errors');
		end

		function testImageStimulusAnimatorDrivesXY(testCase)
			%> Exercise imageStimulus.animate -> applyAnimator ->
			%> updateXY without a PTB window: attach a constructed
			%> screenManager and mark the stimulus setup.
			sM = testCase.makeStubScreen();
			am = makeLissajous(testCase);
			img = testCase.makeStubImage(sM, am);
			verifyTrue(testCase, img.animator == am, 'animator attached');
			img.angleOut = 30;
			img.syncAnimator();
			verifyEqual(testCase, img.xFinalD, am.x, 'AbsTol', 1e-12, ...
				'syncAnimator lands on the path start');
			for i = 1:10
				img.animate();
				verifyEqual(testCase, img.xFinalD, am.x, 'AbsTol', 1e-12, ...
					'stimulus X driven by the animator');
				verifyEqual(testCase, img.yFinalD, am.y, 'AbsTol', 1e-12, ...
					'stimulus Y driven by the animator');
			end
			verifyEqual(testCase, am.tick, 10, 'animator advanced with stimulus');
			verifyEqual(testCase, img.angleOut, 30, ...
				'angleOut untouched when the animator does not orient');
			img.rewindAnimator();
			verifyEqual(testCase, am.tick, 0, 'rewindAnimator rewinds the path');
			verifyEqual(testCase, img.xFinalD, am.x, 'AbsTol', 1e-12, ...
				'position returned to the path start');
		end

		function testImageStimulusOrientation(testCase)
			sM = testCase.makeStubScreen();
			am = makeLissajous(testCase, 'orientToPath', true);
			img = testCase.makeStubImage(sM, am);
			img.animate();
			verifyEqual(testCase, img.angleOut, -rad2deg(am.angle), ...
				'AbsTol', 1e-12, 'stimulus rotates to the path tangent');
		end

		function testStimulusUpdateRewindsAnimator(testCase)
			%> exampleStimulus.update() is just rewind + computePosition, so
			%> it can run headlessly and exercises the real update() path.
			sM = testCase.makeStubScreen();
			am = makeLissajous(testCase);
			stim = exampleStimulus('verbose', false);
			setP(stim, 'ppd', sM.ppd);
			setP(stim, 'sM', sM);
			setP(stim, 'isSetup', true);
			stim.addprop('angleOut');
			p = stim.addprop('xPositionOut');
			p.SetMethod = @setXOutPixels;
			p = stim.addprop('yPositionOut');
			p.SetMethod = @setYOutPixels;
			stim.addprop('doAnimator');
			stim.addprop('doMotion');
			stim.doMotion = false;
			stim.doAnimator = true;
			stim.animator = am;
			for i = 1:5
				stim.animate();
			end
			verifyEqual(testCase, am.tick, 5, 'animator advanced 5 frames');
			stim.update();
			verifyEqual(testCase, am.tick, 0, 'update() rewinds the animator');
			verifyEqual(testCase, stim.xFinalD, am.x, 'AbsTol', 1e-12, ...
				'update() moves the stimulus back to the path start');
		end
	end

	% ===================================================================
	% DYN4J DYNAMICS ENGINE — CI-safe, no PTB window required
	% ===================================================================
	methods (Test, TestTags = {'CI'})
		function testDyn4jVersionMatchesBundle(testCase)
			makeAM(testCase); %> construction loads the bundled jar
			verifyEqual(testCase, animationManager.loadedDyn4jVersion(), ...
				animationManager.dyn4jVersion, ...
				'the dyn4j version Java loaded must be the bundled one');
		end

		function testDyn4jJarMatchesVersion(testCase)
			dir = fullfile(fileparts(which('animationManager')), 'lib');
			jar = fullfile(dir, sprintf('dyn4j-%s.jar', ...
				animationManager.dyn4jVersion));
			verifyEqual(testCase, exist(jar, 'file'), 2, ...
				sprintf('bundled dyn4j jar should exist: %s', jar));
		end

		function testStepAppliesGravity(testCase)
			am = makeRigidWorld(testCase, [0 -9.8]);
			c = getBody(am, 'ball').getWorldCenter();
			p0 = [c.x c.y];
			n = 10;
			for i = 1:n
				step(am, 1, false); %> physics only, no stimulus updates
			end
			c = getBody(am, 'ball').getWorldCenter();
			p1 = [c.x c.y];
			verifyEqual(testCase, p1(1), p0(1), 'AbsTol', 1e-9, ...
				'no motion along X');
			verifyLessThan(testCase, p1(2), p0(2), ...
				'gravity pulls the body along -Y in dyn4j coordinates');
			%> semi-implicit Euler: dy = g*dt^2*n*(n+1)/2
			dt = am.timeDelta;
			verifyEqual(testCase, p0(2)-p1(2), 9.8*dt^2*n*(n+1)/2, ...
				'RelTol', 0.05, 'free fall distance over 10 steps');
		end

		function testStepAppliesVelocity(testCase)
			am = makeRigidWorld(testCase, [0 0]);
			am.editBody('ball', [], [], 10, 0); %> 10 degrees/s along +X
			c = getBody(am, 'ball').getWorldCenter();
			p0 = [c.x c.y];
			n = 10;
			for i = 1:n
				step(am, 1, false);
			end
			c = getBody(am, 'ball').getWorldCenter();
			p1 = [c.x c.y];
			verifyEqual(testCase, p1(2), p0(2), 'AbsTol', 1e-9, ...
				'no motion along Y');
			verifyEqual(testCase, p1(1)-p0(1), 10*n*am.timeDelta, ...
				'RelTol', 0.05, 'distance travelled with a 10 degree/s velocity');
		end

		function testCollisionDetected(testCase)
			am = makeAM(testCase, 'timeDelta', 1/60);
			am.rigidParams.gravity = [0 0];
			ball = discStimulus('verbose', false, 'name', 'ball', 'size', 72);
			ball.xPosition = 0; ball.yPosition = 0;
			addBody(am, ball, 'Circle', 'normal', 1, 0.2, 0.5);
			wall = barStimulus('verbose', false, 'name', 'wall', ...
				'barWidth', 4, 'barHeight', 4);
			wall.xPosition = 1; wall.yPosition = 0; %> overlaps the ball
			addBody(am, wall, 'Rectangle', 'infinite');
			setup(am, struct('fps', 60, 'ppd', 36));
			step(am, 1, false);
			[hit, other] = isCollision(am, 'ball');
			verifyTrue(testCase, hit, 'overlapping bodies generate a contact');
			verifyEqual(testCase, class(other), 'org.dyn4j.dynamics.Body', ...
				'the colliding body is returned');
			verifyEqual(testCase, getBodyName(am, other.hashCode), "wall", ...
				'the wall is the other body');
		end

		function testEditBodyMovesAndSetsVelocity(testCase)
			am = makeRigidWorld(testCase, [0 0]);
			am.editBody('ball', 3, -2); %> opticka Y is negated for dyn4j
			c = getBody(am, 'ball').getWorldCenter();
			p = [c.x c.y];
			verifyEqual(testCase, p, [3 2], 'AbsTol', 1e-9, ...
				'body translated (dyn4j +Y is opticka -Y)');
			am.editBody('ball', [], [], 4, 0);
			v = getBody(am, 'ball').getLinearVelocity();
			verifyEqual(testCase, [v.x v.y], [4 0], 'AbsTol', 1e-9, ...
				'linear velocity set');
		end

		function testRmBodyKeepsWorldSteppable(testCase)
			am = makeRigidWorld(testCase, [0 0]);
			wall = barStimulus('verbose', false, 'name', 'wall', ...
				'barWidth', 2, 'barHeight', 2);
			addBody(am, wall, 'Rectangle', 'infinite');
			setup(am, struct('fps', 60, 'ppd', 36));
			verifyEqual(testCase, am.nBodies, 2, 'two bodies before removal');
			rmBody(am, 'wall');
			verifyEqual(testCase, am.nBodies, 1, 'wall removed');
			verifyEmpty(testCase, getBody(am, 'wall'), 'wall no longer found');
			step(am, 1, false); %> the world must still be usable
			verifyEqual(testCase, am.tick, 1, 'world still steps');
		end

		function testWorldBounds(testCase)
			am = makeAM(testCase, 'timeDelta', 1/60);
			am.rigidParams.screenBounds = true;
			am.screenBounds = [-11 -8 11 8]; %> a 22 x 16 degree screen
			ball = discStimulus('verbose', false, 'name', 'ball', 'size', 72);
			addBody(am, ball, 'Circle', 'normal');
			setup(am, struct('fps', 60, 'ppd', 36));
			bnds = am.world.getBounds();
			verifyEqual(testCase, bnds.getWidth(), 22, 'AbsTol', 1e-9, ...
				'bounds width from the screen rect');
			verifyEqual(testCase, bnds.getHeight(), 16, 'AbsTol', 1e-9, ...
				'bounds height from the screen rect');
		end

		function testShapesMapToDyn4j(testCase)
			am = makeAM(testCase);
			d = discStimulus('verbose', false, 'name', 'c', 'size', 72);
			circle = addBody(am, d, 'Circle');
			r = barStimulus('verbose', false, 'name', 'r', ...
				'barWidth', 2, 'barHeight', 4);
			rect = addBody(am, r, 'Rectangle');
			s = barStimulus('verbose', false, 'name', 's', ...
				'barWidth', 4, 'barHeight', 0.2);
			seg = addBody(am, s, 'Segment');
			verifyEqual(testCase, class(circle.body.getFixture(0).getShape()), ...
				'org.dyn4j.geometry.Circle', 'circle maps to Circle');
			verifyEqual(testCase, class(rect.body.getFixture(0).getShape()), ...
				'org.dyn4j.geometry.Rectangle', 'rectangle maps to Rectangle');
			verifyEqual(testCase, class(seg.body.getFixture(0).getShape()), ...
				'org.dyn4j.geometry.Segment', 'segment maps to Segment');
		end

		function testSensorBody(testCase)
			am = makeAM(testCase);
			d = discStimulus('verbose', false, 'name', 'sensor', 'size', 72);
			body = addBody(am, d, 'Circle', 'sensor');
			verifyTrue(testCase, body.body.getFixture(0).isSensor(), ...
				'sensor fixture is a sensor');
			verifyEqual(testCase, body.type, 'sensor', 'body type is sensor');
			verifyEqual(testCase, ...
				char(body.body.getMass().getType().name()), 'INFINITE', ...
				'sensors are immovable');
			setSensorState(am, 'sensor', false);
			verifyFalse(testCase, am.getFixture('sensor').isSensor(), ...
				'sensor state can be cleared');
		end
	end

	% ===================================================================
	% HARDWARE TESTS
	% ===================================================================
	methods (Test, TestTags = {'hardware'})
		function testImageStimulusFollowsLissajous(testCase)
			assumeFalse(testCase, ~isempty(getenv('GITHUB_ACTIONS')), 'Skip in CI');
			am = makeAM(testCase, 'type', 'lissajous');
			am.lissajous.a = 1; am.lissajous.b = 1;
			am.lissajous.delta = pi/2;
			am.lissajous.size = 8; am.lissajous.speed = 6;
			am.lissajous.xPosition = 1; am.lissajous.yPosition = -2;
			sM = screenManager; sM.windowed = [0 0 800 600];
			sM.disableSyncTests = true; sM.visualDebug = true; sM.bitDepth = '8bit';
			open(sM); cleanup = onCleanup(@() close(sM));
			img = imageStimulus('filePath', 'moon.png', 'size', 2, ...
				'verbose', false);
			img.animator = am; %> attach before setup
			setup(img, sM);    %> stimulus setup also sets up the animator
			verifyTrue(testCase, am.isSetup, 'animator setup by stimulus setup');
			verifyTrue(testCase, img.doAnimator, 'stimulus uses the animator');
			verifyEqual(testCase, img.xFinalD, am.x, 'AbsTol', 1e-9, ...
				'stimulus starts on the path after setup');
			verifyEqual(testCase, am.timeDelta, sM.screenVals.ifi, ...
				'AbsTol', 1e-6, 'animator timeDelta from screen');
			verifyEqual(testCase, am.nFrames, am.lissajous.nFrames, ...
				'path generated at the screen frame rate');
			for i = 1:12
				draw(img); flip(sM); animate(img);
				verifyEqual(testCase, img.xFinalD, am.x, 'AbsTol', 1e-9, ...
					'stimulus X follows the path');
				verifyEqual(testCase, img.yFinalD, am.y, 'AbsTol', 1e-9, ...
					'stimulus Y follows the path');
			end
			verifyEqual(testCase, am.tick, 12, 'animator advanced with stimulus');
			reset(img); reset(am);
		end

		function testSetupWithScreen(testCase)
			assumeFalse(testCase, ~isempty(getenv('GITHUB_ACTIONS')), 'Skip in CI');
			am = makeAM(testCase, 'timeDelta', 0.016);
			sM = screenManager; sM.windowed = [0 0 800 600];
			sM.disableSyncTests = true; sM.visualDebug = true; sM.bitDepth = '8bit';
			open(sM); cleanup = onCleanup(@() close(sM));
			d = discStimulus('verbose', false, 'size', 4, 'name', 'ball');
			setup(d, sM);
			addBody(am, d);
			setup(am, sM);
			verifyTrue(testCase, ~isempty(am.isSetup), 'screen should be set');
			verifyEqual(testCase, am.ppd, sM.ppd, 'ppd should match screen');
			reset(d);
		end

		function testStep(testCase)
			assumeFalse(testCase, ~isempty(getenv('GITHUB_ACTIONS')), 'Skip in CI');
			am = makeAM(testCase, 'timeDelta', 0.016);
			sM = screenManager; sM.windowed = [0 0 800 600];
			sM.disableSyncTests = true; sM.visualDebug = true; sM.bitDepth = '8bit';
			open(sM); cleanup = onCleanup(@() close(sM));
			d = discStimulus('verbose', false, 'size', 4, 'name', 'ball', ...
				'speed', 20, 'angle', 45);
			setup(d, sM);
			addBody(am, d);
			setup(am, sM);
			draw(d);flip(sM);
			step(am, 1, true);
			draw(d);flip(sM);
			verifyEqual(testCase, am.tick, 1, 'tick should be 1 after one step');
			verifyEqual(testCase, am.timeStep, 0, 'timeStep (tick-1*timeDelta) should be 0');
			reset(d);
		end

		function testStepMultiple(testCase)
			assumeFalse(testCase, ~isempty(getenv('GITHUB_ACTIONS')), 'Skip in CI');
			am = makeAM(testCase, 'timeDelta', 0.016);
			sM = screenManager; sM.windowed = [0 0 800 600];
			sM.disableSyncTests = true; sM.visualDebug = true; sM.bitDepth = '8bit';
			open(sM); cleanup = onCleanup(@() close(sM));
			d = discStimulus('verbose', false, 'size', 4, 'name', 'ball', ...
				'speed', 10, 'angle', 0);
			setup(d, sM);
			addBody(am, d);
			setup(am, sM);
			for i = 1:5
				step(am, 1, true);
			end
			verifyEqual(testCase, am.tick, 5, 'tick should be 5 after 5 steps');
			verifyTrue(testCase, ~isempty(am.x), 'x should have a value after steps');
			verifyTrue(testCase, ~isempty(am.y), 'y should have a value after steps');
			reset(d);
		end
	end
end

% ========================================================================
%> @brief setXOutPixels mimics the degrees->pixels setter installed on
%> xPositionOut by every stimulus setup()
% ========================================================================
function setXOutPixels(obj,value)
	obj.xPositionOut = value * obj.ppd;
end

% ========================================================================
%> @brief setYOutPixels mimics the degrees->pixels setter installed on
%> yPositionOut by every stimulus setup()
% ========================================================================
function setYOutPixels(obj,value)
	obj.yPositionOut = value * obj.ppd;
end
