% ========================================================================
%> @brief ANIMATIONMANAGER provides per frame paths for stimuli
%>
% ========================================================================
classdef animationManager < optickaCore
	
	properties
		%> type of animation path, linear | brownian | circular
		type char = 'linear'
		%> length of the animation in seconds
		length double = 2
		%> speed in deg/s
		speed double = 1
		%> angle in deg, if animation is circular, this is added 
		angle double = 0
		%> For moving stimuli do we start "before" our initial position? THis allows you to
		%> center a stimulus at a screen location, but then drift it across that location, so
		%> if xyPosition is 0,0 and startPosition is -2 then the stimulus will start at -2 drifing
		%> towards 0.
		startPosition double = 0
		%> for random walks what is the variance in angle?
		angleVariance double = 0
		%> wrap when leaving the screen?
		wrap logical = false
		%> bounce when hitting the edge?
		bounce logical = false
		%> verbose?
		verbose = true
	end
	
	properties (SetAccess = private, GetAccess = public)
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
		%> pixels per degree (normally inhereted from screenManager)
		ppd double = 36
		%> stimulus position defined as rect [true] or point [false]
		isRect logical = true
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
			if nargin == 0; varargin.name = 'animationManager'; end
			me=me@optickaCore(varargin); %superclass constructor
			me.parseArgs(varargin, me.allowedProperties);
			
		end
		
		function setup(me, stimulus)
			me.xOut = stimulus.xOut;
			me.yOut = stimulus.yOut;
			me.dstRect = stimulus.dstRect;
			me.mvRect = stimulus.mvRect;
			me.tick = 0;
			me.speed = stimulus.speed;
			if ~isempty(me.findprop('motionAngle'))
				me.angle = stimulus.motionAngle;
			else
				me.angle = stimulus.angle;
			end
			me.startPosition = stimulus.startPosition;
			me.isRect = stimulus.isRect;
			me.screenVals = stimulus.sM.screenVals;
		end
		
		
		function pos = update(me)
			if me.isRect
				me.mvRect=OffsetRect(me.mvRect,me.dX,me.dY);
				pos = me.mvRect;
			else
				me.xOut = me.xOut + me.dX;
				me.yOut = me.yOut + me.dY;
				pos = [me.xOut me.yOut];
			end
		end
		
		function reset(me)
			me.tick = 0;
			me.xOut = [];
			me.yOut = [];
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