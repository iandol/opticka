% ========================================================================
%> @brief LABJACKT Connects and manages a LabJack T4 / T7
%>
% ========================================================================
classdef labJackT < handle
	
	properties
		%> friendly object name, setting this to 'null' will force silentMode=1
		name='LabJackT'
		%> what LabJack device to use; 3 = U3, 6 = U6
		deviceID = 4
		%> if more than one labJack connected, which one to open?
		device = 1
		%> silentMode allows one to gracefully fail methods without a labJack connected
		silentMode = false
		%> header needed by loadlib
		header = '/usr/local/include/LabJackM.h'
		%> the library itself
		library = '/usr/local/lib/libLabJackM'
		%> do we log everything to the command window?
		verbose = true
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
		devCount int32
		%> device types
		devTypes int32
		%> handle to the opened device itself
		handle int32 = []
		%> have we successfully opened the labjack?
		isOpen = false
		%> universal ID
		uuid = 0
		%> clock() dateStamp set on construction
		dateStamp = []
	end
	
	properties (SetAccess = private, Dependent = true)
		%> The fullName is the object name combined with its uuid and class name
		fullName
	end
	
	properties (SetAccess = private, GetAccess = private)
		LJM_dtANY int32 = 0
		LJM_dt4 int32 = 4
		LJM_dt7 int32 = 7
		LJM_dtTSERIES int32 = 84
		LJM_ctANY int32 = 0 
		LJM_ctUSB int32 = 1
		LJM_ctTCP int32 = 2
		LJM_ctETHERNET int32 = 3
		LJM_ctWIFI int32 = 4
		%> Is our handle a valid one, this is a cache so we save a bit of
		%> time on calling the method each time
		vHandle = 0
		%> what properties are allowed to be passed on construction
		allowedProperties='device|deviceID|name|silentMode|verbose|openNow|header|library'
		%>document what our strobed word is actually setting, shown to user if verbose = true
		strobeComment = ''
		%> class name
		className = ''
		%> timedTTL cache
		timedTTLCache = []
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
		function obj = labJackT(varargin)
			obj.className = class(obj);
			obj.dateStamp = clock();
			obj.uuid = num2str(dec2hex(floor((now - floor(now))*1e10)));
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
			if obj.silentMode == false || isempty(obj.handle)
				if ismac == true || isunix == true
					if ~libisloaded('libLabJackM')
						try
							loadlibrary(obj.library,obj.header);
						catch ME
							obj.salutation('open method',['Loading the LJM library failed: ' ME.message],true);
							warning(['Loading the LJM library failed: ' ME.message]);
							obj.version = ['Library Load FAILED: ' ME.message];
							obj.silentMode = true;
							obj.verbose = true;
							return
						end
					end
					obj.functionList = libfunctions('libLabJackM', '-full'); %store our raw lib functions
				else %incomplete PC support, basically need to add PC equivalents of rawRead and rawWrite
					
				end
				
				[error,obj.devCount,obj.devTypes] = calllib('libLabJackM','LJM_ListAll',obj.LJM_dtANY,obj.LJM_dtANY,[],[],[],[],[]);
				if error > 0
					ename = calllib('libLabJackM','LJM_ErrorToString',error,'');
					warning(['Error found: ' ename]);
				end
				
				[error, ~, thandle] = calllib('libLabJackM','LJM_Open',0,0,'ANY',0);
				if error > 0
					ename = calllib('libLabJackM','LJM_ErrorToString',error,'');
					obj.close();
					obj.silentMode = true;
					error(['Error found: ' ename]);
				else
					obj.handle = thandle;
					obj.isOpen = true;
					obj.silentMode = false;
					obj.salutation('OPEN method','Loading the LJM library is a success');
				end
			else %silentmode is ~false
				obj.close();
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
				error =  calllib('libLabJackM','LJM_Close',obj.handle);
				if error > 0 
					obj.salutation('CLOSE method','LabJack Handle not valid');
				else
					obj.salutation('CLOSE method','LabJack Handle has been closed');
				end
				obj.devCount = [];
				obj.devTypes = [];
				obj.handle=[];
				obj.isOpen = false;
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
			out = calllib('libLabJackM', 'LJUSB_WriteTO', obj.handle, byte, length(byte), obj.timeOut);
			if out == 0;	obj.salutation('rawWrite','ERROR WRITING!',true); end
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
			in =  calllib('libLabJackM', 'LJUSB_ReadTO', obj.handle, bytein, count, obj.timeOut);
			if in == 0; obj.salutation('rawRead','ERROR READING!',true); end
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
				if obj.readResponse; obj.inp = obj.rawRead(zeros(1,10),10); end
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
				if obj.readResponse; obj.inp = obj.rawRead(zeros(1,10),10); end
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
		%> @param line 0-7=FIO, 8-15=EIO, or 16-19=CIO
		%>	@param time time in ms
		%> @param sync optional logical flag whether to use blocking (true) command
		% ===================================================================
		function timedTTL(obj,line,time)
			if (~exist('line','var') || ~exist('time','var'))
				if ~isempty(obj.timedTTLCache)
					obj.outp = obj.rawWrite(obj.timedTTLCache);
					if obj.readResponse; obj.inp = obj.rawRead(zeros(1,10),10); end
					obj.salutation('timedTTL method','Cached Command used')
				else
					fprintf('\ntimedTTL Input options: \n\tline (single value 0-7=FIO, 8-15=EIO, or 16-19=CIO), time (in ms)\n\n');
				end
				return
			end
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
				
				obj.command = obj.checksum(cmd,'extended');
				obj.timedTTLCache = obj.command;
				obj.outp = obj.rawWrite(obj.command);
				if obj.readResponse; obj.inp = obj.rawRead(zeros(1,10),10); end
				obj.salutation('timedTTL method',sprintf('Line:%g Tlong:%g Tshort:%g output time = %g ms', line, time1, time2, otime*1000))
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
			if ~exist('value','var');fprintf('\nsetDIO Input options: \n\tvalue, [mask], [value direction], [mask direction]\n\n');return;end
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
				
				obj.command = obj.checksum(cmd,'extended');
				obj.outp = obj.rawWrite(obj.command);
				if obj.readResponse; obj.inp = obj.rawRead(zeros(1,10),10); end
			end
		end
		
		% ===================================================================
		%> @brief setDIODirection
		%>	setDIODirection sets the direction for FIO, EIO and CIO as read or write
		%>	@param value is binary identifier for 0-7 bit range
		%> @param mask is the mask to apply the command
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
				
				obj.command = obj.checksum(cmd,'extended');
				obj.outp = obj.rawWrite(obj.command);
				if obj.readResponse; obj.inp = obj.rawRead(zeros(1,10),10); end
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
				
				obj.command = obj.checksum(cmd,'extended');
				obj.outp = obj.rawWrite(obj.command);
				if obj.readResponse; obj.inp = obj.rawRead(zeros(1,10),10); end
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
				if obj.readResponse; obj.inp = obj.rawRead(zeros(1,10),10); end
				%obj.salutation('strobeWord', obj.strobeComment);
