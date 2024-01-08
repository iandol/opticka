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
			'airResistanceCoeff', 0.1, 'elasticityCoeff', 0.8, ...
			'acceleration',[0, -9.8],...
			'floor',-100)
		timeDelta		= 0.01
		%> what happens at edge of screen [bounce | wrap | none]
		boundsCheck char ...
			{mustBeMember(boundsCheck,{'bounce','wrap','none'})} = 'bounce'
		%> verbose?
		verbose = true
		%> length of the animation in seconds
		timeToEnd double = 10
	end
	
	properties (SetAccess = private, GetAccess = public)
		%> tick updates +1 on each draw, resets on each update
		tick double = 0
		%> current time step in simulation
		timeStep = 0
		%> angle
		anglev = 0
		%> radius of object
		radius 
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
		gravity	double		= -9.8
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
			me.timeStep = 0;
			me.speed = stimulus.speed;
			if ~isempty(me.findprop('direction'))
				me.angle = stimulus.direction;
			else
				me.angle = stimulus.angle;
			end
			me.rigidStep(me.timeStep);
		end
		
		function animate
			
		end

		function pos = update(me)
			if me.isRect
				me.mvRect=OffsetRect(me.mvRect,me.dX,me.dY);
				pos = me.mvRect;
			else
				me.xFinal = me.xFinal + me.dX;
				me.yFinal = me.yFinal + me.dY;
				pos = [me.xFinal me.yFinal];
			end
		end
		
		function reset(me)
			me.tick = 0;
			me.xFinal = [];
			me.yFinal = [];
			me.dstRect = [];
			me.mvRect = [];
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

		function rigidStep(me)
			
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