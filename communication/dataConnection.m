% ========================================================================
%> @brief dataConnection Connects and manages a socket connection
%>
%> Connects and manages TCP/UDP Communication. We allow both TCP and UDP
%> connections, and can choose to be a client or server in TCP mode. To use
%> at its simplest in UDP mode, both clients on the same machine:
%>
%> %OPEN CLIENT 1
%> >> d1=dataConnection('rPort',4321,'lPort',1234,'protocol','udp','autoOpen',1)
%> %OPEN CLIENT 2
%> >> d2=dataConnection('rPort',1234,'lPort',4321,'protocol','udp','autoOpen',1)
%> >> d1.write('my command')
%> >> data = d2.read()
%> >> d2.write('my response')
%> >> response = d1.read()
%> >> d1.close();
%> >> d2.close();
%>
%> Please read through the other public methods:
%>  * close() closes connection
%>  * checkData() check if there is data sent from remote object available to read
%>  * checkClient() if you are a TCP server, check if a client tries to connect
%>  * readVar() & writeVar() reads structures and objects over the wire
%> There is also an autoServer mode, where the object opens a TCP server
%> and responds to commands, allowing you to send data and EVAL commands on a
%> remote machine...
% ========================================================================
classdef dataConnection < handle
	%dataConnection Allows send/recieve over Ethernet
	%   This uses the TCP/UDP library to manage connections between servers
	%   and clients in Matlab
	properties
		%> Whether this object is a 'client' or 'server' (TCP), normally UDP
		%> objects will always be clients
		type = 'client'
		%> protocol = 'tcp' | 'udp'
		protocol = 'tcp'
		%> the local port to open
		lPort = 1111
		%> the remote port to open
		rPort = 5678
		%> the local address to open
		lAddress = '127.0.0.1'
		%> the remote address to open
		rAddress = '127.0.0.1'
		%> do we try to open the connection on construction
		autoOpen = 0
		%> the data to send to the remote object
		dataOut = []
		%> the format the data is required
		dataType = 'string'
		%> verbosity
		verbosity = 1
		%> this is a mode where the object sits in a loop and can be
		%> controlled by a remote matlab instance, which passes commands the
		%> server can 'put' or 'eval'
		autoServer = false
		%> default read timeout
		readTimeOut = 0
		%> default write timeout
		writeTimeOut = 0
		%> sometimes we shouldn't cleanup connections on delete, e.g. when we pass this
		%> object to another matlab instance as we will close the wrong connections!!!
		cleanup = true
	end
	
	properties (SetAccess = private, GetAccess = public)
		%> data received
		dataIn = []
		%> length of data in bytes
		dataLength
	end
	
	properties (SetAccess = private, GetAccess = public, Transient = true)
		connList = []
		rconnList = []
		conn = -1
		rconn = -1
		%> is there data available?
		hasData = false
		%> is this connection open?
		isOpen = false
		status = -1
		statusMessage = ''
		error
	end
	
	properties (SetAccess = private, GetAccess = private)
		allowedProperties='^(type|protocol|lPort|rPort|lAddress|rAddress|autoOpen|dataType|verbosity|autoServer|readTimeOut|writeTimeOut|cleanup)$'
		remoteCmd = '--remote--'
		breakCmd = '--break--'
		busyCmd = '--busy--'
		matfileCmd = '--matfile--'
	end
	
	methods
		% ===================================================================
		%> @brief CONSTRUCTOR
		%>
		%> Configures input structure to assign properties
		% ===================================================================
		function obj = dataConnection(varargin)
			
			obj.parseArgs(varargin);
			if obj.autoServer == true
				obj.type='server';
				obj.protocol='tcp';
				obj.startServer;
			elseif obj.autoOpen == true
				obj.open;
			end
		end
		
		% ===================================================================
		%> @brief Open an ethernet connection
		%>
		%> Open an ethernet connection, dependent on whether we are using a UDP
		%> or TCP connection
		% ===================================================================
		function conn = open(obj)
			switch obj.protocol
				case 'udp'
					obj.conn = pnet('udpsocket', obj.lPort);
					if obj.conn >= 0
						pnet(obj.conn ,'setwritetimeout', obj.writeTimeOut);
						pnet(obj.conn ,'setreadtimeout', obj.readTimeOut);
						obj.isOpen = true;
						obj.connList = [obj.connList obj.conn];
						obj.connList = unique(obj.connList);
					else
						fprintf('%s cannot open UDP socket (%d)\n', ...
							mfilename, obj.conn);
						obj.isOpen = false;
						obj.conn = -1;
					end
					conn = obj.conn;					
				case 'tcp'
					switch obj.type
						case 'server'
							loop = 1;
							while loop <= 10
								obj.rconn = pnet('tcpsocket',obj.lPort);
								pnet(obj.rconn ,'setwritetimeout', obj.writeTimeOut);
								pnet(obj.rconn ,'setreadtimeout', obj.readTimeOut);
								if obj.rconn < 0
									fprintf('---> %s cannot create TCP server (status: %d)',mfilename,obj.rconn);
									pause(0.1);
									if loop == 2 %see if we have rogue connetions
										for i = 1:length(obj.rconnList)
											try %#ok<TRYNC>
												pnet(obj.rconnList(i),'close');
											end
										end
									elseif loop == 3
										for i = 0:8
											try
												pnet(i,'close');
											end
										end
									end
								else
									obj.isOpen = true;
									obj.rconnList = unique([obj.rconnList obj.rconn]);
									obj.checkStatus('rconn')
									loop = 100;break;
								end
								loop = loop + 1;
							end
							conn = obj.rconn;	
						case 'client'
							loop = 1;
							while loop <= 10
								obj.conn=pnet('tcpconnect',obj.rAddress,obj.rPort);
								if obj.conn == -1
									fprintf('---> CAN NOT CONNECT TO HOST: %s PORT: %d\nRETRY....',obj.rAddress,obj.rPort);
									pause(0.5);
								else
									
									break
								end
							end
							
							if obj.conn >= 0
								% disable blocking
								pnet(obj.conn ,'setwritetimeout', obj.writeTimeOut);
								pnet(obj.conn ,'setreadtimeout', obj.readTimeOut);
								obj.status = pnet(obj.conn,'status');
								if obj.status < 1
									obj.close('conn')
									warning('---> %s cannot connect to remote TCP host (status: %d)',mfilename,obj.status);
								else
									fprintf('---> CONNECTED TO HOST: %s PORT: %d !\n',obj.rAddress,obj.rPort);
									obj.isOpen = true;
									obj.connList = unique([obj.connList obj.conn]);
								end
							else
								fprintf('---> %s cannot open TCP socket (%d)', ...
									mfilename, obj.conn);
								obj.isOpen = false;
								obj.conn = -1;
							end
							conn = obj.conn;
					end
			end
		end
		
		% ===================================================================
		%> @brief Close the connection
		%>
		%> Close the ethernet connection
		% ===================================================================
		function status = close(obj,type,force)
			if ~exist('type','var');type = 'conn';end
			if ~exist('force','var');force = true;end
			if ischar(force);force = true;end
			status = 0;
			
			switch type
				case {'conn','local'}
					name = 'conn';
					list = 'connList';
					type = 'local';
				case {'rconn','remote'}
					name = 'rconn';
					list = 'rconnList';
					type = 'remote';
			end
			
			try
				obj.salutation('close Method',['Trying to close ' type ' connection...'])
				if force == true
					for i = 1:length(obj.(list))
						try
							pnet(obj.(list)(i), 'close');
							fprintf('Closed connection %i.\n',obj.(list)(i));
						catch %#ok<CTCH>
							status = -1;
							fprintf('Couldn''t close connection %i, perhaps closed?\n',obj.(list)(i));
						end
					end
				else
					obj.status = pnet(obj.(name),'status');
					if obj.status <=0;
						obj.isOpen = false;
						obj.salutation('close Method','Connection appears closed...');
					else
						try %#ok<TRYNC>
							pnet(obj.(name), 'close');
						end
					end
					obj.conn = -1;
				end
			end
		end
		
		% ===================================================================
		%> @brief Close all connections
		%>
		%> Close all connections
		% ===================================================================
		function status = closeAll(obj)
			obj.status = 0;
			obj.conn = -1;
			obj.rconn = -1;
			try
				pnet('closeall');
				obj.salutation('closeAll Method','Closed all PNet connections')
			catch
				obj.salutation('closeAll Method','Failed to close all PNet connections')
				obj.status = -1;
			end
			status = obj.status;
		end
		
		% ===================================================================
		%> @brief Check if there is data non-destructively
		%>
		%> Check if there is data non-destructively, i.e. attempt to read
		%> from the given pnet socket without consuming available data
		%>
		%> @return hasData (logical)
		% ===================================================================
		function hasData = checkData(obj)
			obj.hasData = false;
			switch obj.protocol
				case 'udp'%============================UDP
					data = pnet(obj.conn, 'read', 65536, obj.dataType, 'view');
					if isempty(data)
						obj.hasData = pnet(obj.conn, 'readpacket') > 0;
					else
						obj.hasData = true;
					end
				case 'tcp'%============================TCP
					data = pnet(obj.conn, 'read', 1024, obj.dataType, 'noblock', 'view');
					if ~isempty(data)
						obj.hasData = true;
					end
					
			end
			hasData = obj.hasData;
		end
		
		% ===================================================================
		%> @brief Read a single line of data
		%>
		%> Read a single line of data from the connection
		%> @return data read from connection
		% ===================================================================
		% Read any avalable data from the given pnet socket.
		function data = readline(obj)
			data = [];
			switch obj.protocol
				case 'udp'%============================UDP
					nBytes = pnet(obj.conn, 'readpacket');
					if nBytes > 0
						data = pnet(obj.conn, 'readline', nBytes, 'noblock');
					end
				case 'tcp'%============================TCP
					data = pnet(obj.conn, 'readline', 1024,' noblock');
			end
			obj.dataIn = data;
		end
		
		% ===================================================================
		%> @brief Read any avalable data from the given pnet socket.
		%>
		%> Read any avalable data from the given pnet socket.
		%>
		%> @param all (optional, logical) whether to read as much data as is present or
		%>  only one item
		%> @param (optional) dataType the type of data to read in
		%> @param (optional) size is size in bytes to read
		%> @return data the data returned from the connection
		% ===================================================================
		function data = read(obj,all,dataType,size)
			
			if ~exist('all','var')
				all = 0;
			end
			if ischar(all) && ~isempty(all) %convert from string if string not empty
				all = 1;
			end
			if ~exist('dataType','var') || isempty(dataType)
				dataType=obj.dataType;
			end
			
			data = [];
			loop = 1;
			olddataType=obj.dataType;
			
			switch obj.protocol
				%============================UDP
				case 'udp'
					if ~exist('size','var');size=65536;end
					while loop > 0
						dataIn = pnet(obj.conn, 'read', size, dataType);
						if isempty(dataIn)
							nBytes = pnet(obj.conn, 'readpacket');
							if nBytes > 0
								dataIn = pnet(obj.conn, 'read', nBytes, dataType);
							end
							if ischar(dataIn) && ~isempty(regexpi(dataIn,'--matfile--'))
								dataType = 'uint32';
								tmpfile=[tempname,'.mat'];
								VAR=[];
								try
									nBytes = pnet(obj.conn, 'readpacket');
									bytes=double(pnet(obj.conn,'Read',[1 1],'uint32'));
									nBytes = pnet(obj.conn, 'readpacket');
									pnet(obj.conn,'ReadToFile',tmpfile,bytes);
									load(tmpfile);
								end
								try
									delete(tmpfile);
								end
								dataIn = VAR;
								loop = 0;
							end
						end
						if all == 0
							loop = 0;
							data = dataIn;
						else
							data{loop} = dataIn;
							if obj.checkData
								loop = loop + 1;
							else
								loop = 0;
							end
						end
					end
					if iscell(data) && length(data) == 1
						data = data{1};
					end
					obj.dataIn = data;
					%============================TCP
				case 'tcp'
					if ~exist('size','var');size=256000;end
					while loop > 0
						dataIn=pnet(obj.conn,'read', size, dataType,'noblock');
						if all == false
							data = dataIn;
							break
						end
						if isempty(dataIn)
							loop = 0;
						else
							data{loop} = dataIn;
							loop = loop + 1;
						end
					end
					if iscell(data) && length(data) == 1
						data = data{1};
					end
					obj.dataIn = data;
			end
		end
		
		% ===================================================================
		%> @brief Write data to the given pnet socket.
		%>
		%> @param data to write to connection
		%> @param formatted (0[default]|1) whether to send data raw (0) or as a formatted string (1)
		%> @param sendPacket (0|1[default]) for UDP connections actually send the packet or wait to fill buffer with another call first
		% ===================================================================
		function write(obj, data, formatted, sendPacket)
			
			if ~exist('data','var')
				data = obj.dataOut;
			end
			if ~exist('formatted','var')
				formatted = false;
			end
			if ~exist('sendPacket','var')
				sendPacket = true;
			end
			
			switch obj.protocol
				case 'udp'%============================UDP
					if formatted == false
						pnet(obj.conn, 'write', data);
					else
						pnet(obj.conn, 'printf', data);
					end
					if sendPacket;pnet(obj.conn, 'writepacket', obj.rAddress, obj.rPort);end
				case 'tcp'%============================TCP
					if formatted == false
						pnet(obj.conn, 'write', data);
					else
						pnet(obj.conn, 'printf', data);
					end
			end
		end
		
		% ===================================================================
		%> @brief Read any available variable from the given pnet socket.
		%>
		%> Read any avalable variable from the given pnet socket.
		% ===================================================================
		function data = readVar(obj)
			pnet(obj.conn ,'setreadtimeout', 5);
			data = obj.getVar;
			pnet(obj.conn ,'setreadtimeout', obj.readTimeOut);
		end
		
		% ===================================================================
		%> @brief
		%>
		%>
		% ===================================================================
		% Write data to the given pnet socket.
		function writeVar(obj, varargin)
			pnet(obj.conn ,'setwritetimeout', 5);
			obj.putVar(varargin);
			pnet(obj.conn ,'setwritetimeout', obj.writeTimeOut);
		end
		
		% ===================================================================
		%> @brief Check client
		%>
		%> Check status
		% ===================================================================
		function isClient = checkClient(obj)
			isClient = false;
			if strcmpi(obj.type,'server')
				try
					obj.conn=pnet(obj.rconn,'tcplisten');
					if obj.conn > -1
						[rhost,rport]=pnet(obj.conn,'gethost');
						fprintf('START SERVING NEW CONNECTION FROM IP %d.%d.%d.%d port:%d',rhost,rport)
						pnet(obj.conn ,'setwritetimeout', obj.writeTimeOut);
						pnet(obj.conn ,'setreadtimeout', obj.readTimeOut);
						obj.rPort = rport;
						obj.rAddress = rhost;
						obj.isOpen = 2;
						isClient = true;
					else
						obj.conn = -1;
						obj.isOpen = false;
						obj.salutation('No client available')
					end
				catch
					obj.conn = -1;
					obj.isOpen = false;
					obj.salutation('Couldn''t find client connection');
				end
			end
			
		end
		
		% ===================================================================
		%> @brief Check status
		%>
		%> Check status
		% ===================================================================
		% 		#define STATUS_NOCONNECT   0    // Disconnected pipe that is not closed
		% 		#define STATUS_TCP_SOCKET  1
		% 		#define STATUS_IO_OK       5    // Used for IS_... test
		% 		#define STATUS_UDP_CLIENT  6
		% 		#define STATUS_UDP_SERVER  8
		% 		#define STATUS_CONNECT     10   // Used for IS_... test
		% 		#define STATUS_TCP_CLIENT  11
		% 		#define STATUS_TCP_SERVER  12
		% 		#define STATUS_UDP_CLIENT_CONNECT 18
		% 		#define STATUS_UDP_SERVER_CONNECT 19
		function status = checkStatus(obj,conn) %#ok<INUSD>
			status = -1;
			try
				if ~exist('conn','var') || strcmp(conn,'conn')
					conn='conn';
				else
					conn = 'rconn';
				end
				obj.status = pnet(obj.(conn),'status');
				if obj.status <=0;obj.(conn) = -1; obj.isOpen = false;obj.salutation('checkStatus Method','Connection appears closed...');end
				switch obj.status
					case -1
						obj.statusMessage = 'STATUS_NOTFOUND';
					case 0
						obj.statusMessage = 'STATUS_NOCONNECT';
					case 1
						obj.statusMessage = 'STATUS_TCP_SOCKET';
					case 5
						obj.statusMessage = 'STATUS_IO_OK';
					case 6
						obj.statusMessage = 'STATUS_UDP_CLIENT';
					case 8
						obj.statusMessage = 'UDP_SERVER';
					case 10
						obj.statusMessage = 'STATUS_CONNECT';
					case 11
						obj.statusMessage = 'STATUS_TCP_CLIENT';
					case 12
						obj.statusMessage = 'STATUS_TCP_SERVER';
					case 18
						obj.statusMessage = 'STATUS_UDP_CLIENT_CONNECT';
					case 19
						obj.statusMessage = 'STATUS_UDP_SERVER_CONNECT';
					otherwise
						obj.statusMessage = 'UNDEFINED';
				end
				obj.salutation(obj.statusMessage,'checkStatus')
				status = obj.status;
			catch %#ok<CTCH>
				obj.status = -1;
				obj.statusMessage = 'UNKNOWN';
				status = obj.status;
				obj.(conn) = -1;
				obj.isOpen = false;
				fprintf('Couldn''t check status\n')
			end
		end
		
		% ===================================================================
		%> @brief Initialize the server loop
		%>
		%> Initialize the server loop
		% ===================================================================
		function startServer(obj)
			obj.conn = pnet('tcpsocket',obj.lPort);
			pnet(obj.conn ,'setwritetimeout', obj.writeTimeOut);
			pnet(obj.conn ,'setreadtimeout', obj.readTimeOut);
			ls = 1;
			msgloop=1;
			while ls			
				if msgloop == 1;fprintf('\nWAIT FOR CONNECTION ON PORT: %d\n',obj.lPort);end
				msgloop=2;
				try
					obj.rconn = pnet(obj.conn,'tcplisten');
					pause(0.01);
				catch ME
					disp 'Try:  "pnet closeall"  in all matlab sessions on this server.';
					disp ' ';
					ls = 0;
					rethrow(ME);
				end
				
				if obj.rconn >= 0
					msgloop=1;
					try
						[obj.rAddress,obj.rPort]=pnet(obj.rconn,'gethost');
						fprintf('START SERVING NEW CONNECTION FROM IP %d.%d.%d.%d port:%d\n\n',obj.rAddress,obj.rPort);
						obj.serverLoop;
					catch %#ok<*CTCH>
						disp 'Server loop initialisation failed';
					end
				end
				
				if obj.checkForEscape == 1
					pnet(obj.rconn,'close')
					pnet(obj.conn,'close')
					obj.conn = -1;
					obj.rconn = -1;
					break;
				end
			end
			
			obj.close;
			
		end
		
		% ===================================================================
		%> @brief Send command to a remote dataConnection server
		%>
		%> Send command to remote dataConnection server. Commands can be
		%> 'echo', 'put', 'get' and 'eval'
		%>
		%> @param varargin can be
		% ===================================================================
		function varargout = sendCommand(obj,varargin)
			if obj.conn < 0
				obj.open;
			end
			switch varargin{1}
				case 'ping'
					pnet(obj.conn,'printf','\n--remote--\n');
					obj.flushStatus; % Flush status buffer. Keep last status in readbuffer
					ping.time = GetSecs;
					obj.putVar(obj.conn,'ping',ping);
				case 'echo'
					pnet(obj.conn,'printf','\n--remote--\n');
					obj.flushStatus; % Flush status buffer. Keep last status in readbuffer
					obj.putVar(obj.conn,'echo','Hello!');
				case 'put'
					pnet(obj.conn,'printf','\n--remote--\n');
					obj.flushStatus; % Flush status buffer. Keep last status in readbuffer
					obj.putVar(obj.conn,varargin);
					return
				case 'eval'
					obj.waitNotBusy; %pnet_remote(obj.conn,'WAITNOTBUSY');
					pnet(obj.conn,'printf','\n--remote--\n');
					obj.putVar(obj.conn,varargin);
					return
				case 'get'
					pnet(obj.conn,'printf','\n--remote--\n');
					obj.flushStatus; % Flush status buffer. Keep last status in readbuffer
					obj.putVar(obj.conn,varargin);
					varargout=obj.getVar;
				case 'close'
					pnet(obj.conn,'printf','\n--remote--\n');
					obj.flushStatus; % Flush status buffer. Keep last status in readbuffer
					obj.putVar(obj.conn,'close');
					close(obj);
				otherwise
					
			end
			
		end
		
		
	end %END METHODS
	
	%=======================================================================
	methods ( Access = private ) % PRIVATE METHODS
	%=======================================================================
		
		% ===================================================================
		%> @brief checkForEscape
		%>
		%> Check if the user has hit escape
		% ===================================================================
		function waitNotBusy(obj)
			while strcmp(obj.flushStatus,'busy')
				pause(0.01);
			end
			return
		end
		% ===================================================================
		%> @brief checkForEscape
		%>
		%> Check if the user has hit escape
		% ===================================================================
		function out = checkForEscape(obj)
			out=false;
			[~,~,key] = KbCheck(-1);
			key=KbName(key);
			if strcmpi(key,'escape') %allow keyboard break
				out=true;
			end
		end
		
		% ===================================================================
		%> @brief Run the server loop
		%>
		%> Run the server loop
		% ===================================================================
		function serverLoop(obj)
			while pnet(obj.rconn,'status')
				ls = true;
				while ls
					okflag = true;
					str = ''; 
					fprintf('Waiting for %s command...',obj.remoteCmd);
					while ~strcmpi(str,obj.remoteCmd) && pnet(obj.rconn,'status')
						pause(0.01);
						str=pnet(obj.rconn,'readline',1024,'noblock');
						if checkForEscape(obj)
							pnet(obj.rconn,'close');
							return;
						end
					end
					if pnet(obj.rconn,'status')==0;break;end
					C=getVar(obj);
					pnet(obj.rconn,'printf',['\n' obj.busyCmd '\n']);
					drawnow;
					if ~isempty(C) && iscell(C)
						switch lower(C{1})
							case 'ping'
								C=C(2:end);
								for n=1:2:length(C)
									fprintf('\n');
									disp(['REMOTE PING>> ' C{n}]);
									try
										assignin('caller',C{n:n+1});
									catch
										okflag = false;
									end
								end
							case 'eval'
								global DEFAULT_CON__;
								DEFAULT_CON__=obj.rconn;
								try
									fprintf('\n');
									disp(['REMOTE EVAL>> ' C{2:min(2:end)}]);
									evalin('caller',C{2:end},'okflag=0;');
								catch
									okflag = false;
								end
								DEFAULT_CON__=[];
							case 'put'
								C=C(2:end);
								for n=1:2:length(C)
									fprintf('\n');
									disp(['REMOTE PUT>> ' C{n}]);
									try
										assignin('caller',C{n:n+1});
									catch
										okflag = false;
									end
								end
							case 'get'
								C=C(2:end);
								R=cell(size(C));
								for n=1:length(C)
									fprintf('\n');
									disp(['REMOTE GET>> ' C{n}]);
									try
										R{n}=evalin('caller',[C{n} ';']);
									catch
										okflag = false;
									end
								end
								pnet_putvar(obj.rconn,R);
							case 'close'
								pnet(obj.rconn,'close');
								return;
						end %END SWITCH
					else
						disp('Remote Message appeared Empty...');
					end
					
					if okflag
						pnet(obj.rconn,'printf','\n--ready--\n');
					else
						pnet(obj.rconn,'printf','\n--error--\n');
						disp(sprintf('\nERROR: %s\n',lasterr));
					end
					
				end %END WHILE ls
				
			end %END while pnet(obj.rconn,'status')
			
		end
		
		
		% ===================================================================
		%> @brief Flush the server messagelist
		%>
		%> Flush the server messagelist
		% ===================================================================
		function stat=flushStatus(obj)
			while 1 % Loop that finds, returns and leaves last text line in buffer.
				str=pnet(obj.conn,'read', 1024,'view','noblock');
				if length(regexp([str,' '],'\n'))<=1
					stat=pnet(obj.conn,'readline',1024,'view','noblock'); % The return
					stat=stat(3:end-2);
					return;
				end
				dump=pnet(obj.conn,'readline',1024,'noblock'); % Then remove last line
			end
		end
		
		% ===================================================================
		%> @brief putVar
		%>
		%>
		% ===================================================================
		function putVar(obj,varargin)
			if ~isempty(varargin)
				if length(varargin)==2 && varargin{1}==0;varargin = varargin{2:end};end
				while iscell(varargin) && length(varargin) == 1
					varargin = varargin{1};
				end
				VAR=varargin;
				switch obj.protocol
					case 'udp'
						switch class(VAR)
							case {'double' 'char' 'int8' 'int16' 'int32' 'uint8' 'uint16' 'uint32'}
								pnet(obj.conn,'printf','%s',class(VAR));
								obj.status = pnet(obj.conn, 'writepacket', obj.rAddress, obj.rPort);
								
								pnet(obj.conn,'Write',uint32(ndims(VAR)));
								obj.status = pnet(obj.conn, 'writepacket', obj.rAddress, obj.rPort);
								
								pnet(obj.conn,'Write',uint32(size(VAR)));
								obj.status = pnet(obj.conn, 'writepacket', obj.rAddress, obj.rPort);
								
								pnet(obj.conn,'Write',VAR);
								obj.status = pnet(obj.conn, 'writepacket', obj.rAddress, obj.rPort);
							otherwise
								try
									bytes = uint32(getByteStreamFromArray(VAR));
									dataLength = uint32(size(bytes)); %#ok<*PROP>
									
									pnet(obj.conn,'printf','--bytestream--');
									obj.status = pnet(obj.conn, 'writepacket', obj.rAddress, obj.rPort);
									
									pnet(obj.conn,'Write',uint32(ndims(bytes)));
									obj.status = pnet(obj.conn, 'writepacket', obj.rAddress, obj.rPort);
									
									pnet(obj.conn,'Write',dataLength);
									obj.status = pnet(obj.conn, 'writepacket', obj.rAddress, obj.rPort);

									pnet(obj.conn,'Write',bytes);
									obj.status = pnet(obj.conn, 'writepacket', obj.rAddress, obj.rPort);
								end
						end
					case 'tcp'
						switch class(VAR)
							case {'double' 'char' 'int8' 'int16' 'int32' 'uint8' 'uint16' 'uint32'}
								pnet(obj.conn,'printf','\n%s\n',class(VAR));
								pnet(obj.conn,'Write',uint32(ndims(VAR)));
								pnet(obj.conn,'Write',uint32(size(VAR)));
								pnet(obj.conn,'Write',VAR);
							otherwise
								try
									bytes = uint32(getByteStreamFromArray(VAR));
									dataLength = uint32(size(bytes));
									pnet(obj.conn,'printf','\n--bytestream--\n');
									pnet(obj.conn,'Write',uint32(ndims(dataLength)));
									pnet(obj.conn,'Write',dataLength);
									pnet(obj.conn,'Write',bytes);
									pnet(obj.conn,'printf','\n--end--\n');
								end
						end
				end
			end
		end
		
		% ===================================================================
		%> @brief getVar
		%>
		%>
		% ===================================================================
		function varargout = getVar(obj)
			VAR='';
			dataclass='';
			switch obj.protocol
				case 'udp'
					while obj.checkData
						dataclass = pnet(obj.conn, 'read', 65536, obj.dataType);
						if isempty(dataclass)
							nBytes = pnet(obj.conn, 'readpacket');
							if nBytes > 0
								dataclass = pnet(obj.conn, 'read', nBytes, obj.dataType);
							end
						end
						switch dataclass
							case {'double' 'char' 'int8' 'int16' 'int32' 'uint8' 'uint16' 'uint32'}
								nBytes = pnet(obj.conn, 'readpacket');
								datadims=double(pnet(obj.conn,'Read',1,'uint32'));
								
								nBytes = pnet(obj.conn, 'readpacket');
								datasize=double(pnet(obj.conn,'Read',datadims,'uint32'));
								
								nBytes = pnet(obj.conn, 'readpacket');
								VAR=pnet(obj.conn,'Read',datasize,dataclass);
							case '--matfile--'
								
							case '--bytestream--'
								%tmpfile=[tempname,'.mat'];
								VAR=[];
								try
									nBytes = pnet(obj.conn, 'readpacket');
									datadims=double(pnet(obj.conn,'Read',1,'uint32'));
									
									nBytes = pnet(obj.conn, 'readpacket');
									datasize=double(pnet(obj.conn,'Read',datadims,'uint32'));
									
									nBytes = pnet(obj.conn, 'readpacket');
									bytes=pnet(obj.conn,'Read',datasize,'uint32');
									VAR=getArrayFromByteStream(uint8(bytes));
									fprintf('Reported size: %ix%i | Returned Size: %ix%i\n',...
										datasize(1),datasize(2),size(bytes,1),size(bytes,2));
									%nBytes = pnet(obj.conn, 'readpacket');
									%pnet(obj.conn,'ReadToFile',tmpfile,bytes);
									%load(tmpfile);
									break;
								end
								%try delete(tmpfile); end
						end
					end
				case 'tcp'
					if obj.rconn >= 0
						thisConnection = obj.rconn;
					else
						thisConnection = obj.conn;
					end
					lp = 25;
					while lp > 0 
						lp = lp - 1;
						dataclass=pnet(thisConnection,'readline',1024);
						switch dataclass
							case {'double' 'char' 'int8' 'int16' 'int32' 'uint8' 'uint16' 'uint32'}
								datadims=double(pnet(thisConnection,'Read',1,'uint32'));
								datasize=double(pnet(thisConnection,'Read',datadims,'uint32'));
								VAR=pnet(thisConnection,'Read',datasize,dataclass);
								fprintf('Reported size: %ix%i | Returned Size: %ix%i\n',...
										datasize(1),datasize(2),size(VAR,1),size(VAR,2));
								break;
							case '--matfile--'
								tmpfile=[tempname,'.mat'];
								VAR=[];
								try
									datasize=double(pnet(thisConnection,'Read',[1 1],'uint32'));
									pnet(thisConnection,'ReadToFile',tmpfile,datasize);
									load(tmpfile);
									break;
								end
								try delete(tmpfile); end
							case '--bytestream--'
								VAR=[];
								try 
									dimz=double(pnet(thisConnection,'Read',[1 1],'uint32'));
									datasize=double(pnet(thisConnection,'Read',dimz,'uint32'));
									bytes=pnet(thisConnection,'Read',datasize,'uint32');
									VAR=getArrayFromByteStream(uint8(bytes));
									fprintf('Reported size: %ix%i | Returned Size: %ix%i\n',...
										datasize(1),datasize(2),size(bytes,1),size(bytes,2));
									break;
								end
						end
					end
					if lp == 0; disp('TCP loop depleted waiting for variable...'); end
			end
			varargout{1}=VAR;
			return;
		end
		
		% ===================================================================
		%> @brief Object Destructor
		%>
		%>
		% ===================================================================
		function delete(obj)
			if obj.cleanup == true
				obj.salutation('dataConnection delete Method','Cleaning up now...')
				obj.close;
			else
				obj.salutation('dataConnection delete Method','Closing (no cleanup)...')
			end
		end
		
		% ===================================================================
		%> @brief Prints messages dependent on verbosity
		%>
		%> Prints messages dependent on verbosity
		%> @param in the calling function
		%> @param message the message that needs printing to command window
		% ===================================================================
		function salutation(obj,in,message)
			if obj.verbosity > 0
				if ~exist('in','var')
					in = 'General Message';
				end
				if exist('message','var')
					fprintf(['--> dataConnection: ' message ' | ' in '\n']);
				end
			end
		end
		
		% ===================================================================
		%> @brief Sets properties from a structure, ignores invalid properties
		%>
		%> @param varargin input structure
		% ===================================================================
		function parseArgs(obj,varargin)
			while iscell(varargin) && length(varargin) == 1 %cell data is wrapped in passed cell
				varargin = varargin{1}; %unwrap
			end
			if iscell(varargin)
				if mod(length(varargin),2) == 1 % odd
					varargin = varargin(1:end-1); %remove last arg
				end
				odd = logical(mod(1:length(varargin),2));
				even = logical(abs(odd-1));
				varargin = cell2struct(varargin(even),varargin(odd),2);
			end
			if nargin>0 && isstruct(varargin)
				fnames = fieldnames(varargin); %find our argument names
				for i=1:length(fnames)
					if regexp(fnames{i},obj.allowedProperties) %only set if allowed property
						obj.salutation(fnames{i},'Configuring setting in constructor');
						obj.(fnames{i})=varargin.(fnames{i}); %we set up the properies from the arguments as a structure
					end
				end
			end
		end
	end
	
	methods (Static)
		% ===================================================================
		%> @brief load object method
		%>
		%> we have to make sure we don't load a saved object with connection
		%> numbers intact, this can cause wrongly closed connections if another
		%> dataConnection is open with the same numbered connection. cleanup
		%> property is used to stop the delete method from calling close methods.
		% ===================================================================
		function lobj=loadobj(in)
			fprintf('Loading dataConnection object...\n');
			in.cleanup=0;
			in.conn=-1;
			in.rconn=-1;
			in.connList=[];
			in.rconnList=[];
			lobj=in;
		end
	end
end