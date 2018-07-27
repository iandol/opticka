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
		%> screen manager that handles opening the display++
		sM screenManager
		%> default mask
		mask double = (2^10) -1
		%> repetitions of DIO
		repetitions double = 1
		%> command
		command double = 0
		%> for simple strobeMode, how many 100musec windows to keep value high?
		nWindows double = 30
	end
	
	properties (SetAccess = private, GetAccess = public, Dependent = true)
		%> what to add to the value to trigger the strobe line (e.g. 512 for pin 10 strobe)
		strobeShift double
	end
	
	properties (SetAccess = protected, GetAccess = public)
		%> computed data packet
		sendData double = []
		%> computed mask
		sendMask double = (2^10) -1
		%> send this value for the next sendStrobe
		sendValue double = 0
		%> run even if there is not Display++ attached
		silentMode logical = true
		%> is there a Display++ attached?
		isAttached logical = false
		%> last value sent
		lastValue double = []
	end
	
	properties (SetAccess = private, GetAccess = private)
		%> cached value to speed things up
		strobeShift_
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
				if ret == 1
					obj.isAttached = true;
					obj.silentMode = false;
					obj.strobeShift_ = obj.strobeShift; % cache value
					if isempty(obj.sM) || obj.sM.isOpen == false
						warning('SCREEN is CLOSED, no commands will work');
					end
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
		function sendStrobe(obj, value)
			if obj.silentMode || isempty(obj.sM) || obj.sM.isOpen == false; return; end
			if exist('value','var')
				prepareStrobe(obj,value,obj.mask)
			end
			BitsPlusPlus('DIOCommand', obj.sM.win, obj.repetitions, obj.sendMask, obj.sendData, obj.command);
% 			if obj.verbose == true
% 				fprintf('===>>> sendStrobe VALUE: %i\t| mode:%s\t| mask:%s\n',...
% 					obj.sendValue, obj.strobeMode, dec2bin(obj.mask));
% 			end
		end
		
		% ===================================================================
		%> @brief Prepare and send a strobed word
		%> 
		%> @param value 
		% ===================================================================
		function prepareStrobe(obj, value, mask)
			if ~exist('value','var') || isempty(value)
				value = obj.sendValue;
			end
			if ~exist('mask','var') || isempty(mask); mask = obj.mask; end
			
			obj.lastValue = obj.sendValue;
			obj.sendValue = value;
			obj.sendMask = mask;
			
			switch obj.strobeMode
				case 'plexon'
					obj.sendData = [value, value + obj.strobeShift_, value + obj.strobeShift_,...
						zeros(1,248-3)];
				otherwise
					obj.sendData = [repmat(value,1,obj.nWindows), zeros(1,248-obj.nWindows)];
			end
		end
		
		% ===================================================================
		%> @brief Prepare and send a strobed word
		%> 
		%> @param value 
		% ===================================================================
		function triggerStrobe(obj)
			sendStrobe(obj);
		end
		
		% ===================================================================
		%> @brief Prepare and send a strobed word
		%> 
		%> @param value 
		% ===================================================================
		function sendStrobeAndFlip(obj, value)
			if obj.silentMode || isempty(obj.sM) || obj.sM.isOpen == false; return; end
			prepareStrobe(obj,value);
			sendStrobe(obj);
			flip(obj.sM); flip(obj.sM);
			if obj.verbose == true
				fprintf('===>>> sendStrobeAndFlip VALUE: %i\t| mode: %s\t| mask: %s\n', value, obj.strobeMode, dec2bin(mask));
			end
		end
		
		% ===================================================================
		%> @brief Prepare and send a TTL
		%> 
		%> @param 
		% ===================================================================
		function sendTTL(obj, value, mask)
			if obj.silentMode || isempty(obj.sM) || obj.sM.isOpen == false; return; end
			if ~exist('value','var') || isempty(value)
				warning('No value specified, abort sending TTL')
				return
			end
			if ~exist('mask','var') || isempty(mask); mask = obj.mask; end
			data = [repmat(value,1,10),zeros(1,248-10)];
			BitsPlusPlus('DIOCommand', obj.sM.win, obj.repetitions, mask, data, obj.command);
			
			if obj.verbose == true
				fprintf('===>>> SEND TTL: %i - mask: %s\n', value, dec2bin(mask));
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
		function bitsMode(obj)
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
		function monoMode(obj)
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
		function colourMode(obj)
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
		%> @brief Get method 
		%>
		%> @param
		% ===================================================================
		function shift = get.strobeShift(obj)
			shift = 2^(obj.strobeLine-1);
			obj.strobeShift_ = shift;
		end
		
		% ===================================================================
		%> @brief 
		%> 
		%> @param 
		% ===================================================================
		function startRecording(obj,value)
			if obj.silentMode || isempty(obj.sM) || obj.sM.isOpen == false; return; end
			if strcmpi(obj.strobeMode,'plexon')
				if ~exist('value','var') || isempty(value);value=500;end
				sendStrobeAndFlip(obj,value);
			end
		end
		
		% ===================================================================
		%> @brief 
		%> 
		%> @param 
		% ===================================================================
		function resumeRecording(obj,value)
			if obj.silentMode || isempty(obj.sM) || obj.sM.isOpen == false; return; end
			if strcmpi(obj.strobeMode,'plexon')
				if ~exist('value','var') || isempty(value);value=501;end
				sendStrobeAndFlip(obj,value);
			end
		end
		
		% ===================================================================
		%> @brief 
		%> 
		%> @param 
		% ===================================================================
		function pauseRecording(obj,value)
			if obj.silentMode || isempty(obj.sM) || obj.sM.isOpen == false; return; end
			if strcmpi(obj.strobeMode,'plexon')
				if ~exist('value','var') || isempty(value);value=502;end
				sendStrobeAndFlip(obj,value);
			end
		end
		
		% ===================================================================
		%> @brief 
		%> 
		%> @param 
		% ===================================================================
		function stopRecording(obj,value)
			if obj.silentMode || isempty(obj.sM) || obj.sM.isOpen == false; return; end
			if strcmpi(obj.strobeMode,'plexon')
				if ~exist('value','var') || isempty(value);value=503;end
				sendStrobeAndFlip(obj,value);
			end
		end
		
		% ===================================================================
		%> @brief 
		%> 
		%> @param 
		% ===================================================================
		function startFixation(obj)
			sendStrobe(obj,248); 
		end
		
		% ===================================================================
		%> @brief 
		%> 
		%> @param 
		% ===================================================================
		function correct(obj)
			sendStrobe(obj,251); 
		end
		
		% ===================================================================
		%> @brief 
		%> 
		%> @param 
		% ===================================================================
		function incorrect(obj)
			sendStrobe(obj,252); 
		end
		
		% ===================================================================
		%> @brief 
		%> 
		%> @param 
		% ===================================================================
		function breakFixation(obj)
			sendStrobe(obj,249); 
		end
		
		% ===================================================================
		%> @brief 
		%> 
		%> @param 
		% ===================================================================
		function rstart(obj,varargin)
			resumeRecording(obj);
		end
		
		% ===================================================================
		%> @brief 
		%> 
		%> @param 
		% ===================================================================
		function rstop(obj,varargin)
			pauseRecording(obj);
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

