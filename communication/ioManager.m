% ======================================================================
%> @brief Input Output manager, a dummy class to allow task to run without
%> strobe hardware 
%>
%> 
%>
%> Copyright ©2014-2022 Ian Max Andolina — released: LGPL3, see LICENCE.md
% ======================================================================
classdef ioManager < optickaCore
	
	properties
		%> verbosity
		verbose = true
		%> the hardware object
		io
		%>
		silentMode logical = true
		%>
		stimOFFValue = 255
	end
	
	properties (SetAccess = private, GetAccess = public, Dependent = true)
		%> hardware class
		type char
	end
	
	properties (SetAccess = protected, GetAccess = public)
		isOpen logical = false
		sendValue
		lastValue
	end
	
	properties (SetAccess = private, GetAccess = private)
		%> properties allowed to be modified during construction
		allowedProperties char = 'io|verbose'
	end
	
	methods
		% ===================================================================
		%> @brief Class constructor
		%> 
		%> @param 
		% ===================================================================
		function me = ioManager(varargin)
			if nargin == 0; varargin.name = 'IO Manager'; end
			me=me@optickaCore(varargin); %superclass constructor
			if nargin > 0; me.parseArgs(varargin,me.allowedProperties); end
		end

		% ===================================================================
		%> @brief 
		%> 
		%> @param 
		% ===================================================================
		function open(me, varargin)
			me.silentMode = true;
			me.isOpen = false;
		end
		
		% ===================================================================
		%> @brief 
		%> 
		%> @param 
		% ===================================================================
		function close(me,varargin)

		end
		
		% ===================================================================
		%> @brief 
		%> 
		%> @param 
		% ===================================================================
		function resetStrobe(me,varargin)

		end
		
		% ===================================================================
		%> @brief 
		%> 
		%> @param 
		% ===================================================================
		function triggerStrobe(me,varargin)

		end
		
		% ===================================================================
		%> @brief 
		%> 
		%> @param 
		% ===================================================================
		function prepareStrobe(me,value)
			if ~exist('value','var'); return; end
			me.lastValue = me.sendValue;
			me.sendValue = value;
		end
		
		% ===================================================================
		%> @brief 
		%> 
		%> @param 
		% ===================================================================
		function sendStrobe(me, value)
			if ~exist('value','var'); return; end
			me.lastValue = me.sendValue;
			me.sendValue = value;
		end

		% ===================================================================
		%> @brief 
		%> 
		%> @param 
		% ===================================================================
		function strobeServer(me,value)
			if ~exist('value','var'); return; end
			me.lastValue = me.sendValue;
			me.sendValue = value;
		end

		% ===================================================================
		%> @brief 
		%> 
		%> @param 
		% ===================================================================
		function sendTTL(me,value)

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
		%> @brief 
		%> 
		%> @param 
		% ===================================================================
		function type = get.type(me)
			if isempty(me.io)
				type = 'undefined';
			else
				if isa(me.io,'plusplusManager')
					type = 'Display++';
				elseif isa(me.io,'labJackT')
					type = 'LabJack T4/T7';
				elseif isa(me.io,'labJack')
					type = 'LabJack U3/U6';
				elseif isa(me.io,'dPixxManager')
					type = 'DataPixx';
				elseif isa(me.io,'arduinoManager')
					type = 'Arduino';
				end
			end
		end
			
		% ===================================================================
		%> @brief Delete method, closes gracefully
		%>
		% ===================================================================
		function delete(me)
			try
				if ~isempty(me.io)
					close(me);
				end
			catch
				warning('IO Manager Couldn''t close hardware')
			end
		end
		
	end
	
end

