% ========================================================================
%> @brief LABJACKT Connects and manages a LabJack T4 / T7
%>
% ========================================================================
classdef labJackT < handle
	
	properties
		%> friendly object name, setting this to 'null' will force silentMode=1
		name char = 'LabJackT'
		%> what LabJack device to use; 3 = U3, 6 = U6
		deviceID = 4
		%> if more than one labJack connected, which one to open?
		device = 1
		%> silentMode allows one to gracefully fail methods without a labJack connected
		silentMode logical = false
		%> header needed by loadlib
		header char = '/usr/local/include/LabJackM.h'
		%> the library itself
		library char = '/usr/local/lib/libLabJackM'
		%> do we log everything to the command window?
		verbose logical = true
		%> allows the constructor to run the open method immediately (default)
		openNow logical = true
		%> strobeTime is time of strobe in ms; max = 100ms
		strobeTime = 5
	end
	
	properties (SetAccess = private, GetAccess = public)
		%> function list returned from loading LJM
		functionList
		%> library version returned on first open
		version
		%> device serial number
		serialNumber
		%> internal test, should be 1122867
		testValue
		%> how many devices are connected
		devCount int32
		%> device types
		devTypes int32
		%> handle to the opened device itself
		handle int32 = []
		%> have we successfully opened the labjack?
		isOpen = false
		%> Is our handle a valid one, this is a cache so we save a bit of
		%> time on calling the method each time
		isValid = 0
		%> universal ID
		uuid = 0
		%> clock() dateStamp set on construction
		dateStamp = []
		%> raw command 
		command
		%> last error found
		lastError
	end
	
	properties (SetAccess = private, Dependent = true)
		%> The fullName is the object name combined with its uuid and class name
		fullName
	end
	
	properties (SetAccess = private, GetAccess = private)
		%> RAM address for communication
		RAMAddress uint32 = 46000
		%> minimal lua server to allow fast asynchronous strobing of EIO
		miniServer char = 'LJ.setLuaThrottle(100)LJ.IntervalConfig(0,500)local a=LJ.CheckInterval;local b=MB.R;local c=MB.W;local d=-1;local e=-1;c(2601,0,255)c(2602,0,255)c(46000,3,0)c(2501,0,0)c(2502,0,0)while true do d=b(46000,3)if d~=e and(d>=1 and d<=255)then c(2501,0,d)c(61590,1,2000)c(2501,0,0)e=d elseif d~=e and(d>=256 and d<=271)then c(2502,0,d-256)c(61590,1,100000)c(61590,1,100000)c(61590,1,100000)c(2502,0,0)e=d elseif d~=e and d==0 then c(2501,0,0)e=d end;if a(0)then c(46000,3,0)end end'
		%> constants
		LJM_dtANY int32		= 0
		LJM_dt4 int32		= 4
		LJM_dt7 int32		= 7
		LJM_dtTSERIES int32 = 84
		LJM_ctANY int32		= 0 
		LJM_ctUSB int32		= 1
		LJM_ctTCP int32		= 2
		LJM_ctETHERNET int32 = 3
		LJM_ctWIFI int32	= 4
		LJM_UINT16 int32	= 0
		LJM_UINT32 int32	= 1
		LJM_INT32 int32		= 2
		LJM_FLOAT32 int32	= 3
		LJM_TESTRESULT uint32 = 1122867
		%> library name
		libName char = 'libLabJackM'
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
		function me = labJackT(varargin)
			if nargin>0
				me.parseArgs(varargin,me.allowedProperties);
			end
			me.className = class(me);
			me.dateStamp = clock();
			me.uuid = num2str(dec2hex(floor((now - floor(now))*1e10)));
			if strcmpi(me.name, 'null') %we were deliberately passed null, means go into silent mode
				me.silentMode	= true;
				me.openNow		= false;
				me.salutation('CONSTRUCTOR Method','labJack running in silent mode...')
			end
			if me.openNow == true
				open(me);
			end
		end
		
		% ===================================================================
		%> @brief Open the LabJack device
		%>
		%> Open the LabJack device
		% ===================================================================
		function open(me)
			if me.silentMode || me.isOpen; return; end
			if isunix || ismac
				if ~libisloaded(me.libName)
					try
						warning off; loadlibrary(me.library,me.header); warning on;
					catch ME
						warning(['Loading the LJM library failed: ' ME.message]);
						me.version = ['Library Load FAILED: ' ME.message];
						me.silentMode = true;
						me.verbose = true;
						return
					end
				end
				me.functionList = libfunctions(me.libName, '-full'); %store our raw lib functions
				
				[err,me.devCount,me.devTypes] = calllib(me.libName,'LJM_ListAll',0,0,0,0,[],[],[]);
				me.checkError(err);
				
				[err, ~, thandle] = calllib(me.libName,'LJM_Open',0,0,'ANY',0);
				me.checkError(err);
				if err > 0
					me.close();
					me.silentMode = true;
				else
					me.handle = thandle;
					me.isOpen = true;
					me.silentMode = false;
				end
				
				err = calllib(me.libName, 'LJM_WriteLibraryConfigS', 'LJM_SEND_RECEIVE_TIMEOUT_MS', 500);
				if err == 0; me.salutation('OPEN method','Set timeout to 500ms!'); end
				
				[~, ~, vals] = calllib(me.libName, 'LJM_eReadNames', me.handle,...
					3, {'SERIAL_NUMBER','FIRMWARE_VERSION','TEST'}, [0 0 0], 0);
				me.serialNumber = uint32(vals(1));
				me.version = vals(2);
				me.testValue = uint32(vals(3));
				
				%initialise EIO and CIO
				err = calllib(me.libName, 'LJM_eWriteNames', me.handle, 4, {'EIO_DIRECTION','CIO_DIRECTION',...
					'EIO_STATE','CIO_STATE'}, [255 255 0 0], 0);
				me.checkError(err);
				
				if ~me.silentMode;me.salutation('OPEN method','Loading the LabJackT is a success!');end
			else 
				ljmAsm = NET.addAssembly('LabJack.LJM');
				% Creating an object to nested class LabJack.LJM.CONSTANTS
				t = ljmAsm.AssemblyHandle.GetType('LabJack.LJM+CONSTANTS');
				LJM_CONSTANTS = System.Activator.CreateInstance(t); 
				[err, me.handle] = LabJack.LJM.OpenS('ANY', 'ANY', 'ANY', 0);
			end
				
		end
		
		% ===================================================================
		%> @brief Close the LabJack device
		%>	void LJUSB_CloseDevice(HANDLE hDevice);
		%>	//Closes the handle of a LabJack USB device.
		% ===================================================================
		function close(me)
			if ~isempty(me.handle)
				if ispc
					LabJack.LJM.Close(me.handle);
				else
					err =  calllib(me.libName,'LJM_Close',me.handle);
					if err > 0 
						me.salutation('CLOSE method','LabJack Handle not valid');
					else
						me.salutation('CLOSE method','LabJack Handle has been closed');
					end
					me.devCount = [];
					me.devTypes = [];
					me.handle=[];
					me.isOpen = false;
					me.isValid = false;
				end
			else
				me.salutation('CLOSE method','No handle to close...');
			end
		end
		
		% ===================================================================
		%> @brief 
		%>	
		% ===================================================================
		function result = isHandleValid(me)
			if me.silentMode || isempty(me.handle); return; end
			me.isValid = false;
			[err, ~, val] = calllib(me.libName, 'LJM_eReadName', me.handle, 'TEST', 0);
			me.checkError(err);
			if err == 0 && uint32(val) == me.LJM_TESTRESULT
				me.isValid = true;
			end
			result = me.isValid;
		end
		
		
		% ===================================================================
		%> @brief 
		%>	
		% ===================================================================
		function initialiseServer(me)
			if me.silentMode || isempty(me.handle); return; end
			
			%prepare string
			str = sprintf([me.miniServer '\0']); %0byte terminator
			strN = length(str);
			
			%stop server
			calllib(me.libName, 'LJM_eWriteName', me.handle, 'LUA_RUN', 0);
			WaitSecs(0.5);
			calllib(me.libName, 'LJM_eWriteName', me.handle, 'LUA_RUN', 0);
			
			%upload new script	
			err = calllib(me.libName, 'LJM_eWriteName', me.handle, 'LUA_SOURCE_SIZE', strN);
			me.checkError(err,true);
			err = calllib(me.libName, 'LJM_eWriteNameByteArray', me.handle, 'LUA_SOURCE_WRITE', strN, str, 0);
			me.checkError(err,true);
			%err = calllib(me.libName, 'LJM_eWriteNameArray', me.handle, 'LUA_SOURCE_WRITE', strN, str, 0);
			[~, ~, len] = calllib(me.libName, 'LJM_eReadName', me.handle, 'LUA_SOURCE_SIZE', 0);
			if len ~= strN; error('Problem with the upload...'); end
			
			%copy to flash
			calllib(me.libName, 'LJM_eWriteNames', me.handle, 2, {'LUA_SAVE_TO_FLASH','LUA_RUN_DEFAULT'}, ...
				[1 1], 0);
			
			%start the server
			err = calllib(me.libName, 'LJM_eWriteName', me.handle, 'LUA_RUN', 1);
			me.checkError(err,true);
			
		end
		
		% ===================================================================
		%> @brief sends a value to RAMAddress, requires the Lua server to
		%> be running, 0-255 control EIO, 256-271 controls CIO
		%>	
		% ===================================================================
		function strobeServer(me, value)
			if me.silentMode || isempty(me.handle); return; end
			calllib(me.libName, 'LJM_eWriteAddress', me.handle, me.RAMAddress, me.LJM_FLOAT32, value);
		end
		
		% ===================================================================
		%> @brief check if lua code is running
		%>	
		% ===================================================================
		function result = isServerRunning(me)
			if me.silentMode || isempty(me.handle); return; end
			[~, value] = calllib(me.libName, 'LJM_eReadName', me.handle, 'LUA_RUN',0);
			result = logical(value);
		end

		
		% ===================================================================
		%> @brief 
		% ===================================================================
		function sendStrobedEIO(me,value)
			if me.silentMode || isempty(me.handle); return; end
			calllib(me.libName, 'LJM_eWriteAddresses', me.handle,...
 				3, [2501 61590 2501], [me.LJM_UINT16 me.LJM_UINT32 me.LJM_UINT16], [value me.strobeTime*1000 0], 0);
		end
		
		% ===================================================================
		%> @brief 
		% ===================================================================
		function sendStrobedCIO(me,value)
			if me.silentMode || isempty(me.handle); return; end
			calllib(me.libName, 'LJM_eWriteAddresses', me.handle,...
 				3, [2502 61590 2502], [me.LJM_UINT16 me.LJM_UINT32 me.LJM_UINT16], [value me.strobeTime*1000 0], 0);
		end
		
		% ===================================================================
		%> @brief Prepare Strobe Word
		%>	
		% ===================================================================
		function prepareStrobe(me,value)
			if me.silentMode || isempty(me.handle); return; end
			cmd = zeros(64,1);
			[err,~,~,~,~,~,~,cmd] = calllib(me.libName, 'LJM_AddressesToMBFB',...
				64, [2501 61590 2501], [0 1 0], [1 1 1], [1 1 1], [value me.strobeTime*1000 0], 3, cmd);
			me.command = cmd;
			me.checkError(err);
		end
		
		% ===================================================================
		%> @brief Send the Strobe command
		%>
		%>
		% ===================================================================
		function strobeWord(me)
			if me.silentMode || isempty(me.handle) || isempty(me.command); return; end
			me.writeCmd();
		end
		
		% ===================================================================
		%> @brief timedTTL Send a TTL with a defined time of pulse
		%>
		%> @param line 0-7=FIO, 8-15=EIO, or 16-19=CIO
		%> @param time time in ms
		% ===================================================================
		function timedTTL(me,line,time)
			if (~exist('line','var') || ~exist('time','var'))
				fprintf('\ntimedTTL Input options: \n\tline (single value 0-7=FIO, 8-15=EIO, or 16-19=CIO), time (in ms)\n\n');
				return
			end
			
			
			me.salutation('timedTTL method',sprintf('Line:%g Tlong:%g Tshort:%g output time = %g ms', line, time1, time2, otime*1000))
			
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
		function setDIO(me,value,mask,valuedir,maskdir)
			if me.silentMode || isempty(me.handle); return; end
			if ~exist('value','var');fprintf('\nsetDIO Input options: \n\tvalue, [mask], [value direction], [mask direction]\n\n');return;end
			if ~exist('mask','var');mask=[255,255,255];end %all DIO by default
			if ~exist('valuedir','var');valuedir=[255,255,255];maskdir=valuedir;end %all DIO set to output
			
		end
		
		% ===================================================================
		%> @brief setDIODirection
		%>	setDIODirection sets the direction for FIO, EIO and CIO as read or write
		%>	@param value is binary identifier for 0-7 bit range
		%> @param mask is the mask to apply the command
		% ===================================================================
		function setDIODirection(me,value,mask)
			if me.silentMode || isempty(me.handle); return; end
			if ~exist('value','var');fprintf('\nsetDIODirection Input options: \n\t\tvalue, [mask]\n\n');return;end
			if ~exist('mask','var');mask=[255,255,255];end

		end
		
		% ===================================================================
		%> @brief setDIOValue
		%>	setDIOValue sets the value for FIO, EIO and CIO as HIGH or LOW
		%>	@param value is binary identifier for 0-7 bit range
		%>  @param mask is the mask to apply the command
		% ===================================================================
		function setDIOValue(me,value,mask)
			if me.silentMode || isempty(me.handle); return; end
			if ~exist('value','var');fprintf('\nSetDIOValue Input options: \n\t\tvalue, [mask]\n\n');return;end
			if ~exist('mask','var');mask=[255,255,255];end
			
		end
		
		% ===================================================================
		%> @brief concatenate the name with a uuid at get.
		%> @param
		%> @return name the concatenated name
		% ===================================================================
		function name = get.fullName(me)
			if isempty(me.name)
				name = [me.className '#' me.uuid];
			else
				name = [me.name ' <' me.className '#' me.uuid '>'];
			end
		end
		
	end
	
	%=======================================================================
	methods ( Static ) % STATIC METHODS
	%=======================================================================
		
	end % END STATIC METHODS
	
	
	%=======================================================================
	methods ( Access = private ) % PRIVATE METHODS
	%=======================================================================
	
		function checkError(me,err,halt)
			if ~exist('halt','var'); halt = false; end
			if err > 0
				me.lastError = calllib(me.libName,'LJM_ErrorToString',err,'');
			else
				me.lastError='';
			end
			if err > 0 && me.verbose
				warning('labJackT error %i: %s',err,me.lastError); 
			elseif err > 0 && halt 
				error('labJackT error %i: %s',err,me.lastError); 
			end	
		end
	
		function writeCmd(me)
			if me.silentMode || isempty(me.handle) || isempty(me.command); return; end
			err = calllib(me.libName, 'LJM_MBFBComm', me.handle, 1, me.command, 0);
			me.checkError(err);
		end
		
		function writeCmd2(me)
			% WILL CRASH MATLAB!
			if me.silentMode || isempty(me.handle) || isempty(me.command); return; end
			tic;err = calllib(me.libName, 'LJM_WriteRaw', me.handle, me.command, length(me.command));fprintf('%.2f\n',toc*1000)
			me.checkError(err);
		end
		
		function writeRAMValue(me,value)
			if me.silentMode || isempty(me.handle); return; end
			calllib(me.libName, 'LJM_eWriteAddress', me.handle, me.RAMAddress, me.LJM_FLOAT32, value);
		end
		
		function value = readRAMValue(me)
			if me.silentMode || isempty(me.handle); return; end
			[~, value] = calllib(me.libName, 'LJM_eReadAddress', me.handle, me.RAMAddress, me.LJM_FLOAT32, 0);
		end
		
		% ===================================================================
		%> @brief delete is the object Destructor
		%>	Destructor automatically called when object is cleared
		%>
		% ===================================================================
		function delete(me)
			me.salutation('DELETE Method','labJackT object Cleaning up...')
			me.close;
		end
		
		% ===================================================================
		%> @brief salutation - log message to command window
		%>	log message to command window, dependent on verbosity
		%>
		% ===================================================================
		function salutation(me,in,message,verbose)
			if ~exist('verbose','var')
				verbose = me.verbose;
			end
			if verbose ~= false
				if ~exist('in','var')
					in = 'General Message';
				end
				if exist('message','var')
					fprintf(['---> labJackT: ' message ' | ' in '\n']);
				else
					fprintf(['---> labJackT: ' in '\n']);
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
		function parseArgs(me, args, allowedProperties)
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
			for i=1:length(fnames)
				if regexp(fnames{i},allowedProperties) %only set if allowed property
					me.salutation(fnames{i},'Configuring setting in constructor');
					me.(fnames{i})=args.(fnames{i}); %we set up the properies from the arguments as a structure
				end
			end
		end
	end
end