% ======================================================================
%> @brief Display++ Communication Class
%>
%> 
% ======================================================================
classdef plusplusManager < optickaCore
	
	properties
		%> verbosity
		verbose = true
		%> use 'plexon' for strobe bit or 'simple' for EEG machine
		strobeMode char = 'plexon'
		%> which digital I/O to use for the strobe trigger
		strobeLine double = 10
		%>
		sM screenManager
		%>
		mask double = 2^16-1
		%>
		repetitions double = 1
		%>
		command double = 0
	end
	
	properties (SetAccess = private, GetAccess = public, Dependent = true)
		%> what to add to the value to trigger the strobe line (e.g. 512 for pin 10 strobe)
		strobeShift double
	end
	
	properties (SetAccess = protected, GetAccess = public)
		%> value sent by prepareStrobe
		currentValue double
		%> boolean if strobe has been prepared
		isPrepared logical = false
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
			BitsPlusPlus('DIOCommandReset', obj.sM.win);
			obj.currentValue = [];
			obj.isPrepared = false;
			if obj.verbose == true
				fprintf('===>>> RESET STROBE\n');
			end
		end
		
		% ===================================================================
		%> @brief Prepare and send a strobed word
		%> 
		%> @param value of the 15bit strobed word
		% ===================================================================
		function prepareStrobe(obj, value, mask)
			if ~exist('mask','var') || isempty(mask); mask = obj.mask; end
			if ~strcmpi(obj.strobeMode,'plexon')
				warning('Only plexon mode allows preparing a strobe to send')
				return
			end
			BitsPlusPlus('DIOCommand', obj.sM.win, obj.repetitions, obj.mask, value, obj.command);
			obj.currentValue = value;
			obj.isPrepared = true;
			if obj.verbose == true
				fprintf('===>>> prepareStrobe VALUE: %i - mask: %s\n', value, dec2bin(mask));
			end
		end
		
		% ===================================================================
		%> @brief Prepare and send a strobed word
		%> 
		%> @param value 
		% ===================================================================
		function sendStrobe(obj,value)
			if ~exist('value','var') || isempty(value)
				if strcmpi(obj.strobeMode,'plexon')
					value = obj.currentValue;
				else
					warning('No value specified, abort sending strobe')
					return
				end
			end
			switch obj.strobeMode
				case 'plexon'
					BitsPlusPlus('DIOCommand', obj.sM.win, obj.repetitions, obj.mask, value + obj.strobeShift, obj.command);
				otherwise
					BitsPlusPlus('DIOCommand', obj.sM.win, obj.repetitions, obj.mask, value, obj.command);
			end
			obj.currentValue = [];
			obj.isPrepared = false;
			if obj.verbose == true
				fprintf('===>>> sendStrobe VALUE: %i | mode: %s | mask: %s\n', value, obj.strobeMode, dec2bin(obj.mask));
			end
		end
		
		% ===================================================================
		%> @brief Prepare and send a strobed word
		%> 
		%> @param value 
		% ===================================================================
		function sendStrobeAndFlip(obj, value, mask)
			if ~exist('mask','var') || isempty(mask); mask = obj.mask; end

			resetStrobe(obj)
			BitsPlusPlus('DIOCommand', obj.sM.win, obj.repetitions, mask, value, obj.command);
			flip(obj.sM)
			BitsPlusPlus('DIOCommand', obj.sM.win, obj.repetitions, mask, value + obj.strobeShift, obj.command);
			flip(obj.sM)
			resetStrobe(obj)
			
			if obj.verbose == true
				fprintf('===>>> sendStrobeAndFlip SEND VALUE: %i - mask: %s\n',value, dec2bin(strobeMask));
			end
		end
		
		% ===================================================================
		%> @brief Prepare and send a TTL
		%> 
		%> @param 
		% ===================================================================
		function sendTTL(obj, value, mask)
			if ~exist('mask','var') || isempty(mask); mask = obj.mask; end

			BitsPlusPlus('DIOCommand', obj.sM.win, obj.repetitions, mask, value, obj.command);
			
			if obj.verbose == true
				fprintf('===>>> SEND TTL: %i - mask: %s\n', value, dec2bin(mask));
			end
		end
		
		
		% ===================================================================
		%> @brief Get method 
		%>
		%> @param
		% ===================================================================
		function shift = get.strobeShift(obj)
			shift = 2^(obj.strobeLine-1);
		end
			
		% ===================================================================
		%> @brief Delete method, closes DataPixx gracefully
		%>
		% ===================================================================
		function delete(obj)
			obj.salutation('DELETE method',[obj.fullName ' has been closed/reset...']);
		end
		
	end
	
end

