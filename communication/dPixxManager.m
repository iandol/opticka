classdef dPixxManager < optickaCore
	%UNTITLED Summary of this class goes here
	%   Detailed explanation goes here
	
	properties
		verbose = true
		strobeLine = 15
	end
	
	properties (SetAccess = protected, GetAccess = public)
		nBits = 0
		isOpen = false
	end
	
	methods
		function obj = dPixxManager(varargin)
			if nargin == 0; varargin.name = 'dataPixx Manager'; end
			obj=obj@optickaCore(varargin); %superclass constructor
			if nargin > 0; obj.parseArgs(varargin,obj.allowedProperties); end
		end
		
		function open(obj)
			tic
			% Open Datapixx, and stop any schedules which might already be running
			Datapixx('Open');
			obj.nBits = Datapixx('GetDinNumBits');
			Datapixx('StopAllSchedules');
			Datapixx('RegWrRd');    % Synchronize Datapixx registers to local register cache
			fprintf('open = %g ms\n',toc*1000);
			obj.isOpen = true;
		end
		
		function close(obj)
			if obj.isOpen
				Datapixx('Close')
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
				if value > 32767;value = 32767;end
				valueStrobe = bitor(value, 2^15);
				strobe = [value valueStrobe, 0];
				bufferAddress = 8e6;
				Datapixx('WriteDoutBuffer', strobe, bufferAddress);
				Datapixx('SetDoutSchedule', 0, [1e5,1], length(strobe), bufferAddress, length(strobe));
			end
		end
		
		function triggerStrobe(obj)
			if obj.isOpen
				Datapixx('StartDoutSchedule');
				Datapixx('RegWrVideoSync');
			end
		end
		
		function rstart(obj)
			if obj.isOpen
				setLine(obj,8,1);
			end
		end
		
		function rstop(obj)
			if obj.isOpen
				setLine(obj,8,0);
			end
		end
		
		
		function setLine(obj,line,value)
			if obj.isOpen
				if line > 8 || line < 1
					fprintf('1-7 lines are available on dataPixx only!\n')
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
		
		function findStrobe(obj)
			if obj.isOpen
				a = 1;
				for i=1:7
					fprintf('%g Strobe %g: %s (%g)\n',i,a,dec2bin(a),length(dec2bin(a)));
					Datapixx('SetDoutValues', bitshift(a,2^16), bitshift(a,2^16));
					Datapixx('RegWrRd');
					WaitSecs(0.01);
					Datapixx('SetDoutValues', 0, bitshift(a,2^16));
					Datapixx('RegWrRd');
					WaitSecs(1);
					a = a * 2;
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

