% ========================================================================
%> @brief LABJACK Connects and manages a LabJack U3 / U6
%>
%> Connects and manages a LabJack U3 / U6. To run this in OS X and Linux,
%> you need to install libusb and the exodriver. The easiest way to do this
%> is to use homebrew on OS X, a light-weight package manager to install
%> universal builds of these:
%>     bash$ brew install libusb exodriver --universal
%> For linux, see instructions on the labjack site.
%> With the exodriver installed, you create a new labJack object and you
%> can then dend figital I/O commands and strobed words. labJack ises a 12bit
%> word across EIO and CIO, using CIO0 as the strobe bit so one has a
%> resultant 11bits of values in the strobed word. For example:
%>
%> >> lj = labJack('verbose',true) %open labJack verbosely
%> >> lj.toggleFIO(1) %toggle FIO1 between low and high
%> >> lj.timedTTL(3,200) % send a 200ms timed TTL pulse on FIO3
% ========================================================================
classdef labJack < handle
	
	properties
		%> friendly object name, setting this to 'null' will force silentMode=1
		name='LabJack'
		%> what LabJack device to use; 3 = U3, 6 = U6
		deviceID = 6
		%> silentMode allows one to gracefully fail methods without a labJack connected
		silentMode = false
		%> header needed by loadlib
		header = '/usr/local/include/labjackusb.h'
		%> the library itself
		library = '/usr/local/lib/liblabjackusb'
		%> do we log everything to the command window?
		verbose = false
		%> allows the constructor to run the open method immediately (default)
		openNow = true
		%> strobeTime is time of strobe in unit multiples of timeShort: 16
		%> units ~=1ms on a U6 where timeShort is 64e-6 .If you use a U3
		%> this needs to be 8 for a 1ms pulse...
		strobeTime = 16
	end
	
	properties (SetAccess = private, GetAccess = public)
		%> function list returned from loading the exodriver
		functionList
		%> library version returned on first open
		version
		%> how many devices are connected
		devCount
		%> handle to the opened device itself
		handle = []
		%> have we successfully opened the labjack?
		isOpen = false
		%> an input buffer
		inp = []
		%> output buffer, normally the number of bytes written
		outp = []
		%> FIO0 state
		fio0 = 0
		%> FIO1 state
		fio1 = 0
		%> FIO2 state
		fio2 = 0
		%> FIO2 state
		fio3 = 0
		%> FIO4 state
		fio4 = 0
		%> FIO5 state
		fio5 = 0
		%> FIO6 state
		fio6 = 0
		%> FIO7 state
		fio7 = 0
		%> LED state, which is controllable only on the U3
		led = 1
		%> The raw strobed word command generated with prepareStrobe, sent with strobeWord
		strobeCommand = []
	end
	
	properties (SetAccess = private, GetAccess = private)
		% WaitShort time quantum is 64microseconds for U6 and 128microseconds for U3
		timeShort = 64e-6
		% WaitLong time quantum is 16ms for U6 and 32ms for U3
		timeLong  = 16e-3
		%>raw commands ,you can use labjackPython to find/verify these. These
		%>are easy ways to control the I/O, but this object also includes
		%>SetDIO which calculates the command denovo and can control CIO EIO
		%>and FIO. The raw commands below may be faster, but I've never been
		%>able to tell a difference when benchmarking them.
		fio0High = hex2dec(['15'; 'f8'; '03'; '00'; '18'; '01'; '00'; '0d'; '80'; '0b'; '80'; '00'])'
		fio1High = hex2dec(['17'; 'f8'; '03'; '00'; '1a'; '01'; '00'; '0d'; '81'; '0b'; '81'; '00'])'
		fio2High = hex2dec(['19'; 'f8'; '03'; '00'; '1c'; '01'; '00'; '0d'; '82'; '0b'; '82'; '00'])'
		fio3High = hex2dec(['1b'; 'f8'; '03'; '00'; '1e'; '01'; '00'; '0d'; '83'; '0b'; '83'; '00'])'
		fio4High = hex2dec(['1d'; 'f8'; '03'; '00'; '20'; '01'; '00'; '0d'; '84'; '0b'; '84'; '00'])'
		fio5High = hex2dec(['1f'; 'f8'; '03'; '00'; '22'; '01'; '00'; '0d'; '85'; '0b'; '85'; '00'])'
		fio6High = hex2dec(['21'; 'f8'; '03'; '00'; '24'; '01'; '00'; '0d'; '86'; '0b'; '86'; '00'])'
		fio7High = hex2dec(['23'; 'f8'; '03'; '00'; '26'; '01'; '00'; '0d'; '87'; '0b'; '87'; '00'])'
		fio0Low  = hex2dec(['94'; 'f8'; '03'; '00'; '98'; '00'; '00'; '0d'; '80'; '0b'; '00'; '00'])'
		fio1Low  = hex2dec(['96'; 'f8'; '03'; '00'; '9a'; '00'; '00'; '0d'; '81'; '0b'; '01'; '00'])'
		fio2Low  = hex2dec(['98'; 'f8'; '03'; '00'; '9c'; '00'; '00'; '0d'; '82'; '0b'; '02'; '00'])'
		fio3Low  = hex2dec(['9a'; 'f8'; '03'; '00'; '9e'; '00'; '00'; '0d'; '83'; '0b'; '03'; '00'])'
		fio4Low  = hex2dec(['9c'; 'f8'; '03'; '00'; 'a0'; '00'; '00'; '0d'; '84'; '0b'; '04'; '00'])'
		fio5Low  = hex2dec(['9e'; 'f8'; '03'; '00'; 'a2'; '00'; '00'; '0d'; '85'; '0b'; '05'; '00'])'
		fio6Low  = hex2dec(['a0'; 'f8'; '03'; '00'; 'a4'; '00'; '00'; '0d'; '86'; '0b'; '06'; '00'])'
		fio7Low  = hex2dec(['a2'; 'f8'; '03'; '00'; 'a6'; '00'; '00'; '0d'; '87'; '0b'; '07'; '00'])'
		ledIsON  = hex2dec(['05'; 'f8'; '02'; '00'; '0a'; '00'; '00'; '09'; '01'; '00'])' %only works on U3
		ledIsOFF = hex2dec(['04'; 'f8'; '02'; '00'; '09'; '00'; '00'; '09'; '00'; '00'])' %only works on U3
		%> Is our handle a valid one, this is a cache so we save a bit of
		%> time on calling the method each time
		vHandle = 0
		%> what properties are allowed to be passed on construction
		allowedProperties='deviceID|name|silentMode|verbose|openNow|header|library|strobeTime'
		%>document what our strobed word is actually setting, shown to user if verbose = true
		strobeComment = ''
	end
	
	%=======================================================================
	methods %------------------PUBLIC METHODS
	%=======================================================================
		
		% ===================================================================
		%> @brief Class constructor
		%>
		%> We use parseArgs to parse allowed properties on construction and also
		%> switch into silent mode and/or auto open the labjack connection.
		%>
		%> @param varargin are passed as a structure of properties which is
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
				if ismac == true || isunix == true
					if ~libisloaded('liblabjackusb')
						try
							loadlibrary(obj.library,obj.header);
						catch ME
							obj.salutation('open method',['Loading the exodriver library failed: ' ME.message]);
							obj.version = ['Library Load FAILED: ' ME.message];
							obj.silentMode = true;
							obj.verbose = true;
							return
						end
					end
					obj.functionList = libfunctions('liblabjackusb', '-full'); %store our raw lib functions
					obj.version =  calllib('liblabjackusb','LJUSB_GetLibraryVersion');
					obj.devCount = calllib('liblabjackusb','LJUSB_GetDevCount',obj.deviceID);
				else %incomplete PC support, basically need to add PC equivalents of rawRead and rawWrite
					obj.library = 'labjackud';
					obj.header = 'C:\progra~1\LabJack\drivers\labjackud.h';
					if (libisloaded('labjackud') || (libisloaded('labjackud_doublePtr')))
						% Libraries already loaded
					else
						loadlibrary(obj.library,obj.header);
						loadlibrary labjackud labjackud_doublePtr.h alias labjackud_doublePtr
						% If you wish to view a list of the available LabJack UD functions
						% and their associated Output Values and Input Arguments, uncomment out
						% the appropriate line of code below.
						%libfunctionsview labjackud % Use this in version 7.0 and newer
						%libfunctionsview labjackud_doublePtr % Use this in version 7.0+
						%libmethodsview labjackud % Use this in version 6.5
						%libmethodsview labjackud_doublePtr % Use this in version 6.5
					end
				end
				obj.inp=zeros(10,1);
				if obj.devCount == 0 %no device was found with input deviceID, lets scan for another device
					if obj.deviceID == 3 %we tried a U3, now lets try a U6
						obj.devCount = calllib('liblabjackusb','LJUSB_GetDevCount',6);
						if obj.devCount > 0 %yup it's a U6
							obj.deviceID = 6;
						end
					elseif obj.deviceID == 6 %we tried a U6, now lets try a U3
						obj.devCount = calllib('liblabjackusb','LJUSB_GetDevCount',3);
						if obj.devCount > 0
							obj.deviceID = 3;
						end
					end
					if obj.devCount == 0
						obj.salutation('open method','No LabJack U3 or U6 devices found, going into silent mode');
						obj.version = 'device discovery FAILED';
						obj.isOpen = false;
						obj.handle = [];
						obj.vHandle = false;
						obj.verbose = false;
						obj.silentMode = true; %we switch into silent mode just in case someone tries to use the object
						return
					end
				end
				obj.handle = calllib('liblabjackusb','LJUSB_OpenDevice',1,0,obj.deviceID);
				if obj.validHandle();
					obj.version = calllib('liblabjackusb','LJUSB_GetDeviceDescriptorReleaseNumber',obj.handle);
					if obj.deviceID == 3 %respecify the time quantum for the U3
						obj.timeShort = 128e-6;
						obj.timeLong = 32e-3;
					end
					obj.isOpen = true;
					obj.salutation('open method','LabJack succesfully opened...');
					obj.salutation('open method',sprintf('Device U%g - Time Quantum short/long = %g secs / %g secs',obj.deviceID,obj.timeShort,obj.timeLong));
					none=[0,0,0];
					obj.setDIO(none); %Sink all our DIO to output LOW
				else
					obj.salutation('open method','LabJack failed to open, going into silent mode');
					obj.version = 'device opening FAILED';
					obj.isOpen = false;
					obj.handle = [];
					obj.verbose = false;
					obj.silentMode = true; %we switch into silent mode just in case someone tries to use the object
				end
			else %silentmode is ~false
				obj.isOpen = false;
				obj.handle = [];
				obj.vHandle = false;
				obj.verbose = false;
				obj.silentMode = true; %double make sure it is set to true
			end
		end
		
		% ===================================================================
		%> @brief Close the LabJack device
		%>	void LJUSB_CloseDevice(HANDLE hDevice);
		%>	//Closes the handle of a LabJack USB device.
		% ===================================================================
		function close(obj)
			if ~isempty(obj.handle)
				if obj.validHandle() == true %double-check we still have valid handle
					calllib('liblabjackusb','LJUSB_CloseDevice',obj.handle);
				end
				obj.salutation('CLOSE method','LabJack Handle has been closed');
				obj.isOpen = false;
				obj.handle=[];
				obj.vHandle = false;
			else
				obj.salutation('CLOSE method','No handle to close...');
			end
		end
		
		% ===================================================================
		%> @brief Is Handle Valid?
		%>	bool LJUSB_IsHandleValid(HANDLE hDevice);
		%>	//Is handle valid.
		% ===================================================================
		function vHandle = validHandle(obj)
			obj.vHandle = false; %our cached value
			if obj.silentMode == false
				if ~isempty(obj.handle)
					obj.vHandle = calllib('liblabjackusb','LJUSB_IsHandleValid',obj.handle);
					if obj.vHandle
						obj.salutation('validHandle Method',sprintf('Handle to LabJack U%g is VALID',obj.deviceID));
					else
						obj.salutation('validHandle Method',sprintf('Handle to LabJack U%g is INVALID',obj.deviceID),true);
					end
				else
					obj.vHandle = false;
					obj.isOpen = false;
					obj.handle = [];
					obj.salutation('validHandle Method','Handle to LabJack is INVALID (empty handle)',true);
				end
			end
			vHandle = obj.vHandle;
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
			if ~exist('bytein','var')
				bytein = zeros(10,1);
			end
			if ~exist('count','var') || count > length(bytein)
				count = length(bytein);
			end
			in =  calllib('liblabjackusb', 'LJUSB_Read', obj.handle, bytein, count);
		end
		
		% ===================================================================
		%> @brief WaitShort
		%>	LabJack Wait in multiples of 64/128microseconds
		%>	@param time time in ms; remember 64/128microseconds is the atomic minimum
		% ===================================================================
		function waitShort(obj,time)
			if obj.silentMode == false && obj.vHandle == 1
				time = time / 1000; %convert to seconds
				time=ceil(time/obj.timeLong);
				if time > 255
					time = 255; %truncate to maximum time delay allowed
				end
				
				cmd=zeros(10,1);
				cmd(2) = 248; %hex2dec('f8'); %feedback
				cmd(3) = 2; %number of bytes in packet
				cmd(8) = 5; %IOType for waitshort is 5
				cmd(9) = time;
				
				obj.command = obj.checksum(cmd,'extended');
				
				obj.outp = obj.rawWrite(obj.command);
				obj.inp = obj.rawRead(zeros(1,10),10);
			end
		end
		
		% ===================================================================
		%> @brief WaitLong
		%>	LabJack Wait in multiples of 16/32ms
		%>	@param time time in ms, remember 16/32ms is the atomic minimum
		% ===================================================================
		function waitLong(obj,time)
			if obj.silentMode == false && obj.vHandle == 1
				time = time / 1000; %convert to seconds
				time=ceil(time/obj.timeLong);
				if time > 255
					time = 255; %truncate to maximum time delay allowed
				end
				
				cmd=zeros(10,1);
				cmd(2) = 248; %hex2dec('f8'); %feedback
				cmd(3) = 2; %number of bytes in packet
				cmd(8) = 6; %IOType for waitlong is 6
				cmd(9) = time;
				
				obj.command = obj.checksum(cmd,'extended');
				
				obj.outp = obj.rawWrite(obj.command);
				obj.inp = obj.rawRead(zeros(1,10),10);
			end
		end
		
		% ===================================================================
		%> @brief timedTTL Send a TTL with a defined time of pulse
		%>
		%> Note that there is a maximum time to the TTL pulse which is ~8.16secs
		%> for the U3 and ~4.08secs for the U6; we can extend that time by
		%> adding more feedback commands in the command packet but this
		%> shouldn't be needed anyway. Any time longer than this will be
		%> truncated to the maximum allowable time.
		%>
		%>  @param line 0-7=FIO, 8-15=EIO, or 16-19=CIO
		%>	@param time time in ms
		%>  @param sync optinal logical flag whether to use blocking (true) command
		% ===================================================================
		function timedTTL(obj,line,time,sync)
			if ~exist('line','var') || ~exist('time','var');fprintf('\ntimedTTL Input options: \n\t\tline (single value 0-7=FIO, 8-15=EIO, or 16-19=CIO), time (in ms)\n\n');return;end
			if ~exist('sync','var'); sync = false; end
			if obj.silentMode == false && obj.vHandle == 1
				time = time / 1000; %convert to seconds
				time1 = 0;
				time2 = 0;
				if time >= obj.timeLong %we need to use greater resolution for fine timing
					
					time1 = floor(time/obj.timeLong);
					if time1 > 255 %truncate to maximum time delay allowed
						time1 = 255; %truncate to maximum time delay allowed
					elseif time1 < 1 %truncate to minimum
						time1 = 1;
					end
					
					time2 = time - (time1 * obj.timeLong);
					time2 = round(time2/obj.timeShort);
					if time2 > 255 %truncate to maximum time delay allowed
						time2 = 255; %truncate to maximum time delay allowed
					elseif time2 < 0 %truncate to minimum
						time2 = 0;
					end
					
					otime = (time1 * obj.timeLong) + (time2 * obj.timeShort);
					
					cmd=zeros(16,1);
					cmd(2) = 248; %command byte for feedback command (f8 in hex)
					cmd(3) = (length(cmd)-6)/2;
					
					cmd(8) = 11; %BitStateWrite: IOType=11
					cmd(9) = line+128; %add 128 as bit 7 sets value high
					
					cmd(10) = 6; %IOType for waitshort is 5, waitlong is 6
					cmd(11) = time1; %time to wait in unit multiples
					
					cmd(12) = 5; %IOType for waitshort is 5, waitlong is 6
					cmd(13) = time2; %time to wait in unit multiples
					
					cmd(14) = 11; %BitStateWrite: IOType=11
					cmd(15) = line; %bit to set low
					
				else
					
					time2=ceil(time/obj.timeShort);
					if time2 > 255 %truncate to maximum time delay allowed
						time2 = 255; %truncate to maximum time delay allowed
					end
					iotype = 5;
					
					otime = time2 * obj.timeShort;
					
					cmd=zeros(14,1);
					cmd(2) = 248; %command byte for feedback command (f8 in hex)
					cmd(3) = (length(cmd)-6)/2;
					
					cmd(8) = 11; %BitStateWrite: IOType=11
					cmd(9) = line+128; %add 128 as bit 7 sets value high
					
					cmd(10) = iotype; %IOType for waitshort is 5, waitlong is 6
					cmd(11) = time2; %time to wait in unit multiples, this is the time of the strobe
					
					cmd(12) = 11; %BitStateWrite: IOType=11
					cmd(13) = line;
					
				end
				
				command = obj.checksum(cmd,'extended');
				obj.outp = obj.rawWrite(command);
				if sync; obj.inp = obj.rawRead(zeros(1,10),10); end
				obj.salutation('timedTTL method',sprintf('T1:%g T2:%g output time = %g secs', time1, time2, otime))
			end
		end
		
		% ===================================================================
		%> @brief setDIO
		%>	setDIO sets the direction/value for FIO, EIO and CIO
		%>  If only value supplied, set all others to [255,255,255]
		%>  @param value is binary identifier for 0-7 bit range
		%>  @param mask is the mask to apply the command
		%>  @param valuedir binary identifier for input (0) or output (1) default=[255, 255, 255]
		%>  @param maskdir is the mask to apply the command. default=[255, 255,255]
		% ===================================================================
		function setDIO(obj,value,mask,valuedir,maskdir)
			if ~exist('value','var');fprintf('\nsetDIO Input options: \n\t\tvalue, [mask], [value direction], [mask direction]\n\n');return;end
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
				obj.outp = obj.rawWrite(cmd);
				obj.inp = obj.rawRead(zeros(1,10),10);
			end
		end
		
		% ===================================================================
		%> @brief setDIODirection
		%>	setDIODirection sets the direction for FIO, EIO and CIO as read or write
		%>	@param value is binary identifier for 0-7 bit range
		%>  @param mask is the mask to apply the command
		% ===================================================================
		function setDIODirection(obj,value,mask)
			if ~exist('value','var');fprintf('\nsetDIODirection Input options: \n\t\tvalue, [mask]\n\n');return;end
			if ~exist('mask','var');mask=[255,255,255];end
			if obj.silentMode == false && obj.vHandle == 1
				cmd=zeros(14,1);
				cmd(2) = 248; %command byte for feedback command (f8 in hex)
				cmd(3) = (length(cmd)-6)/2;
				cmd(8) = 29; %IOType for PortDirWrite = 29
				cmd(9:11) = mask;
				cmd(12:14) = value;
				
				cmd = obj.checksum(cmd,'extended');
				obj.outpout = obj.rawWrite(cmd);
				obj.inp = obj.rawRead(zeros(1,10),10);
			end
		end
		
		% ===================================================================
		%> @brief setDIOValue
		%>	setDIOValue sets the value for FIO, EIO and CIO as HIGH or LOW
		%>	@param value is binary identifier for 0-7 bit range
		%>  @param mask is the mask to apply the command
		% ===================================================================
		function setDIOValue(obj,value,mask)
			if ~exist('value','var');fprintf('\nSetDIOValue Input options: \n\t\tvalue, [mask]\n\n');return;end
			if ~exist('mask','var');mask=[255,255,255];end
			if obj.silentMode == false && obj.vHandle == 1
				cmd=zeros(14,1);
				cmd(2) = 248; %command byte for feedback command (f8 in hex)
				cmd(3) = (length(cmd)-6)/2;
				cmd(8) = 27; %IOType for PortStateWrite = 27
				cmd(9:11) = mask;
				cmd(12:14) = value;
				
				cmd = obj.checksum(cmd,'extended');
				obj.outp = obj.rawWrite(cmd);
				obj.inp = obj.rawRead(zeros(1,10),10);
			end
		end
		
		% ===================================================================
		%> @brief Prepare Strobe Word
		%>	Sets the strobe value for EIO (8bits) and CIO (4bits) which are
		%> accesible via the DB15 using a single cable. This avoids using FIO, which
		%> can therefore be used for addtional control TTLs (FIO0 and FIO1 are used
		%> for START/STOP and pause/unpause of the Plexon Omniplex in Opticka for
		%> example).
		%>
		%>	@param value The value to be strobed, range is 0-2047 for 11bits
		%>  In Opticka, 0 and 2047 are reserved. Value can be 3 byte markers for
		%>  FIO (which is ignored), EIO and CIO respectively. CIO0 is used as the
		%>  strobe line, which leaves EIO0-7 and CIO1-3 for value data.
		%> @param mask Which bits to mask
		%> @param sendNow if true then sends the value immediately
		% ===================================================================
		function prepareStrobe(obj,value,mask,sendNow)
			if obj.silentMode == false && obj.vHandle == 1
				if value>2047;value=2047;end %block anything bigger than 2^11
				if value<0; value = 0; end %block anything smaller than 0
				obj.strobeComment = ['Original Value = ' num2str(value) ' | '];
				[eio,cio]=obj.prepareWords(value,0); %construct our word split to eio and cio, set strobe low
				ovalue(1) = 0; %fio will be 0
				ovalue(2) = eio;
				ovalue(3) = cio;
				[eio2,cio2]=obj.prepareWords(value,1); %construct our word split to eio and cio, set strobe high
				ovalue2(1) = 0; %fio will be 0
				ovalue2(2) = eio2;
				ovalue2(3) = cio2;
				mask = [0,255,255]; %lock fio, allow all of eio and cio
				obj.strobeComment = [obj.strobeComment 'FIO EIO & CIO: ' num2str(0) ' ' num2str(eio2) ' ' num2str(cio2)];
				
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
				cmd(23) = obj.strobeTime; %time to wait in unit multiples, this is the time of the strobe
				
				cmd(24) = 27; %IOType for PortStateWrite (1b in hex)
				cmd(25:27) = mask;
				cmd(28:30) = 0;
				
				obj.strobeCommand = obj.checksum(cmd,'extended');
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
			if ~isempty(obj.strobeCommand)
				obj.rawWrite(obj.strobeCommand);
				obj.inp = obj.rawRead(zeros(1,10),10);
				obj.salutation('strobeWord', obj.strobeComment);
