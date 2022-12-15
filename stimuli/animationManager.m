% ========================================================================
%> @brief ANIMATIONMANAGER TODO provides per frame paths for stimuli
%>
%> @todo build the physics code for the different types of motion
%>
%> Copyright ©2014-2022 Ian Max Andolina — released: LGPL3, see LICENCE.md
% ========================================================================	
classdef animationManager < optickaCore
	properties
		%> type of animation path, linear | sinusoidal | brownian | circular
		type char ...
			{mustBeMember(type,{'linear','sinusoidal','brownian','circular'})} = 'linear'
		%> parameters for each animation type
		params struct
		%> for random walks what is the variance in angle?
		angleVariance double = 0
		%> what happens at edge of screen [wrap | bounce | none]
		boundsCheck char ...
			{mustBeMember(boundsCheck,{'wrap','bounce','none'})} = 'wrap'
		%> verbose?
		verbose = true
		%> seed for random walks
		seed uint32
		%> length of the animation in seconds
		length double = inf
	end
	
	properties (SetAccess = private, GetAccess = public)
		%> speed in deg/s
		speed double = 1
		%> the direction of the whole grating object - i.e. the object can
		%> move (speed property) as well as the grating texture rotate within the object.
		direction = 0
		%> angle in deg, if animation is circular, this is added 
		angle double = 0
		%> For moving stimuli do we start "before" our initial position? THis allows you to
		%> center a stimulus at a screen location, but then drift it across that location, so
		%> if xyPosition is 0,0 and startPosition is -2 then the stimulus will start at -2 drifing
		%> towards 0.
		startPosition double = 0
		%> do we lock the angle to the direction? If so what is the offset
		%> (0 = parallel, 90 = orthogonal etc.)
		lockAngle double = []
		%> tick updates +1 on each draw, resets on each update
		tick double = 0
		%> computed X position 
		xOut double = []
		%> computed Y position
		yOut double = []
		%> X update 
		dX double
		%> Y update 
		dY double
		%> source screen rectangle position [LEFT TOP RIGHT BOTTOM]
		dstRect double = []
		%> current screen rectangle position [LEFT TOP RIGHT BOTTOM]
		mvRect double = []
		%> pixels per degree, inhereted from a screenManager
		ppd double = 36
		%> stimulus position defined as rect [true] or point [false]
		isRect logical = true
		%> screen manager link
		screen
	end
	
	properties (SetAccess = private, Dependent = true)
		
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
			me.xFinal = stimulus.xOut;
			me.yFinal = stimulus.yFinal;
			me.dstRect = stimulus.dstRect;
			me.mvRect = stimulus.mvRect;
			me.tick = 0;
			me.speed = stimulus.speed;
			if ~isempty(me.findprop('direction'))
				me.angle = stimulus.direction;
			else
				me.angle = stimulus.angle;
			end
			me.startPosition = stimulus.startPosition;
			me.isRect = stimulus.isRect;
			me.screenVals = stimulus.sM.screenVals;
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
		
	end % END STATIC METHODS

	%=======================================================================
	methods ( Access = private ) % PRIVATE METHODS
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