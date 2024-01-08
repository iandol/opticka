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
			'airResistanceCoeff', -0.1, 'elasticityCoeff', 0.8, ...
			'gravity', -9.8,...
			'floor', -20, 'leftwall', [], 'rightwall', []);
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
		
		function setup(me, stimulus)
			me.stimulus = stimulus;
			me.ppd = stimulus.ppd;
			me.rigidparams.x = stimulus.xPositionOut;
			me.rigidparams.y = stimulus.yPositionOut;
			me.dstRect = stimulus.dstRect;
			me.mvRect = stimulus.mvRect;
			me.tick = 0;
			me.timeStep = [];
			me.speed = stimulus.speed;
			me.torque = 0;
			me.angularVelocity = 0;
			me.momentOfInertia = 0.5 * me.rigidparams.mass * me.rigidparams.radius^2;

			if ~isempty(me.findprop('direction'))
				me.angle = stimulus.direction;
			else
				me.angle = stimulus.angle;
			end

			[me.dX, me.dY] = pol2cart(deg2rad(me.angle, me.speed));
			me.rigidStep(me.timeStep);

		end
		
		function animate(me)
			switch me.type
				case 'rigid'
					rigidStep(me);
			end
		end

		
		function reset(me)
			me.tick = 0;
			me.timeStep = [];
			me.dX = [];
			me.dY = [];
			me.dstRect = [];
			me.mvRect = [];
		end

		function rigidStep(me)
			if isempty(me.timeStep) 
				me.timeStep = 0;
				me.tick = 1;
			else
				me.timeStep = me.timeStep + me.rigidparams.timeDelta;
				me.tick = me.tick + 1;
			end

			velocity = [me.dX, me.dY];
			acceleration = [0, me.rigidparams.gravity]; 

    		% Apply air resistance
    		airResistance = me.rigidparams.airResistanceCoeff * velocity;
    		acceleration = acceleration + airResistance;
    		
    		% Update velocity and position
    		velocity = velocity + acceleration * me.rigidparams.timeDelta;
    		position = position + velocity * me.rigidparams.timeDelta;
    		
    		% Calculate angular acceleration
    		angularAcceleration = torque / me.momentOfInertia;
    		
    		% Update angular velocity and position
    		me.angularVelocity = me.angularVelocity + angularAcceleration * me.rigidparams.timeDelta;
    		me.angle = me.angle + me.angularVelocity * me.rigidparams.timeDelta;

			% Collision detection with floor
			if me.y - me.rigidparams.radius < me.rigidparams.floorY
    			me.y = me.rigidparams.floorY + me.rigidparams.radius;
    			velocity(2) = -me.rigidparams.elasticityCoeff * velocity(2); % reverse and dampen the y-velocity
    			me.angularVelocity = me.rigidparams.elasticityCoeff * me.angularVelocity; % reverse and dampen the angular velocity
			end
			
			% Collision detection with walls
			if ~isempty(me.rigidparams.leftwall) && me.x - me.rigidparams.radius < me.rigidparams.leftwall
    			me.x = me.rigidparams.leftwall + me.rigidparams.radius;
    			velocity(1) = -me.rigidparams.elasticityCoeff * velocity(1); % reverse and dampen the x-velocity
    			me.angularVelocity = -me.rigidparams.elasticityCoeff * me.angularVelocity; % reverse and dampen the angular velocity
			end
			if ~isempty(me.rigidparams.rightwall) && me.x + me.rigidparams.radius > me.rigidparams.rightwall
    			me.x = me.rigidparams.rightwall - me.rigidparams.radius;
    			velocity(1) = -me.rigidparams.elasticityCoeff * velocity(1); % reverse and dampen the x-velocity
    			me.angularVelocity = -me.rigidparams.elasticityCoeff * me.angularVelocity; % reverse and dampen the angular velocity
			end
			me.dX = velocity(1);
			me.dY = velocity(2);

			% Calculate the arc length traveled
    		arcLength = me.dX * me.rigidparams.timeDelta;
    		
    		% Update angle based on arc length
    		me.angle = me.angle - arcLength / me.rigidparams.radius;

			me.kineticEnergy = 0.5 * me.rigidparams.mass * norm(velocity)^2 + 0.5 * me.momentOfInertia * me.angularVelocity^2;
			me.potentialEnergy = me.rigidparams.mass * -me.rigidparams.gravity * (me.y - me.rigidparams.radius - me.rigidparams.floorY);
		end
		
	end
	
	%=======================================================================
	methods ( Static ) % STATIC METHODS
	%=======================================================================
		
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
			dX = delta .* cos(baseStimulus.d2r(angle));
			dY = delta .* sin(baseStimulus.d2r(angle));
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