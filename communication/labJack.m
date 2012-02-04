% ========================================================================
%> @brief LABJACK Connects and manages a LabJack U3 / U6
%>
%> Connects and manages a LabJack U3 / U6
%>
% ========================================================================
classdef labJack < handle
	
	properties
		name='LabJack'
		%> silentMode allows one to call methods without a working labJack
		%> what LabJack device to use; 3 = U3, 6 = U6
		deviceID = 6
		%> friendly name, setting this to 'null' will force silentMode=1
		silentMode = false
		%> header needed by loadlib
		header = '/usr/local/include/labjackusb.h'
		%> the library itself
		library = '/usr/local/lib/liblabjackusb'
		%> how much detail to show
		verbose = false
		%> allows the constructor to run the open method immediately
		openNow = true
		%> strobeTime is time of strobe in unit multiples of 127uS 8 ~=1ms
		strobeTime = 4
	end
	
	properties (SetAccess = private, GetAccess = public)
		%> function list returned from loading the exodriver
		functions
		%> library version returned on first open
		version
		%> how many devices are connected
		devCount
		%> handle to the opened device itself
		handle = []
		%> on succesful open set this to 1
		isOpen = false
		%> an input buffer, currently unused.
		inp = []
		%> FIO0 state
		fio0 = 0
		%> FIO1 state
		fio1 = 0
		%> FIO4 state
		fio4 = 0
		%> FIO5 state
		fio5 = 0
		%> FIO6 state
		fio6 = 0
		%> FIO7 state
		fio7 = 0
		%> LED state
		led = 1
		%> The raw strobed word command generated with prepareStrobe, sent with strobeWord
		command = []
	end
	
	properties (SetAccess = private, GetAccess = private)
		%>raw commands
		fio0High = hex2dec(['15'; 'f8'; '03'; '00'; '18'; '01'; '00'; '0d'; '80'; '0b'; '80'; '00'])'
		fio1High = hex2dec(['17'; 'f8'; '03'; '00'; '1a'; '01'; '00'; '0d'; '81'; '0b'; '81'; '00'])'
		fio4High = hex2dec(['1d'; 'f8'; '03'; '00'; '20'; '01'; '00'; '0d'; '84'; '0b'; '84'; '00'])'
		fio5High = hex2dec(['1f'; 'f8'; '03'; '00'; '22'; '01'; '00'; '0d'; '85'; '0b'; '85'; '00'])'
		fio6High = hex2dec(['21'; 'f8'; '03'; '00'; '24'; '01'; '00'; '0d'; '86'; '0b'; '86'; '00'])'
		fio7High = hex2dec(['23'; 'f8'; '03'; '00'; '26'; '01'; '00'; '0d'; '87'; '0b'; '87'; '00'])'
		fio0Low  = hex2dec(['94'; 'f8'; '03'; '00'; '98'; '00'; '00'; '0d'; '80'; '0b'; '00'; '00'])'
		fio1Low  = hex2dec(['96'; 'f8'; '03'; '00'; '9a'; '00'; '00'; '0d'; '81'; '0b'; '01'; '00'])'
		fio4Low  = hex2dec(['9c'; 'f8'; '03'; '00'; 'a0'; '00'; '00'; '0d'; '84'; '0b'; '04'; '00'])'
		fio5Low  = hex2dec(['9e'; 'f8'; '03'; '00'; 'a2'; '00'; '00'; '0d'; '85'; '0b'; '05'; '00'])'
		fio6Low  = hex2dec(['a0'; 'f8'; '03'; '00'; 'a4'; '00'; '00'; '0d'; '86'; '0b'; '06'; '00'])'
		fio7Low  = hex2dec(['a2'; 'f8'; '03'; '00'; 'a6'; '00'; '00'; '0d'; '87'; '0b'; '07'; '00'])'
		ledIsON  = hex2dec(['05'; 'f8'; '02'; '00'; '0a'; '00'; '00'; '09'; '01'; '00'])'
		ledIsOFF = hex2dec(['04'; 'f8'; '02'; '00'; '09'; '00'; '00'; '09'; '00'; '00'])'
		%> Is our handle a valid one?
		vHandle = 0
		%> what properties are allowed to be passed on construction
		allowedProperties='deviceID|name|silentMode|verbose|openNow|header|library|strobeTime'
		%>document what our strobed word is actually setting
		comment = ''
	end
	
	%=======================================================================
	methods %------------------PUBLIC METHODS
		%=======================================================================
		
		% ===================================================================
		%> @brief Class constructor
		%>
		%> More detailed description of what the constructor does.
		%>
		%> @param args are passed as a structure of properties which is
		%> parsed.
		%> @return instance of labJack class.
		% ===================================================================
		function obj = labJack(varargin)
			if nargin>0 
				obj.parseArgs(varargin,obj.allowedProperties);
			end
			if strcmpi(obj.name, 'null') || ispc %we were deliberately passed null, means go into silent mode
				obj.silentMode = true;
				obj.verbose = true;
				obj.salutation('CONSTRUCTOR Method','labJack running in silent mode...')
				obj.verbose = false;
			elseif obj.openNow == true
				obj.open
			end
		end
		
		% ===================================================================
		%> @brief Open the LabJack device
		%>
		%> Open the LabJack device
		% ===================================================================
		function open(obj)
			if obj.silentMode == false
				if ~libisloaded('liblabjackusb')
					try
						loadlibrary(obj.library,obj.header);
					catch %#ok<CTCH>
						obj.silentMode = true;
						obj.verbose = true;
						return
					end
				end
				obj.functions = libfunctions('liblabjackusb', '-full'); %store our raw lib functions
				obj.version =  calllib('liblabjackusb','LJUSB_GetLibraryVersion');
				obj.devCount = calllib('liblabjackusb','LJUSB_GetDevCount',obj.deviceID);
				if obj.devCount == 0
					obj.salutation('open method','No LabJack devices found, going into silent mode');
					obj.isOpen = false;
					obj.handle = [];
					obj.vHandle = false;
					obj.verbose = false;
					obj.silentMode = true; %we switch into silent mode just in case someone tries to use the object
					return
				end
				obj.handle = calllib('liblabjackusb','LJUSB_OpenDevice',1,0,obj.deviceID);
				obj.validHandle;
				if obj.vHandle
					obj.isOpen = true;
					obj.salutation('open method','LabJack succesfully opened...');
					none=[0,0,0];
					obj.setDIO(none); %Sink all our DIO to output LOW
				else
					obj.salutation('open method','LabJack didn''t open, going into silent mode');
					obj.isOpen = false;
					obj.handle = [];
					obj.verbose = false;
					obj.silentMode = true; %we switch into silent mode just in case someone tries to use the object
				end
			else
				obj.isOpen = false;
				obj.handle = [];
				obj.vHandle = false;
				obj.verbose = false;
				obj.silentMode = true; %double make sure it is set to 1 exactly
			end
		end
		
		% ===================================================================
		%> @brief Close the LabJack device
		%>	void LJUSB_CloseDevice(HANDLE hDevice);
		%>	//Closes the handle of a LabJack USB device.
		% ===================================================================
		function close(obj)
			if ~isempty(obj.handle) && obj.silentMode == false
				obj.validHandle; %double-check we still have valid handle
				if obj.vHandle && ~isempty(obj.handle)
					calllib('liblabjackusb','LJUSB_CloseDevice',obj.handle);
				end
				obj.isOpen = false;
				obj.handle=[];
				obj.vHandle = 0;
				obj.salutation('CLOSE method',['Closed handle: ' num2str(obj.vHandle)]);
			else
				obj.salutation('CLOSE method',['No handle to close: ' num2str(obj.vHandle)]);
			end
		end
		
		% ===================================================================
		%> @brief Is Handle Valid?
		%>	bool LJUSB_IsHandleValid(HANDLE hDevice);
		%>	//Is handle valid.
		% ===================================================================
		function validHandle(obj)
			if obj.silentMode == false
				if ~isempty(obj.handle)
					obj.vHandle = calllib('liblabjackusb','LJUSB_IsHandleValid',obj.handle);
					if obj.vHandle
						obj.salutation('validHandle Method','VALID Handle');
					else
						obj.salutation('validHandle Method','INVALID Handle');
					end
				else
					obj.vHandle = false;
					obj.isOpen = false;
					obj.handle = [];
					obj.salutation('validHandle Method','INVALID Handle');
				end
			end
		end
		
		% ===================================================================
		%> @brief Write formatted command string to LabJack
		%> 		unsigned long LJUSB_Write(HANDLE hDevice, BYTE *pBuff, unsigned long count);
		%> 		// Writes to a device. Returns the number of bytes written, or -1 on error.
		%> 		// hDevice = The handle for your device
		%> 		// pBuff = The buffer to be written to the device.
		%> 		// count = The number of bytes to write.
		%> 		// This function replaces the deprecated LJUSB_BulkWrite, which required the endpoint
		%>
		%> @param byte The raw hex encoded command packet to send
		% ===================================================================
		function out = rawWrite(obj,byte)
			out = calllib('liblabjackusb', 'LJUSB_Write', obj.handle, byte, length(byte));
		end
		
		% ===================================================================
		%> @brief Read response string back from LabJack
		%> 		unsigned long LJUSB_Read(HANDLE hDevice, BYTE *pBuff, unsigned long count);
		%> 		// Reads from a device. Returns the number of bytes read, or -1 on error.
		%> 		// hDevice = The handle for your device
		%> 		// pBuff = The buffer to filled in with bytes from the device.
		%> 		// count = The number of bytes expected to be read.
		%> 		// This function replaces the deprecated LJUSB_BulkRead, which required the endpoint
		%>
		%> @param bytein
		%> @param count
		% ===================================================================
		function in = rawRead(obj,bytein,count)
			if ~exist('count','var')
				count = length(bytein);
			end
			in =  calllib('liblabjackusb', 'LJUSB_Read', obj.handle, bytein, count);
		end
		
		% ===================================================================
		%> @brief Turn LED ON
		%>
		%>
		% ===================================================================
		function ledON(obj)
			if obj.silentMode == false && obj.vHandle == 1
				obj.rawWrite(obj.ledIsON);
				%in = obj.rawRead(obj.inp,10);
			end
		end
		
		% ===================================================================
		%> @brief Turn LED OFF
		%>
		%>
		% ===================================================================
		function ledOFF(obj)
			if obj.silentMode == false && obj.vHandle == 1
				obj.rawWrite(obj.ledIsOFF);
				%in = obj.rawRead(obj.inp,10);
			end
		end
		
		% ===================================================================
		%> @brief WaitShort
		%>	LabJack Wait in multiples of 128µs
		%>	@param time time in ms, remember 0.128ms is the atomic minimum
		% ===================================================================
		function waitShort(obj,time)
			time=ceil(time/0.128);
			cmd=zeros(10,1);
			%obj.inp=zeros(10,1);
			cmd(2) = 248; %hex2dec('f8'); %feedback
			cmd(3) = 2; %number of bytes in packet
			cmd(8) = 5; %IOType for waitlong is 6
			cmd(9) = time;
			
			obj.command = obj.checksum(cmd,'extended');
			
			out = obj.rawWrite(obj.command);
			%in = obj.rawRead(obj.inp,10);
		end
		
		% ===================================================================
		%> @brief WaitLong
		%>	LabJack Wait in multiples of 32ms
		%>	@param time time in ms, remember 32ms is the atomic minimum
		% ===================================================================
		function waitLong(obj,time)
			time=ceil(time/32);
			cmd=zeros(10,1);
			%obj.inp=zeros(10,1);
			cmd(2) = 248; %hex2dec('f8'); %feedback
			cmd(3) = 2; %number of bytes in packet
			cmd(8) = 6; %IOType for waitlong is 6
			cmd(9) = time;
			
			obj.command = obj.checksum(cmd,'extended');
			
			out = obj.rawWrite(obj.command);
			%in = obj.rawRead(obj.inp,10);
		end
		
		% ===================================================================
		%> @brief SetDIO
		%>	SetDIO sets the direction/value for FIO, EIO and CIO as read or write
		%>  if only value supplied, set all others to [255,255,255]
		%>  @param value is binary identifier for 0-7 bit range
		%>  @param mask is the mask to apply the command
		%>  @param valuedir binary identifier for input (0) or output (1) default=[255, 255, 255]
		%>  @param maskdir is the mask to apply the command. default=[255, 255,255]
		% ===================================================================
		function setDIO(obj,value,mask,valuedir,maskdir)
			if ~exist('value','var');fprintf('\nInput options: \n\t\tvalue, [mask], [value direction], [mask direction]\n\n');return;end
			if ~exist('mask','var');mask=[255,255,255];end %all DIO by default
			if ~exist('valuedir','var');valuedir=[255,255,255];maskdir=valuedir;end %all DIO set to output
			if obj.silentMode == false && obj.vHandle == 1
				cmd=zeros(14,1);
				cmd(2) = 248; %command byte for feedback command (f8 in hex)
				cmd(3) = (length(cmd)-6)/2;
				cmd(8) = 29; %IOType for PortDirWrite = 29
				cmd(9:11) = maskdir;
				cmd(12:14) = valuedir;
				cmd(8) = 27; %IOType for PortStateWrite = 27
				cmd(9:11) = mask;
				cmd(12:14) = value;
				
				cmd = obj.checksum(cmd,'extended');
				out = obj.rawWrite(cmd);
				%in = obj.rawRead(obj.inp,10);
			end
		end
		
		% ===================================================================
		%> @brief SetDIODirection
		%>	SetDIO sets the direction for FIO, EIO and CIO as read or write
		%>	@param value is binary identifier for 0-7 bit range
		%>  @param mask is the mask to apply the command
		% ===================================================================
		function setDIODirection(obj,value,mask)
			if ~exist('value','var');fprintf('\nInput options: \n\t\tvalue, [mask]\n\n');return;end
			if ~exist('mask','var');mask=[255,255,255];end
			if obj.silentMode == false && obj.vHandle == 1
				cmd=zeros(14,1);
				cmd(2) = 248; %command byte for feedback command (f8 in hex)
				cmd(3) = (length(cmd)-6)/2;
				cmd(8) = 29; %IOType for PortDirWrite = 29
				cmd(9:11) = mask;
				cmd(12:14) = value;
				
				cmd = obj.checksum(cmd,'extended');
				out = obj.rawWrite(cmd);
				%in = obj.rawRead(obj.inp,10);
			end
		end
		
		% ===================================================================
		%> @brief SetDIOValue
		%>	SetDIO sets the value for FIO, EIO and CIO as HIGH or LOW
		%>	@param value is binary identifier for 0-7 bit range
		%>  @param mask is the mask to apply the command
		% ===================================================================
		function setDIOValue(obj,value,mask)
			if ~exist('mask','var');mask=[255,255,255];end
			if obj.silentMode == false && obj.vHandle == 1
				cmd=zeros(14,1);
				cmd(2) = 248; %command byte for feedback command (f8 in hex)
				cmd(3) = (length(cmd)-6)/2;
				cmd(8) = 27; %IOType for PortStateWrite = 27
				cmd(9:11) = mask;
				cmd(12:14) = value;
				
				cmd = obj.checksum(cmd,'extended');
				out = obj.rawWrite(cmd);
				%in = obj.rawRead(obj.inp,10);
			end
		end
		
		% ===================================================================
		%> @brief Prepare Strobe Word
		%>	Sets the strobe value for EIO (8bits) and CIO (4bits) which are
		%> accesible via the DB15 using a single cable. This avoids using FIO, which
		%> can therefore be used for addtional control TTLs (FIO0 and FIO1 are used
		%> for START/STOP and pause/unpause of the Plexon Omniplex in Opticka for
		%> example.
		%>
		%>	@param value The value to be strobed, range is 0-2047 for 11bits
		%>  In Opticka, 0 and 2047 are reserved. Value can be 3 byte markers for
		%>  FIO (which is ignored), EIO and CIO respectively. CIO0 is used as the
		%>  strobe line, which leaves EIO0-7 and CIO1-3 for value data.
		%>  @param mask Which bits to mask
		%>  @param sendNow if true then sends the value immediately
		% ===================================================================
		function prepareStrobe(obj,value,mask,sendNow)
			if obj.silentMode == false && obj.vHandle == 1
				if value>2047;value=2047;end %block anything bigger than 2^11
				if value<0; value = 0; end %block anything smaller than 0
				obj.comment = ['Original Value = ' num2str(value) ' | '];
				[eio,cio]=obj.prepareWords(value,0); %construct our word split to eio and cio, set strobe low
				ovalue(1) = 0; %fio will be 0
				ovalue(2) = eio;
				ovalue(3) = cio;
				[eio2,cio2]=obj.prepareWords(value,1); %construct our word split to eio and cio, set strobe high
				ovalue2(1) = 0; %fio will be 0
				ovalue2(2) = eio2;
				ovalue2(3) = cio2;
				mask = [0,255,255]; %lock fio, allow all of eio and cio
				obj.comment = [obj.comment 'FIO EIO & CIO: ' num2str(0) ' ' num2str(eio2) ' ' num2str(cio2)];
				
				cmd=zeros(30,1);
				cmd(2) = 248; %command byte for feedback command (f8 in hex)
				cmd(3) = (length(cmd)-6)/2;
				
				cmd(8) = 27; %IOType for PortStateWrite (1b in hex)
				cmd(9:11) = mask;
				cmd(12:14) = ovalue; %This is our strobe number but with strobe line set low, th
				
				cmd(15) = 27; %IOType for PortStateWrite (1b in hex)
				cmd(16:18) = mask;
				cmd(19:21) = ovalue2; %The same value but now set strobe high, all our values should be readable
				
				cmd(22) = 5; %IOType for waitshort is 5, waitlong is 6
				cmd(23) = obj.strobeTime; %time to wait in unit multiples, this is the time the strobe
				
				cmd(24) = 27; %IOType for PortStateWrite (1b in hex)
				cmd(25:27) = mask;
				cmd(28:30) = 0;
				
				obj.command = obj.checksum(cmd,'extended');
				if exist('sendNow','var')
					obj.strobeWord;
				end
			end
		end
		
		% ===================================================================
		%> @brief Send the Strobe command
		%>
		%>
		% ===================================================================
		function strobeWord(obj)
			if ~isempty(obj.command)
				obj.rawWrite(obj.command);
				%in = obj.rawRead(obj.inp,10);
				obj.salutation('strobeWord', obj.comment);
				%obj.comment = '';
				%obj.command = [];
				% if in(6) > 0
				% 	obj.salutation('strobeWord',['Feedback error in IOType ' num2str(in(7))]);
				% end
			end
		end
		
		% ===================================================================
		%> @brief Prepare Strobe Word split into EIO (8bit) and CIO (3bit). 0-2047
		%>  %is the max # of variables with 2^11bits.
		%>
		%>	 @param value The value to be split into EIO and CIO 
		%>  @return eio is an 8bit word value represented the LSB
		%>  @return cio is a 4bit value where the 1st bit is 1 for strobe line 22
		%>  and the rest is the 3bit remainder to combine with eio to make an
		%>  11bit strobed word.
		% ===================================================================
		function [eio,cio] = prepareWords(obj,value,strobeState)
			if ~exist('strobeState','var')
				strobeState = 1;
			end
			eio = bitand(value,255); %get eio easily ANDing with 255
			msb = bitshift(value,-8); %our msb is bitshifted 8 bits
			msb = bitshift(msb,1); %shift it across as cio0 is reserved;
			cio = bitor(msb,strobeState); %OR with 1 as cio0 is the strobe trigger and needs to be 1
		end
		
		% ===================================================================
		%> @brief Set FIO to a value
		%>
		%>	@param val The value to be set
		%> line which FIO to set
		% ===================================================================
		function setFIO(obj,val,line)
			if ~exist('val','var');fprintf('\nInput options: \n\t\tvalue, [line]\n\n');return;end
			if obj.silentMode == false && obj.vHandle == 1
				if ~exist('line','var');line=0;end
				myname = ['fio' num2str(line)];
				cmdHigh = [myname 'High'];
				cmdLow = [myname 'Low'];
				if ~exist('val','var')
					val = abs(obj.(myname)-1);
				end
				if val == 1
					out = obj.rawWrite(obj.(cmdHigh));
					%in  = obj.rawRead(obj.inp,10);
					obj.(myname) = 1;
					obj.salutation('SETFIO',[myname ' is HIGH'])
				else
					out = obj.rawWrite(obj.(cmdLow));
					%in  = obj.rawRead(obj.inp,10);
					obj.(myname) = 0;
					obj.salutation('SETFIO',[myname ' is LOW'])
				end
			end
		end
		
		% ===================================================================
		%> @brief Toggle FIO value
		%>
		%>
		% ===================================================================
		function toggleFIO(obj,line)
			if obj.silentMode == false && obj.vHandle == 1
				if ~exist('line','var');line=0;end
				myname = ['fio' num2str(line)];
				obj.(myname)=abs(obj.(myname)-1);
				obj.setFIO(obj.(myname),line);
			end
		end
		
		% ===================================================================
		%> @brief Set FIO4 to a value
		%>
		%>	@param val The value to be set
		% ===================================================================
		function setFIO4(obj,val)
			if obj.silentMode == false && obj.vHandle == 1
				if ~exist('val','var')
					val = abs(obj.fio4-1);
				end
				if val == 1
					out = obj.rawWrite(obj.fio4High);
					%in  = obj.rawRead(obj.inp,10);
					obj.fio4 = 1;
					obj.salutation('SETFIO4','FIO4 is HIGH')
				else
					out = obj.rawWrite(obj.fio4Low);
					%in  = obj.rawRead(obj.inp,10);
					obj.fio4 = 0;
					obj.salutation('SETFIO4','FIO4 is LOW')
				end
			end
		end
		
		% ===================================================================
		%> @brief Toggle FIO4 value
		%>
		%>
		% ===================================================================
		function toggleFIO4(obj)
			if obj.silentMode == false && obj.vHandle == 1
				obj.fio4=abs(obj.fio4-1);
				obj.setFIO4(obj.fio4);
			end
		end
		
		% ===================================================================
		%> @brief Set FIO5 to a value
		%>
		%>	@param val The value to be set
		% ===================================================================
		function setFIO5(obj,val)
			if obj.silentMode == false && obj.vHandle == 1
				if ~exist('val','var')
					val = abs(obj.fio5-1);
				end
				if val == 1
					out = obj.rawWrite(obj.fio5High);
					%in  = obj.rawRead(obj.inp,10);
					obj.fio5 = 1;
					obj.salutation('SETFIO5','FIO5 is HIGH')
				else
					out = obj.rawWrite(obj.fio5Low);
					%in  = obj.rawRead(obj.inp,10);
					obj.fio5 = 0;
					obj.salutation('SETFIO5','FIO5 is LOW')
				end
			end
		end
		
		% ===================================================================
		%> @brief Toggle FIO5 value
		%>
		%>
		% ===================================================================
		function toggleFIO5(obj)
			if obj.silentMode == false && obj.vHandle == 1
				obj.fio5=abs(obj.fio5-1);
				obj.setFIO5(obj.fio5);
			end
		end
		
		% ===================================================================
		%> @brief Set FIO6 to a value
		%>
		%>	@param val The value to be set
		% ===================================================================
		function setFIO6(obj,val)
			if obj.silentMode == false && obj.vHandle == 1
				if ~exist('val','var')
					val = abs(obj.fio5-1);
				end
				if val == 1
					out = obj.rawWrite(obj.fio6High);
					%in  = obj.rawRead(obj.inp,10);
					obj.fio6 = 1;
					obj.salutation('SETFIO6','FIO6 is HIGH')
				else
					out = obj.rawWrite(obj.fio6Low);
					%in  = obj.rawRead(obj.inp,10);
					obj.fio6 = 0;
					obj.salutation('SETFIO6','FIO6 is LOW')
				end
			end
		end
		
		% ===================================================================
		%> @brief Toggle FIO6 value
		%>
		%>
		% ===================================================================
		function toggleFIO6(obj)
			if obj.silentMode == false && obj.vHandle == 1
				obj.fio6=abs(obj.fio6-1);
				obj.setFIO6(obj.fio6);
			end
		end
		
		% ===================================================================
		%> @brief Set FIO7 to a value
		%>
		%>	@param val The value to be set
		% ===================================================================
		function setFIO7(obj,val)
			if obj.silentMode == false && obj.vHandle == 1
				if ~exist('val','var')
					val = abs(obj.fio7-1);
				end
				if val == 1
					out = obj.rawWrite(obj.fio7High);
					%in  = obj.rawRead(obj.inp,10);
					obj.fio7 = 1;
					obj.salutation('SETFIO7','FIO7 is HIGH')
				else
					out = obj.rawWrite(obj.fio7Low);
					%in  = obj.rawRead(obj.inp,10);
					obj.fio7 = 0;
					obj.salutation('SETFIO7','FIO7 is LOW')
				end
			end
		end
		
		% ===================================================================
		%> @brief Toggle FIO7 value
		%>
		%>
		% ===================================================================
		function toggleFIO7(obj)
			if obj.silentMode == false && obj.vHandle == 1
				obj.fio7=abs(obj.fio7-1);
				obj.setFIO7(obj.fio7);
			end
		end
		
		% ===================================================================
		%> @brief Reset the LabJack
		%>
		%> @param resetType whether to use a soft (1) or hard (2) reset
		%> type
		% ===================================================================
		function reset(obj,resetType)
			if ~exist('resetType','var')
				resetType = 0;
			end
			cmd=zeros(4,1);
			cmd(2) = hex2dec('99'); %command code
			if resetType == 0 %soft reset
				cmd(3) = bin2dec('01');
			else
				cmd(3) = bin2dec('10');
			end
			
			obj.command = obj.checksum(cmd,'normal');
			
			%out = obj.rawWrite(cmd);
			%in  = obj.rawRead(obj.inp,4);
		end
		
		% ===================================================================
		%> @brief checksum
		%>	Calculate checksum for data packet
		%>
		% ===================================================================
		function command = checksum(obj,command,type)
			switch type
				case 'normal'
					command(1) = obj.checksum8(command(2:end));
				case 'extended'
					[command(5),command(6)] = obj.checksum16(command(7:end));
					command(1) = obj.checksum8(command(2:6));
			end
		end
		
	end
	
	%=======================================================================
	methods ( Static ) % STATIC METHODS
		%=======================================================================
		
		% ===================================================================
		%> @brief checksum8
		%>	Calculate checksum for data packet
		%>
		% ===================================================================
		function chk = checksum8(in)
			% 			if ischar(in) %hex input
			% 				in = hex2dec(in);
			% 				hexMode = 1;
			% 			end
			in = sum(uint16(in));
			quo = floor(in/2^8);
			remd = rem(in,2^8);
			in = quo+remd;
			quo = floor(in/2^8);
			remd = rem(in,2^8);
			chk = quo + remd;
			% 			if exist('hexMode','var')
			% 				chk = dec2hex(chk);
			% 			end
		end
		
		% ===================================================================
		%> @brief checksum16
		%>	Calculate checksum (lsb and msb) for extended data packet
		%>
		% ===================================================================
		function [lsb,msb] = checksum16(in)
			% 			if ischar(in) %hex input
			% 				in = hex2dec(in);
			% 				hexMode = 1;
			% 			end
			in = sum(uint16(in));
			lsb = bitand(in,255);
			msb = bitshift(in,-8);
			% 			if exist('hexMode','var')
			% 				lsb = dec2hex(lsb);
			% 				msb = dec2hex(msb);
			% 			end
		end
		
	end % END STATIC METHODS
	
	
	%=======================================================================
	methods ( Access = private ) % PRIVATE METHODS
	%=======================================================================
		
		%===============Destructor======================%
		function delete(obj)
			obj.salutation('DELETE Method','labJack Cleaning up...')
			obj.close;
		end
		
		%===========Salutation==========%
		function salutation(obj,in,message)
			if obj.verbose > 0
				if ~exist('in','var')
					in = 'General Message';
				end
				if exist('message','var')
					fprintf(['---> labJack: ' message ' | ' in '\n']);
				else
					fprintf(['---> labJack: ' in '\n']);
				end
			end
		end
		
		% ===================================================================
		%> @brief Sets properties from a structure or varargin cell, ignores invalid properties
		%>
		%> @param args input structure
		% ===================================================================
		function parseArgs(obj, args, allowedProperties)
			allowedProperties = ['^(' allowedProperties ')$'];
			while iscell(args) && length(args) == 1
				args = args{1};
			end
			if iscell(args)
				if mod(length(args),2) == 1 % odd
					args = args(1:end-1); %remove last arg
				end
				odd = logical(mod(1:length(args),2));
				even = logical(abs(odd-1));
				args = cell2struct(args(even),args(odd),2);
			end
			fnames = fieldnames(args); %find our argument names
			for i=1:length(fnames);
				if regexp(fnames{i},allowedProperties) %only set if allowed property
					obj.salutation(fnames{i},'Configuring setting in constructor');
					obj.(fnames{i})=args.(fnames{i}); %we set up the properies from the arguments as a structure
				end
			end
		end
	end
end