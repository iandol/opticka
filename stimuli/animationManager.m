% ========================================================================
%> @brief ANIMATIONMANAGER TODO provides per frame paths for stimuli
%>
%> @todo build the physics code for the different types of motion
%>
%> Copyright ©2014-2022 Ian Max Andolina — released: LGPL3, see LICENCE.md
% ========================================================================	
classdef animationManager < optickaCore
	properties
		%> type of animation path, rigid | linear | sinusoidal | brownian | circular
		type char ...
			{mustBeMember(type,{'rigid','linear','sinusoidal','brownian','circular'})} = 'rigid'
		%> parameters for each animation type
		rigidparams = struct('radius', 2, 'mass', 2, ...
			'position', [0, 0], 'velocity', [1, 0], ...
			'airResistanceCoeff', 0.2, 'elasticityCoeff', 0.8, ...
			'gravity', 9.8,...
			'floor', 10, 'leftwall', [], 'rightwall', [], 'ceiling', [],...
			'avoidRects',[]);
		timeDelta		= 0.01
		%> what happens at edge of screen [bounce | wrap | none]
		boundsCheck char ...
			{mustBeMember(boundsCheck,{'bounce','wrap','none'})} = 'bounce'
		%> verbose?
		verbose = true
		%> default length of the animation in seconds for prerendering
		timeToEnd double = 10
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
		%> stimulus
		stimulus
	end
	
	properties (SetAccess = private, GetAccess = private)
		%> useful screen info and initial gamma tables and the like
		screenVals struct
		%> what properties are allowed to be passed on construction
		allowedProperties='type|speed|angle|startPosition|verbose'
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
		end
		
		% ===================================================================
		%> @brief Load an image
		%>
		% ===================================================================
		function setup(me, stimulus)
			me.reset;
			me.stimulus = stimulus;
			me.ppd = stimulus.ppd;
			me.x = stimulus.sM.toDegrees(stimulus.xFinal,'x');
			me.y = stimulus.sM.toDegrees(stimulus.yFinal,'y');
			me.rigidparams.radius = stimulus.size/2;
			me.tick = 0;
			me.timeStep = [];
			me.torque = 0;
			me.angularVelocity = 0;
			me.momentOfInertia = 0.5 * me.rigidparams.mass * me.rigidparams.radius^2;

			if ~isempty(me.findprop('direction'))
				me.angle = deg2rad(stimulus.direction);
			else
				me.angle = deg2rad(stimulus.angle);
			end

			[me.dX, me.dY] = pol2cart(me.angle, stimulus.speed);
			me.rigidparams.position = [me.x me.y];
			me.rigidparams.velocity = [me.dX me.dY];
		end
		
		% ===================================================================
		%> @brief Load an image
		%>
		% ===================================================================
		function animate(me)
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
			me.momentOfInertia = 0.5 * me.rigidparams.mass * me.rigidparams.radius^2;
		end

		% ===================================================================
		%> @brief Load an image
		%>
		% ===================================================================
		function rigidStep(me)
			if isempty(me.timeStep) 
				me.timeStep = 0;
				me.tick = 1;
			else
				me.timeStep = me.timeStep + me.timeDelta;
				me.tick = me.tick + 1;
			end

			position = [me.x, me.y];
			velocity = [me.dX, me.dY];
			acceleration = [0, me.rigidparams.gravity]; 
			r = me.rigidparams.radius;

    		% Apply air resistance
    		airResistance = -me.rigidparams.airResistanceCoeff * velocity;
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
			if me.y + r > me.rigidparams.floor
    			me.y = me.rigidparams.floor - r - 0.01;
    			velocity(2) = -me.rigidparams.elasticityCoeff * velocity(2); % reverse and dampen the y-velocity
    			me.angularVelocity = -me.rigidparams.elasticityCoeff * me.angularVelocity; % reverse and dampen the angular velocity
			end
			% Collision detection with floor
			if me.y - r < me.rigidparams.ceiling
    			me.y = me.rigidparams.ceiling + r + 0.01;
    			velocity(2) = -me.rigidparams.elasticityCoeff * velocity(2); % reverse and dampen the y-velocity
    			me.angularVelocity = -me.rigidparams.elasticityCoeff * me.angularVelocity; % reverse and dampen the angular velocity
			end
			% Collision detection with walls
			if me.x - r < me.rigidparams.leftwall
    			me.x = me.rigidparams.leftwall + r;
    			velocity(1) = -me.rigidparams.elasticityCoeff * velocity(1); % reverse and dampen the x-velocity
    			me.angularVelocity = -me.rigidparams.elasticityCoeff * me.angularVelocity; % reverse and dampen the angular velocity
			end
			if me.x + r > me.rigidparams.rightwall
    			me.x = me.rigidparams.rightwall - r	;
    			velocity(1) = -me.rigidparams.elasticityCoeff * velocity(1); % reverse and dampen the x-velocity
    			me.angularVelocity = -me.rigidparams.elasticityCoeff * me.angularVelocity; % reverse and dampen the angular velocity
			end
			if ~isempty(me.rigidparams.avoidRects)
				for i = 1:size(me.rigidparams.avoidRects)
					
				end
			end

			me.dX = velocity(1);
			me.dY = velocity(2);

			% Calculate the arc length traveled
    		arcLength = me.dX * me.timeDelta;
    		
    		% Update angle based on arc length
    		me.angle = me.angle - arcLength / me.rigidparams.radius;

			me.kineticEnergy = 0.5 * me.rigidparams.mass * norm(velocity)^2 + 0.5 * me.momentOfInertia * me.angularVelocity^2;
			me.potentialEnergy = me.rigidparams.mass * -me.rigidparams.gravity * (me.y - me.rigidparams.radius - me.rigidparams.floor);
		end

		% ===================================================================
		%> @brief Load an image
		%>
		% ===================================================================
		function editBody(me,x,y,dx,dy)
			if exist('x','var') && ~isempty(x); me.x = x; end
			if exist('y','var') && ~isempty(y); me.y = y; end
			if exist('dx','var') && ~isempty(dx); me.dX = dx; end
			if exist('dy','var') && ~isempty(dy); me.dY = dy; end
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
			s =screenManager;
			i = imageStimulus('size',4);
			i.filePath = '/home/cog5/Downloads/moon.png';
			i.xPosition = -5;
			i.yPosition = 5;
			i.angle = 45;
			i.speed = 20;
			
			sv = open(s);
			
			a = animationManager;
			a.rigidparams.mass = 5;
			a.rigidparams.leftwall = sv.leftInDegrees;
			a.rigidparams.rightwall = sv.rightInDegrees;
			a.rigidparams.floor = sv.bottomInDegrees;
			a.timeDelta = sv.ifi;
			
			setup(i, s);
			
			setup(a, i);
			
			for jj = 1:sv.fps*10
			
				draw(i);
				flip(s);
				i.updateXY(a.x, a.y, true);
				i.angleOut = -rad2deg(a.angle);
				animate(a);
				t(jj)=a.timeStep;
				x(jj)=a.x;
				y(jj)=a.y;
				ke(jj) = a.kineticEnergy;
				pe(jj) = a.potentialEnergy;
			
			end
			
			close(s)
			reset(i);
			
			figure
			tiledlayout(2,1);
			nexttile
			plot(t,x);
			hold on
			plot(t,y);
			nexttile
			plot(t,ke);
			hold on
			plot(t,pe);
		
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