% ======================================================================
%> @brief Input Output manager, provides single interface to different
%> hardware, currently just a dummy class
%>
%> 
% ======================================================================
classdef ioManager < optickaCore
	
	properties
		%> verbosity
		verbose = true
		%> the hardware object
		io
		%>
		silentMode logical = true
	end
	
	properties (SetAccess = private, GetAccess = public, Dependent = true)
		%> hardware class
		type char
	end
	
	properties (SetAccess = protected, GetAccess = public)
		
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
		function obj = ioManager(varargin)
			if nargin == 0; varargin.name = 'IO Manager'; end
			obj=obj@optickaCore(varargin); %superclass constructor
			if nargin > 0; obj.parseArgs(varargin,obj.allowedProperties); end
		end

		% ===================================================================
		%> @brief 
		%> 
		%> @param 
		% ===================================================================
		function open(obj,varargin)

		end
		
		% ===================================================================
		%> @brief 
		%> 
		%> @param 
		% ===================================================================
		function close(obj,varargin)

		end
		
		% ===================================================================
		%> @brief 
		%> 
		%> @param 
		% ===================================================================
		function resetStrobe(obj,varargin)

		end
		
		% ===================================================================
		%> @brief 
		%> 
		%> @param 
		% ===================================================================
		function triggerStrobe(obj,varargin)

		end
		
		% ===================================================================
		%> @brief 
		%> 
		%> @param 
		% ===================================================================
		function prepareStrobe(obj,varargin)

		end
		
		% ===================================================================
		%> @brief 
		%> 
		%> @param 
		% ===================================================================
		function sendStrobe(obj,varargin)

		end
		
		% ===================================================================
		%> @brief 
		%> 
		%> @param 
		% ===================================================================
		function sendTTL(obj,varargin)

		end
		
		% ===================================================================
		%> @brief 
		%> 
		%> @param 
		% ===================================================================
		function startRecording(obj,value)

		end
		
		% ===================================================================
		%> @brief 
		%> 
		%> @param 
		% ===================================================================
		function resumeRecording(obj,value)

		end
		
		% ===================================================================
		%> @brief 
		%> 
		%> @param 
		% ===================================================================
		function pauseRecording(obj,value)

		end
		
		% ===================================================================
		%> @brief 
		%> 
		%> @param 
		% ===================================================================
		function stopRecording(obj,value)

		end
		
		% ===================================================================
		%> @brief 
		%> 
		%> @param 
		% ===================================================================
		function startFixation(obj)
			
		end
		
		% ===================================================================
		%> @brief 
		%> 
		%> @param 
		% ===================================================================
		function correct(obj)
			
		end
		
		% ===================================================================
		%> @brief 
		%> 
		%> @param 
		% ===================================================================
		function incorrect(obj)
			
		end
		
		% ===================================================================
		%> @brief 
		%> 
		%> @param 
		% ===================================================================
		function breakFixation(obj)
			
		end
		
		% ===================================================================
		%> @brief 
		%> 
		%> @param 
		% ===================================================================
		function rstart(obj,varargin)

		end
		
		
		% ===================================================================
		%> @brief 
		%> 
		%> @param 
		% ===================================================================
		function rstop(obj,varargin)

		end
		
		% ===================================================================
		%> @brief 
		%> 
		%> @param 
		% ===================================================================
		function timedTTL(obj,varargin)

		end
		
		% ===================================================================
		%> @brief Prepare and send a TTL
		%> 
		%> @param 
		% ===================================================================
		function type = get.type(obj)
			if isempty(obj.io)
				type = 'undefined';
			else
				if isa(obj.io,'plusplusManager')
					type = 'Display++';
				elseif isa(obj.io,'dPixxManager')
					type = 'DataPixx';
				elseif isa(obj.io,'arduinoManager')
					type = 'Arduino';
				end
			end
		end
			
		% ===================================================================
		%> @brief Delete method, closes DataPixx gracefully
		%>
		% ===================================================================
		function delete(obj)
			try
				close(obj.io);
			catch
				warning('IO Manager Couldn''t close hardware')
			end
		end
		
	end
	
end

