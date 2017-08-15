classdef arduinoManager < optickaCore
	%ARDUINOMANAGER Connects and manages arduino communication
	properties
		port					= ''
		board					= ''
		silentMode		= false %this allows us to be called even if no arduino is attached
		verbose				= true
	end
	properties (SetAccess = private, GetAccess = public)
		device
		deviceID
		availablePins
	end
	properties (SetAccess = private, GetAccess = private)
		allowedProperties='silentMode|verbose'
	end
	methods%------------------PUBLIC METHODS--------------%
		
		%==============CONSTRUCTOR============%
		function obj = arduinoManager(varargin)
			if nargin>0
				obj.parseArgs(varargin,obj.allowedProperties);
            end
            if ~exist('arduino','file')
               obj.comment = 'You need to Install Arduino Support files!';
               obj.silentMode = true;
            end
		end
		
		%===============OPEN DEVICE================%
		function open(obj)
			if obj.silentMode==false && ~isa(obj.device,'arduino')
				try
					if ~isempty(obj.port)
						obj.device = arduino(obj.port);
					else
						obj.device = arduino;
					end
					obj.deviceID = obj.device.Port;
					obj.availablePins = obj.device.AvailablePins;
					for i = 2:13
						configurePin(obj.device,['D' num2str(i)],'unset')
						writeDigitalPin(obj.device,['D' num2str(i)],0);
                    end
                    obj.silentMode = false;
				catch ME
					fprintf('\n\nCouldn''t open Arduino, try a valid name')
					obj.silentMode = true;
				end
			end
		end
		
		%===============SEND TTL================%
		function sendTTL(obj, line, time)
			obj.timedTTL(line,time)
		end
		
		%===============SEND TTL================%
		function timedTTL(obj, line, time)
			if obj.silentMode==false
				if ~exist('line','var') || isempty(line); line = 9; end
				if ~exist('time','var') || isempty(time); time = 500; end
				time = time - 30; %there is an arduino 30ms delay
				if time < 0; time = 0; warning('Arduino TTLs >= ~30ms!');end
				writeDigitalPin(obj.device,['D' num2str(line)],1);
				WaitSecs(time/1e3);
				writeDigitalPin(obj.device,['D' num2str(line)],0);
			end
		end
		
		%===============CLOSE PORT================%
		function close(obj)
			if obj.silentMode==false
				obj.device = [];
				obj.deviceID = '';
				obj.availablePins = '';
			end
		end
		
	end
	
	methods ( Access = private ) %----------PRIVATE METHODS---------%
		%===========Delete Method==========%
		function delete(obj)
			fprintf('sendSerial Delete method will automagically close connection if open...\n');
			obj.close;
		end
		
	end
	
end