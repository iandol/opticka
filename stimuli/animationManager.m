% ========================================================================
%> @brief ANIMATIONMANAGER Provides per frame paths for stimuli
%> We integrate dyn4j java physics engine for rigid body
%>
%> @todo build the code for the different types of motion
%>
%> Copyright ©2014-2022 Ian Max Andolina — released: LGPL3, see LICENCE.md
% ========================================================================	
classdef animationManager < optickaCore

	properties
		%> type of animation path, rigid | linear | sinusoidal | brownian | circular
		%> only rigid supported so far
		type char ...
			{mustBeMember(type,{'rigid','linear','sinusoidal','brownian','circular'})} = 'rigid'
		%> bodyList
		bodies = struct([])
		%> parameters for each animation type
		rigidParams = struct('gravity', [0 -9.8],'LinearDamping', 0.05, 'AngularDamping', 0.075,...
			'screenBounds',false);
		sinusoidalParams = struct();
		brownianParams = struct();
		timeDelta		= 0.016
		%> verbose?
		verbose = false
		%> default length of the animation in seconds if prerendering
		timeToEnd double = 10
		%> what happens at edge of screen [bounce | wrap | none]
		boundsCheck char ...
			{mustBeMember(boundsCheck,{'bounce','wrap','none'})} = 'bounce'
	end

	properties (Dependent = true, SetAccess = protected, GetAccess = public)
		nBodies
		nObstacles
	end


	properties (SetAccess = private, GetAccess = public)
		%> tick updates +1 on each draw, resets on each update
		tick double = 0
		%> current time step in simulation
		timeStep = 0
		%> angle
		angle = 0
		%>
		angularVelocity
		%> moment of inertia
		momentOfInertia
		%>
		kineticEnergy
		%>
		potentialEnergy
		%>
		torque
		%> computed X position 
		x double = []
		%> computed Y position
		y double = []
		%> X update 
		dX double
		%> Y update 
		dY double
		%> pixels per degree, inhereted from a screenManager
		ppd double = 36
		%> did we hit left wall?
		hitFloor = false
		%> did we hit left wall?
		hitCeiling = false
		%> did we hit left wall?
		hitLeftWall = false
		%> did we hit left wall?
		hitRightWall = false
		%> world for rigidbody simulation
		world = []
		screenBounds = []
	end
	
	properties (SetAccess = private, GetAccess = private)
		isFloor = false
		isLeftWall = false
		isRightWall = false
		isCeiling = false
		massType = struct('NORMAL',[],'INFINITE',[],'FIXED_ANGULAR_VELOCITY',[],'FIXED_LINEAR_VELOCITY',[])
		bodyTemplate = struct('name','','type','','body',[],'stimulus',[],'shape','Circle','radius',2,'density',1,'friction',0.2,'elasticity',0.75,'position',[0 0],'velocity',[0 0])
		%> useful screen info and initial gamma tables and the like
		screenVals struct
		%> what properties are allowed to be passed on construction
		allowedProperties='screen|bodies|obstacles|type|speed|angle|startPosition|verbose'
	end
	
	%=======================================================================
	methods %------------------PUBLIC METHODS
	%=======================================================================
		
		% ===================================================================
		%> @brief Class constructor
		%>
		%> We use parseArgs to parse allowed properties on construction.
		%>
		%> @param varargin are passed as a structure of properties which is
		%> parsed.
		%> @return instance of class.
		% ===================================================================
		function me = animationManager(varargin)
			args = optickaCore.addDefaults(varargin,struct('name','animationManager'));
			me=me@optickaCore(args); %superclass constructor
			me.parseArgs(args,me.allowedProperties);
			% dyn4j jar -- see https://dyn4j.org/pages/getting-started
			javaaddpath([me.paths.whereami '/stimuli/lib/dyn4j-5.0.2.jar']);
			me.massType.NORMAL = javaMethod('valueOf', 'org.dyn4j.geometry.MassType', 'NORMAL');
    		me.massType.INFINITE = javaMethod('valueOf', 'org.dyn4j.geometry.MassType', 'INFINITE');
			me.massType.FIXED_ANGULAR_VELOCITY = javaMethod('valueOf', 'org.dyn4j.geometry.MassType', 'FIXED_ANGULAR_VELOCITY');
			me.massType.FIXED_LINEAR_VELOCITY = javaMethod('valueOf', 'org.dyn4j.geometry.MassType', 'FIXED_LINEAR_VELOCITY');
		end

		% % ===================================================================
		% %> @brief Load an image
		% %>
		% % ===================================================================
		% function addObstacle(me, name, shape, params, isSensor)
		% 	if ~exist('name','var') || isempty(name); name = 'generic'; end
		% 	if ~exist('shape','var') || isempty(shape); shape = 'Rectangle'; end
		% 	if ~exist('params','var') || isempty(params); params = [-20 15 2- 15.1]; end
		% 	if ~exist('isSensor','var') || isempty(isSensor); isSensor = false; end
		% 	shape = [upper(shape(1)) lower(shape(2:end))];
		% 	if ~matches(shape,{'Circle','Rectangle','Triangle','Ellipse','Segment'}); warning('Not supported shape');return;end
		% 	switch shape
		% 		case 'Rectangle'
		% 			f = javaObject('org.dyn4j.geometry.Rectangle', RectWidth(params), RectHeight(params));
		% 			[thisX, thisY] = RectCenterd(params); 
		% 		case 'Segment'
		% 			wa=javaObject('org.dyn4j.geometry.Vector2', params(1), params(2));
		% 			wb=javaObject('org.dyn4j.geometry.Vector2', params(3), params(4));
		% 			f = javaObject('org.dyn4j.geometry.Segment', wa, wb);
		% 			thisX = params(1) - params(3);
		% 			thisY = params(2) - params(4);
		% 		otherwise
		% 			f = javaObject('org.dyn4j.geometry.Circle', params(3));
		% 			thisX = params(1); thisY = params(2);
		% 	end
		% 	thisObstacle = me.obstacleTemplate;
		% 	thisObstacle.x = thisX;
		% 	thisObstacle.y = thisY;
		% 	thisObstacle.name = name;
		% 	thisObstacle.sensor = isSensor;
		% 	thisObstacle.body = javaObject('org.dyn4j.dynamics.Body');
		% 	fixture = thisObstacle.body.addFixture(f);
		% 	if isSensor; fixture.setSensor(true); end
		% 	thisObstacle.body.setMass(me.massType.INFINITE);
		% 	if ~strcmpi(shape,'Segment'); thisObstacle.body.translate(thisX, thisY); end	
		% 	if isempty(me.obstacles)
		% 		me.obstacles = thisObstacle;
		% 	else
		% 		me.obstacles(end+1) = thisObstacle;
		% 	end
		% end

		% ===================================================================
		%> @brief 
		%>
		% ===================================================================
		function addBody(me, stimulus, shape, type, density, friction, elasticity)
			if ~exist('stimulus','var') || ~isa(stimulus, 'baseStimulus'); return; end
			if ~exist('shape','var') || isempty(shape); shape = 'Circle'; end
			if ~exist('type','var') || isempty(type); type = 'normal'; end
			if ~exist('density','var') || isempty(density); density = 1; end
			if ~exist('friction','var') || isempty(friction); friction = 0.2; end
			if ~exist('elasticity','var') || isempty(elasticity); elasticity = 0.75; end
			shape = [upper(shape(1)) lower(shape(2:end))];
			if ~matches(shape,{'Circle','Rectangle','Triangle','Ellipse'}); warning('Not supported shape');return;end
			
			thisX = stimulus.xPosition;
			thisY = stimulus.yPosition;
			sz = stimulus.getP('size');
			if stimulus.szIsPx; sz = sz / stimulus.ppd; end
			bw = stimulus.getP('barWidth');
			bh = stimulus.getP('barHeight');
			sc = stimulus.getP('scale');
			if isempty(sc); sc = 1; end
			w = stimulus.getP('widthD') * sc;
			h = stimulus.getP('heightD') * sc;
			if isempty(bw) 
				if ~isempty(sz) && sz > 0
					bw = sz;
				elseif ~isempty(w) && w > 0
					bw = w; 
				end
			end
			if isempty(bh) 
				if ~isempty(sz) && sz > 0
					bh = sz;
				elseif ~isempty(h) && h > 0
					bh = h; 
				end
			end
			if isempty(sz) || sz == 0; sz = max([bw bh]); end
			r = sz / 2;
			
			switch shape
				case 'Rectangle'
					thisShape = javaObject('org.dyn4j.geometry.Rectangle', bw, bh);
				case 'Segment'
					if bh > bw; params = [0 0 0.1 bh]; else; params = [0 0 bh 0.1]; end
					wa=javaObject('org.dyn4j.geometry.Vector2', params(1), params(2));
					wb=javaObject('org.dyn4j.geometry.Vector2', params(3), params(4));
					thisShape = javaObject('org.dyn4j.geometry.Segment', wa, wb);
				otherwise
					thisShape = javaObject('org.dyn4j.geometry.Circle', r);
			end

			thisBody = me.bodyTemplate;
			thisBody.name = stimulus.name;
			thisBody.type = type;
			thisBody.stimulus = stimulus;
			thisBody.shape = shape;
			thisBody.density = density;
			thisBody.friction = friction;
			thisBody.elasticity = elasticity;
			thisBody.radius = r;
			if isprop(stimulus,'direction')
				theta = deg2rad(stimulus.getP('direction'));
			else
				theta = deg2rad(stimulus.getP('angle'));
			end
			if isempty(theta); theta = 0; end
			[cx,cy] = pol2cart(theta, stimulus.speed);
			thisBody.velocity = [cx -cy];
			thisBody.position = [stimulus.xPosition -stimulus.yPosition];
			thisBody.body = javaObject('org.dyn4j.dynamics.Body');
    		fixture = thisBody.body.addFixture(thisShape);
			fixture.setDensity(thisBody.density);
			fixture.setFriction(thisBody.friction);
    		fixture.setRestitution(thisBody.elasticity); % set coefficient of restitution
			if matches(lower(type),'normal')
				thisBody.body.setMass(me.massType.NORMAL);
			elseif matches(lower(type),'sensor')
				fixture.setSensor(true);
				thisBody.body.setMass(me.massType.INFINITE);
			else
				thisBody.body.setMass(me.massType.INFINITE);
			end
    		thisBody.body.translate(thisBody.position(1), thisBody.position(2));
    		initialVelocity = javaObject('org.dyn4j.geometry.Vector2', thisBody.velocity(1), thisBody.velocity(2));
    		thisBody.body.setLinearVelocity(initialVelocity);
			if isempty(me.bodies)
				me.bodies = thisBody;
			else
				me.bodies(end+1) = thisBody;
			end
		end
		
		% ===================================================================
		%> @brief 
		%>
		% ===================================================================
		function setup(me, screen, useBounds)
			if ~exist('screen','var') || isempty(screen); screen = screenManager; end
			if ~exist('useBounds','var') || isempty(useBounds); useBounds = false; end
			me.reset;
			me.tick = 0;
			me.timeStep = [];
			me.torque = 0;

			me.ppd = screen.ppd;

			me.world = javaObject('org.dyn4j.world.World');
			me.world.setGravity(me.rigidParams.gravity(1),me.rigidParams.gravity(2));

			if useBounds && ~isempty(screen.screenVals.rectInDegrees)
				me.screenBounds = screen.screenVals.rectInDegrees;
				if me.rigidParams.screenBounds
					bnds = javaObject('org.dyn4j.collision.AxisAlignedBounds', Rectwidth(screen.screenVals.rectInDegrees), RectHeight(screen.screenVals.rectInDegrees));
					me.world.setBounds(bnds);
				end
			end

			settings = me.world.getSettings();
			settings.setAtRestDetectionEnabled(true);
			settings.setStepFrequency(screen.screenVals.ifi);
			settings.setMaximumAtRestLinearVelocity(0.75);
			settings.setMaximumAtRestAngularVelocity(0.5);
			settings.setMinimumAtRestTime(0.2); %def = 0.5

			fprintf('--->>> RigidBody World with %.2fs step time created!\n',settings.getStepFrequency);

			for i = 1:me.nBodies
				fprintf('\t--> Adding body %s as a %s\n',...
					me.bodies(i).name,me.bodies(i).shape);
				me.world.addBody(me.bodies(i).body);
			end
			
		end
		
		% ===================================================================
		%> @brief 
		%>
		% ===================================================================
		function step(me)
			switch me.type
				case 'rigid'
					rigidStep(me);
			end
		end

		% ===================================================================
		%> @brief Load an image
		%>
		% ===================================================================
		function reset(me)
			me.world = [];
			me.isFloor = false;
			me.isLeftWall = false;
			me.isRightWall = false;
			me.isCeiling = false;
			me.hitCeiling = false;
			me.hitFloor = false;
			me.hitLeftWall = false;
			me.hitRightWall = false;
			me.tick = 0;
			me.timeStep = [];
			me.torque = 0;
			me.kineticEnergy=0;
			me.potentialEnergy=0;
			me.angle=0;
			me.angularVelocity = 0;
			me.x = [];
			me.y = [];
			me.dX = [];
			me.dY = [];
			me.screenBounds = [];
		end

		% ===================================================================
		%> @brief Load an image
		%>
		% ===================================================================
		function rigidStep(me, tick)
			if ~exist('tick','var') || isempty(tick); tick = 1; end

			me.world.step(tick);
			me.tick = me.tick + tick;
			me.timeStep = (me.tick - 1) * me.timeDelta;

			a = 1;
			for ii=1:length(me.bodies)
				if matches(me.bodies(ii).type,'normal')
					pos = me.bodies(ii).body.getWorldCenter();
					lv = me.bodies(ii).body.getLinearVelocity();
					av = me.bodies(ii).body.getAngularVelocity();
					me.x(a) = pos.x;
					me.y(a) = -pos.y;
					if lv.x > 0; av = abs(av); else; av = -abs(av); end
					me.angularVelocity(a) = a;
					a = a + 1;
				end
			end
			
		end

		% ===================================================================
		%> @brief Load an image
		%>
		% ===================================================================
		function oldrigidStep(me, tick)
			if exist('tick','var') && ~isempty(tick)
				me.tick = tick;
				me.timeStep = (me.tick - 1) * me.timeDelta;
			elseif isempty(me.timeStep) 
				me.timeStep = 0;
				me.tick = 1;
			else
				me.tick = me.tick + 1;
				me.timeStep = (me.tick - 1) * me.timeDelta;
			end

			position = [me.x, me.y];
			velocity = [me.dX, me.dY];
			acceleration = [0, me.rigidParams.gravity]; 
			r = me.rigidParams.radius;

    		% Apply air resistance
    		airResistance = -me.rigidParams.airResistanceCoeff * velocity;
    		acceleration = acceleration + airResistance;
    		
    		% Update velocity and position
    		velocity = velocity + acceleration * me.timeDelta;
    		position = position + velocity * me.timeDelta;
    		
    		% Calculate angular acceleration
    		angularAcceleration = me.torque / me.momentOfInertia;
    		
    		% Update angular velocity and position
    		me.angularVelocity = me.angularVelocity + angularAcceleration * me.timeDelta;
    		me.angle = me.angle + me.angularVelocity * me.timeDelta;

			me.x = position(1);
			me.y = position(2);

			% Collision detection with floor
			if me.y + r > me.rigidParams.floor
    			me.y = me.rigidParams.floor - r - 0.01;
    			velocity(2) = -me.rigidParams.elasticityCoeff * velocity(2); % reverse and dampen the y-velocity
    			me.angularVelocity = -me.rigidParams.elasticityCoeff * me.angularVelocity; % reverse and dampen the angular velocity
				me.hitFloor = true;
			end
			% Collision detection with ceiling
			if me.y - r < me.rigidParams.ceiling
    			me.y = me.rigidParams.ceiling + r + 0.01;
    			velocity(2) = -me.rigidParams.elasticityCoeff * velocity(2); % reverse and dampen the y-velocity
    			me.angularVelocity = -me.rigidParams.elasticityCoeff * me.angularVelocity; % reverse and dampen the angular velocity
				me.hitCeiling = true;
			end
			% Collision detection with walls
			if me.x - r < me.rigidParams.leftwall
    			me.x = me.rigidParams.leftwall + r;
    			velocity(1) = -me.rigidParams.elasticityCoeff * velocity(1); % reverse and dampen the x-velocity
    			me.angularVelocity = -me.rigidParams.elasticityCoeff * me.angularVelocity; % reverse and dampen the angular velocity
				me.hitLeftWall = true;
			end
			if me.x + r > me.rigidParams.rightwall
    			me.x = me.rigidParams.rightwall - r	;
    			velocity(1) = -me.rigidParams.elasticityCoeff * velocity(1); % reverse and dampen the x-velocity
    			me.angularVelocity = -me.rigidParams.elasticityCoeff * me.angularVelocity; % reverse and dampen the angular velocity
				me.hitRightWall = true;
			end
			if ~isempty(me.rigidParams.avoidRects)
				for i = 1:size(me.rigidParams.avoidRects)
					rect = me.rigidParams.avoidRects{i};
					
				end
			end

			me.dX = velocity(1);
			me.dY = velocity(2);

			% Calculate the arc length traveled
    		arcLength = me.dX * me.timeDelta;
    		
    		% Update angle based on arc length
    		me.angle = me.angle - arcLength / me.rigidParams.radius;

			me.kineticEnergy = 0.5 * me.rigidParams.mass * norm(velocity)^2 + 0.5 * me.momentOfInertia * me.angularVelocity^2;
			me.potentialEnergy = me.rigidParams.mass * -me.rigidParams.gravity * (me.y - me.rigidParams.radius - me.rigidParams.floor);
		end

		% ===================================================================
		%> @brief 
		%>
		% ===================================================================
		function editBody(me,x,y,dx,dy)
			if exist('x','var') && ~isempty(x); me.x = x; end
			if exist('y','var') && ~isempty(y); me.y = y; end
			if exist('dx','var') && ~isempty(dx); me.dX = dx; end
			if exist('dy','var') && ~isempty(dy); me.dY = dy; end
		end

		% ===================================================================
		%> @brief 
		%>
		% ===================================================================
		function value = get.nBodies(me)
			value = length(me.bodies);
		end

		
	end
	
	%=======================================================================
	methods ( Static ) % STATIC METHODS
	%=======================================================================
		
		% ===================================================================
		%> @brief Load an image
		%>
		% ===================================================================
		function demo()
			s = screenManager;
			if max(Screen('Screens')) == 0; s.windowed = [0 0 1200 800]; end
			sv = open(s);

			i = imageStimulus('filePath','moon.png','size',4);
			i.name = 'moon';
			i.xPosition = sv.leftInDegrees+4;
			i.yPosition = -5;
			i.angle = -75;
			i.speed = 20;

			floor = barStimulus('alpha',0.2,'barWidth',sv.widthInDegrees,...
				'barHeight',1,'yPosition',sv.bottomInDegrees-2);
			floor.name = 'floor';
			wall1 = barStimulus('alpha',0.2,'barWidth',1,'barHeight',...
				sv.heightInDegrees,'xPosition',sv.leftInDegrees+2);
			wall1.name = 'wall1';
			wall2 = barStimulus('alpha',0.2,'barWidth',1,'barHeight',...
				sv.heightInDegrees,'xPosition',sv.rightInDegrees-2);
			wall2.name = 'wall2';
			ceiling = floor.clone;
			ceiling.name = 'ceiling';
			ceiling.yPosition = sv.topInDegrees;
			sensor = discStimulus('alpha',0.2,'size',4);
			sensor.name = 'sensor';

			m = metaStimulus('stimuli',{i,floor,wall1,wall2,ceiling,sensor});
			m.setup(s);
			
			a = animationManager;
			a.timeDelta = sv.ifi;
			%addBody(me, stimulus, shape, type, density, friction, elasticity)
			a.addBody(i, 'Circle', 'normal', 10, 0.2, 0.8);
			a.addBody(floor,'Rectangle','infinite');
			a.addBody(wall1,'Rectangle','infinite');
			a.addBody(wall2,'Rectangle','infinite');
			a.addBody(ceiling,'Rectangle','infinite');
			a.addBody(sensor,'Circle','sensor');

			a.setup(s);

			RestrictKeysForKbCheck([KbName('LeftArrow') KbName('RightArrow') KbName('UpArrow') KbName('DownArrow') ...
				KbName('1!') KbName('2@') KbName('3#') KbName('space') KbName('ESCAPE')]);


			Priority(1);
			
			for jj = 1:sv.fps*10
				step(a);
				draw(m);
				flip(s);
				
				i.updateXY(a.x, a.y, true);
				i.angleOut = i.angleOut + rad2deg(a.angle)*sv.ifi;
				t(jj)=a.timeStep;
				x(jj)=a.x;
				y(jj)=a.y;
				ke(jj) = a.kineticEnergy;
				pe(jj) = a.potentialEnergy;
			end

			Priority(0);
			close(s)
			reset(i);
			
			figure;
			tiledlayout(2,1);
			nexttile;
			plot(t,x);
			hold on;
			plot(t,y);
			box on; grid on; axis ij
			legend({'X','Y'})
			xlabel('Time (s)')
			ylabel('X|Y Position')
			nexttile;
			plot(t,ke);
			hold on;
			plot(t,pe);
			box on; grid on;
			xlabel('Time (s)')
			ylabel('Kinetic|Potential Energy')
			legend({'KE','PE'})
		
		end

		% ===================================================================
		%> @brief degrees2radians
		%>
		% ===================================================================
		function r = d2r(degrees)
		% d2r(degrees)
			r=degrees*(pi/180);
		end
		
		% ===================================================================
		%> @brief radians2degrees
		%>
		% ===================================================================
		function degrees = r2d(r)
		% r2d(radians)
			degrees=r*(180/pi);
		end
		
		% ===================================================================
		%> @brief findDistance in X and Y coordinates
		%>
		% ===================================================================
		function distance = findDistance(x1, y1, x2, y2)
		% findDistance(x1, y1, x2, y2)
			dx = x2 - x1;
			dy = y2 - y1;
			distance=sqrt(dx^2 + dy^2);
		end
		
		% ===================================================================
		%> @brief updatePosition returns dX and dY given an angle and delta
		%>
		% ===================================================================
		function [dX, dY] = updatePosition(delta,angle)
		% updatePosition(delta, angle)
			dX = delta .* cos(animationManager.d2r(angle));
			dY = delta .* sin(animationManager.d2r(angle));
		end
		
		% ===================================================================
		%> @brief bezier function
		%>
		% ===================================================================
		function bez = bezier(t,P)
			bez = bsxfun(@times,(1-t).^3,P(1,:)) + ...
			bsxfun(@times,3*(1-t).^2.*t,P(2,:)) + ...
			bsxfun(@times,3*(1-t).^1.*t.^2,P(3,:)) + ...
			bsxfun(@times,t.^3,P(4,:));
		end
		
	end % END STATIC METHODS

	%=======================================================================
	methods ( Access = protected ) % PRIVATE METHODS
	%=======================================================================
		
		% ===================================================================
		%> @brief delete is the object Destructor
		%>	Destructor automatically called when object is cleared
		%>
		% ===================================================================
		function delete(me)
			me.salutation('DELETE Method','animationManager object Cleaning up...')
		end
		
	end
end