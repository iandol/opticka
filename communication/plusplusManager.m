% ======================================================================
%> @brief Display++ Communication Class
%>
%> 
% ======================================================================
classdef plusplusManager < optickaCore
	
	properties
		%> verbosity
		verbose = false
		%> use 'plexon' for strobe bit or 'simple' for EEG machine
		strobeMode char = 'plexon'
		%> which digital I/O to use for the strobe trigger
		strobeLine double = 10
		%>
		sM screenManager
		%>
		mask double = (2^10) -1
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
		%> send a value for the next sendStrobe
		sendValue double = []
		%> run even if there is not Display++ attached
		silentMode logical = true
		%> is there a Display++ attached?
		isAttached logical = false
		%> last value sent
		lastValue double = []
	end
	
	properties (SetAccess = private, GetAccess = private)
		%> properties allowed to be modified during construction
		allowedProperties='sM|silentMode|verbose|strobeLine'
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
			open(obj);
		end
		
		% ===================================================================
		%> @brief reset strobed word
		%> 
		%> @param value of the 15bit strobed word
		% ===================================================================
		function open(obj)
			try
				ret = BitsPlusPlus('OpenBits#');
				if isempty(obj.sM) || obj.sM.isOpen == false
					warning('SCREEN is CLOSED, no commands will work')
					obj.isAttached = true;
					obj.silentMode = false;
				elseif ret == 1
					obj.isAttached = true;
					obj.silentMode = false;
				else
					warning('Cannot find Display++, going into Silent mode...')
					obj.isAttached = true;
					obj.silentMode = false;
				end
			catch
				warning('Problem searching for Display++, entering silentMode')
				obj.isAttached = false;
				obj.silentMode = true;
			end
		end
		
		% ===================================================================
		%> @brief Prepare and send a strobed word
		%> 
		%> @param value 
		% ===================================================================
		function sendStrobe(obj, value, mask)
			if obj.silentMode==true;return;end
			if ~exist('value','var') || isempty(value)
				if ~isempty(obj.sendValue) && obj.sendValue >= 0
					value = obj.sendValue;
				else
					warning('No value specified, abort sending strobe')
					return
				end
			end
			if ~exist('mask','var') || isempty(mask); mask = obj.mask; end
			switch obj.strobeMode
				case 'plexon'
					data = [value, value + obj.strobeShift, value + obj.strobeShift,...
						zeros(1,248-3)];
					BitsPlusPlus('DIOCommand', obj.sM.win, obj.repetitions, mask, data, obj.command);
				otherwise
					data = [value, value, value, zeros(1,248-3)];
					BitsPlusPlus('DIOCommand', obj.sM.win, obj.repetitions, mask, data, obj.command);
			end
			obj.lastValue = value;
			if obj.verbose == true
				fprintf('===>>> sendStrobe VALUE: %i\t| mode: %s\t| mask: %s\n', value, obj.strobeMode, dec2bin(obj.mask));
			end
		end
		
		% ===================================================================
		%> @brief Prepare and send a strobed word
		%> 
		%> @param value 
		% ===================================================================
		function prepareStrobe(obj, value)

			obj.lastValue = obj.sendValue;
			obj.sendValue = value;
			
		end
		% ===================================================================
		%> @brief Prepare and send a strobed word
		%> 
		%> @param value 
		% ===================================================================
		function sendStrobeAndFlip(obj, value, mask)
			if obj.silentMode==true;return;end
			if ~exist('mask','var') || isempty(mask); mask = obj.mask; end

			sendStrobe(obj,value,mask);
			flip(obj.sM);
			flip(obj.sM);
			
			if obj.verbose == true
				fprintf('===>>> sendStrobeAndFlip VALUE: %i\t| mode: %s\t| mask: %s\n', value, obj.strobeMode, dec2bin(mask));
			end
		end
		
		
		% ===================================================================
		%> @brief reset strobed word
		%> 
		%> @param value of the 15bit strobed word
		% ===================================================================
		function resetStrobe(obj)
			if obj.silentMode==true;return;end
			BitsPlusPlus('DIOCommandReset', obj.sM.win);
			if obj.verbose == true
				fprintf('===>>> RESET STROBE\n');
			end
		end
		
		% ===================================================================
		%> @brief reset strobed word
		%> 
		%> @param value of the 15bit strobed word
		% ===================================================================
		function statusScreen(obj)
			if obj.silentMode==true;return;end
			BitsPlusPlus('SwitchToStatusScreen');
			if obj.verbose == true
				fprintf('===>>> Showing Status Screen\n');
			end
		end
		
		% ===================================================================
		%> @brief reset strobed word
		%> 
		%> @param value of the 15bit strobed word
		% ===================================================================
		function bitsmode(obj)
			if obj.silentMode==true;return;end
			BitsPlusPlus('SwitchToBits++');
			if obj.verbose == true
				fprintf('===>>> Switch to Bits++ mode\n');
			end
		end
		
		% ===================================================================
		%> @brief reset strobed word
		%> 
		%> @param value of the 15bit strobed word
		% ===================================================================
		function monomode(obj)
			if obj.silentMode==true;return;end
			BitsPlusPlus('SwitchToMono++');
			if obj.verbose == true
				fprintf('===>>> Switch to Mono++ mode\n');
			end
		end
		
		% ===================================================================
		%> @brief reset strobed word
		%> 
		%> @param value of the 15bit strobed word
		% ===================================================================
		function colourmode(obj)
			if obj.silentMode==true;return;end
			BitsPlusPlus('SwitchToColour++');
			if obj.verbose == true
				fprintf('===>>> Switch to Colour++ mode\n');
			end
		end
		
		% ===================================================================
		%> @brief reset strobed word
		%> 
		%> @param value of the 15bit strobed word
		% ===================================================================
		function close(obj)
			if obj.silentMode==true;return;end
			BitsPlusPlus('Close');
			if obj.verbose == true
				fprintf('===>>> Closing Display++\n');
			end
		end
		
		% ===================================================================
		%> @brief Prepare and send a TTL
		%> 
		%> @param 
		% ===================================================================
		function sendTTL(obj, value, mask)
			if obj.silentMode==true;return;end
			if ~exist('value','var') || isempty(value)
				warning('No value specified, abort sending strobe')
				return
			end
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
			close(obj);
			obj.salutation('DELETE method',[obj.fullName ' has been closed/reset...']);
		end
		
	end
	
end

