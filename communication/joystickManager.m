% ========================================================================
classdef joystickManager < optickaCore
%> @class joystickManager
%> @brief Manages the Simia Joystick
%>
%> Copyright ©2014-2023 Ian Max Andolina — released: LGPL3, see LIv12345c12345CENCE.md
% ========================================================================
	
	%---------------PUBLIC PROPERTIES---------------%
	properties
		joystickName		= 'simia joystick'
		silentMode			= false;
		verbose				= false;
	end

	%-----------------CONTROLLED PROPERTIES-------------%
	properties (SetAccess = protected, GetAccess = public)
		isConnected			= false
		nJoysticks			= 0
		id					= 0
		names				= {}
	end

	%--------------------PROTECTED PROPERTIES----------%
	properties (SetAccess = protected, GetAccess = protected)
		allowedProperties	= {'joystickName'}
	end

	%=======================================================================
	methods %------------------PUBLIC METHODS
	%=======================================================================
	
		% ===================================================================
		function me = joystickManager(varargin)
		%joystickManager Construct an instance of this class
		%> @fn joystickManager(varargin)
		% ===================================================================
			args = optickaCore.addDefaults(varargin);
			me = me@optickaCore(args); %we call the superclass constructor first
			me.parseArgs(args, me.allowedProperties);

			testConnected(me);
			
		end

		function open(me)
			reset(me)
			testConnected(me);
			if me.id > 0
				me.silentMode = false;
				me.isConnected = true;
			end
		end

		function reset(me, hardReset)
			if exist('hardReset','var') && hardReset == true
				Gamepad('Unplug');
			end
			me.isConnected = false;
			me.silentMode = false;
			me.nJoysticks = 0;
			me.id = 0;
			me.names = {};
		end

		function test(me)
			if ~me.isConnected
				open(me);
			end
			if me.silentMode; return; end
			s = screenManager;
			sv = open(s);
			
			KbName('UnifyKeyNames')
			stopKey	= KbName('escape');
			centerKey = KbName('F1');
			oldr=RestrictKeysForKbCheck([stopKey centerKey]);
			ListenChar(-1);
			
			SetMouse(sv.xCenter,sv.yCenter,sv.win);
			x = Gamepad('GetAxis', me.id, 1);
			y = Gamepad('GetAxis', me.id, 2);
			[xm, ym] = GetMouse(sv.win);
			HideCursor(s.screen);

			while true
				x = Gamepad('GetAxis', me.id, 1);
				y = Gamepad('GetAxis', me.id, 2);
				[xm,ym] = GetMouse(sv.win);
				xy = s.toDegrees([xm ym]);
				s.drawText(sprintf('x = %.2f y = %.2f xm = %.2f ym = %.2f',x,y,xy(1),xy(2)));
				s.drawCross(1,[1 0 0],xy(1),xy(2));
				s.flip;
				[keyDown, ~, keyCode] = optickaCore.getKeys();
				if keyDown 
					if keyCode(stopKey); break; end
					if keyCode(centerKey); SetMouse(sv.xCenter,sv.yCenter,sv.win); end
				end
			end

			RestrictKeysForKbCheck([]);
			ListenChar(0);
			ShowCursor;
			WaitSecs(1);
			reset(me);
			SetMouse(500,500,0);
			close(s);
		end

	end

	methods
		function testConnected(me)
			n = Gamepad('GetNumGamepads');
			me.names = Gamepad('GetGamepadNamesFromIndices', 1:n);
			tmpid = Gamepad('GetGamepadIndicesFromNames', me.joystickName);
			if ~isempty(tmpid)
				me.id = tmpid;
				fprintf('--->>> joystickManager: %s with ID %i is available\n',me.joystickName,me.id);
			else
				me.id = 0;
				warning('--->>> joystickManager: no joystick attached, replug joystick, and try a Gamepad(''Unplug'') or clear all');
			end
		end
	end
end