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
%> When `type` is 'lissajous' no physics is used: a lissajousPath is
%> generated at the display frame rate by setup(), then animate()/step()
%> advances one frame and updates x, y (degrees) and, when orientToPath is
%> true, angle. Attach the manager to a stimulus *before* stimulus setup,
%> which then sets the manager up with its screenManager:
%>
%> ```matlab
%> s = screenManager; open(s);
%> im = imageStimulus('filePath','moon.png','size',2);
%> a = animationManager('type','lissajous');
%> a.lissajous.a = 3; a.lissajous.b = 4; a.lissajous.delta = pi/4;
%> a.lissajous.size = 12; a.lissajous.speed = 8;
%> im.animator = a;
%> setup(im, s);        %> generates the path at the screen frame rate
%> for i = 1:a.nFrames
%> 	draw(im); flip(s); animate(im);   %> animate pulls the next X/Y
%> end
%> ```
%>
%> @TODO build the remaining motion path types apart from rigid and
%> lissajous. These could be static methods.
%>
%> Contributions: Heting Zhang
%> Copyright ©2014-2025 Ian Max Andolina — released: LGPL3, see LICENCE.md
% ========================================================================	
classdef animationManager < optickaCore

	properties
		%> type of animation path: rigid | lissajous | linear | sinusoidal |
		%> brownian | circular; rigid and lissajous are implemented
		type char ...
			{mustBeMember(type,{'rigid','lissajous','linear','sinusoidal','brownian','circular'})} ...
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
		%> lissajous path generator used when type = 'lissajous'; set its
		%> a, b, delta, size, speed, totalTime, xPosition and yPosition then
		%> setup() generates one frame per display refresh at the screen fps
		lissajous lissajousPath = lissajousPath.empty()
		%> orient stimuli to the path tangent each frame, stimuli copy the
		%> resulting angle to their angleOut; false keeps stimuli upright
		orientToPath logical = false
		%> screen rectangle in degrees [left top right bottom] used for the
		%> world bounds when rigidParams.screenBounds is true; setup()
		%> fills this from a screenManager, set it directly for headless
		%> or offline use
		screenBounds = []
	end

	properties (Dependent = true, SetAccess = protected, GetAccess = public)
		nBodies
		nObstacles
		%> number of frames in a lissajous path, 0 for other types
		nFrames
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
		%> types of bodies in dyn4j
		massType		= struct('NORMAL',[],'INFINITE',[],'FIXED_ANGULAR_VELOCITY',[],'FIXED_LINEAR_VELOCITY',[])
		%> did we setup the manager with a PTB scren etc.?
		isSetup logical		= false
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
		allowedProperties = ["type","bodies","rigidParams","brownianParams",...
			"timeDelta","verbose","boundsCheck","timeToEnd","lissajous",...
			"orientToPath","screenBounds"]
	end

	properties (Constant = true)
		%> dyn4j version bundled in stimuli/lib and required at runtime;
		%> bump this (and the jar) together when upgrading dyn4j, the
		%> constructor verifies the version Java actually loaded
		dyn4jVersion char = '6.0.0'
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
			if isempty(me.lissajous)
				me.lissajous = lissajousPath('verbose',false);
			end
			try
				% dyn4j jar -- see https://dyn4j.org/pages/getting-started
				% Only add the jar when the required version is not already
				% on the class path (static or dynamic): re-adding an
				% existing jar makes MATLAB try to `clear java`, which warns
				% ("Objects of org/dyn4j/geometry/MassType class exist - not
				% clearing java") whenever another animationManager is
				% alive. Any *other* dyn4j already on the path silently wins
				% the class lookup, so loadDyn4j checks the version Java
				% actually reports before we use it.
				animationManager.loadDyn4j(me.paths.whereami, me.dyn4jVersion);
				me.massType.NORMAL = javaMethod('valueOf', 'org.dyn4j.geometry.MassType', 'NORMAL');
    			me.massType.INFINITE = javaMethod('valueOf', 'org.dyn4j.geometry.MassType', 'INFINITE');
				me.massType.FIXED_ANGULAR_VELOCITY = javaMethod('valueOf', 'org.dyn4j.geometry.MassType', 'FIXED_ANGULAR_VELOCITY');
				me.massType.FIXED_LINEAR_VELOCITY = javaMethod('valueOf', 'org.dyn4j.geometry.MassType', 'FIXED_LINEAR_VELOCITY');
			catch ME
				%> a wrong or missing jar is a packaging error: rethrow so
				%> tests and users see it instead of an "environment
				%> unavailable" message
				if any(strcmp(ME.identifier, {'animationManager:dyn4jVersion', ...
						'animationManager:dyn4jJarMissing'}))
					rethrow(ME)
				end
				error('animationManager:dyn4jLoad', ...
					'Could not load dyn4j %s: %s\nEnsure Java is installed and Opticka is properly added to path.', ...
					me.dyn4jVersion, ME.message)
			end
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
					if id(j) > 0 && id(j) <= me.nBodies
						rmIdx = [rmIdx id(j)];
					end
				end
			end
			if isempty(rmIdx); return; end
			%> drop the bodies from the physics world as well: removing
			%> only our record leaves them colliding in the simulation
			if isa(me.world,'org.dyn4j.world.World')
				for j = rmIdx
					me.world.removeBody(me.bodies(j).body);
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
		function setup(me, screen, useBounds)
			if ~exist('useBounds','var') || isempty(useBounds); useBounds = false; end
			me.useBounds = useBounds;

			%> resolve the screen: a screenManager, a struct of screen
			%> values (fps/ifi/ppd, for offline use) or a stored manager
			thisScreen = [];
			if exist('screen','var') && ~isempty(screen) && ...
					(isa(screen,'screenManager') || isstruct(screen))
				thisScreen = screen;
			elseif isscalar(me.screen) && isa(me.screen,'screenManager')
				thisScreen = me.screen;
			end

			if isa(thisScreen,'screenManager')
				me.screen = thisScreen;
				me.ppd = thisScreen.ppd;
				if isempty(me.timeDelta)
					me.timeDelta = thisScreen.screenVals.ifi;
				end
			elseif isstruct(thisScreen)
				if isfield(thisScreen,'ppd') && ~isempty(thisScreen.ppd)
					me.ppd = thisScreen.ppd;
				end
				if isempty(me.timeDelta)
					if isfield(thisScreen,'ifi') && ~isempty(thisScreen.ifi)
						me.timeDelta = thisScreen.ifi;
					elseif isfield(thisScreen,'fps') && ~isempty(thisScreen.fps)
						me.timeDelta = 1 / thisScreen.fps;
					end
				end
			end
			if isempty(me.timeDelta); me.timeDelta = 1/60; end

			if matches(me.type,'lissajous')
				me.reset; %> clear any previous world and path
				if isempty(me.lissajous)
					me.lissajous = lissajousPath('verbose',false);
				end
				if isempty(thisScreen)
					thisScreen = struct('fps',1/me.timeDelta,'ppd',me.ppd);
				end
				me.lissajous.setup(thisScreen);
				me.x = me.lissajous.x(1);
				me.y = me.lissajous.y(1);
				me.isSetup = true;
				if me.verbose
					fprintf(['≣≣≣≣⊱ Lissajous %g:%g δ=%0.3f path: %i frames ' ...
						'@ %gHz (%.3fs, %0.2f° arc)\n'],...
						me.lissajous.a,me.lissajous.b,me.lissajous.delta,...
						me.lissajous.nFrames,me.lissajous.fps,...
						me.lissajous.duration,me.lissajous.arcLength);
				end
			else
				setupWorld(me);
				me.isSetup = true;
			end
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
				case 'lissajous'
					stepLissajous(me,varargin);
			end
		end

		% ===================================================================
		%> @brief animate advances the animation by one frame
		%>
		%> Stimuli call animate(me.animator) from their own animate() method
		%> then copy animator.x / animator.y (degrees) to their position. For
		%> 'lissajous' this advances one path frame; for 'rigid' it steps the
		%> physics world by one timeDelta.
		% ===================================================================
		function animate(me)
			me.step();
		end

		% ===================================================================
		%> @brief rewind returns a lissajous animation to its first frame
		%>
		%> Keeps the generated path so a trial can be repeated cheaply
		%> without calling setup() again. No effect on other types.
		% ===================================================================
		function rewind(me)
			if ~isempty(me.lissajous)
				me.lissajous.rewind();
			end
			me.tick = 0;
			me.timeStep = 0;
			me.angle = 0;
			%> expose the first position so syncAnimator() can place the
			%> stimulus on the path start straight after a rewind
			if me.isSetup && ~isempty(me.lissajous) && me.lissajous.nFrames > 0
				me.x = me.lissajous.x(1);
				me.y = me.lissajous.y(1);
			else
				me.x = [];
				me.y = [];
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
			if ~isempty(me.lissajous)
				me.lissajous.reset();
			end
			me.isSetup		= false;
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
			if state == true
				body.setMass(me.massType.INFINITE);
			else
				updateMassType(me, me.bodies(idx));
			end
			%> set the flag last: updateMassType re-applies the sensor
			%> state for bodies whose stored type is 'sensor'
			fixture.setSensor(state);
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

		% ===================================================================
		%> @brief number of frames in a lissajous path
		% ===================================================================
		function value = get.nFrames(me)
			if matches(me.type,'lissajous') && ~isempty(me.lissajous)
				value = me.lissajous.nFrames;
			else
				value = 0;
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
		%> @brief loadedDyn4jVersion reports the dyn4j version Java loaded
		%>
		%> The class path, not Opticka, decides which dyn4j classes are
		%> used: a stale jar (say 5.0.2 left over from another checkout)
		%> added before the bundled one wins the class lookup. The
		%> constructor verifies this against the `dyn4jVersion` constant,
		%> this accessor makes the same check available for diagnostics.
		%>
		%> @return version string, e.g. '6.0.0', or '' when dyn4j is not
		%> on the Java class path at all
		% ===================================================================
		function version = loadedDyn4jVersion()
			version = '';
			try
				version = char(javaMethod('getVersion', 'org.dyn4j.Version'));
			catch
				version = '';
			end
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
		%> @brief demoLissajous animate an image along a lissajous path
		%>
		%> Opens a screen, attaches an animationManager of type 'lissajous'
		%> to an imageStimulus, then animates it through the stimulus
		%> animate() method. Press ESC to stop.
		% ===================================================================
		function demoLissajous()
			s = screenManager;
			if max(Screen('Screens')) == 0
				PsychDebugWindowConfiguration([],0.6);
			end
			open(s);
			img = imageStimulus('filePath','moon.png','size',2);
			img.animator = animationManager('type','lissajous');
			img.animator.lissajous.a = 3;
			img.animator.lissajous.b = 4;
			img.animator.lissajous.delta = pi/4;
			img.animator.lissajous.size = 12;
			img.animator.lissajous.speed = 8;
			setup(img,s); %> stimulus setup generates the path at screen fps

			RestrictKeysForKbCheck(KbName('ESCAPE'));
			Priority(1);
			for i = 1:img.animator.nFrames
				draw(img);
				drawText(s,sprintf('Lissajous %g:%g  frame %i/%i',...
					img.animator.lissajous.a,img.animator.lissajous.b,...
					img.animator.tick,img.animator.nFrames));
				flip(s);
				animate(img);
				[isKey,~,keyCode] = KbCheck(-1);
				if isKey && keyCode(KbName('ESCAPE')); break; end
			end
			Priority(0);
			reset(img);
			close(s);
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
	methods ( Static, Access = protected ) % PROTECTED STATIC METHODS
	%=======================================================================

		% ===================================================================
		%> @brief loadDyn4j make sure the required dyn4j version is loaded
		%>
		%> Adds the jar bundled in stimuli/lib when Java is not already
		%> running the required version, then verifies the version Java
		%> reports. Errors with animationManager:dyn4jVersion when the
		%> required version cannot be loaded, which normally means an older
		%> dyn4j jar was added earlier in this MATLAB session (a JVM cannot
		%> unload classes).
		%>
		%> @param whereami Opticka root folder (me.paths.whereami)
		%> @param required dyn4j version the class expects
		% ===================================================================
		function loadDyn4j(whereami, required)
			if strcmp(animationManager.loadedDyn4jVersion(), required)
				return
			end
			jarFile = fullfile(whereami, 'stimuli', 'lib', ...
				sprintf('dyn4j-%s.jar', required));
			if ~exist(jarFile, 'file')
				error('animationManager:dyn4jJarMissing', ...
					'The bundled dyn4j jar was not found: %s', jarFile);
			end
			javaaddpath(jarFile, '-begin');
			loaded = animationManager.loadedDyn4jVersion();
			if ~strcmp(loaded, required)
				if isempty(loaded)
					loaded = 'no dyn4j';
				else
					loaded = ['dyn4j ' loaded];
				end
				error('animationManager:dyn4jVersion', ...
					['animationManager requires dyn4j %s but %s is on the ' ...
					'Java class path. Restart MATLAB (the JVM cannot ' ...
					'unload classes), remove the other dyn4j jar from ' ...
					'javaclasspath, then construct animationManager again.'], ...
					required, loaded);
			end
		end

	end % END PROTECTED STATIC METHODS

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
		%> @brief stepLissajous advances a lissajous path by n frames
		%>
		%> Updates x and y (degrees), tick and timeStep. The path loops
		%> automatically at the end of the curve and the angle is set to the
		%> tangent direction when orientToPath is true.
		% ===================================================================
		function stepLissajous(me, args)
			if ~me.isSetup || isempty(me.lissajous) || me.lissajous.nFrames < 1
				error('animationManager:notSetup',...
					'You need to setup() animationManager BEFORE you can animate() or step()');
			end
			n = 1;
			if ~isempty(args) && isnumeric(args{1}) && ~isempty(args{1})
				n = max(1,round(args{1}));
			end
			for i = 1:n
				[x,y] = me.lissajous.step();
			end
			me.tick = me.lissajous.tick;
			me.timeStep = (me.tick - 1) * me.timeDelta;
			me.x = x;
			me.y = y;
			if me.orientToPath
				me.angle = deg2rad(me.lissajous.direction(me.lissajous.tick));
			else
				me.angle = 0;
			end
		end

		% ===================================================================
		%> @brief 
		%>
		% ===================================================================
		function rigidStep(me, tick, updatePositions)
			if exist('tick','var') && iscell(tick) && ~isempty(tick)
				% this was passed as varargin so it ends up wrapped in a
				% cell, unwrap it
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

			%> remember the screen rectangle in degrees so the world bounds
			%> can be related to the PTB dimensions
			if me.useBounds && isscalar(me.screen) && ...
					~isempty(me.screen.screenVals.rectInDegrees)
				me.screenBounds = me.screen.screenVals.rectInDegrees;
			end
			%> AxisAlignedBounds is centred on the origin and wants the
			%> width/height, not the PTB rect: r = [left top right bottom]
			if me.rigidParams.screenBounds && ~isempty(me.screenBounds)
				r = me.screenBounds;
				bnds = javaObject('org.dyn4j.collision.AxisAlignedBounds', ...
					r(3)-r(1), r(4)-r(2));
				me.world.setBounds(bnds);
			end
			settings = me.world.getSettings();
			settings.setAtRestDetectionEnabled(true);
			settings.setStepFrequency(me.timeDelta);
			settings.setMaximumAtRestLinearVelocity(0.75);
			settings.setMaximumAtRestAngularVelocity(0.5);
			settings.setMinimumAtRestTime(0.2); %def = 0.5

			setupBodies(me);
			if me.verbose
				fprintf('≣≣≣≣⊱ RigidBody World with %.3fs step time created!\n',settings.getStepFrequency);
				fprintf('	 Adding bodies: ');
			end
			for i = 1:me.nBodies
				if me.verbose; fprintf('%s  ',me.bodies(i).name); end
				me.world.addBody(me.bodies(i).body);
			end
			if me.verbose; fprintf('\n'); end
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