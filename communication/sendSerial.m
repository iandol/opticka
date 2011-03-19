classdef sendSerial < handle
	%SENDSERIAL Connects and manages Serial port communication
	%   Connects and manages Serial port communication
	properties
		name='pci-serial0'
		baudRate=115200
		silentMode=0 %this allows us to be called even if no serial port is attached
		verbosity=1
		openNow=1 %allows the constructor to run the open method immediately
	end
	properties (SetAccess = private, GetAccess = public)
		portHandle
		deviceID
		toggleRTS=0 %keep the state here to toggle on succesive calls
		toggleDTR=0
	end
	properties (SetAccess = private, GetAccess = private)
		%defaultName='usbserial-A600drIC';
		defaultName = 'pci-serial0';
		allowedPropertiesBase='^(name|baudRate|silentMode|verbosity|openNow)$'
	end
	methods%------------------PUBLIC METHODS--------------%
		
		%==============CONSTRUCTOR============%
		function obj = sendSerial(args)
			if nargin>0 && isstruct(args)
				if nargin>0 && isstruct(args)
					fnames = fieldnames(args); %find our argument names
					for i=1:length(fnames);
						if regexp(fnames{i},obj.allowedPropertiesBase) %only set if allowed property
							obj.salutation(fnames{i},'Configuring property in sendSerial constructor');
							obj.(fnames{i})=args.(fnames{i}); %we set up the properies from the arguments as a structure
						end
					end
				end
			elseif nargin==1 && ischar(args)
				obj.name=args; %assume a name
			end
			if isempty(obj.name) || strcmpi(obj.name,'default')%we were deliberately passed an empty name, will re-specify default
				obj.name=obj.defaultName;
			end
			if ispc % there is a find bug on windows in PTB (reported to the forum)
				obj.name = 'com1';
				obj.deviceID = obj.name;
			else
				obj.find; %find the full connection info
			end
			if obj.openNow==1
				obj.open
			end
		end
		
		%===============OPEN PORT================%
		function open(obj)
			if obj.silentMode==0
				obj.portHandle=IOPort('OpenSerialport', obj.deviceID, sprintf(' BaudRate=%i',obj.baudRate));
				IOPort('Verbosity', obj.verbosity);
				if isempty(obj.portHandle)
					obj.salutation('','Couldn''t open Serial Port, try the open method with another name');
					obj.silentMode=1;
				end
			end
		end
		
		%===============FIND PORT================%
		function find(obj,name)
			if exist('name','var')
				if ischar(name)
					obj.name=name;
				end
			end
			obj.deviceID=FindSerialPort(obj.name,1,1);
			if isempty(obj.deviceID)
				obj.salutation('','Couldn''t find Serial Port, try the find method with another name');
				obj.silentMode=1;
			else
				obj.silentMode=0;
			end
		end
		
		%===============CLOSE PORT================%
		function close(obj)
			if ~isempty(obj.portHandle)
				IOPort('Verbosity', 4); %reset to default
				IOPort('Close', obj.portHandle);
				obj.portHandle=[];
			end
		end
		
		%===============SET RTS Line================%
		function setRTS(obj,value)
			if obj.silentMode==0
				if value==0 || value==1
					IOPort('ConfigureSerialPort', obj.portHandle, sprintf('RTS=%i', value));
				end
			end
		end
		
		%===============TOGGLE RTS Line================%
		function toggleRTSLine(obj)
			if obj.silentMode==0
				IOPort('ConfigureSerialPort', obj.portHandle, sprintf('RTS=%i', obj.toggleRTS));
				obj.toggleRTS=~obj.toggleRTS;	
			end
		end
		
		%===============SET DTR Line================%
		function setDTR(obj,value)
			if obj.silentMode==0
				if value==0 || value==1
					IOPort('ConfigureSerialPort', obj.portHandle, sprintf('DTR=%i', value));
				end
			end
		end
		
		%===============TOGGLE DTR Line================%
		function toggleDTRLine(obj)
			if obj.silentMode==0
				IOPort('ConfigureSerialPort', obj.portHandle, sprintf('DTR=%i', obj.toggleDTR));
				obj.toggleDTR=~obj.toggleDTR;	
			end
		end
	end
	
	
	methods ( Access = private ) %----------PRIVATE METHODS---------%
		%===========Delete Method==========%
		function delete(obj)
			fprintf('sendSerial Delete method will automagically close connection if open...\n');
			obj.close;
		end
		
		%===========Salutation==========%
		function salutation(obj,in,message)
			if obj.verbosity > 0
				if ~exist('in','var')
					in = 'random user';
				end
				if exist('message','var')
					fprintf([message ' | ' in '\n']);
				else
					fprintf(['\nHello from ' obj.name ' | sendSerial\n\n']);
				end
			end
		end
	end
end