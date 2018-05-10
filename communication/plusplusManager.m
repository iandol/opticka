% ======================================================================
%> @brief Display++ Communication Class
%>
%> 
% ======================================================================
classdef plusplusManager < optickaCore
	
	properties
		%> verbosity
		verbose = true
		%> which digital I/O to use for the strobe trigger
		strobeLine double = 16
		%> silentMode allows one to gracefully fail methods without a dataPixx connected
		silentMode logical = false
		%>
		sM screenManager
		%>
		mask double = 2^16-1
		%>
		repetitions double = 1
		%>
		command double = 0
	end
	
	properties (SetAccess = protected, GetAccess = public)
		isOpen = false
	end
	
	properties (SetAccess = private, GetAccess = private)
		%> properties allowed to be modified during construction
		allowedProperties='silentMode|verbose|strobeLine'
	end
	
	methods
		% ===================================================================
		%> @brief Class constructor
		%> 
		%> @param 
		% ===================================================================
		function obj = plusplusManager(varargin)
			if nargin == 0; varargin.name = 'Display++ Manager'; end
			obj=obj@optickaCore(varargin); %superclass constructor
			if nargin > 0; obj.parseArgs(varargin,obj.allowedProperties); end
		end
		
		% ===================================================================
		%> @brief Open the DataPixx
		%> 
		%> @param 
		% ===================================================================
		function open(obj,sM)
			obj.isOpen = false;
			obj.sM = sM;
		end
		
		% ===================================================================
		%> @brief Close the DataPixx
		%> 
		%> @param 
		% ===================================================================
		function close(obj)
			
		end
		
		% ===================================================================
		%> @brief Prepare and send a strobed word
		%> 
		%> @param value of the 15bit strobed word
		% ===================================================================
		function sendStrobe(obj,value)
			if obj.verbose == true
				fprintf('===>>> SEND VALUE: %i\n',value);
			end
			BitsPlusPlus('DIOCommand', obj.sM.win, obj.repetitions, obj.mask, value, obj.command);
		end
		
		% ===================================================================
		%> @brief Prepare and send a strobed word
		%> 
		%> @param value of the 15bit strobed word
		% ===================================================================
		function sendTTL(obj,value)
			ttlMask = 2^15;
			if value > 0
				value = 2^15;
			end
			BitsPlusPlus('DIOCommand', obj.sM.win, obj.repetitions, ttlMask, value, obj.command);
		end
			
		% ===================================================================
		%> @brief Delete method, closes DataPixx gracefully
		%>
		% ===================================================================
		function delete(obj)
			close(obj);
			obj.salutation('DELETE method',[obj.fullName ' has been closed/reset...']);
		end
		
	end
	
end

