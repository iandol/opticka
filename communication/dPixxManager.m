classdef dPixxManager < optickaCore
	%UNTITLED Summary of this class goes here
	%   Detailed explanation goes here
	
	properties
		verbose = true
		strobeLine = 16
		%> silentMode allows one to gracefully fail methods without a dataPixx connected
		silentMode = false
	end
	
	properties (SetAccess = protected, GetAccess = public)
		nBits = 0
		isOpen = false
	end
	
	properties (SetAccess = private, GetAccess = private)
		%> properties allowed to be modified during construction
		allowedProperties='silentMode|verbose|strobeLine'
	end
	
	methods
		function obj = dPixxManager(varargin)
			if nargin == 0; varargin.name = 'dataPixx Manager'; end
			obj=obj@optickaCore(varargin); %superclass constructor
			if nargin > 0; obj.parseArgs(varargin,obj.allowedProperties); end
		end
		
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
		
		function close(obj)
			if obj.isOpen
				obj.salutation('close method','Closing DataPixx...',true);
				Datapixx('Close');				
				obj.isOpen = false;
			end
		end
		
		function sendStrobe(obj,value)
			if obj.isOpen
				valueStrobe = bitor(value, 2^15);
				strobe = [value valueStrobe, 0];
				bufferAddress = 8e6;
				Datapixx('WriteDoutBuffer', strobe, bufferAddress);
				Datapixx('SetDoutSchedule', 0, [1e5,1], length(strobe), bufferAddress, length(strobe));
				Datapixx('StartDoutSchedule');
				Datapixx('RegWr');
			end
		end
		
		function prepareStrobe(obj,value)
			if obj.isOpen
				if value > 32767; value = 32767; end
				valueStrobe = bitor(value, 2^(obj.strobeLine-1));
				strobe = [value valueStrobe, 0];
				bufferAddress = 8e6;
				Datapixx('WriteDoutBuffer', strobe, bufferAddress);
				Datapixx('SetDoutSchedule', 0, [1e5,1], length(strobe), bufferAddress, length(strobe));
				if obj.verbose; fprintf('>>>STROBE Value %g prepared!\n',value); end
			end
		end
		
		function triggerStrobe(obj)
			if obj.isOpen
				Datapixx('StartDoutSchedule');
				Datapixx('RegWrVideoSync');
				%fprintf('>>>STROBE sent to Plexon!\n');
			end
		end
		
		function rstart(obj)
			if obj.isOpen
				setLine(obj,8,1);
				if obj.verbose; fprintf('>>>RSTART sent to Plexon!\n'); end
			end
		end
		
		function rstop(obj)
			if obj.isOpen
				setLine(obj,8,0);
				if obj.verbose; fprintf('>>>RSTOP sent to Plexon!\n'); end
			end
		end
		
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
		%> @brief Delete method
		%>
		% ===================================================================
		function delete(obj)
			close(obj);
			obj.salutation('DELETE method',[obj.fullName ' has been closed/reset...']);
		end
		
	end
	
end

