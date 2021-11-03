% ======================================================================
%> @brief DataPixx Communication Class
%>
%> The DataPixx (VPixx Technologies Inc.) is a robust stimulus timing tool, 
%> allowing microsecond precision of strobed words and TTLs locked to display onset. 
%> It also enables better contrast range modes, critical for threshold type experiments.
%> Opticka is an object oriented stimulus generator based on Psychophysics toolbox
%> See http://iandol.github.com/opticka/ for more details
%>
%> Copyright ©2014-2021 Ian Max Andolina — released: LGPL3, see LICENCE.md
% ======================================================================
classdef dPixxManager < optickaCore
	
	properties
		%> verbosity
		verbose = true
		%> which digital I/O to use for the strobe trigger
		strobeLine double = 16
		%> what value to send for stimulus off / inf
		stimOFFValue double= 2^15
		%> silentMode allows one to gracefully fail methods without a dataPixx connected
		silentMode logical = false
	end
	
	properties (SetAccess = protected, GetAccess = public)
		nBits double = 0
		isOpen logical = false
		sendValue
		lastValue
	end
	
	properties (SetAccess = private, GetAccess = private)
		%> properties allowed to be modified during construction
		allowedProperties char = 'silentMode|verbose|strobeLine|stimOFFValue'
	end
	
	methods
		% ===================================================================
		%> @brief Class constructor
		%> 
		%> @param 
		% ===================================================================
		function obj = dPixxManager(varargin)
			if nargin == 0; varargin.name = 'dataPixx Manager'; end
			obj=obj@optickaCore(varargin); %superclass constructor
			if nargin > 0; obj.parseArgs(varargin,obj.allowedProperties); end
		end
		
		% ===================================================================
		%> @brief Open the DataPixx
		%> 
		%> @param 
		% ===================================================================
		function open(obj)
			obj.isOpen = false;
			if obj.silentMode == false
				try
					Datapixx('Open'); % Open Datapixx, and stop any schedules which might already be running
					obj.nBits = Datapixx('GetDinNumBits');
					Datapixx('StopAllSchedules');
					Datapixx('RegWrRd');    % Synchronize Datapixx registers to local register cache
					obj.silentMode = false;
					obj.isOpen = true;
				catch %#ok<CTCH>
					obj.salutation('open method','DataPixx not opening, switching into silent mode',true);
					obj.silentMode = true;
					obj.isOpen = false;
				end
			end
		end
		
		% ===================================================================
		%> @brief Close the DataPixx
		%> 
		%> @param 
		% ===================================================================
		function close(obj)
			if obj.isOpen
				obj.salutation('close method','Closing DataPixx...',true);
				Datapixx('Close');				
				obj.isOpen = false;
			end
		end
		
		% ===================================================================
		%> @brief Prepare and send a strobed word
		%> 
		%> @param value of the 15bit strobed word
		% ===================================================================
		function sendStrobe(obj,value)
			if obj.isOpen
				if value > 32767; value = 32767; end
				valueStrobe = bitor(value, 2^(obj.strobeLine-1));
				bufferAddress = 8e6;
				Datapixx('WriteDoutBuffer', strobe, bufferAddress);
				Datapixx('SetDoutSchedule', 0, [1e5,1], length(strobe), bufferAddress, length(strobe));
				Datapixx('StartDoutSchedule');
				Datapixx('RegWr');
				if obj.verbose; fprintf('>>>STROBE Value %g sent!\n',value); end
				obj.lastValue = obj.sendValue;
				obj.sendValue = value;
			end
		end
		
		% ===================================================================
		%> @brief Prepare, but don't send a strobed word 
		%> 
		%> @param value of the 15bit strobed word
		% ===================================================================
		function prepareStrobe(obj,value)
			if obj.isOpen
				if value > 32767; value = 32767; end
				valueStrobe = bitor(value, 2^(obj.strobeLine-1));
				strobe = [value valueStrobe, 0];
				bufferAddress = 8e6;
				Datapixx('WriteDoutBuffer', strobe, bufferAddress);
				Datapixx('SetDoutSchedule', 0, [1e5,1], length(strobe), bufferAddress, length(strobe));
				if obj.verbose; fprintf('>>>STROBE Value %g prepared!\n',value); end
				obj.lastValue = obj.sendValue;
				obj.sendValue = value;
			end
		end
		
		% ===================================================================
		%> @brief Trigger (send) a pre-prepared strobed word on the next frame
		%> 
		%> @param 
		% ===================================================================
		function triggerStrobe(obj)
			if obj.isOpen
				Datapixx('StartDoutSchedule');
				Datapixx('RegWrVideoSync');
				if obj.verbose; fprintf('>>>STROBE Value %g sent!\n',value); end
			end
		end
		
		% ===================================================================
		%> @brief reset the strobe
		%> 
		%> @param 
		% ===================================================================
		function resetStrobe(obj)
			if obj.isOpen
				Datapixx('StopAllSchedules');
				Datapixx('RegWrRd');
			end
		end
		
		
		% ===================================================================
		%> @brief Send RSTART to the Plexon
		%> 
		%> @param 
		% ===================================================================
		function rstart(obj)
			if obj.isOpen
				setLine(obj,8,1);
				if obj.verbose; fprintf('>>>RSTART sent to Plexon!\n'); end
			end
		end
		
		% ===================================================================
		%> @brief Send RSTOP to the Plexon
		%> 
		%> @param 
		% ===================================================================
		function rstop(obj)
			if obj.isOpen
				setLine(obj,8,0);
				if obj.verbose; fprintf('>>>RSTOP sent to Plexon!\n'); end
			end
		end
		
		% ===================================================================
		%> @brief 
		%> 
		%> @param 
		% ===================================================================
		function startRecording(obj,value)
			if obj.silentMode==true;return;end
			sendTTL(obj, 7); %we are using dataPixx bit 7 > plexon evt23 to toggle start/stop
		end
		
		% ===================================================================
		%> @brief 
		%> 
		%> @param 
		% ===================================================================
		function resumeRecording(obj,value)
			if obj.silentMode==true;return;end
			rstart(obj);
		end
		
		% ===================================================================
		%> @brief 
		%> 
		%> @param 
		% ===================================================================
		function pauseRecording(obj,value)
			if obj.silentMode==true;return;end
			rstop(obj); %pause plexon
		end
		
		% ===================================================================
		%> @brief 
		%> 
		%> @param 
		% ===================================================================
		function stopRecording(obj,value)
			if obj.silentMode==true;return;end
			sendTTL(obj, 7); % we are using dataPixx bit 7 > plexon evt23 to toggle start/stop
		end
		
		% ===================================================================
		%> @brief 
		%> 
		%> @param 
		% ===================================================================
		function startFixation(obj)
			sendTTL(obj,3); %send TTL on line 3 (pin 19)
		end
		
		% ===================================================================
		%> @brief 
		%> 
		%> @param 
		% ===================================================================
		function correct(obj)
			sendTTL(obj,4);
		end
		
		% ===================================================================
		%> @brief 
		%> 
		%> @param 
		% ===================================================================
		function incorrect(obj)
			sendTTL(obj,6);
		end
		
		% ===================================================================
		%> @brief 
		%> 
		%> @param 
		% ===================================================================
		function breakFixation(obj)
			sendTTL(obj,5);
		end

		% ===================================================================
		%> @brief Send TTL
		%> 
		%> @param line 1-8 (pins 17-24) are available on dataPixx only!
		% ===================================================================
		function sendTTL(obj,line)
			if obj.isOpen
				if ~exist('line','var') || line > 8 || line < 1
					fprintf('1-8 lines (pins 17-24) are available on dataPixx only!\n')
					return
				end
				line = 2^(line-1);
				val = bitshift(line,16);
				mask = bitshift(line,16);
				Datapixx('SetDoutValues', 0, mask);
				Datapixx('RegWr');
				Datapixx('SetDoutValues', val, mask);
				Datapixx('RegWr');
				WaitSecs(0.001);
				Datapixx('SetDoutValues', 0, mask);
				Datapixx('RegWr');
			end
		end
		
		% ===================================================================
		%> @brief Set line output low or high
		%> 
		%> @param line 1-8 (pins 17-24) are available on dataPixx only!
		%> @param value 0 = low | 1 = high
		% ===================================================================
		function setLine(obj,line,value)
			if obj.isOpen
				if line > 8 || line < 1
					fprintf('1-8 lines (pins 17-24) are available on dataPixx only!\n')
					return
				end
				line = 2^(line-1);
				val = bitshift(line,16);
				mask = bitshift(line,16);
				if value == 0
					Datapixx('SetDoutValues', 0, mask);
					Datapixx('RegWr');
				else
					Datapixx('SetDoutValues', val, mask);
					Datapixx('RegWr');
				end
			end
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

