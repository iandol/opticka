% ========================================================================
%> @brief ANIMATIONMANAGER Provides per frame paths for stimuli
%> We integrate dyn4j java physics engine for rigid body. The plan is to
%> also support sinusoidal, brownian, circular etc.
%> 
%> ```matlab
%> screen = screenManager(); % create a screen object
%> ball = imageStimulus('size',4,'filePath','moon.png','name','moon');
%> ball.speed = 25; % will define velocity
%> ball.angle = -45; % will define velocity
%> world = animationManager('timeDelta', 0.016);
%> screenParamaters = open(screen); % open screen
%> % initialise stimulus with PTB screen parameters
%> setup(ball, screen);
%> addScreenBoundaries(world, screenParamaters); % add floor,ceiling and walls based on the screen
%> addBody(world, ball); % add stimulus as a rigidbody to animationManager
%> % initialise the simulation and pass the PTB
%> % screen so that the world can be related 
%> % to the PTB dimensions. 
%> % The mapping is 1° visual angle = 1 meter.
%> setup(world, screen); 
%> for i = 1:120 % run for 120 frames
%> 	draw(ball); % draw the stimulus
%> 	flip(screen); % flip the screen
%> 	% step the simulation one step (0.016s) forwards
%> 	% true flag will update the ball stimulus at the new position
%> 	step(world, 1, true); 
%> end
%> ```
%>
%> @TODO build the code for the different types of motion paths apart from rigid
%> body 2D physics. These could be static methods.
%>
%> Contributions: Heting Zhang
%> Copyright ©2014-2025 Ian Max Andolina — released: LGPL3, see LICENCE.md
% ========================================================================	
classdef animationManager < optickaCore

	properties
		%> type of animation path, rigid | linear | sinusoidal | brownian | circular
		%> only rigid supported so far
		type char ...
			{mustBeMember(type,{'rigid','linear','sinusoidal','brownian','circular'})} ...
			= 'rigid'
		%> bodyList
		bodies = struct([])
		%> parameters for each animation type
		rigidParams = struct('gravity', [0 -9.8],'linearDamping', 0.05, 'angularDamping', 0.075,...
			'screenBounds',false);
		sinusoidalParams = struct();
		brownianParams = struct();
		timeDelta		= []
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

	properties (Hidden = true)
		wallColour = [1 0.5 0 1];
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
	end

	properties (SetAccess = private, GetAccess = public)
		%> tick updates +1 on each draw, resets on each update
		tick double		= 0
		%> current time step in simulation
		timeStep		= 0
		%> angle
		angle			= 0
		%> computed X position 
		x double		= []
		%> computed Y position
		y double		= []
		%> X update 
		dX double
		%> Y update 
		dY double
		%> pixels per degree, inhereted from a screenManager
		ppd double		= 36
		%> did we hit left wall?
		hitFloor		= false
		%> did we hit left wall?
		hitCeiling		= false
		%> did we hit left wall?
		hitLeftWall		= false
		%> did we hit left wall?
		hitRightWall	= false
		%> world for rigidbody simulation
		world = []
		screenBounds	= []
		%> types of bodies in dyn4j
		massType		= struct('NORMAL',[],'INFINITE',[],'FIXED_ANGULAR_VELOCITY',[],'FIXED_LINEAR_VELOCITY',[])
		
	end
	
	properties (Access = protected)
		screen screenManager
		useBounds logical = false
		trackIndex		= []
		isFloor			= false
		isLeftWall		= false
		isRightWall		= false
		isCeiling		= false
		bodyTemplate	= struct('name','','idx',0,'hash',[],'type','','body',[],...
			'stimulus',[],'shape','Circle','radius',2,'density',1,'angle',0,'theta',0,...
			'friction',0.2,'elasticity',0.75,'position',[0 0],'updatedPosition',[],'velocity',[0 0])
		%> what properties are allowed to be passed on construction
		allowedProperties = ["type","bodies","rigidParams","brownianParams","timeDelta","verbose"]
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
			javaaddpath([me.paths.whereami '/stimuli/lib/dyn4j-5.0.2.jar'],'-begin');
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
		%> @param type -- normal|bullet (move & collide) | infinite (non-moveable, collidable) | sensor (non-moveable, non-collidable)
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
			if ~exist('av','var') || isempty(av); av = []; end
			
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
					wa = me.vector2( params(1), params(2) );
					wb = me.vector2( params(3), params(4) );
					thisShape = javaObject('org.dyn4j.geometry.Segment', wa, wb);
					tx = ['points = ' sprintf(' %+.2f ', params)];
				otherwise
					thisShape = javaObject('org.dyn4j.geometry.Circle', r);
					tx = sprintf('radius = %.2f',r);
			end

			% build the structure
			thisBody = me.bodyTemplate;
			thisBody.body = javaObject('org.dyn4j.dynamics.Body');
			thisBody.body.addFixture(thisShape);
			thisBody.hash = thisBody.body.hashCode;
			thisBody.name = stimulus.name;
			if matches(type,'bullet')
				thisBody.type = 'normal';
				thisBody.body.setBullet(true);
			else
				thisBody.type = type;
			end
			thisBody.isBullet = thisBody.body.isBullet;
			thisBody.stimulus = stimulus;
			thisBody.shape = shape;
			thisBody.density = density;
			thisBody.friction = friction;
			thisBody.elasticity = elasticity;
			thisBody.radius = r;
			thisBody.position = [thisX thisY];
			thisBody.updatedPosition = thisBody.position;
			thisBody.angle = deg2rad(stimulus.getP('angle'));
			if isprop(stimulus,'direction')
				thisBody.theta = deg2rad(stimulus.getP('direction'));
			else
				thisBody.theta = thisBody.angle;
			end
			
			setupBody(me, thisBody);

			if isempty(me.bodies)
				thisBody.idx = 1;
				me.bodies = thisBody;
			else
				thisBody.idx = me.nBodies+1;
				me.bodies(thisBody.idx) = thisBody;
			end
			if me.verbose
				fprintf('≣≣≣≣⊱ addBody: %s:%s:%s -- X:%+0.2f Y:%+0.2f -- %s\n',thisBody.name,type,shape,stimulus.xPosition,stimulus.yPosition,tx);
			end
			makeTrackIndex(me);
		end

		% ===================================================================
		%> @brief return the first body matching name or hash
		%>
		% ===================================================================
		function [body, trackidx, idx, stim, hash] = getBody(me, id, bodyType)
			body = []; idx = []; trackidx = []; stim = [];
			if ~exist('id','var') || isempty(id); return; end
			if ~exist('bodyType','var') || isempty(bodyType); bodyType = 'native'; end
			if ischar(id) || isstring(id)
				names = string({me.bodies.name});
				idx = find(matches(names,id));
			elseif isnumeric(id) && id <= me.nBodies
				idx = id;
			else
				hashes = [me.bodies.hash];
				idx = find(hashes == id);
			end
			if ~isempty(idx)
				if matches(bodyType,'struct')
					body = me.bodies(idx);
				else
					body = me.bodies(idx).body;
				end
				hash = me.bodies(idx).hash;
				stim = me.bodies(idx).stimulus;
				trackidx = find(me.trackIndex == idx);
			end
		end

		% ===================================================================
		%> @brief 
		%> NOTE: input y and vy are in opticka coordinates (-y = up) whereas
		%> world has +y = up, make sure your Y input is in opticka format
		% ===================================================================
		function editBody(me, id, x, y, vx, vy, av, editStim)
			if ~exist('id','var') || isempty(id); return; end
			if ~exist('editStim','var') || isempty(editStim); editStim = false; end
			if isjava(id)
				item = getBody(me, id.hashCode, 'struct');
				body = id;
			else
				item = getBody(me, id, 'struct');
				body = item.body;
			end
			pos = body.getWorldCenter();
			lv = body.getLinearVelocity();
			a = body.getAngularVelocity();

			changePos = false;
			if exist('x','var') && ~isempty(x) && x ~= pos.x
				thisX = x; changePos = true;
			else
				thisX = pos.x;
			end
			if exist('y','var') && ~isempty(y) && y ~= pos.y
				thisY = -y; changePos = true; % thisY is now in dyn4j Y coordinates
			else
				thisY = pos.y;
			end
			if changePos
				item.updatedPosition = [thisX -thisY];
				body.setAtRest(false);
				body.translateToOrigin();
				body.translate(thisX, thisY);
			end
			if editStim % force the visual stimulus to change too, Y is opticka format
				item.stimulus.updateXY(thisX, -thisY, true); 
			end

			changeV = false;
			if exist('vx','var') && ~isempty(vx) && vx ~= lv.x
				thisVX = vx; changeV = true;
			else
				thisVX = lv.x;
			end
			if exist('vy','var') && ~isempty(vy) && vy ~= -lv.y
				thisVY = -vy; changeV = true;
			else
				thisVY = lv.y;
			end
			if changeV
				item.velocity = [thisVX thisVY];
				body.setLinearVelocity(thisVX, thisVY);
			end

			if exist('av','var') && ~isempty(av) && av ~= a
				body.setAngularVelocity(av);
			end

			body.updateMass();

			if me.verbose
				pos2 = body.getWorldCenter();
				lv2 = body.getLinearVelocity();
				a2 = body.getAngularVelocity();
				fprintf('≣≣≣≣⊱ editBody %i: x:%.1f->%.1f y:%.1f->%.1f vx:%.1f->%.1f vy:%.1f->%.1f a:%.1f->%.1f STIM: %.1fx %.1fy\n',...
					body.hashCode, pos.x, pos2.x, pos.y, pos2.y, ...
					lv.x, lv2.x, lv.y, lv2.y, a, a2, item.stimulus.xFinalD, item.stimulus.yFinalD);
			end
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
		function setEnabled(me, id, state)
			if ~exist('id','var') || isempty(id); return; end
			if ~exist('state','var') || isempty(state); state = true; end
			if isjava(id)
				body = id;
			else
				body = getBody(me, id, 'native');
			end
			body.setEnabled(state);
			if me.verbose
				fprintf('≣≣≣≣⊱ setEnabled: %i is enabled: %i\n',body.hashCode,body.isEnabled());
			end
		end

		% ===================================================================
		%> @brief modifies the physics body and opticka stimulus
		%>
		% ===================================================================
		function show(me, id)
			if ~exist('id','var') || isempty(id); return; end
			if isjava(id)
				body =  getBody(me, id.hashCode, 'struct');
			else
				body = getBody(me, id, 'struct');
			end
			body.body.setEnabled(true);
			show(body.stimulus);
			if me.verbose
				fprintf('≣≣≣≣⊱ show: %s is shown\n',body.name);
			end
		end

		% ===================================================================
		%> @brief 
		%>
		% ===================================================================
		function hide(me, id)
			if ~exist('id','var') || isempty(id); return; end
			if isjava(id)
				body =  getBody(me, id.hashCode, 'struct');
			else
				body = getBody(me, id, 'struct');
			end
			body.body.setEnabled(false);
			hide(body.stimulus);
			if me.verbose
				fprintf('≣≣≣≣⊱ hide: %s is hidden\n',body.name);
			end
		end

		% ===================================================================
		%> @brief 
		%>
		% ===================================================================
		function [collision, collisionBody] = isCollision(me, body)
			if ~exist('body','var') || isempty(body); return; end
			if isnumeric(body) 
				body = me.bodies(body);
			elseif ischar(body) || isstring(body)
				body = getBody(me,body);
			end
			collision = false;
			collisionBody = [];
			if isa(body,'org.dyn4j.dynamics.Body')
				c = me.world.getContacts(body);
				if ~isempty(c) && c.size > 0
					collision = true;
					c2 = c.get(0);
					collisionBody = c2.getOtherBody(body);
				end
			end
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
		function update(me)
			setupBodies(me);
			setupWorld(me);
		end

		% ===================================================================
		%> @brief 
		%>
		% ===================================================================
		function setup(me,screen,useBounds)
			if ~exist('screen','var') || isempty(screen); screen = screenManager; end
			if ~exist('useBounds','var') || isempty(useBounds); useBounds = false; end
			me.screen = screen;
			me.useBounds = useBounds;
			me.ppd = me.screen.ppd;
			if isempty(me.timeDelta)
				me.timeDelta = me.screen.screenVals.ifi;
			end
			setupWorld(me);
		end

		% ===================================================================
		%> @brief addScreenBoundaries add physical walls at the screen edges
		%>
		%> @param sv screenVals from screenManager
		%> @param padding [left top right bottom]
		% ===================================================================
		function boundaryStimuli = addScreenBoundaries(me, sv, padding)
			if ~exist('sv','var'); return; end
			if ~exist('padding','var') || isempty(padding); padding = [0 0 0 0]; end

			w = sv.widthInDegrees;
			h = sv.heightInDegrees;
			l = sv.leftInDegrees + padding(1)/2;
			t = sv.topInDegrees + padding(2)/2;
			r = sv.rightInDegrees - padding(3)/2;
			b = sv.bottomInDegrees - padding(4)/2;

			padding(padding == 0) = 0.1; 

			lw = barStimulus('isVisible',false,'barWidth',padding(1),'barHeight',h,...
				'xPosition',l,'yPosition',0,'name','leftwall','colour',me.wallColour);
			cl = barStimulus('isVisible',false,'barWidth',w,'barHeight',padding(2),...
				'xPosition',0,'yPosition',t,'name','ceiling','colour',me.wallColour);
			rw = barStimulus('isVisible',false,'barWidth',padding(3),'barHeight',h,...
				'xPosition',r,'yPosition',0,'name','rightwall','colour',me.wallColour);
			fl = barStimulus('isVisible',false,'barWidth',w,'barHeight',padding(4),...
				'xPosition',0,'yPosition',b,'name','floor','colour',me.wallColour);
						
			me.addBody(lw,'Rectangle','infinite');
			me.addBody(cl,'Rectangle','infinite');
			me.addBody(rw,'Rectangle','infinite');
			me.addBody(fl,'Rectangle','infinite');

			boundaryStimuli = metaStimulus('stimuli', {lw, cl, rw, fl});

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
				me.bodies(ii).stimulus.angleOut = me.bodies(ii).stimulus.angleOut + rad2deg(av) * me.timeDelta;
			end
		end

		% ===================================================================
		%> @brief Load an image
		%>
		% ===================================================================
		function reset(me)
			me.trackIndex	= [];
			if isa(me.world,'org.dyn4j.world.World'); me.world.removeAllBodies(); me.world.removeAllJoints(); end
			me.world		= [];
			me.isFloor		= false;
			me.isLeftWall	= false;
			me.isRightWall	= false;
			me.isCeiling	= false;
			me.hitCeiling	= false;
			me.hitFloor		= false;
			me.hitLeftWall	= false;
			me.hitRightWall = false;
			me.tick			= 0;
			me.timeStep		= [];
			me.torque		= 0;
			me.kineticEnergy = 0;
			me.potentialEnergy = 0;
			me.angle		= 0;
			me.angularVelocity = 0;
			me.x			= [];
			me.y			= [];
			me.dX			= [];
			me.dY			= [];
			me.screenBounds	= [];
		end

		% ===================================================================
		%> @brief 
		%>
		% ===================================================================
		function [fixture, body] = getFixture(me, name, num)
			fixture = [];
			if ~exist('name','var') || isempty(name); return; end
			if ~exist('num','var') || isempty(num); num = 0; end
			body = me.getBody(name);
			if ~isempty(body); fixture = body.getFixture(num); end
		end

		% ===================================================================
		%> @brief 
		%>
		% ===================================================================
		function setSensorState(me, name, state)
			[body, ~, idx] = me.getBody(name);
			fixture = me.getFixture(name,0);
			fixture.setSensor(state);
			if state == true
				body.setMass(me.massType.INFINITE);
			else
				updateMassType(me, me.bodies(idx));
			end
		end

		% ===================================================================
		%> @brief 
		%>
		% ===================================================================
		function name = getBodyName(me, hash)
			if me.nBodies < 1; return; end
			hashes = [me.bodies.hash];
			names = [string({me.bodies.name})];
			idx = hashes == hash;
			name = names(idx);
		end

		% ===================================================================
		%> @brief 
		%>
		% ===================================================================
		function value = get.nBodies(me)
			value = length(me.bodies);
		end

		% ===================================================================
		%> @brief 
		%>
		% ===================================================================
		function value = get.nObstacles(me)
			value = 0;
			for jj = 1:me.nBodies
				if ~matches(me.bodies(jj).type, {'normal','sensor'})
					value = value + 1;
				end
			end
		end

	end % END PUBLIC METHODS
	
	%=======================================================================
	methods ( Static ) % STATIC METHODS
	%=======================================================================
		

		% ===================================================================
		%> @brief dyn4j Vector2
		%>
		% ===================================================================
		function v = vector2(x, y)
			v = javaObject('org.dyn4j.geometry.Vector2', x, y);
		end

		% ===================================================================
		%> @brief
		%>
		% ===================================================================
		function demo()

			% open a new PTB screen
			s = screenManager;
			if max(Screen('Screens')) == 0
				PsychDebugWindowConfiguration([],0.6);
			end
			sv = open(s);

			% create a new animation manager
			a = animationManager;
			a.verbose = true;
			a.timeDelta = sv.ifi;
			stims = a.addScreenBoundaries(sv,[1 1 1 2]);
			
			% create our stimuli
			moon = imageStimulus('filePath','moon.png','size',4);
			moon.name = 'moon';
			moon.xPosition = sv.leftInDegrees+4;
			moon.yPosition = -5;
			moon.direction = 75;
			moon.speed = 25;

			moon2 = clone(moon);
			moon2.xPosition = -moon2.xPosition;
			moon2.speed = -5;
			moon2.direction = -80;

			moon3 = clone(moon);
			moon3.xPosition = 0;
			moon3.yPosition = sv.bottomInDegrees + 5;
			moon3.speed = 25;
			moon3.direction = -180;
			
			sensor = discStimulus('colour',[0.7 0.5 0.5 0.3],'size',8);
			sensor.name = 'sensor';

			% add the stimuli as physics bodies
			% me.addBody(stimulus, shape, type, density, friction, elasticity, angular velocity)
			a.addBody(sensor,'Circle','sensor');
			a.addBody(moon, 'Circle', 'normal', 10, 0.2, 0.8, moon.speed);
			a.addBody(moon2, 'Circle', 'normal', 10, 0.2, 0.8, moon2.speed);
			a.addBody(moon3, 'Circle', 'normal', 10, 0.2, 0.8, moon3.speed);

			% setup all stimuli with PTB screen
			stims.stimuli{end+1} = sensor;
			stims.stimuli{end+1} = moon;
			stims.stimuli{end+1} = moon2;
			stims.stimuli{end+1} = moon3;
			stims.setup(s);
			edit(stims, 1:4, 'colourOut', [0.7 0.3 0 1]);
			
			% setup animationmamager with PTB screen
			a.setup(s);

			RestrictKeysForKbCheck([KbName('LeftArrow') KbName('RightArrow') KbName('UpArrow') KbName('DownArrow') ...
				KbName('1!') KbName('2@') KbName('3#') KbName('space') KbName('ESCAPE') KbName('F1')]);
			Priority(1);

			body = getBody(a,'moon');
			sense = getBody(a, 'sensor');
			
			for jj = 1:sv.fps*60
				step(a);
				v.x = a.linearVelocity(1,1);
				v.y = a.linearVelocity(1,2);
				av = a.angularVelocity(1);
				
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
					elseif strcmpi(KbName(keyCode),'F1')
						captureScreen(s);
					elseif strcmpi(KbName(keyCode),'LeftArrow')
						body.setAtRest(false);
						body.applyImpulse(a.vector2(-40,0));
					elseif strcmpi(KbName(keyCode),'RightArrow')
						body.setAtRest(false);
						body.applyImpulse(a.vector2(40,0));
					elseif strcmpi(KbName(keyCode),'UpArrow')
						body.setAtRest(false);
						body.applyImpulse(a.vector2(0,40));
					elseif strcmpi(KbName(keyCode),'DownArrow')
						body.setAtRest(false);
						ody.applyImpulse(a.vector2(0,-40));
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

				draw(stims);
				s.drawText(sprintf('FULL PHYSICS ENGINE SUPPORT:\n X: %.3f  Y: %.3f VX: %.3f VY: %.3f A: %.3f INBOX: %i R: %.2f',...
					a.x(1),a.y(1),v.x,v.y, av, inBox,3))
				flip(s);
			end

			Priority(0);
			close(s)
			reset(stims); 

			figure;
			tiledlayout(1,1);
			nexttile;
			plot(t,x);
			hold on;
			plot(t,y);
			box on; grid on; axis ij
			legend({'X','Y'})
			xlabel('Time (s)')
			ylabel('X|Y Position')
			% nexttile;
			% plot(t,ke);
			% hold on;
			% plot(t,pe);
			% box on; grid on;
			% xlabel('Time (s)')
			% ylabel('Kinetic|Potential Energy')
			% legend({'KE','PE'})
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
		%> @brief return the first body matching name or hash
		%>
		% ===================================================================
		function [trackidx, idx] = getBodyIDX(me, id)
			idx = []; trackidx = [];
			if ~exist('id','var') || isempty(id); return; end
			if ischar(id)
				names = string({me.bodies.name});
				idx = find(matches(names,id));
			elseif isa(id,'org.dyn4j.dynamics.Body')
				hashes = [me.bodies.hash];
				idx = find(hashes == id.hashCode);
			else
				hashes = [me.bodies.hash];
				idx = find(hashes == id);
			end
			if ~isempty(idx)
				trackidx = find(me.trackIndex == idx);
			end
		end

		% ===================================================================
		%> @brief 
		%>
		% ===================================================================
		function rigidStep(me, tick, updatePositions)
			if exist('tick','var') && iscell(tick) && ~isempty(tick)
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
		function setupWorld(me)
			me.reset;
			me.tick = 0;
			me.timeStep = [];
			me.torque = 0;

			me.world = javaObject('org.dyn4j.world.World');
			me.world.setGravity(me.rigidParams.gravity(1),me.rigidParams.gravity(2));

			if me.useBounds && ~isempty(me.screen.screenVals.rectInDegrees)
				me.screenBounds = me.screen.screenVals.rectInDegrees;
				if me.rigidParams.screenBounds
					bnds = javaObject('org.dyn4j.collision.AxisAlignedBounds', Rectwidth(me.screen.screenVals.rectInDegrees), RectHeight(me.screen.screenVals.rectInDegrees));
					me.world.setBounds(bnds);
				end
			end
			settings = me.world.getSettings();
			settings.setAtRestDetectionEnabled(true);
			settings.setStepFrequency(me.timeDelta);
			settings.setMaximumAtRestLinearVelocity(0.75);
			settings.setMaximumAtRestAngularVelocity(0.5);
			settings.setMinimumAtRestTime(0.2); %def = 0.5

			setupBodies(me);
			fprintf('≣≣≣≣⊱ RigidBody World with %.3fs step time created!\n',settings.getStepFrequency);
			fprintf('\t Adding bodies: ');
			for i = 1:me.nBodies
				fprintf('%s  ',me.bodies(i).name);
				me.world.addBody(me.bodies(i).body);
			end
			fprintf('\n');
			makeTrackIndex(me);
		end

		% ===================================================================
		%> @brief 
		%>
		% ===================================================================
		function setupBodies(me)
			for ii = 1:me.nBodies
				thisBody = me.bodies(ii);
				setupBody(me, thisBody);
			end
		end

		% ===================================================================
		%> @brief 
		%>
		% ===================================================================
		function setupBody(me, thisBody)
			if isempty(thisBody.theta); thisBody.theta = 0; end
			thisBody.position = [thisBody.stimulus.xPosition -thisBody.stimulus.yPosition];
			if isempty(thisBody.velocity); thisBody.velocity = [0 0]; end

			fixture = thisBody.body.getFixture(0);
			fixture.setDensity(thisBody.density);
			fixture.setFriction(thisBody.friction);
			fixture.setRestitution(thisBody.elasticity); % set coefficient of restitution

			av = updateMassType(me, thisBody);
	
			thisBody.body.translateToOrigin();
			thisBody.body.translate(thisBody.position(1), thisBody.position(2));
			thisBody.body.setLinearVelocity(javaObject('org.dyn4j.geometry.Vector2', thisBody.velocity(1), thisBody.velocity(2)));
			thisBody.body.setAngularVelocity(av);
			thisBody.body.setLinearDamping(me.rigidParams.linearDamping);
			thisBody.body.setAngularDamping(me.rigidParams.angularDamping);
		end

		% ===================================================================
		%> @brief 
		%>
		% ===================================================================
		function av = updateMassType(me, thisBody, type)
			if ~exist('type','var') || isempty(type); type = 'normal'; end
			if matches(lower(thisBody.type),'normal')
				[cx,cy] = pol2cart(thisBody.theta, thisBody.stimulus.speed);
				thisBody.body.setMass(me.massType.NORMAL);
				thisBody.velocity = [cx -cy];
				av = cx/2;
			elseif matches(lower(thisBody.type),'sensor')
				fixture = thisBody.body.getFixture(0);
				fixture.setSensor(true);
				thisBody.velocity = [0 0];
				thisBody.body.setMass(me.massType.INFINITE);
				av = 0;
			else
				thisBody.velocity = [0 0];
				thisBody.body.setMass(me.massType.INFINITE);
				av = 0;
			end
			thisBody.body.updateMass();
		end

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
			reset(me);
			me.salutation('DELETE Method','animationManager object Cleaning up...')
		end
		
	end
end