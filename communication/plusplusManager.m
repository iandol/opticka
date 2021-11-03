% ======================================================================
%> @brief Display++ Communication Class
%>
%> 
%>
%> Copyright ©2014-2021 Ian Max Andolina — released: LGPL3, see LICENCE.md
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
		%> computed data packet
		tempData double = []
		%> computed mask
		tempMask double = (2^10) -1
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
		function me = plusplusManager(varargin)
			if nargin == 0; varargin.name = 'Display++ Manager'; end
			me=me@optickaCore(varargin); %superclass constructor
			if nargin > 0; me.parseArgs(varargin,me.allowedProperties); end
		end
		
		% ===================================================================
		%> @brief reset strobed word
		%> 
		%> @param value of the 15bit strobed word
		% ===================================================================
		function open(me)
			try
				ret = BitsPlusPlus('OpenBits#');
				if ret == 1
					me.isAttached = true;
					me.silentMode = false;
					me.strobeShift_ = me.strobeShift; % cache value
					if isempty(me.sM) || me.sM.isOpen == false
						warning('SCREEN is CLOSED, no I/O commands will work');
					end
					if ~isempty(me.sM) & ~isempty(regexpi(me.sM.bitDepth,'^EnableBits'))
						warning('SCREEN is not set to use Bits++ mode, I/O WILL FAIL!');
					end
				else
					warning('Cannot find Display++, going into Silent mode...')
					me.isAttached = false;
					me.silentMode = true;
				end
			catch ME
				Getreport(ME);
				me.sM.checkWindowValid();
				warning('Problem searching for Display++, entering silentMode')
				me.isAttached = false;
				me.silentMode = true;
                fprintf('--->>> plusplusManager: make sure your serial port is set up and you''ve validated with BitsPlusIdentityClutTest(2) etc\n');
			end
		end
		
		% ===================================================================
		%> @brief Prepare and send a strobed word
		%> 
		%> @param value 
		% ===================================================================
		function sendStrobe(me, value)
			if me.silentMode || isempty(me.sM) || me.sM.isOpen == false; return; end
			if exist('value','var')
				prepareStrobe(me, value, me.mask, true);
				data = me.tempData;
				mask = me.tempMask; %#ok<*PROPLC>
			else
				value = me.sendValue;
				data = me.sendData;
				mask = me.sendMask;
			end
			BitsPlusPlus('DIOCommand', me.sM.win, me.repetitions, mask, data, me.command);
            if me.verbose; fprintf('===>>> sendStrobe: %i | mode:%s\t| mask:%s |\n', value, me.strobeMode, dec2bin(mask)); end
		end
		
		% ===================================================================
		%> @brief Prepare and send a strobed word
		%> 
		%> @param value the strobe word value
		%> @param mask the mask to send
		%> @param temporary if true we don't change sendStrobe value
		% ===================================================================
		function prepareStrobe(me, value, mask, temporary)
			if ~exist('value','var') || isempty(value)
				value = me.sendValue;
			end
			if ~exist('mask','var') || isempty(mask); mask = me.mask; end
			if ~exist('temporary','var'); temporary = false; end
			
			if temporary
				me.lastValue = value;
				me.tempMask = mask;
			else
				me.lastValue = me.sendValue;
				me.sendValue = value;
			end
			
			switch me.strobeMode
				case 'plexon'
					data = [value, value + me.strobeShift_, value + me.strobeShift_,...
						zeros(1,248-3)];
				otherwise
					data = [repmat(value,1,me.nWindows), zeros(1,248-me.nWindows)];
			end
			if temporary
				me.tempData = data;
			else
				me.sendData = data;
			end
			if me.verbose == true
				fprintf('===>>> prepareStrobe VALUE: %i\t| mode:%s\t| mask:%s | %i\n',...
					value, me.strobeMode, dec2bin(me.mask), temporary);
			end
		end
		
		% ===================================================================
		%> @brief Prepare and send a strobed word
		%> 
		%> @param value 
		% ===================================================================
		function triggerStrobe(me)
			sendStrobe(me);
		end
		
		% ===================================================================
		%> @brief Prepare and send a strobed word
		%> 
		%> @param value 
		% ===================================================================
		function sendStrobeAndFlip(me, value)
			if me.silentMode || isempty(me.sM) || me.sM.isOpen == false; return; end
			if exist('value','var'); prepareStrobe(me,value,me.mask);	end
			sendStrobe(me);
			flip(me.sM); flip(me.sM);
			if me.verbose == true
				fprintf('===>>> sendStrobeAndFlip VALUE: %i\t| mode: %s\t| mask: %s\n', ...
					me.sendValue, me.strobeMode, dec2bin(me.mask));
			end
		end
		
		% ===================================================================
		%> @brief Prepare and send a TTL
		%> 
		%> @param 
		% ===================================================================
		function sendTTL(me, value, mask)
			if me.silentMode || isempty(me.sM) || me.sM.isOpen == false; return; end
			if ~exist('value','var') || isempty(value)
				warning('No value specified, abort sending TTL')
				return
			end
			if ~exist('mask','var') || isempty(mask); mask = me.mask; end
			data = [repmat(value,1,10),zeros(1,248-10)];
			BitsPlusPlus('DIOCommand', me.sM.win, me.repetitions, mask, data, me.command);
			
			if me.verbose == true
				fprintf('===>>> SEND TTL: %i - mask: %s\n', value, dec2bin(mask));
			end
		end
		
		% ===================================================================
		%> @brief reset strobed word
		%> 
		%> @param value of the 15bit strobed word
		% ===================================================================
		function resetStrobe(me)
			if me.silentMode==true;return;end
			BitsPlusPlus('DIOCommandReset', me.sM.win);
			if me.verbose == true
				fprintf('===>>> RESET STROBE\n');
			end
		end
		
		% ===================================================================
		%> @brief reset strobed word
		%> 
		%> @param value of the 15bit strobed word
		% ===================================================================
		function statusScreen(me)
			if me.silentMode==true;return;end
			BitsPlusPlus('SwitchToStatusScreen');
			if me.verbose == true
				fprintf('===>>> Showing Status Screen\n');
			end
		end
		
		% ===================================================================
		%> @brief reset strobed word
		%> 
		%> @param value of the 15bit strobed word
		% ===================================================================
		function bitsMode(me)
			if me.silentMode==true;return;end
			BitsPlusPlus('SwitchToBits++');
			if me.verbose == true
				fprintf('===>>> Switch to Bits++ mode\n');
			end
		end
		
		% ===================================================================
		%> @brief reset strobed word
		%> 
		%> @param value of the 15bit strobed word
		% ===================================================================
		function monoMode(me)
			if me.silentMode==true;return;end
			BitsPlusPlus('SwitchToMono++');
			if me.verbose == true
				fprintf('===>>> Switch to Mono++ mode\n');
			end
		end
		
		% ===================================================================
		%> @brief reset strobed word
		%> 
		%> @param value of the 15bit strobed word
		% ===================================================================
		function colourMode(me)
			if me.silentMode==true;return;end
			BitsPlusPlus('SwitchToColour++');
			if me.verbose == true
				fprintf('===>>> Switch to Colour++ mode\n');
			end
		end
		
		% ===================================================================
		%> @brief reset strobed word
		%> 
		%> @param value of the 15bit strobed word
		% ===================================================================
		function close(me)
			if me.silentMode==true;return;end
			BitsPlusPlus('Close');
			if me.verbose == true
				fprintf('===>>> Closing Display++\n');
			end
		end	
		
		% ===================================================================
		%> @brief Get method 
		%>
		%> @param
		% ===================================================================
		function shift = get.strobeShift(me)
			shift = 2^(me.strobeLine-1);
			me.strobeShift_ = shift;
		end
		
		% ===================================================================
		%> @brief 
		%> 
		%> @param 
		% ===================================================================
		function startRecording(me,value)
			if me.silentMode || isempty(me.sM) || me.sM.isOpen == false; return; end
			if strcmpi(me.strobeMode,'plexon')
				if ~exist('value','var') || isempty(value);value=500;end
				sendStrobeAndFlip(me,value);
			end
		end
		
		% ===================================================================
		%> @brief 
		%> 
		%> @param 
		% ===================================================================
		function resumeRecording(me,value)
			if me.silentMode || isempty(me.sM) || me.sM.isOpen == false; return; end
			if strcmpi(me.strobeMode,'plexon')
				if ~exist('value','var') || isempty(value);value=501;end
				sendStrobeAndFlip(me,value);
			end
		end
		
		% ===================================================================
		%> @brief 
		%> 
		%> @param 
		% ===================================================================
		function pauseRecording(me,value)
			if me.silentMode || isempty(me.sM) || me.sM.isOpen == false; return; end
			if strcmpi(me.strobeMode,'plexon')
				if ~exist('value','var') || isempty(value);value=502;end
				sendStrobeAndFlip(me,value);
			end
		end
		
		% ===================================================================
		%> @brief 
		%> 
		%> @param 
		% ===================================================================
		function stopRecording(me,value)
			if me.silentMode || isempty(me.sM) || me.sM.isOpen == false; return; end
			if strcmpi(me.strobeMode,'plexon')
				if ~exist('value','var') || isempty(value);value=503;end
				sendStrobeAndFlip(me,value);
			end
		end
		
		% ===================================================================
		%> @brief 
		%> 
		%> @param 
		% ===================================================================
		function startFixation(me)
			sendStrobe(me,248); 
		end
		
		% ===================================================================
		%> @brief 
		%> 
		%> @param 
		% ===================================================================
		function correct(me)
			sendStrobe(me,251); 
		end
		
		% ===================================================================
		%> @brief 
		%> 
		%> @param 
		% ===================================================================
		function incorrect(me)
			sendStrobe(me,252); 
		end
		
		% ===================================================================
		%> @brief 
		%> 
		%> @param 
		% ===================================================================
		function breakFixation(me)
			sendStrobe(me,249); 
		end
		
		% ===================================================================
		%> @brief 
		%> 
		%> @param 
		% ===================================================================
		function rstart(me,varargin)
			resumeRecording(me);
		end
		
		% ===================================================================
		%> @brief 
		%> 
		%> @param 
		% ===================================================================
		function rstop(me,varargin)
			pauseRecording(me);
		end
			
		% ===================================================================
		%> @brief Delete method, closes DataPixx gracefully
		%>
		% ===================================================================
		function delete(me)
			close(me);
			me.salutation('DELETE method',[me.fullName ' has been closed/reset...']);
        end
        
        % ===================================================================
		%> @brief Test strobes vis Display++ screen
		%>
		% ===================================================================
        function runTests(me)
            if isempty(me.sM)
                me.sM = screenManager();
            end
            me.sM.backgroundColour = [0.8 0.2 0.2];
            me.sM.bitDepth = 'EnableBits++Bits++Output';
            me.sM.blend = true;
            me.sM.open();
            
            me.open();
            
            fprintf('\nAttempting to send some strobes...\n')
            WaitSecs(0.5)
            
            strobeVals = [1 : 30];
            for i =1:length(strobeVals)
                t=sprintf('Testing strobe %i', strobeVals(i));
                DrawFormattedText(me.sM.win, t, 10, 50);
                me.sendStrobe(strobeVals(i));
                me.sM.flip();
                if i < 20
                    DrawFormattedText(me.sM.win, [t ' ... '], 10, 50);
                    me.sM.flip();
                end
                WaitSecs(0.25);
                me.resetStrobe();
            end
            
            WaitSecs(0.5);
            me.sM.close();
            me.close();
        end
		
	end
	
end

