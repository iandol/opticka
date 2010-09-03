classdef sendTTL < handle
	%SENDSERIAL Connects and manages Serial port communication
	%   Connects and manages Serial port communication
	properties
		name='LabJack'
		deviceID = 3
		silentMode=0 %this allows us to be called even if no serial port is attached
		header = '/usr/local/include/labjackusb.h'
		library = '/usr/local/lib/liblabjackusb'
		verbosity=0
		openNow=1 %allows the constructor to run the open method immediately
		version
		devCount
		isOpen
		handle
	end
	properties (SetAccess = private, GetAccess = private)
		allowedPropertiesBase='^(name|silentMode|verbosity|openNow)$'
	end
	methods%------------------PUBLIC METHODS--------------%
		
		%==============CONSTRUCTOR============%
		function obj = sendTTL(args)
			if nargin>0 && isstruct(args)
				if nargin>0 && isstruct(args)
					fnames = fieldnames(args); %find our argument names
					for i=1:length(fnames);
						if regexp(fnames{i},obj.allowedPropertiesBase) %only set if allowed property
							obj.salutation(fnames{i},'Configuring property in sendTTL constructor');
							obj.(fnames{i})=args.(fnames{i}); %we set up the properies from the arguments as a structure
						end
					end
				end
			elseif nargin==1 && ischar(args)
				obj.name=args; %assume a name
			end
			if isempty(obj.name) %we were deliberately passed an empty name, will re-specify default
				obj.name='LabJack';
			end
			if obj.openNow==1
				obj.open
			end
		end
		
		%===============OPEN Labjack================%
		function open(obj)
			if obj.silentMode==0
				if ~libisloaded('liblabjackusb')
					loadlibrary(obj.library,obj.header);
				end
				libfunctions liblabjackusb -full
				obj.version =  calllib('liblabjackusb','LJUSB_GetLibraryVersion');
				obj.devCount = calllib('liblabjackusb','LJUSB_GetDevCount',obj.deviceID);
				obj.handle = calllib('liblabjackusb','LJUSB_OpenDevice',1,0,obj.deviceID);
				obj.isOpen = 1;
			end
		end
		
		%===============CLOSE Labjack================%
		% 		void LJUSB_CloseDevice(HANDLE hDevice);
		% 		//Closes the handle of a LabJack USB device.
		function close(obj)
			if ~isempty(obj.handle)
				calllib('liblabjackusb','LJUSB_CloseDevice',obj.handle);
				obj.isOpen = 0;
				obj.handle=[];
			end
		end
		
		%===============Raw WRITE================%
		% 		unsigned long LJUSB_Write(HANDLE hDevice, BYTE *pBuff, unsigned long count);
		% 		// Writes to a device. Returns the number of bytes written, or -1 on error.
		% 		// hDevice = The handle for your device
		% 		// pBuff = The buffer to be written to the device.
		% 		// count = The number of bytes to write.
		% 		// This function replaces the deprecated LJUSB_BulkWrite, which required the endpoint	
		function rawWrite(obj)
			
		end
		
		%===============Raw READ================%
		% 		unsigned long LJUSB_Read(HANDLE hDevice, BYTE *pBuff, unsigned long count);
		% 		// Reads from a device. Returns the number of bytes read, or -1 on error.
		% 		// hDevice = The handle for your device
		% 		// pBuff = The buffer to filled in with bytes from the device.
		% 		// count = The number of bytes expected to be read.
		% 		// This function replaces the deprecated LJUSB_BulkRead, which required the endpoint
		function rawRead(obj)
	
		end
		
		%===============Raw WRITE PORT================%
		%HIGH:
		%[0x1d, 0xf8, 0x3, 0x0, 0x20, 0x1, 0x0, 0xd, 0x84, 0xb, 0x84, 0x0]
		%['1d'; 'f8'; '03'; '00'; '20'; '01'; '00'; '0d'; '84'; '0b'; '84'; '00']
		%LOW:
		%[0x9c, 0xf8, 0x3, 0x0, 0xa0, 0x0, 0x0, 0xd, 0x84, 0xb, 0x4, 0x0]
		%['9c'; 'f8'; '03'; '00'; 'a0'; '00'; '00'; '0d'; '84'; '0b'; '04';
		%'00']
		function setFIO4(obj,val)
			highPtr = hex2dec(['1d'; 'f8'; '03'; '00'; '20'; '01'; '00'; '0d'; '84'; '0b'; '84'; '00'])';
			lowPtr = hex2dec(['9c'; 'f8'; '03'; '00'; 'a0'; '00'; '00'; '0d'; '84'; '0b'; '04'; '00'])';
			%highPtr=libpointer('uint8Ptr',high);
			%lowPtr=libpointer('uint8Ptr',low);
			if ~exist('val','var')
				val = 0;
			end
			inp=[];
			if val == 1
				out = calllib('liblabjackusb', 'LJUSB_Write', obj.handle, highPtr, 12);
				in =  calllib('liblabjackusb', 'LJUSB_Read', obj.handle, inp, 10);
			else
				out = calllib('liblabjackusb', 'LJUSB_Write', obj.handle, lowPtr, 12);
				in =  calllib('liblabjackusb', 'LJUSB_Read', obj.handle, inp, 10);
			end	
		end		
	end
	
	methods ( Access = private ) %----------PRIVATE METHODS---------%
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