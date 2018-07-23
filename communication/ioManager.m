% ======================================================================
%> @brief Input Output manager, provides single interface to different
%> hardware
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
		%> @brief reset strobed word
		%> 
		%> @param value of the 15bit strobed word
		% ===================================================================
		function open(obj)

		end
		
		% ===================================================================
		%> @brief reset strobed word
		%> 
		%> @param value of the 15bit strobed word
		% ===================================================================
		function resetStrobe(obj)

		end
		
		% ===================================================================
		%> @brief Prepare and send a strobed word
		%> 
		%> @param value of the 15bit strobed word
		% ===================================================================
		function prepareStrobe(obj)

		end
		
		% ===================================================================
		%> @brief Prepare and send a strobed word
		%> 
		%> @param value 
		% ===================================================================
		function sendStrobe(obj)

		end
		
		% ===================================================================
		%> @brief Prepare and send a TTL
		%> 
		%> @param 
		% ===================================================================
		function sendTTL(obj)

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

