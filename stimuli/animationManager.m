% ========================================================================
%> @brief ANIMATIONMANAGER Provides per frame paths for stimuli
%> We integrate dyn4j java physics engine for rigid body. The plan is to
%> also support sinusoidal, brownian, circular etc.
%> 
%> ```matlab
%> s = screenManager();
%> b = imageStimulus('size',4,'filePath','moon.png','name','moon');
%> b.speed = 25; % will define velocity
%> b.angle = -45; % will define velocity
%> a = animationManager();
%> sv = open(s); % open screen
%> setup(b, s); % initialise stimulus with open screen
%> addScreenBoundaries(a, sv); % add floor, ceiling and walls based on the screen
%> addBody(a, b); % add stimulus as a rigidbody to animationManager
%> setup(a); % initialise the simulation.
%> for i = 1:60
%> 	draw(b); % draw the stimulus
%> 	flip(s); % flip the screen
%> 	step(a); % step the simulation
%> end
%> ```
%>
%> @TODO build the code for the different types of motion
%>
%> Copyright ©2014-2024 Ian Max Andolina — released: LGPL3, see LICENCE.md
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
		rigidParams = struct('gravity', [0 -9.8],'linearDamping', 0.05, 'angularDamping', 0.075,...
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
		linearVelocity
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
	
	properties (Access = protected)
		trackIndex = []
		isFloor = false
		isLeftWall = false
		isRightWall = false
		isCeiling = false
		massType = struct('NORMAL',[],'INFINITE',[],'FIXED_ANGULAR_VELOCITY',[],'FIXED_LINEAR_VELOCITY',[])
		bodyTemplate = struct('idx',0,'hash',[],'name','','type','','body',[],...
			'stimulus',[],'shape','Circle','radius',2,'density',1,...
			'friction',0.2,'elasticity',0.75,'position',[0 0],'velocity',[0 0])
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

		% ===================================================================
		%> @brief 
		%>
		%> @param stimulus -- the stimulus object
		%> @param shape -- what shape to give it in the physics simulation
		%> @param type -- normal (move & collide) | infinite (non-moveable, collidable) | sensor (non-moveable, non-collidable)
		%> @param density -- 
		%> @param friction --
		%> @param elasticity --
		%> @param angularvelocity -- initial angular velocity
		% ===================================================================
		function thisBody = addBody(me, stimulus, shape, type, density, friction, elasticity, av)
			% addBody(me, stimulus, shape, type, density, friction, elasticity, av)
			if ~exist('stimulus','var') || ~isa(stimulus, 'baseStimulus'); return; end
			if ~exist('shape','var') || isempty(shape); shape = 'Circle'; end
			if ~exist('type','var') || isempty(type); type = 'normal'; end
			if ~exist('density','var') || isempty(density); density = 1; end
			if ~exist('friction','var') || isempty(friction); friction = 0.2; end
			if ~exist('elasticity','var') || isempty(elasticity); elasticity = 0.75; end
			
			shape = [upper(shape(1)) lower(shape(2:end))];
			if ~matches(shape,{'Circle','Segment','Rectangle','Triangle','Ellipse'}); warning('Not supported shape');return;end
			
			% get values from the stimulus
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
			
			% handle the different shapes
			switch shape
				case 'Rectangle'
					thisShape = javaObject('org.dyn4j.geometry.Rectangle', bw, bh);
					tx = sprintf('width = %.2f height = %.2f',bw,bh);
				case 'Segment'
					if bh > bw
						params = [0 -(bh/2) 0 (bh/2)]; 
					else
						params = [-(bw/2) 0 (bw/2) 0]; 
					end
					wa=javaObject('org.dyn4j.geometry.Vector2', params(1), params(2));
					wb=javaObject('org.dyn4j.geometry.Vector2', params(3), params(4));
					thisShape = javaObject('org.dyn4j.geometry.Segment', wa, wb);
					tx = ['points = ' sprintf(' %+.2f ', params)];
				otherwise
					thisShape = javaObject('org.dyn4j.geometry.Circle', r);
					tx = sprintf('radius = %.2f',r);
			end

			% build the structure
			thisBody = me.bodyTemplate;
			thisBody.body = javaObject('org.dyn4j.dynamics.Body');
			thisBody.hash = thisBody.body.hashCode;
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
			[cx,cy] = pol2cart(theta, stimulus.speed);
			thisBody.position = [stimulus.xPosition -stimulus.yPosition];
    		fixture = thisBody.body.addFixture(thisShape);
			fixture.setDensity(thisBody.density);
			fixture.setFriction(thisBody.friction);
    		fixture.setRestitution(thisBody.elasticity); % set coefficient of restitution
			if matches(lower(type),'normal')
				thisBody.body.setMass(me.massType.NORMAL);
				thisBody.velocity = [cx -cy];
				if ~exist('av','var') || isempty(av); av = cx/2; end
			elseif matches(lower(type),'sensor')
				fixture.setSensor(true);
				thisBody.velocity = [0 0];
				thisBody.body.setMass(me.massType.INFINITE);
				if ~exist('av','var') || isempty(av); av = 0; end
			else
				thisBody.body.setMass(me.massType.INFINITE);
				thisBody.velocity = [0 0];
				if ~exist('av','var') || isempty(av); av = 0; end
			end
			thisBody.body.translateToOrigin();
    		thisBody.body.translate(thisBody.position(1), thisBody.position(2));
    		thisBody.body.setLinearVelocity(javaObject('org.dyn4j.geometry.Vector2', thisBody.velocity(1), thisBody.velocity(2)));
			thisBody.body.setAngularVelocity(av);
			thisBody.body.setLinearDamping(me.rigidParams.linearDamping);
			thisBody.body.setAngularDamping(me.rigidParams.angularDamping);
			thisBody.body.updateMass();
			if isempty(me.bodies)
				thisBody.idx = 1;
				me.bodies = thisBody;
			else
				thisBody.idx = me.nBodies+1;
				me.bodies(end+1) = thisBody;
			end
			if me.verbose
				fprintf('---> addBody: %s:%s:%s -- X:%+0.2f Y:%+0.2f -- %s\n',thisBody.name,type,shape,stimulus.xPosition,stimulus.yPosition,tx);
			end
			makeTrackIndex(me);
		end

		% ===================================================================
		%> @brief 
		%>
		% ===================================================================
		function rmBody(me, id)
			if ~exist('id','var') || isempty(id); return; end
			rmIdx = [];
			if ischar(id)
				for j = 1:me.nBodies
					if matches(id, me.bodies(j).name)
						rmIdx = [rmIdx j];
					end
				end
			elseif isnumeric(id)
				for j = 1:length(id)
					if id(j) > 0 && id(j) < me.nBodies
						rmIdx = [rmIdx id(j)];
					end
				end
			end
			me.bodies(rmIdx) = [];
			for ii = 1:me.nBodies
				me.bodies(ii).idx = ii;
			end
			makeTrackIndex(me);
		end

		% ===================================================================
		%> @brief 
		%>
		% ===================================================================
		function resetBodies(me)
			for ii = 1:me.nBodies
				me.bodies(ii).idx = ii;
			end
		end

		% ===================================================================
		%> @brief 
		%>
		% ===================================================================
		function isCollision(me,name)
			body = me.getBody(name);
			if ~isempty(body)
				c = me.world.getContacts(body);
				if ~isempty(c)
					c = c.get(0);
					body2 = c.getOtherBody(body);

				end
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

			fprintf('--->>> RigidBody World with %.3fs step time created!\n',settings.getStepFrequency);
			fprintf('\t Adding bodies: ');
			for i = 1:me.nBodies
				fprintf('%s  ',me.bodies(i).name);
				me.world.addBody(me.bodies(i).body);
			end
			fprintf('\n');
			makeTrackIndex(me);
		end

		% ===================================================================
		%> @brief addScreenBoundaries add physical walls at the screen edges
		%>
		%> @param sv screenVals from screenManager
		%> @param padding [left top right bottom]
		% ===================================================================
		function addScreenBoundaries(me, sv, padding)
			if ~exist('sv','var'); return; end
			if ~exist('padding','var') || isempty(padding); padding = [0 0 0 0]; end

			w = sv.widthInDegrees;
			h = sv.heightInDegrees;
			l = sv.leftInDegrees + padding(1);
			t = sv.topInDegrees + padding(2);
			r = sv.rightInDegrees - padding(1);
			b = sv.bottomInDegrees - padding(1);

			fl = barStimulus('isVisible',false,'barWidth',w,'barHeight',0.01,...
				'xPosition',0,'yPosition',b,'name','floor');
			cl = barStimulus('isVisible',false,'barWidth',w,'barHeight',0.01,...
				'xPosition',0,'yPosition',t,'name','ceiling');
			lw = barStimulus('isVisible',false,'barWidth',0.01,'barHeight',h,...
				'xPosition',l,'yPosition',0,'name','leftwall');
			rw = barStimulus('isVisible',false,'barWidth',0.01,'barHeight',h,...
				'xPosition',r,'yPosition',0,'name','rightwall');

			me.addBody(fl,'Segment','infinite');
			me.addBody(cl,'Segment','infinite');
			me.addBody(lw,'Segment','infinite');
			me.addBody(rw,'Segment','infinite');
		end

		% ===================================================================
		%> @brief 
		%>
		% ===================================================================
		function updateBodyPositions(me)
			a = 0;
			for ii = me.trackIndex
				a = a + 1;
				pos = me.bodies(ii).body.getWorldCenter();
				lv = me.bodies(ii).body.getLinearVelocity();
				av = me.bodies(ii).body.getAngularVelocity();
				me.x(a) = pos.x;
				me.y(a) = -pos.y;
				if lv.x > 0; av = abs(av); else; av = -abs(av); end
				me.linearVelocity(a,:) = [lv.x lv.y];
				me.angularVelocity(a) = av;
				me.bodies(ii).stimulus.updateXY(me.x(a), me.y(a), true);
				me.bodies(ii).stimulus.angleOut = me.bodies(ii).stimulus.angleOut + rad2deg(av)*me.timeDelta;
			end
		end
		
		% ===================================================================
		%> @brief 
		%>
		% ===================================================================
		function step(me,varargin)
			switch me.type
				case 'rigid'
					rigidStep(me,varargin);
			end
		end

		% ===================================================================
		%> @brief Load an image
		%>
		% ===================================================================
		function reset(me)
			me.trackIndex = [];
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
		%> @brief 
		%>
		% ===================================================================
		function rigidStep(me, tick, updatePositions)
			if exist('tick','var') && iscell(tick)
				if length(tick)==2; updatePositions = tick{2}; end
				tick = tick{1};
			end
			if ~exist('tick','var') || isempty(tick); tick = 1; end
			if ~exist('updatePositions','var') || isempty(updatePositions); updatePositions = true; end
			if isempty(me.world); error('You need to setup() animationManager BEFORE you can step()');end
			me.world.step(tick);
			me.tick = me.tick + tick;
			me.timeStep = (me.tick - 1) * me.timeDelta;

			if updatePositions
				updateBodyPositions(me);
			end
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
		%> @brief return the first body matching name
		%>
		% ===================================================================
		function [body, trackidx, idx, stim] = getBody(me, id)
			body = []; idx = []; trackidx = []; stim = [];
			if ~exist('id','var') || isempty(id); return; end
			if ischar(id)
				names = string({me.bodies.name});
				idx = find(matches(names,id));
			else
				hashes = [me.bodies.hash];
				idx = find(hashes == id);
			end
			if ~isempty(idx)
				body = me.bodies(idx).body;
				stim = me.bodies(idx).stimulus;
				trackidx = find(me.trackIndex == idx);
			end
		end

		% ===================================================================
		%> @brief 
		%>
		% ===================================================================
		function fixture = getFixture(me, name, num)
			fixture = [];
			if ~exist('name','var') || isempty(name); return; end
			if ~exist('num','var') || isempty(num); num = 0; end
			isBody = false;
			a = 1;
			while a <= me.nBodies
				if matches(name, me.bodies(a).name); isBody = true; break; end
				a = a + 1;
			end
			if isBody; fixture = me.bodies(a).body.getFixture(num); end
		end

		% ===================================================================
		%> @brief 
		%>
		% ===================================================================
		function value = get.nBodies(me)
			value = length(me.bodies);
		end

	end % END PUBLIC METHODS
	
	%=======================================================================
	methods ( Static ) % STATIC METHODS
	%=======================================================================
		
		% ===================================================================
		%> @brief Load an image
		%>
		% ===================================================================
		function demo()

			% open a new PTB screen
			s = screenManager;
			if max(Screen('Screens')) == 0; s.windowed = [0 0 1200 800]; end
			sv = open(s);

			% create our stimuli
			moon = imageStimulus('filePath','moon.png','size',4);
			moon.name = 'moon';
			moon.xPosition = sv.leftInDegrees+4;
			moon.yPosition = -5;
			moon.angle = 85;
			moon.speed = 20;
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
			sensor = discStimulus('colour',[0.7 0.5 0.5 0.2],'size',8);
			sensor.name = 'sensor';

			% setup all stimuli with PTB screen
			all = metaStimulus('stimuli',{moon,floor,wall1,wall2,ceiling,sensor});
			all.setup(s);
			
			% create a new animation manager
			a = animationManager;
			a.verbose = true;
			a.timeDelta = sv.ifi;
			% add the stmuli as physics bodies
			%me.addBody(stimulus, shape, type, density, friction, elasticity, angular velocity)
			a.addBody(floor,'Rectangle','infinite');
			a.addBody(ceiling,'Rectangle','infinite');
			a.addBody(wall1,'Rectangle','infinite');
			a.addBody(wall2,'Rectangle','infinite');
			a.addBody(sensor,'Circle','sensor');
			a.addBody(moon, 'Circle', 'normal', 10, 0.2, 0.8, moon.speed);
			
			% setup animationmamager with PTB screen
			a.setup(s);

			RestrictKeysForKbCheck([KbName('LeftArrow') KbName('RightArrow') KbName('UpArrow') KbName('DownArrow') ...
				KbName('1!') KbName('2@') KbName('3#') KbName('space') KbName('ESCAPE')]);
			Priority(1);

			body = getBody(a,'moon');
			sense = getBody(a, 'sensor');
			
			for jj = 1:sv.fps*60
				step(a);
				v.x = a.linearVelocity(1,1);
				v.y = a.linearVelocity(1,1);
				av = a.angularVelocity(1);
				moon.updateXY(a.x(1), a.y(1), true);
				moon.angleOut = moon.angleOut + rad2deg(av)*sv.ifi;
				t(jj)=a.timeStep;
				x(jj)=a.x(1);
				y(jj)=a.y(1);
				ke(jj) = a.kineticEnergy;
				pe(jj) = a.potentialEnergy;

				inBox = sense.contains(javaObject('org.dyn4j.geometry.Vector2', a.x(1), a.y(1)));

				[isKey,~,keyCode] = KbCheck(-1);
				if isKey
					if strcmpi(KbName(keyCode),'escape')
						break;
					elseif strcmpi(KbName(keyCode),'LeftArrow')
						body.setAtRest(false);
						f = javaObject('org.dyn4j.geometry.Vector2', -20, 0);
						body.applyImpulse(f);
					elseif strcmpi(KbName(keyCode),'RightArrow')
						body.setAtRest(false);
						f = javaObject('org.dyn4j.geometry.Vector2', 20, 0);
						body.applyImpulse(f);
					elseif strcmpi(KbName(keyCode),'UpArrow')
						body.setAtRest(false);
						f = javaObject('org.dyn4j.geometry.Vector2', 0, 20);
						body.applyImpulse(f);
					elseif strcmpi(KbName(keyCode),'DownArrow')
						body.setAtRest(false);
						f = javaObject('org.dyn4j.geometry.Vector2', 0, -20);
						body.applyImpulse(f);
					elseif strcmpi(KbName(keyCode),'1!')
						body.setAtRest(false);
						body.translateToOrigin();
					elseif strcmpi(KbName(keyCode),'2@')
						body.setAtRest(false);
						if av > 0; av = -av; end
						body.setAngularVelocity(av-1);
					else
						body.setAtRest(false);
						if av < 0; av = -av; end
						body.setAngularVelocity(av+1);
					end
				end

				draw(all);
				s.drawText(sprintf('FULL PHYSICS ENGINE SUPPORT:\n X: %.3f  Y: %.3f VX: %.3f VY: %.3f A: %.3f INBOX: %i R: %.2f',...
					a.x(1),a.y(1),v.x,v.y, av, inBox,3))
				flip(s);
			end

			Priority(0);
			close(s)
			reset(moon);
			
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
		% bezier(t, P)
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
		%> @brief 
		%>
		% ===================================================================
		function makeTrackIndex(me)
			me.trackIndex = [];
			for i = 1:me.nBodies
				if matches(me.bodies(i).type,'normal')
					me.trackIndex = [me.trackIndex i];
				end
			end
		end

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