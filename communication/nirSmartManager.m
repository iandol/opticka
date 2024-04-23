% ======================================================================
%> @brief Input Output manager, currently just a dummy class
%>
%> 
%>
%> Copyright ©2014-2022 Ian Max Andolina — released: LGPL3, see LICENCE.md
% ======================================================================
classdef nirSmartManager < optickaCore
	
	properties
		ip char = '127.0.0.1'
		port double = 8889
		%> the hardware object
		io dataConnection
		%>
		silentMode logical = false
		%>
		stimOFFValue = 255
		%> 
		verbose = false
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
		allowedProperties = {'ip','port','io','silentMode','verbose'}
	end
	
	methods
		% ===================================================================
		%> @brief Class constructor
		%> 
		%> @param 
		% ===================================================================
		function me = nirSmartManager(varargin)
			if nargin == 0; varargin.name = 'NirSmart Manager'; varargin.type = 'NirSmart'; end
			me=me@optickaCore(varargin); %superclass constructor
			if nargin > 0; me.parseArgs(varargin,me.allowedProperties); end
			me.io = dataConnection('rAddress', me.ip, 'rPort', me.port);
		end

		% ===================================================================
		%> @brief 
		%> 
		%> @param 
		% ===================================================================
		function open(me,varargin)
			if isempty(me.io)
				me.io = dataConnection('rAddress', me.ip, 'rPort', me.port);
			end
			me.io.rAddress = me.ip;
			me.io.rPort = me.port;
			me.io.readSize = 1024;
			try 
				open(me.io);
			catch ERR
				getREport(ERR);
				me.isOpen = false;
				return
			end
			if me.io.isOpen
				me.isOpen = true;
				fprintf('--->>> Connected to %s : %i\n')
			else
				me.isOpen = false;
				error('===>>> !!! Cannot open TCP port');
			end
		end
		
		% ===================================================================
		%> @brief 
		%> 
		%> @param 
		% ===================================================================
		function close(me,varargin)
			try close(me.io); end
			me.isOpen = false;
		end

		% ===================================================================
		%> @brief 
		%> 
		%> @param 
		% ===================================================================
		function sendStrobe(me, value)
			if ~me.isOpen; return; end
			me.lastValue = me.sendValue;
			me.sendValue = value;
			sendString = [250,252,251,253,3,value,252,253,250,251];
			write(me.io, uint8(sendString));
		end
		
		% ===================================================================
		%> @brief 
		%> 
		%> @param 
		% ===================================================================
		function resetStrobe(me,varargin)
			if ~me.isOpen; return; end
			me.sendValue = 0;
		end
		
		% ===================================================================
		%> @brief 
		%> 
		%> @param 
		% ===================================================================
		function triggerStrobe(me,varargin)
			if ~me.isOpen; return; end
			sendString = [250,252,251,253,3,me.sendValue,252,253,250,251];
			write(me.io, uint8(sendString));
		end
		
		% ===================================================================
		%> @brief 
		%> 
		%> @param 
		% ===================================================================
		function prepareStrobe(me,value)
			if ~me.isOpen; return; end
			me.lastValue = me.sendValue;
			me.sendValue = value;
		end

	end

	methods (Hidden = true)
		
		% ===================================================================
		%> @brief 
		%> 
		%> @param 
		% ===================================================================
		function strobeServer(me,value)
			me.sendStrobe(value);
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
		%> @brief Delete method, closes gracefully
		%>
		% ===================================================================
		function delete(me)
			try
				if ~isempty(me.io)
					close(me.io);
				end
			catch
				warning('IO Manager Couldn''t close hardware')
			end
		end
		
	end
	
end

