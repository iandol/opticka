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
%> stimuli/lib/dyn4j-5.0.2.jar). The constructor calls javaaddpath, so
%> Java must be available. CI-safe tests will be skipped (assumed) if
%> Java is not available.
%>
%> Run with:
%>   >> runtests('tests/AnimationManagerTest.m')
%>   >> runtests('tests/AnimationManagerTest.m', '-ExcludeTag', 'hardware')
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
	end

	% ===================================================================
	% CI-SAFE TESTS
	% ===================================================================
	methods (Test)
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
	% HARDWARE TESTS
	% ===================================================================
	methods (Test, TestTags = {'hardware'})
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
