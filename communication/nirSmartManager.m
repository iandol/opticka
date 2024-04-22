% ======================================================================
%> @brief Input Output manager, currently just a dummy class
%>
%> 
%>
%> Copyright ©2014-2022 Ian Max Andolina — released: LGPL3, see LICENCE.md
% ======================================================================
classdef nirSmartManager < optickaCore
	
	properties
		ip char = '192.168.31.145'
		port double = 5566
		%> verbosity
		verbose logical = true
		%> the hardware object
		io dataConnection
		%>
		silentMode logical = false
		%>
		stimOFFValue = 255
	end
	
	properties (SetAccess = private, GetAccess = public, Dependent = true)
		%> hardware class
		type char
	end
	
	properties (SetAccess = protected, GetAccess = public)
		isOpen logical = false
		sendValue
		lastValue
	end
	
	properties (SetAccess = private, GetAccess = private)
		%> properties allowed to be modified during construction
		allowedProperties char = 'io|verbose'
		t_Client
	end
	
	methods
		% ===================================================================
		%> @brief Class constructor
		%> 
		%> @param 
		% ===================================================================
		function me = nirSmartManager(varargin)
			if nargin == 0; varargin.name = 'NirSmart Manager'; end
			me=me@optickaCore(varargin); %superclass constructor
			if nargin > 0; me.parseArgs(varargin,me.allowedProperties); end
		end

		% ===================================================================
		%> @brief 
		%> 
		%> @param 
		% ===================================================================
		function open(me,varargin)
			me.io = tcpclient(me.ip,me.port);
			set(me.t_Client,'InputBufferSize',1024);
			%%t_Client.InputBuffersize = 100000;
			fopen(me.t_Client);
			disp("Connected!");
			me.isOpen = true;
		end
		
		% ===================================================================
		%> @brief 
		%> 
		%> @param 
		% ===================================================================
		function close(me,varargin)
			fclose(me.t_Client);
			me.isOpen = false;
		end

		% ===================================================================
		%> @brief 
		%> 
		%> @param 
		% ===================================================================
		function sendStrobe(me, value)
			me.lastValue = me.sendValue;
			me.sendValue = value;
			sentString = [250,252,251,253,3,value,252,253,250,251];
			if me.isOpen
				for i = 1:length(sentString)
            		data_sent = sentString(i);
            		fwrite(me.t_Client, data_sent);
        		end
			end
		end
		
		% ===================================================================
		%> @brief 
		%> 
		%> @param 
		% ===================================================================
		function resetStrobe(me,varargin)

		end
		
		% ===================================================================
		%> @brief 
		%> 
		%> @param 
		% ===================================================================
		function triggerStrobe(me,varargin)

		end
		
		% ===================================================================
		%> @brief 
		%> 
		%> @param 
		% ===================================================================
		function prepareStrobe(me,value)
			me.lastValue = me.sendValue;
			me.sendValue = value;
		end
		
		% ===================================================================
		%> @brief 
		%> 
		%> @param 
		% ===================================================================
		function strobeServer(me,value)
			me.lastValue = me.sendValue;
			me.sendValue = value;
		end

		% ===================================================================
		%> @brief 
		%> 
		%> @param 
		% ===================================================================
		function sendTTL(me,value)

		end
		
		% ===================================================================
		%> @brief 
		%> 
		%> @param 
		% ===================================================================
		function startRecording(me,value)

		end
		
		% ===================================================================
		%> @brief 
		%> 
		%> @param 
		% ===================================================================
		function resumeRecording(me,value)

		end
		
		% ===================================================================
		%> @brief 
		%> 
		%> @param 
		% ===================================================================
		function pauseRecording(me,value)

		end
		
		% ===================================================================
		%> @brief 
		%> 
		%> @param 
		% ===================================================================
		function stopRecording(me,value)

		end
		
		% ===================================================================
		%> @brief 
		%> 
		%> @param 
		% ===================================================================
		function startFixation(me)
			
		end
		
		% ===================================================================
		%> @brief 
		%> 
		%> @param 
		% ===================================================================
		function correct(me)
			
		end
		
		% ===================================================================
		%> @brief 
		%> 
		%> @param 
		% ===================================================================
		function incorrect(me)
			
		end
		
		% ===================================================================
		%> @brief 
		%> 
		%> @param 
		% ===================================================================
		function breakFixation(me)
			
		end
		
		% ===================================================================
		%> @brief 
		%> 
		%> @param 
		% ===================================================================
		function rstart(me,varargin)

		end
		
		
		% ===================================================================
		%> @brief 
		%> 
		%> @param 
		% ===================================================================
		function rstop(me,varargin)

		end
		
		% ===================================================================
		%> @brief 
		%> 
		%> @param 
		% ===================================================================
		function timedTTL(me,varargin)

		end
		
		% ===================================================================
		%> @brief 
		%> 
		%> @param 
		% ===================================================================
		function type = get.type(me)
			if isempty(me.io)
				type = 'undefined';
			else
				if isa(me.io,'plusplusManager')
					type = 'Display++';
				elseif isa(me.io,'labJackT')
					type = 'LabJack T4/T7';
				elseif isa(me.io,'labJack')
					type = 'LabJack U3/U6';
				elseif isa(me.io,'dPixxManager')
					type = 'DataPixx';
				elseif isa(me.io,'arduinoManager')
					type = 'Arduino';
				end
			end
		end
			
		% ===================================================================
		%> @brief Delete method, closes gracefully
		%>
		% ===================================================================
		function delete(me)
			try
				if ~isempty(me.io)
					close(me);
				end
			catch
				warning('IO Manager Couldn''t close hardware')
			end
		end
		
	end
	
end

