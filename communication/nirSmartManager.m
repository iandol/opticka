% ======================================================================
%> @brief Input Output manager, currently just a dummy class
%>
%> 
%>
%> Copyright ©2014-2022 Ian Max Andolina — released: LGPL3, see LICENCE.md
% ======================================================================
classdef nirSmartManager < optickaCore
	
	properties
		%> verbosity
		verbose = true
		%> the hardware object
		io
		%>
		silentMode logical = true
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
		function obj = nirSmartManager(varargin)
			if nargin == 0; varargin.name = 'NirSmart Manager'; end
			obj=obj@optickaCore(varargin); %superclass constructor
			if nargin > 0; obj.parseArgs(varargin,obj.allowedProperties); end
		end

		% ===================================================================
		%> @brief 
		%> 
		%> @param 
		% ===================================================================
		function open(obj,varargin)
			obj.t_Client = tcpclient('192.168.31.145',5566);
			set(obj.t_Client,'InputBufferSize',1024);
			%%t_Client.InputBuffersize = 100000;
			fopen(obj.t_Client);
			disp("Connected!");
			obj.isOpen = true;
		end
		
		% ===================================================================
		%> @brief 
		%> 
		%> @param 
		% ===================================================================
		function close(obj,varargin)
			fclose(obj.t_Client);
			obj.isOpen = false;
		end

		% ===================================================================
		%> @brief 
		%> 
		%> @param 
		% ===================================================================
		function sendStrobe(obj, value)
			obj.lastValue = obj.sendValue;
			obj.sendValue = value;
			sentString = [250,252,251,253,3,value,252,253,250,251];
			if obj.isOpen
				for i = 1:length(sentString)
            		data_sent = sentString(i);
            		fwrite(obj.t_Client, data_sent);
        		end
			end
		end
		
		% ===================================================================
		%> @brief 
		%> 
		%> @param 
		% ===================================================================
		function resetStrobe(obj,varargin)

		end
		
		% ===================================================================
		%> @brief 
		%> 
		%> @param 
		% ===================================================================
		function triggerStrobe(obj,varargin)

		end
		
		% ===================================================================
		%> @brief 
		%> 
		%> @param 
		% ===================================================================
		function prepareStrobe(obj,value)
			obj.lastValue = obj.sendValue;
			obj.sendValue = value;
		end
		
		% ===================================================================
		%> @brief 
		%> 
		%> @param 
		% ===================================================================
		function strobeServer(obj,value)
			obj.lastValue = obj.sendValue;
			obj.sendValue = value;
		end

		% ===================================================================
		%> @brief 
		%> 
		%> @param 
		% ===================================================================
		function sendTTL(obj,value)

		end
		
		% ===================================================================
		%> @brief 
		%> 
		%> @param 
		% ===================================================================
		function startRecording(obj,value)

		end
		
		% ===================================================================
		%> @brief 
		%> 
		%> @param 
		% ===================================================================
		function resumeRecording(obj,value)

		end
		
		% ===================================================================
		%> @brief 
		%> 
		%> @param 
		% ===================================================================
		function pauseRecording(obj,value)

		end
		
		% ===================================================================
		%> @brief 
		%> 
		%> @param 
		% ===================================================================
		function stopRecording(obj,value)

		end
		
		% ===================================================================
		%> @brief 
		%> 
		%> @param 
		% ===================================================================
		function startFixation(obj)
			
		end
		
		% ===================================================================
		%> @brief 
		%> 
		%> @param 
		% ===================================================================
		function correct(obj)
			
		end
		
		% ===================================================================
		%> @brief 
		%> 
		%> @param 
		% ===================================================================
		function incorrect(obj)
			
		end
		
		% ===================================================================
		%> @brief 
		%> 
		%> @param 
		% ===================================================================
		function breakFixation(obj)
			
		end
		
		% ===================================================================
		%> @brief 
		%> 
		%> @param 
		% ===================================================================
		function rstart(obj,varargin)

		end
		
		
		% ===================================================================
		%> @brief 
		%> 
		%> @param 
		% ===================================================================
		function rstop(obj,varargin)

		end
		
		% ===================================================================
		%> @brief 
		%> 
		%> @param 
		% ===================================================================
		function timedTTL(obj,varargin)

		end
		
		% ===================================================================
		%> @brief 
		%> 
		%> @param 
		% ===================================================================
		function type = get.type(obj)
			if isempty(obj.io)
				type = 'undefined';
			else
				if isa(obj.io,'plusplusManager')
					type = 'Display++';
				elseif isa(obj.io,'labJackT')
					type = 'LabJack T4/T7';
				elseif isa(obj.io,'labJack')
					type = 'LabJack U3/U6';
				elseif isa(obj.io,'dPixxManager')
					type = 'DataPixx';
				elseif isa(obj.io,'arduinoManager')
					type = 'Arduino';
				end
			end
		end
			
		% ===================================================================
		%> @brief Delete method, closes gracefully
		%>
		% ===================================================================
		function delete(obj)
			try
				if ~isempty(obj.io)
					close(obj);
				end
			catch
				warning('IO Manager Couldn''t close hardware')
			end
		end
		
	end
	
end

