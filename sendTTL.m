classdef sendTTL < handle
	%SENDSERIAL Connects and manages Serial port communication
	%   Connects and manages Serial port communication
	properties
		name='LabJack'
		deviceID = 3
		silentMode = 0
		header = '/usr/local/include/labjackusb.h'
		library = '/usr/local/lib/liblabjackusb'
		verbosity = 1
		openNow = 1 %allows the constructor to run the open method immediately
		version
		devCount
		isOpen = 0
		handle = []
	end
	properties (SetAccess = private, GetAccess = public)
		functions
	end
	properties (SetAccess = private, GetAccess = private)
		fio4 = 0
		inp = []
		fio4High = hex2dec(['1d'; 'f8'; '03'; '00'; '20'; '01'; '00'; '0d'; '84'; '0b'; '84'; '00'])';
		fio5High = hex2dec(['1f'; 'f8'; '03'; '00'; '22'; '01'; '00'; '0d'; '85'; '0b'; '85'; '00'])';
		fio4Low = hex2dec(['9c'; 'f8'; '03'; '00'; 'a0'; '00'; '00'; '0d'; '84'; '0b'; '04'; '00'])';
		fio5Low = hex2dec(['9e'; 'f8'; '03'; '00'; 'a2'; '00'; '00'; '0d'; '85'; '0b'; '05'; '00'])';
		vHandle = 0
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
			end
			if regexp(obj.name,'null') %we were deliberately passed null, means go into silent mode
				obj.silentMode = 1;
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
				obj.functions = libfunctions('liblabjackusb', '-full');
				obj.version =  calllib('liblabjackusb','LJUSB_GetLibraryVersion');
				obj.devCount = calllib('liblabjackusb','LJUSB_GetDevCount',obj.deviceID);
				obj.handle = calllib('liblabjackusb','LJUSB_OpenDevice',1,0,obj.deviceID);
				obj.validHandle;
				if obj.vHandle
					obj.isOpen = 1;
					obj.salutation('open method','LabJack succesfully opened...');
				else
					obj.isOpen = 0;
					obj.handle = [];
					obj.silentMode = 1; %we switch into silent mode just in case someone tries to use the object
					obj.salutation('open method','LabJack open failed, going into silent mode');
				end
			else
				obj.isOpen = 0;
				obj.handle = [];
				obj.vHandle = 0;
				obj.silentMode = 1; %double make sure it is set to 1 exactly
			end
		end
		
		%===============CLOSE Labjack================%
		% 		void LJUSB_CloseDevice(HANDLE hDevice);
		% 		//Closes the handle of a LabJack USB device.
		function close(obj)
			if ~isempty(obj.handle) && obj.silentMode==0
				obj.validHandle; %double-check we still have valid handle
				if obj.vHandle && ~isempty(obj.handle)
					calllib('liblabjackusb','LJUSB_CloseDevice',obj.handle);
				end
				%obj.validHandle;
				obj.isOpen = 0;
				obj.handle=[];
				obj.vHandle = 0;
				obj.salutation('close method',['Closed handle: ' num2str(obj.vHandle)]);
			else
				obj.salutation('close method',['No handle to close: ' num2str(obj.vHandle)]);
			end
		end
		
		%===============CHECK Labjack================%
		% 		bool LJUSB_IsHandleValid(HANDLE hDevice);
		% 		//Is handle valid.
		function validHandle(obj)
			if obj.silentMode == 0
				if ~isempty(obj.handle)
					obj.vHandle = calllib('liblabjackusb','LJUSB_IsHandleValid',obj.handle);
					if obj.vHandle
						obj.salutation('validHandle Method','VALID Handle');
					else
						obj.salutation('validHandle Method','INVALID Handle');
					end
				else 
					obj.vHandle = 0;
					obj.isOpen = 0;
					obj.handle = [];
					obj.salutation('validHandle Method','INVALID Handle');
				end
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
			if obj.silentMode == 0 && obj.vHandle == 1
				if ~exist('val','var')
					val = obj.fio4;
				end
				if val == 1
					out = calllib('liblabjackusb', 'LJUSB_Write', obj.handle, obj.fio4High, 12);
					in =  calllib('liblabjackusb', 'LJUSB_Read', obj.handle, obj.inp, 10);
					obj.fio4 = 1;
					obj.salutation('SETFIO4','FIO4 is HIGH')
				else
					out = calllib('liblabjackusb', 'LJUSB_Write', obj.handle, obj.fio4Low, 12);
					in =  calllib('liblabjackusb', 'LJUSB_Read', obj.handle, obj.inp, 10);
					obj.fio4 = 0;
					obj.salutation('SETFIO4','FIO4 is LOW')
				end
			end
		end	
		
		%===============Toggle FIO4======================%
		function toggleFIO4(obj)
			if obj.silentMode == 0 && obj.vHandle == 1
				obj.fio4=abs(obj.fio4-1);
				obj.setFIO4(obj.fio4);
			end
		end
		
	end
	
	methods ( Access = private ) %----------PRIVATE METHODS---------%
		%===========Salutation==========%
		function salutation(obj,in,message)
			if obj.verbosity > 0
				if ~exist('in','var')
					in = 'General Message';
				end
				if exist('message','var')
					fprintf([message ' | ' in '\n']);
				else
					fprintf(['\nHello from ' obj.name ' | sendTTL\n\n']);
				end
			end
		end
	end
end