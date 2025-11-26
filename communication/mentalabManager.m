% ======================================================================
%> @brief mentaLab Sync Class
%>
%> 
%>
%> Copyright ©2014-2025 Ian Max Andolina — released: LGPL3, see LICENCE.md
% ======================================================================
classdef mentalabManager < optickaCore
	
	properties
		deviceName string = ""
		silentMode logical = false
		stimOFFValue = 255
		verbose = false
	end
	
	properties (SetAccess = private, GetAccess = public, Dependent = true)
		pythonVersion
	end
	
	properties (SetAccess = protected, GetAccess = public)
		isOpen logical = false
		sendValue
		lastValue
		env
	end
	
	properties (SetAccess = private, GetAccess = private)
		pCode = ["import time","import explorepy","exp = explorepy.Explore()"]
		%> properties allowed to be modified during construction
		allowedProperties = {'deviceName','silentMode','stimOFFValue','verbose'}
	end
	
	methods
		% ===================================================================
		%> @brief Class constructor
		%> 
		%> @param 
		% ===================================================================
		function me = mentalabManager(varargin)
			if nargin == 0; varargin.name = 'Mentalab Manager'; varargin.type = 'Mentalab'; end
			me=me@optickaCore(varargin); %superclass constructor
			if nargin > 0; me.parseArgs(varargin,me.allowedProperties); end
			me.env = pyenv;
			if me.env.Version == ""
    			disp "Python not installed"
			end
			try
				pyrun("print('Python is Setup')")
			catch ME
				warning("Python cannot be run, please reconfigure MATLAB pyenv");
				rethrow(ME);
			end
			try
				pyrun(["import explorepy","exp = explorepy.Explore()"]);
			catch ME
				warning("explorepy and liblsl must be added via pip, please configure Python!");
				rethrow(ME);
			end
		end

		% ===================================================================
		%> @brief 
		%> 
		%> @param 
		% ===================================================================
		function open(me,varargin)
			if me.silentMode; me.isOpen = true; return; end
			me.env = pyenv;
			if me.env.Version == ""
    			disp "Python not installed"
			end
			try
				cmd = [me.pCode, sprintf('explore.connect(device_name="%s"',me.deviceName)];
				pyrun(cmd);
				me.isOpen = true;
			catch ME
				warning('--->>> mentalabManager cannot open device!');
				me.isOpen = false;
			end
		end
		
		% ===================================================================
		%> @brief 
		%> 
		%> @param 
		% ===================================================================
		function close(me,varargin)
			me.isOpen = false;
		end

		% ===================================================================
		%> @brief 
		%> 
		%> @param 
		% ===================================================================
		function prepareStrobe(me,value)
			if ~me.isOpen || me.silentMode; return; end
			me.lastValue = me.sendValue;
			me.sendValue = value;
		end

		% ===================================================================
		%> @brief 
		%> 
		%> @param 
		% ===================================================================
		function sendStrobe(me, value)
			if ~me.isOpen || me.silentMode; return; end
			if ~exist('value','var') || isempty(value)
				if ~isempty(me.sendValue)
					value = me.sendValue; 
				else
					warning('--->>> mentalabManager No strobe value set, no strobe sent!'); return
				end
			end
			cmd = [me.pCode, sprintf("exp_device.send_8_bit_trigger(%i)",me.sendValue)];
			pyrun(cmd);
            if me.verbose; fprintf('===>>> mentalabManager: We sent strobe %i!\n',value);end
		end
		
		% ===================================================================
		%> @brief 
		%> 
		%> @param 
		% ===================================================================
		function resetStrobe(me,varargin)
			if ~me.isOpen || me.silentMode; return; end
			me.sendValue = 0;
		end
		
		% ===================================================================
		%> @brief 
		%> 
		%> @param 
		% ===================================================================
		function triggerStrobe(me,varargin)
			if ~me.isOpen || me.silentMode; return; end
			if isempty(me.sendValue); warning('--->>> mentalabManager No strobe value set, trigger failed!'); return; end
			cmd = [me.pcode, sprintf("exp_device.send_8_bit_trigger(%i)",me.sendValue)];
			pyrun(cmd);
		end

		function ver = get.pythonVersion(me)
			ver = me.env.Version;
		end

	end

	methods (Hidden = true)
		
		% ===================================================================
		%> @brief 
		%> 
		%> @param 
		% ===================================================================
		function strobeServer(me,value)
			me.sendStrobe(value);
		end

		% ===================================================================
		%> @brief 
		%> 
		%> @param 
		% ===================================================================
		function sendTTL(me,value) %#ok<*INUSD>

		end
		
		% ===================================================================
		%> @brief 
		%> 
		%> @param 
		% ===================================================================
		function startRecording(me,value)

		end
		
		% ===================================================================
		%> @brief 
		%> 
		%> @param 
		% ===================================================================
		function resumeRecording(me,value)

		end
		
		% ===================================================================
		%> @brief 
		%> 
		%> @param 
		% ===================================================================
		function pauseRecording(me,value)

		end
		
		% ===================================================================
		%> @brief 
		%> 
		%> @param 
		% ===================================================================
		function stopRecording(me,value)

		end
		
		% ===================================================================
		%> @brief 
		%> 
		%> @param 
		% ===================================================================
		function startFixation(me)
			
		end
		
		% ===================================================================
		%> @brief 
		%> 
		%> @param 
		% ===================================================================
		function correct(me)
			
		end
		
		% ===================================================================
		%> @brief 
		%> 
		%> @param 
		% ===================================================================
		function incorrect(me)
			
		end
		
		% ===================================================================
		%> @brief 
		%> 
		%> @param 
		% ===================================================================
		function breakFixation(me)
			
		end
		
		% ===================================================================
		%> @brief 
		%> 
		%> @param 
		% ===================================================================
		function rstart(me,varargin)

		end
		
		
		% ===================================================================
		%> @brief 
		%> 
		%> @param 
		% ===================================================================
		function rstop(me,varargin)

		end
		
		% ===================================================================
		%> @brief 
		%> 
		%> @param 
		% ===================================================================
		function timedTTL(me,varargin)

		end
		
			
		% ===================================================================
		%> @brief Delete method, closes gracefully
		%>
		% ===================================================================
		function delete(me)
			
		end
		
	end
	
end

