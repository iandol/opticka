% ========================================================================
%> @brief LABJACKT Connects and manages a LabJack T4 / T7
%> This class handles digital I/O and analog I/O and analog streaming.
%> Connection can be USB or network. Network is slightly lower latency than USB
%>
%> Example:
%>
%> ```
%> l = labJackT('openNow', true);
%> l.sendStrobe(128); % sends 128 via EIO 8 bits
%> l.close;
%> ```
%>
%> Copyright ©2014-2022 Ian Max Andolina — released: LGPL3, see LICENCE.md
% ========================================================================
classdef labJackT < handle
	
	properties
		%> friendly object name, setting this to 'null' will force silentMode=1
		name char				= 'labJackT'
		%> what LabJack device to use; 4 = T4, 7 = T7
		deviceID double			= 4
		%> if more than one labJack connected, which one to open? Default is first device
		device double			= 1
		%> Connection type: ANY, USB, TCP, ETHERNET, WIFI
		connectType char		= 'ANY'
		%> IP address if using network
		IP char					= ''
		%> strobeTime is time of strobe in ms; max = 100ms
		strobeTime uint32		= 5
		%> streamChannels which channels to stream
		streamChannels double	= 0
		%> stream sample rate (Hz)
		streamSampleRate double = 2000;
		%> number of stream samples to collect in each read
		streamSamples double	= 500;
		%> resolution of the stream 0-5 for T4, 0 is default (=1), 5 being best/slowest
		streamResolution double = 0
		%> timeout for communication in ms
		timeOut	double			= 500
		%> header needed by loadlib
		header char				= '/usr/local/include/LabJackM.h'
		%> the library itself
		library char			= '/usr/local/lib/libLabJackM'
		%> do we log everything to the command window?
		verbose logical			= true
		%> allows the constructor to run the open method immediately
		openNow logical			= false
		%> silentMode=true allows one to gracefully fail methods without a labJack connected
		silentMode logical		= false
		%> comment
		comment char
	end
	
	properties (Hidden = true)
		winLibrary				= 'C:\Windows\System32\LabJackM'
		winHeader				= 'C:\Program Files (x86)\LabJack\Drivers\LabJackM.h'
	end
	
	properties (SetAccess = private, GetAccess = public)
		%> have we successfully opened the labjack?
		isOpen logical			= false
		%> is streaming?
		isStreaming logical		= false
		%> send this value for the next sendStrobe
		sendValue int32			= 0
		%> last value sent
		lastValue double		= []
		%> function list returned from loading LJM
		functionList
		%> firmware library version returned on first open
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
		handle int32			= []
		%> Is our handle a valid one, this is a cache so we save a bit of
		%> time on calling the method each time
		isValid					= 0
		%> universal ID
		uuid					= 0
		%> clock() dateStamp set on construction
		dateStamp				= []
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
		%> constants
		LJM_dtANY int32			= 0
		LJM_dt4 int32			= 4
		LJM_dt7 int32			= 7
		LJM_dtTSERIES int32		= 84
		LJM_ctANY int32			= 0 
		LJM_ctUSB int32			= 1
		LJM_ctTCP int32			= 2
		LJM_ctETHERNET int32	= 3
		LJM_ctWIFI int32		= 4
		LJM_UINT16 int32		= 0
		LJM_UINT32 int32		= 1
		LJM_INT32 int32			= 2
		LJM_FLOAT32 int32		= 3
		LJM_TESTRESULT uint32	= 1122867
		%> RAM address for communication
		RAMAddress uint32		= 46080
		%> minimal lua server to allow fast asynchronous strobing of EIO & CIO
		miniServer char = 'LJ.setLuaThrottle(80)local a=MB.R;local b=MB.W;local c=-1;local d=0;local e=0;b(2601,0,255)b(2602,0,255)b(2501,0,0)b(2502,0,0)b(46080,2,0)while true do c=a(46080,2)if c>=1 and c<=2047 then d=bit.band(c,0xff)e=bit.band(bit.rshift(c,8),0xff)b(2501,0,d)if e>0 then b(2502,0,e)end;b(61590,1,2000)b(2501,0,0)if e>0 then b(2502,0,0)end elseif c>2047 then b(2502,0,8)b(61590,1,10000)b(2502,0,0)elseif c==0 then b(2501,0,0)end;if c>-1 then b(46080,2,-1)end end'
		%> test Lua server, just spits out time every second
		testServer char = 'LJ.IntervalConfig(0,1000)while true do if LJ.CheckInterval(0)then print(LJ.Tick())end end'
		%> library name
		libName char = 'libLabJackM'
		%> what properties are allowed to be passed on construction
		allowedProperties = ['device|deviceID|name|silentMode|verbose|openNow|'...
			'header|library|IP|connectType|'...
			'streamChannels|streamSamples|streamSampleRate|streamResolution']
		%>document what our strobed word is actually setting, shown to user if verbose = true
		strobeComment = ''
		%> class name
		className = ''
		%> timedTTL cache
		timedTTLCache = []
		winLibName = 'LabJackM'
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
			if IsWin
				me.header = me.winHeader;
				me.library = me.winLibrary;
				me.libName = me.winLibName;
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
		function open(me, serial)
			if me.silentMode || me.isOpen; return; end
			if ~exist('serial','var') || isempty(serial); serial = 'ANY'; end
			if isnumeric(serial); serial = num2str(serial); end
			tS=tic;
			if ~libisloaded(me.libName)
				try
					warning off; loadlibrary(me.library,me.header); warning on;
				catch ME
					warning on;
					warning(['Loading the LJM library failed: ' ME.message]);
					txt = ME.getReport();
					fprintf('%s\n',txt);
					fprintf('\nOn Windows, you need to install MINGW to use loadlibrary, check Add-on manager...\n')
					me.version = 'unknown';
					me.lastError = ['Library Load FAILED: ' ME.message];
					me.silentMode = true;
					me.verbose = true;
					return
				end
			end
			
			if isempty(me.functionList)
				me.functionList = libfunctions(me.libName, '-full'); %store our raw lib functions
			end

			if isempty(me.device) || isempty(me.devCount) || isempty(me.devTypes)
				me.listAll();
			end

			if isempty(me.devCount) || me.devCount == 0
				me.salutation('OPEN','No LabJack devices attached, entering silentMode...',true);
				me.close();
				me.silentMode = true;
				me.device = [];
				return
			else
				if isempty(me.device)
					me.device = 1; %default to first device
					me.deviceID = me.devTypes(1);
				end
			end
			
			switch lower(me.connectType)
				case {'usb'}
					[err, ~, thandle] = calllib(me.libName,'LJM_Open',...
						0,me.LJM_ctUSB,serial,0);
				case {'ethernet'}
					[err, ~, thandle] = calllib(me.libName,'LJM_Open',...
						0,me.LJM_ctETHERNET,me.IP,0);
				case {'tcp'}
					[err, ~, thandle] = calllib(me.libName,'LJM_Open',...
						0,me.LJM_ctTCP,me.IP,0);
				case {'wifi'}
					[err, ~, thandle] = calllib(me.libName,'LJM_Open',...
						0,me.LJM_ctWIFI,me.IP,0);
				otherwise
					[err, ~, thandle] = calllib(me.libName,'LJM_Open',...
						0,me.LJM_ctANY,serial,0);
			end
			me.checkError(err);
			if err > 0
				me.salutation('OPEN','Error opening device, entering silentMode...',true);
				me.close();
				me.silentMode = true; me.device = [];
				return
			else
				me.handle = thandle;
				me.isOpen = true;
				me.silentMode = false;
			end

			err = calllib(me.libName, 'LJM_WriteLibraryConfigS', 'LJM_SEND_RECEIVE_TIMEOUT_MS', me.timeOut);
			if err == 0; me.salutation('OPEN method','Set timeout to 500ms!'); end

			[~, ~, vals] = calllib(me.libName, 'LJM_eReadNames', me.handle,...
				3, {'SERIAL_NUMBER','FIRMWARE_VERSION','TEST'}, [0 0 0], 0);
			me.serialNumber = uint32(vals(1));
			me.version = vals(2);
			me.testValue = uint32(vals(3));

			%initialise EIO and CIO
			err = calllib(me.libName, 'LJM_eWriteNames', me.handle, 6, {'FIO_DIRECTION','EIO_DIRECTION','CIO_DIRECTION',...
				'FIO_STATE','EIO_STATE','CIO_STATE'}, [255 255 255 0 0 0], 0);
			me.checkError(err);

			me.isValid = me.isHandleValid;

			if ~me.isServerRunning
				warning('===>>> LabJack T: Lua server NOT running, strobes will fail! Will run labJackT.initialiseServer');
				initialiseServer(me);
			else
				me.salutation('OPEN method','Lua Server is Running :-)');
			end

			me.salutation('OPEN method',sprintf('Loading the LabJackT in %.2fsecs: success!',toc(tS)));	
		end
		
		% ===================================================================
		%> @brief Close the LabJack device
		%>	void LJUSB_CloseDevice(HANDLE hDevice);
		%>	//Closes the handle of a LabJack USB device.
		% ===================================================================
		function close(me)
			if ~isempty(me.handle)
				if ~isempty(me.functionList)
					err =  calllib(me.libName,'LJM_Close',me.handle);
					if err > 0 
						me.salutation('CLOSE method','LabJack Handle not valid');
						try calllib(me.libName,'LJM_CloseAll'); end %#ok<*TRYNC,NOSEMI>
					else
						me.salutation('CLOSE method','LabJack Handle has been closed');
					end
				end
				%me.devCount = [];
				%me.devTypes = [];
				me.handle=[];
				me.isOpen = false;
				me.isValid = false;
			else
				me.salutation('CLOSE method','No handle to close, closeAll called...');
				try calllib(me.libName,'LJM_CloseAll');end
				me.devCount = [];
				me.devTypes = [];
				me.handle=[];
				me.isOpen = false;
				me.isValid = false;
			end
		end
		
		% ===================================================================
		%> @brief 
		%>	
		% ===================================================================
		function reset(me)
			me.close;
			me.silentMode=false;
			me.device = [];
			me.devCount = [];
			me.devTypes = [];
		end
		
		% ===================================================================
		%> @brief 
		%>	
		% ===================================================================
		function [devCount,devTypes] = listAll(me)
			if me.silentMode; return; end
			[err,devCount,devTypes] = calllib(me.libName,'LJM_ListAll',0,0,0,0,[],[],[]);
			me.checkError(err);
			me.devCount = devCount;
			me.devTypes = devTypes;
		end
		
		% ===================================================================
		%> @brief check if lua code is running
		%>	
		% ===================================================================
		function result = isServerRunning(me)
			if me.silentMode || isempty(me.handle); return; end
			[err, ~, value] = calllib(me.libName, 'LJM_eReadName', me.handle, 'LUA_RUN',0);
			me.checkError(err);
			result = logical(value);
		end
		
		% ===================================================================
		%> @brief 
		%>	
		% ===================================================================
		function result = isHandleValid(me)
			if me.silentMode || isempty(me.handle); me.isValid = false; result = false; return; end
			me.isValid = false;
			[err, ~, val] = calllib(me.libName, 'LJM_eReadName', me.handle, 'TEST', 0);
			me.checkError(err);
			if err == 0 && uint32(val) == me.LJM_TESTRESULT
				me.isValid = true;
			end
			result = me.isValid;
		end
		
		% ===================================================================
		%> @brief sends a value to RAMAddress, requires the Lua server to
		%> be running, 0-2047 controls EIO0-8 & CIO0-3 - 2048 TTLs CIO-4
		%>	
		%> @param value 0 - 2048
		% ===================================================================
		function sendStrobe(me, value)
			if me.silentMode || isempty(me.handle); return; end
			if ~exist('value','var') || isempty(value); value = me.sendValue; end
			calllib(me.libName, 'LJM_eWriteAddress', me.handle, me.RAMAddress, me.LJM_INT32, int32(value));
			if me.verbose; fprintf('--->>> LabjackT:sendStrobe Sending strobe: %i\n',value); end
		end
		function setStrobeValue(me, value)
			me.sendValue = value;
		end

		% ===================================================================
		%> @brief 
		% ===================================================================
		function sendStrobedEIO(me, value)
			if me.silentMode || isempty(me.handle); return; end
			if ~exist('value','var') || isempty(value); value = me.sendValue; end
			calllib(me.libName, 'LJM_eWriteAddresses', me.handle,...
 				3, [2501 61590 2501], [me.LJM_UINT16 me.LJM_UINT32 me.LJM_UINT16], [uint16(value) me.strobeTime*1000 uint16(0)], 0);
		end
		
		% ===================================================================
		%> @brief 
		% ===================================================================
		function sendStrobedCIO(me, value)
			if me.silentMode || isempty(me.handle); return; end
			if ~exist('value','var') || isempty(value); value = me.sendValue; end
			calllib(me.libName, 'LJM_eWriteAddresses', me.handle,...
 				3, [2502 61590 2502], [me.LJM_UINT16 me.LJM_UINT32 me.LJM_UINT16], [uint16(value) me.strobeTime*1000 uint16(0)], 0);
		end

		function setFIO(me, line, value, direction)

		end
		
		% ===================================================================
		%> @brief 
		% ===================================================================
		function sendTTL(me,fio,value)
			if me.silentMode || isempty(me.handle); return; end
			if ~exist('fio','var') || isempty(fio); fio = 1; end
			if ~exist('value','var') || isempty(value); return; end

		end
		
		% ===================================================================
		%> @brief setAIO
		%>	setAIO sets the value for FIO, 
		%>	@param channels AIN channels 0-3
		%>  @return out voltages
		% ===================================================================
		function out = getAIN(me,channels)
			if me.silentMode || isempty(me.handle); return; end
			if ~exist('channels','var')||isempty(channels);fprintf('\ngetAIN Input options: \n\t\tchannels 0-3\n\n');return;end
			names = {};
			channels = channels .* 2; %float32 returns are sequential addresses
			[err, ~, ~, out] = calllib(me.libName, 'LJM_eReadAddresses', me.handle,...
				length(channels), channels, repmat(me.LJM_FLOAT32,1,length(channels)), zeros(length(channels)), 0);
			%me.checkError(err);
			out = out(:,1)';
		end
		
		% ===================================================================
		%> @brief startStream
		%>	
		% ===================================================================
		function startStream(me)
			if me.silentMode || isempty(me.handle); return; end
			oldV = me.verbose; me.verbose = false;
			stopStream(me);
			me.verbose = oldV;
			[err] = calllib(me.libName, 'LJM_eWriteName',me.handle,...
				'STREAM_RESOLUTION_INDEX', me.streamResolution);
			channels = me.streamChannels .* 2; %AIN float32 returns are sequential addresses
			[err,~,outrate] = calllib(me.libName, 'LJM_eStreamStart', me.handle,...
				me.streamSamples, length(channels), channels, me.streamSampleRate);
			me.checkError(err,true);
			me.isStreaming = true;
			if me.verbose;fprintf('===>>> Stream %s Started: sample rate: %i, # samples: %i, Update time required: %.2f seconds\n',num2str(me.streamChannels),outrate,me.streamSamples,(me.streamSamples/outrate));end
		end
		
		% ===================================================================
		%> @brief stopStream
		%>	
		% ===================================================================
		function stopStream(me)
			if me.silentMode || isempty(me.handle); return; end
			[err] = calllib(me.libName, 'LJM_eStreamStop', me.handle);
			me.checkError(err);
			me.isStreaming = false;
			fprintf('===>>> Stream Stopped...\n');
		end
		
		% ===================================================================
		%> @brief plotStream
		%>	This plots the last X seconds worth of Analog data (AIN 0-3)
		%>
		%> @param timeL - time in seconds to record
		%> @param updateN - refresh plot every N loops (too many refreshes slows down recording)
		% ===================================================================
		function plotStream(me,timeL,updateN)
			if me.silentMode || isempty(me.handle); return; end
			if ~exist('time','var'); timeL = 10; end
			if ~exist('updates','var'); updateN = 5; end
			h = figure('Name','LabJack AIN Stream (close figure to stop streaming)','Units','normalized',...
				'Position',[0.2 0.2 0.5 0.6],...		
				'Color',[1 1 1],...
				'PaperType','A4','PaperUnits','centimeters',...
				'CloseRequestFcn',{@closeHandler});
			fprintf('===>>> Starting Stream plot of last %.2f secs, close figure to stop plotting...\n',timeL)
			drawnow;
			pause(0.3);
			if ~me.isStreaming;me.startStream();end
			fprintf('\n...........');
			%Priority(1);
			dBL = int32(0);
			lBL = int32(0);
			f = me.streamSampleRate;
			n = me.streamSamples;
			nCh = length(me.streamChannels);
			iLen = n * nCh;
			dLen = f * timeL;
			time = 0:1/f:dLen/f; 
			time = time(1:dLen)';
			dt = zeros(iLen,1);
			data = zeros(dLen,nCh);
			ax = axes(h);
			plot(ax,time,data);
			ax.HitTest = 'off';
			ax.Interactions=[];
			ax.Toolbar = [];
			drawnow;
			plotLoop = 0;
			dBList = zeros(15,1);
			lBList = zeros(15,1);
			stop = 0;
			while ~stop
				[err, dt, dBL, lBL] = calllib(me.libName, 'LJM_eStreamRead', me.handle,...
					dt, dBL, lBL);
				dBList(1:14) = dBList(2:15); dBList(end) = dBL;
				lBList(1:14) = lBList(2:15); lBList(end) = lBL;
				data(1:dLen - n,:) = data(n+1:end,:);
				if size(data,2) > 1
					m = mod(1:iLen,nCh);
					m( m == 0 ) = nCh;
					for i = 1:nCh
						data((dLen - n)+1:end,i) = dt(m==i);
					end
				else
					data((dLen - iLen)+1:end) = dt;
				end
				if mod(plotLoop,updateN) == 0
					plot(ax,time,data);
					ax.HitTest = 'off';
					title(sprintf('%i -- Dev Backlog: %s | Lib Backlog: %s | Err: %i', ...
						plotLoop, sprintf('%i ',dBList), sprintf('%i ',lBList), err));
					drawnow;
					fprintf('\b\b\b\b\b\b\b\b\b\b\bLoop: %5i',plotLoop)
				end
				plotLoop = plotLoop + 1;
			end
			%Priority(0);
			assignin('base','streamdata',table(time,data,'VariableNames',{'Time','AnalogData'}));
			fprintf('===>>> Stopped recording, data exported to base workspace...\n')
			figure('Name','LabJack AIN Stream Data','Units','normalized',...
				'Position',[0.2 0.2 0.7 0.7],...		
				'Color',[1 1 1],...
				'PaperType','A4','PaperUnits','centimeters');
			if size(data,2)>1
				maxa = max(data(:,1));
				maxb = max(data(:,2));
				divi = maxa / maxb;
				data(:,2) = data(:,2) .* divi;
			end
			plot(time*1e3,smoothdata(data,'movmedian',3),'.-');
			%xlim([1000 2000]);
			grid on; grid minor;
			xlabel('Time (ms)')
			ylabel('Voltage (v)');
			title(sprintf('Stream data recorded @ %i Hz for %i seconds',me.streamSampleRate,timeL));
			me.stopStream();
			function closeHandler (src,evnt)
				delete(h);
				stop=1;
			end
		end
		
		% ===================================================================
		%> @brief upload the Lua server to the LabJack and start it
		%>	
		% ===================================================================
		function initialiseServer(me)
			if me.silentMode || isempty(me.handle); return; end
			%prepare string
			mS = regexprep(me.miniServer,'61590,1,2000',['61590,1,' num2str(me.strobeTime*1e3)]); %modify strobe time
			str = sprintf([mS '\0']); %0byte terminator
			strN = length(str);
			
			%stop server
			calllib(me.libName, 'LJM_eWriteName', me.handle, 'LUA_RUN', 0);
			WaitSecs('YieldSecs',0.75);
			calllib(me.libName, 'LJM_eWriteName', me.handle, 'LUA_RUN', 0);
			
			%upload new script	
			err = calllib(me.libName, 'LJM_eWriteName', me.handle, 'LUA_SOURCE_SIZE', strN);
			me.checkError(err,true);
			err = calllib(me.libName, 'LJM_eWriteNameByteArray', me.handle, 'LUA_SOURCE_WRITE', strN, str, 0);
			me.checkError(err,true);
			[~, ~, len] = calllib(me.libName, 'LJM_eReadName', me.handle, 'LUA_SOURCE_SIZE', 0);
			if me.verbose; fprintf('===>>> LUA Server init code sent: %i | recieved: %i | strobe length: %i\n',strN,len,me.strobeTime*1e3); end
			if len < strN; error('Problem with the upload, check with Kipling...'); end
			
			%copy to flash
			calllib(me.libName, 'LJM_eWriteNames', me.handle, 2, {'LUA_SAVE_TO_FLASH','LUA_RUN_DEFAULT'}, ...
				[1 1], 0);
			
			%start the server
			err = calllib(me.libName, 'LJM_eWriteName', me.handle, 'LUA_RUN', 1);
			me.checkError(err);
			WaitSecs('YieldSecs',1);
			
			%check it is running
			[err, ~, val] = calllib(me.libName, 'LJM_eReadName', me.handle, 'LUA_RUN', 0);
			if me.verbose && val==1; disp('===>>> LUA Server is now Running...'); end
			me.checkError(err,true);
			if val ~= 1; warning('Could not start server again...'); end
		end
		
		% ===================================================================
		%> @brief upload the Lua server to the LabJack and start it
		%>	
		% ===================================================================
		function stopServer(me)
			if me.silentMode || isempty(me.handle); return; end
			calllib(me.libName, 'LJM_eWriteName', me.handle, 'LUA_RUN', 0);
			WaitSecs('YieldSecs',0.1);
			[err, ~, val] = calllib(me.libName, 'LJM_eReadName', me.handle, 'LUA_RUN', 0);
			if val==0; disp('===>>> LUA Server is Stopped...'); end
			me.checkError(err,true);
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
	methods (Hidden = true)
	%=======================================================================
		
		% These commands are for compatability with older hardware and
		% protocols etc.
	
		% ===================================================================
		%> @brief 
		%> 
		%> @param 
		% ===================================================================
		function resetStrobe(me,varargin)
			me.sendValue = 0;
		end
		
		% ===================================================================
		%> @brief 
		%> 
		%> @param 
		% ===================================================================
		function startRecording(me,varargin)

		end
		
		% ===================================================================
		%> @brief 
		%> 
		%> @param 
		% ===================================================================
		function resumeRecording(me,varargin)

		end
		
		% ===================================================================
		%> @brief 
		%> 
		%> @param 
		% ===================================================================
		function pauseRecording(me,varargin)

		end
		
		% ===================================================================
		%> @brief 
		%> 
		%> @param 
		% ===================================================================
		function stopRecording(me,varargin)

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
		function startFixation(me, varargin)
			sendStrobe(me,248);
		end

		% ===================================================================
		%> @brief LEGACY Command - create a command to strobe EIO 0-255 ONLY
		%>	
		% ===================================================================
		function prepareStrobe(me,value)
			if me.silentMode || isempty(me.handle); me.sendValue=value; return; end
			me.lastValue = me.sendValue;
			me.sendValue = value;
			cmd = zeros(64,1);
			[err,~,~,~,~,~,~,cmd] = calllib(me.libName, 'LJM_AddressesToMBFB',...
				64, [2501 61590 2501], [0 1 0], [1 1 1], [1 1 1], [value me.strobeTime*1000 0], 3, cmd);
			me.command = cmd;
			me.checkError(err);
			if me.verbose;fprintf('--->>> LabJackT:prepareStrobe saving strobe value: %i\n',value);end
		end
		
		% ===================================================================
		%> @brief LEGACY Command - create a command to strobe EIO 0-255 ONLY
		%>
		%>
		% ===================================================================
		function strobeWord(me)
			if me.silentMode || isempty(me.handle) || isempty(me.command); return; end
			me.writeCmd();
		end

		% ===================================================================
		%> @brief LEGACY - use sendStrobe
		%>	
		% ===================================================================
		function strobeServer(me, value)
			if me.silentMode || isempty(me.handle); return; end
			if ~exist('value','var'); value = me.sendValue; end
			calllib(me.libName, 'LJM_eWriteAddress', me.handle, me.RAMAddress, me.LJM_FLOAT32, value);
			if me.verbose;fprintf('--->>> LabjackT:strobeServer Sending strobe: %i\n',value);end
		end
		
		% ===================================================================
		%> @brief 
		%> 
		%> @param 
		% ===================================================================
		function endStimulus(me)
			sendStrobe(me,255);
		end
		
		% ===================================================================
		%> @brief 
		%> 
		%> @param 
		% ===================================================================
		function correct(me)
			sendStrobe(me,251);
		end
		
		% ===================================================================
		%> @brief 
		%> 
		%> @param 
		% ===================================================================
		function incorrect(me)
			sendStrobe(me,250);
		end
		
		% ===================================================================
		%> @brief 
		%> 
		%> @param 
		% ===================================================================
		function breakFixation(me)
			sendStrobe(me,249);
		end
		
		
	end % END HIDDEN METHODS
	
	%=======================================================================
	methods ( Static ) % STATIC METHODS
	%=======================================================================
		
	end % END STATIC METHODS
	
	%=======================================================================
	methods ( Hidden = true ) % HIDDEN METHODS
	%=======================================================================
		
		function test(me)
			if me.silentMode || isempty(me.handle); return; end
			while true
				me.strobeServer(1); fprintf('Send 1\n');
				WaitSecs('YieldSecs', 0.5);
				me.strobeServer(255); fprintf('Send 255\n');
				WaitSecs('YieldSecs', 0.5);
				me.strobeServer(0); fprintf('Send 0\n');
				[~,~,buttons] = GetMouse();
				if any(buttons); break; end
				WaitSecs('YieldSecs', 0.5);
			end
		end
		
		function testAIN(me,channels)
			stopStream(me);
			nSamples = 2000;
			data = zeros(nSamples,length(channels));
			ti=tic;
			for i = 1:length(data)
				smp = me.getAIN(channels);
				data(i,:) = smp;
			end
			fprintf('Time per sample: %.3f ms\n',(toc(ti)/nSamples)*1e3);
			tic;
			plot(data);
			drawnow;
			toc
		end
		
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
			if err > 0 && halt
				error('labJackT error %i: %s',err,me.lastError); 
			elseif err > 0 && me.verbose 
				warning('labJackT error %i: %s',err,me.lastError); 
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