% 				if obj.inp(6) > 0
% 					obj.salutation('strobeWord',['Feedback error in IOType ' num2str(obj.inp(7))]);
% 				end
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
		%> Note this uses the pregenerated raw commands, so only works with
		%> the FIO bits seen in properties above. Us SetDIO and a mask for a
		%> robust way to control any digital I/O
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
					in  = obj.rawRead(zeros(1,10),10);
					obj.(myname) = 1;
					obj.salutation('SETFIO',[myname ' is HIGH'])
				else
					out = obj.rawWrite(obj.(cmdLow));
					in  = obj.rawRead(zeros(1,10),10);
					obj.(myname) = 0;
					obj.salutation('SETFIO',[myname ' is LOW'])
				end
			end
		end
		
		% ===================================================================
		%> @brief Toggle FIO value
		%>
		%> Note this uses the pregenerated raw commands, so only works with
		%> the FIO bits seen in properties above. Us SetDIO and a mask for a
		%> robust way to control any digital I/O
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
		%> @brief Turn LED ON
		%>
		%> I think this only works on the U3
		% ===================================================================
		function ledON(obj)
			if obj.silentMode == false && obj.vHandle == 1
				obj.outp = obj.rawWrite(obj.ledIsON);
				obj.inp = obj.rawRead(zeros(1,10),10);
			end
		end
		
		% ===================================================================
		%> @brief Turn LED OFF
		%>
		%> I think this only works on the U3
		% ===================================================================
		function ledOFF(obj)
			if obj.silentMode == false && obj.vHandle == 1
				obj.outp = obj.rawWrite(obj.ledIsOFF);
				obj.inp = obj.rawRead(zeros(1,10),10);
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
		%>	Calculate checksum for data packet. Note see the labjack
		%> documentation; there are 2 types of checksums, normal and extended.
		%> This method uses 2 static methods checksum8 and checksum16 for each
		%> type respectively.
		%>
		%> @param command The command that needs checksumming
		%> @param type normal | extended
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
			in = sum(uint16(in));
			quo = floor(in/2^8);
			remd = rem(in,2^8);
			in = quo+remd;
			quo = floor(in/2^8);
			remd = rem(in,2^8);
			chk = quo + remd;
		end
		
		% ===================================================================
		%> @brief checksum16
		%>	Calculate checksum (lsb and msb) for extended data packet
		%>
		% ===================================================================
		function [lsb,msb] = checksum16(in)
			in = sum(uint16(in));
			lsb = bitand(in,255);
			msb = bitshift(in,-8);
		end
		
	end % END STATIC METHODS
	
	
	%=======================================================================
	methods ( Access = private ) % PRIVATE METHODS
	%=======================================================================
		
		% ===================================================================
		%> @brief delete is the object Destructor
		%>	Destructor automatically called when object is cleared
		%>
		% ===================================================================
		function delete(obj)
			obj.salutation('DELETE Method','labJack object Cleaning up...')
			obj.close;
		end
		
		% ===================================================================
		%> @brief salutation - log message to command window
		%>	log message to command window, dependent on verbosity
		%>
		% ===================================================================
		function salutation(obj,in,message,verbose)
			if ~exist('verbose','var')
				verbose = obj.verbose;
			end
			if verbose ~= false
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
		%> @param args input structure/cell - will automagically handle
		%> either type
		%> @param allowedProperties a regex of allowed properties to set at
		%> runtime
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