% 				if obj.inp(6) > 0
% 					obj.salutation('strobeWord',['Feedback error in IOType ' num2str(obj.inp(7))]);
% 				end
			end
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
					obj.outp = obj.rawWrite(obj.(cmdHigh));
					if obj.readResponse; obj.inp  = obj.rawRead(zeros(1,10),10); end
					obj.(myname) = 1;
					obj.salutation('SETFIO',[myname ' is HIGH'])
				else
					obj.outp = obj.rawWrite(obj.(cmdLow));
					if obj.readResponse; obj.inp = obj.rawRead(zeros(1,10),10); end
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
				if obj.readResponse; obj.inp = obj.rawRead(zeros(1,10),10); end
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
				if obj.readResponse; obj.inp = obj.rawRead(zeros(1,10),10); end
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
			
			obj.outp = obj.rawWrite(cmd);
			if obj.readResponse; obj.inp  = obj.rawRead(zeros(4,1)); end
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
		
		% ===================================================================
		%> @brief concatenate the name with a uuid at get.
		%> @param
		%> @return name the concatenated name
		% ===================================================================
		function name = get.fullName(obj)
			if isempty(obj.name)
				name = [obj.className '#' obj.uuid];
			else
				name = [obj.name ' <' obj.className '#' obj.uuid '>'];
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
		function [eio,cio] = prepareWords(value,strobeState)
			if ~exist('strobeState','var')
				strobeState = 1;
			end
			eio = bitand(value,255); %get eio easily ANDing with 255
			msb = bitshift(value,-8); %our msb is bitshifted 8 bits
			msb = bitshift(msb,1); %shift it across as cio0 is reserved;
			cio = bitor(msb,strobeState); %OR with 1 as cio0 is the strobe trigger and needs to be 1
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