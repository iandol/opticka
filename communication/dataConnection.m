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
%>
%> Copyright ©2014-2023 Ian Max Andolina — released: LGPL3, see LICENCE.md
% ========================================================================
classdef dataConnection < handle
	% dataConnection Allows send/recieve over Ethernet
	%   This uses the PNET library to manage connections between servers
	%   and clients in Matlab
	properties
		%> Whether this object is a 'client' or 'server' (TCP). Normally UDP
		%> objects are always clients
		type			= 'client'
		%> protocol = 'tcp' | 'udp'
		protocol		= 'tcp'
		%> the local port to open
		lPort			= 1111
		%> the remote port to open
		rPort			= 5678
		%> the local address to open
		lAddress		= '127.0.0.1'
		%> the remote address to open
		rAddress		= '127.0.0.1'
		%> do we try to open the connection on construction
		autoOpen		= false
		%> the data to send to the remote object
		dataOut			= []
		%> the format the data is required
		dataType		= 'string'
		%> do we log to the command window?
		verbosity		= 0
		%> this is a mode where the object sits in a loop and can be
		%> controlled by a remote matlab instance, which passes commands the
		%> server can 'put' or 'eval'
		autoServer		= false
		%> default read timeout
		readTimeOut		= 0
		%> default write timeout
		writeTimeOut	= 0
		%> default size of chunk to read for tcp
		readSize		= 1024
		%> sometimes we shouldn't cleanup connections on delete, e.g. when we pass this
		%> object to another matlab instance as we will close the wrong connections!!!
		cleanup			= true
	end
	
	properties (SetAccess = private, GetAccess = public)
		%> data received
		dataIn			= []
		%> length of data in bytes
		dataLength
	end
	
	properties (SetAccess = private, GetAccess = public, Transient = true)
		connList		= []
		rconnList		= []
		conn			= -1
		rconn			= -1
		%> is there data available?
		hasData			= false
		%> is this connection open?
		isOpen			= false
		status			= -1
		statusMessage	= ''
		error
	end
	
	properties (SetAccess = private, GetAccess = private)
		allowedProperties = {'type','protocol','lPort','rPort','lAddress',...
			'rAddress','autoOpen','dataType','verbosity','autoServer',...
			'readTimeOut','writeTimeOut','readSize','cleanup'}
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
		function me = dataConnection(varargin)
			
			me.parseArgs(varargin);
			if me.autoServer == true
				me.type='server';
				me.protocol='tcp';
				me.startServer;
			elseif me.autoOpen == true
				me.open;
			end
		end
		
		% ===================================================================
		%> @brief Open an ethernet connection
		%>
		%> Open an ethernet connection, dependent on whether we are using a UDP
		%> or TCP connection
		% ===================================================================
		function conn = open(me)
			if me.isOpen; return; end
			switch me.protocol
				case 'udp'
					me.conn = pnet('udpsocket', me.lPort);
					if me.conn >= 0
						pnet(me.conn ,'setwritetimeout', me.writeTimeOut);
						pnet(me.conn ,'setreadtimeout', me.readTimeOut);
						me.isOpen = true;
						me.connList = [me.connList me.conn];
						me.connList = unique(me.connList);
					else
						fprintf('%s cannot open UDP socket (%d)\n', ...
							mfilename, me.conn);
						me.isOpen = false;
						me.conn = -1;
					end
					conn = me.conn;					
				case 'tcp'
					switch me.type
						case 'server'
							loop = 1;
							while loop <= 10
								me.rconn = pnet('tcpsocket',me.lPort);
								pnet(me.rconn ,'setwritetimeout', me.writeTimeOut);
								pnet(me.rconn ,'setreadtimeout', me.readTimeOut);
								if me.rconn < 0
									fprintf('---> %s cannot create TCP server (status: %d)',mfilename,me.rconn);
									pause(0.1);
									if loop == 2 %see if we have rogue connetions
										for i = 1:length(me.rconnList)
											try pnet(me.rconnList(i),'close'); end %#ok<*TRYNC> 
										end
									elseif loop == 3
										for i = 0:8
											try	pnet(i,'close'); end
										end
									end
								else
									me.isOpen = true;
									me.rconnList = unique([me.rconnList me.rconn]);
									me.checkStatus('rconn')
									loop = 100;break;
								end
								loop = loop + 1;
							end
							conn = me.rconn;	
						case 'client'
							loop = 1;
							while loop <= 10
								me.conn=pnet('tcpconnect',me.rAddress,me.rPort);
								if me.conn == -1
									fprintf('---> CAN NOT CONNECT TO HOST: %s PORT: %d\nRETRY....',me.rAddress,me.rPort);
									pause(0.5);
								else
									break
								end
								loop = loop + 1;
							end
							
							if me.conn >= 0
								% disable blocking
								pnet(me.conn ,'setwritetimeout', me.writeTimeOut);
								pnet(me.conn ,'setreadtimeout', me.readTimeOut);
								me.status = pnet(me.conn,'status');
								if me.status < 1
									me.close('conn')
									warning('---> %s cannot connect to remote TCP host (status: %d)',mfilename,me.status);
								else
									fprintf('---> CONNECTED TO HOST: %s PORT: %d !\n',me.rAddress,me.rPort);
									me.isOpen = true;
									me.connList = unique([me.connList me.conn]);
								end
							else
								fprintf('---> %s cannot open TCP socket (%d)', ...
									mfilename, me.conn);
								me.isOpen = false;
								me.conn = -1;
							end
							conn = me.conn;
					end
			end
		end
		
		% ===================================================================
		%> @brief Close the connection
		%>
		%> Close the ethernet connection
		% ===================================================================
		function status = close(me, type, force)
			if ~exist('type','var')
				if matches(me.type,'server') 
					type = 'rconn';
				else
					type = 'conn';
				end
			end
			if ~exist('force','var'); force = true; end
			if ischar(force); force = true; end
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
				me.salutation('close Method',['Trying to close ' type ' connection...'])
				if force == true
					for i = 1:length(me.(list))
						try
							pnet(me.(list)(i), 'close');
							fprintf('Closed connection %i.\n',me.(list)(i));
						catch %#ok<CTCH>
							status = -1;
							fprintf('Couldn''t close connection %i, perhaps closed?\n',me.(list)(i));
						end
					end
				else
					me.status = pnet(me.(name),'status');
					if me.status <=0
						me.salutation('close Method','Connection appears closed...');
					else
						try %#ok<TRYNC>
							pnet(me.(name), 'close');
						end
					end
					me.(name) = -1; me.(list) = [];
				end
				me.isOpen = false;
			end
		end
		
		% ===================================================================
		%> @brief Close all connections
		%>
		%> Close all connections
		% ===================================================================
		function status = closeAll(me)
			me.status = 0;
			me.conn = -1; me.rconn = -1;
			me.connList = []; me.rconnList = []; 
			try
				pnet('closeall');
				me.salutation('closeAll Method','Closed all PNet connections')
			catch
				me.salutation('closeAll Method','Failed to close all PNet connections')
				me.status = -1;
			end
			me.isOpen = false;
			status = me.status;
		end

		% ===================================================================
		%> @brief Check if there is data non-destructively
		%>
		%> Check if there is data non-destructively, i.e. attempt to read
		%> from the given pnet socket without consuming available data
		%>
		%> @return hasData (logical)
		% ===================================================================
		function hasData = checkData(me)
			me.hasData = false;
			if matches(me.type,'server') && me.rconn > -1
				conn = me.rconn; 
			elseif me.conn > -1
				conn = me.conn;
			else
				return;
			end
			switch me.protocol
				case 'udp'%============================UDP
					data = pnet(conn, 'read', 65536, me.dataType, 'view');
					if isempty(data)
						me.hasData = pnet(conn, 'readpacket') > 0;
					else
						me.hasData = true;
					end
				case 'tcp'%============================TCP
					data = pnet(conn, 'read', me.readSize, me.dataType, 'noblock', 'view');
					if ~isempty(data)
						me.hasData = true;
					end
					
			end
			hasData = me.hasData;
		end

		% ===================================================================
		%> @brief Close all connections
		%>
		%> Close all connections
		% ===================================================================
		function flush(me)
			while me.checkData
				pnet(me.conn,'read', 256000);
			end
		end
		
		% ===================================================================
		%> @brief Read a single line of data
		%>
		%> Read a single line of data from the connection
		%> @return data read from connection
		% ===================================================================
		% Read any avalable data from the given pnet socket.
		function data = readline(me)
			data = [];
			if matches(me.type,'server') && me.rconn > -1
				conn = me.rconn; 
			elseif me.conn > -1
				conn = me.conn;
			else
				return;
			end
			switch me.protocol
				case 'udp'%============================UDP
					nBytes = pnet(conn, 'readpacket');
					if nBytes > 0
						data = pnet(conn, 'readline', nBytes, 'noblock');
					end
				case 'tcp'%============================TCP
					data = pnet(conn, 'readline', me.readSize,' noblock');
			end
			me.dataIn = data;
		end

		% ===================================================================
		%> @brief read last N lines
		%>
		%> Flush the server messagelist
		% ===================================================================
		function data = readLines(me, N, order)
			if ~exist('N','var') || isempty(N); N = 1; end
			if ~exist('order','var') || ~matches(order,{'first','last'}); order = 'last'; end
			data = [];
			if matches(me.type,'server') && me.rconn > -1; conn = me.rconn; elseif me.conn > -1; conn = me.conn; else; return; end
			while 1
				thisData = pnet(conn, 'read', 512000, 'noblock');
				if isempty(thisData); break; end
				data = [data thisData];
			end
			if isempty(data); return; end
			r = regexp(data,'\n');
			if length(r) <= N; return; end
			if matches(order,'first')
				data = data(1:r(N));
			else
				data = data(r(end-N):end);
			end
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
		function data = read(me, all, dataType, size)
			
			if ~exist('all','var')
				all = 0;
			end
			if ischar(all) && ~isempty(all) %convert from string if string not empty
				all = 1;
			end
			if ~exist('dataType','var') || isempty(dataType)
				dataType=me.dataType;
			end
			
			data = [];
			loop = 1;
			olddataType=me.dataType;
			
			switch me.protocol
				%============================UDP
				case 'udp'
					if ~exist('size','var');size=65536;end
					while loop > 0
						dataIn = pnet(me.conn, 'read', size, dataType);
						if isempty(dataIn)
							nBytes = pnet(me.conn, 'readpacket');
							if nBytes > 0
								dataIn = pnet(me.conn, 'read', nBytes, dataType);
							end
							if ischar(dataIn) && ~isempty(regexpi(dataIn,'--matfile--'))
								dataType = 'uint32';
								tmpfile=[tempname,'.mat'];
								VAR=[];
								try
									nBytes = pnet(me.conn, 'readpacket');
									bytes=double(pnet(me.conn,'Read',[1 1],'uint32'));
									nBytes = pnet(me.conn, 'readpacket');
									pnet(me.conn,'ReadToFile',tmpfile,bytes);
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
							if me.checkData
								loop = loop + 1;
							else
								loop = 0;
							end
						end
					end
					if iscell(data) && length(data) == 1
						data = data{1};
					end
					me.dataIn = data;
					%============================TCP
				case 'tcp'
					if ~exist('size','var');size=me.readSize;end
					while loop > 0
						dataIn=pnet(me.conn,'read', size, dataType,'noblock');
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
					me.dataIn = data;
			end
		end
		
		% ===================================================================
		%> @brief Write data to the given pnet socket.
		%>
		%> @param data to write to connection
		%> @param formatted (0[default]|1) whether to send data raw (0) or as a formatted string (1)
		%> @param sendPacket (0|1[default]) for UDP connections actually send the packet or wait to fill buffer with another call first
		% ===================================================================
		function write(me, data, formatted, sendPacket)
			if ~me.isOpen; return; end
			if ~exist('data','var') || isempty(data)
				data = me.dataOut;
			end
			if ~exist('formatted','var') || isempty(formatted)
				formatted = false;
			end
			if ~exist('sendPacket','var') || isempty(sendPacket)
				sendPacket = true;
			end
			
			if matches(me.type,'server') && me.rconn > -1
				conn = me.rconn; 
			elseif me.conn > -1
				conn = me.conn;
			else
				return;
			end

			switch me.protocol
				case 'udp'%============================UDP
					if formatted == false
						pnet(conn, 'write', data);
					else
						pnet(conn, 'printf', data);
					end
					if sendPacket;pnet(me.conn, 'writepacket', me.rAddress, me.rPort);end
				case 'tcp'%============================TCP
					if formatted == false
						pnet(conn, 'write', data);
					else
						pnet(conn, 'printf', data);
					end
			end
		end
		
		% ===================================================================
		%> @brief Read any available variable from the given pnet socket.
		%>
		%> Read any avalable variable from the given pnet socket.
		% ===================================================================
		function data = readVar(me)
			if matches(me.type,'server') && me.rconn > -1
				conn = me.rconn; 
			elseif me.conn > -1
				conn = me.conn;
			else
				return;
			end
			pnet(conn ,'setreadtimeout', 5);
			data = me.getVar;
			pnet(conn ,'setreadtimeout', me.readTimeOut);
		end
		
		% ===================================================================
		%> @brief
		%>
		%>
		% ===================================================================
		% Write data to the given pnet socket.
		function writeVar(me, varargin)
			if matches(me.type,'server') && me.rconn > -1
				conn = me.rconn; 
			elseif me.conn > -1
				conn = me.conn;
			else
				return;
			end
			pnet(conn ,'setwritetimeout', 5);
			me.putVar(varargin);
			pnet(conn ,'setwritetimeout', me.writeTimeOut);
		end
		
		% ===================================================================
		%> @brief Check client
		%>
		%> Check status
		% ===================================================================
		function isClient = checkClient(me)
			isClient = false;
			if strcmpi(me.type,'server')
				try
					me.conn=pnet(me.rconn,'tcplisten');
					if me.conn > -1
						[rhost,rport]=pnet(me.conn,'gethost');
						fprintf('START SERVING NEW CONNECTION FROM IP %d.%d.%d.%d port:%d',rhost,rport)
						pnet(me.conn ,'setwritetimeout', me.writeTimeOut);
						pnet(me.conn ,'setreadtimeout', me.readTimeOut);
						me.rPort = rport;
						me.rAddress = rhost;
						me.isOpen = 2;
						isClient = true;
					else
						me.conn = -1;
						me.isOpen = false;
						me.salutation('No client available')
					end
				catch
					me.conn = -1;
					me.isOpen = false;
					me.salutation('Couldn''t find client connection');
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
		function status = checkStatus(me, conn) %#ok<INUSD>
			status = -1;
			try
				if ~exist('conn','var') && matches(me.type,'client') || strcmp(conn,'conn')
					conn='conn';
				else
					conn = 'rconn';
				end
				me.status = pnet(me.(conn),'status');
				if me.status <=0;me.(conn) = -1; me.isOpen = false;me.salutation('checkStatus Method','Connection appears closed...');end
				switch me.status
					case -1
						me.statusMessage = 'STATUS_NOTFOUND';
					case 0
						me.statusMessage = 'STATUS_NOCONNECT';
					case 1
						me.statusMessage = 'STATUS_TCP_SOCKET';
					case 5
						me.statusMessage = 'STATUS_IO_OK';
					case 6
						me.statusMessage = 'STATUS_UDP_CLIENT';
					case 8
						me.statusMessage = 'UDP_SERVER';
					case 10
						me.statusMessage = 'STATUS_CONNECT';
					case 11
						me.statusMessage = 'STATUS_TCP_CLIENT';
					case 12
						me.statusMessage = 'STATUS_TCP_SERVER';
					case 18
						me.statusMessage = 'STATUS_UDP_CLIENT_CONNECT';
					case 19
						me.statusMessage = 'STATUS_UDP_SERVER_CONNECT';
					otherwise
						me.statusMessage = 'UNDEFINED';
				end
				me.salutation(me.statusMessage,'checkStatus')
				status = me.status;
			catch %#ok<CTCH>
				me.status = -1;
				me.statusMessage = 'UNKNOWN';
				status = me.status;
				me.(conn) = -1;
				me.isOpen = false;
				fprintf('Couldn''t check status\n')
			end
		end
		
		% ===================================================================
		%> @brief Initialize the server loop
		%>
		%> Initialize the server loop
		% ===================================================================
		function startServer(me)
			me.conn = pnet('tcpsocket',me.lPort);
			pnet(me.conn ,'setwritetimeout', me.writeTimeOut);
			pnet(me.conn ,'setreadtimeout', me.readTimeOut);
			ls = 1;
			msgloop=1;
			while ls			
				if msgloop == 1;fprintf('\nWAIT FOR CONNECTION ON PORT: %d\n',me.lPort);end
				msgloop=2;
				try
					me.rconn = pnet(me.conn,'tcplisten');
					pause(0.01);
				catch ME
					disp 'Try:  "pnet closeall"  in all matlab sessions on this server.';
					disp ' ';
					ls = 0;
					rethrow(ME);
				end
				
				if me.rconn >= 0
					msgloop=1;
					try
						[me.rAddress,me.rPort]=pnet(me.rconn,'gethost');
						fprintf('START SERVING NEW CONNECTION FROM IP %d.%d.%d.%d port:%d\n\n',me.rAddress,me.rPort);
						me.serverLoop;
					catch %#ok<*CTCH>
						disp 'Server loop initialisation failed';
					end
				end
				
				if me.checkForEscape == 1
					pnet(me.rconn,'close')
					pnet(me.conn,'close')
					me.conn = -1;
					me.rconn = -1;
					break;
				end
			end
			
			me.close;
			
		end
		
		% ===================================================================
		%> @brief Send command to a remote dataConnection server
		%>
		%> Send command to remote dataConnection server. Commands can be
		%> 'echo', 'put', 'get' and 'eval'
		%>
		%> @param varargin can be
		% ===================================================================
		function varargout = sendCommand(me,varargin)
			if me.conn < 0
				me.open;
			end
			switch varargin{1}
				case 'ping'
					pnet(me.conn,'printf','\n--remote--\n');
					me.flushStatus; % Flush status buffer. Keep last status in readbuffer
					ping.time = GetSecs;
					me.putVar(me.conn,'ping',ping);
				case 'echo'
					pnet(me.conn,'printf','\n--remote--\n');
					me.flushStatus; % Flush status buffer. Keep last status in readbuffer
					me.putVar(me.conn,'echo','Hello!');
				case 'put'
					pnet(me.conn,'printf','\n--remote--\n');
					me.flushStatus; % Flush status buffer. Keep last status in readbuffer
					me.putVar(me.conn,varargin);
					return
				case 'eval'
					me.waitNotBusy; %pnet_remote(me.conn,'WAITNOTBUSY');
					pnet(me.conn,'printf','\n--remote--\n');
					me.putVar(me.conn,varargin);
					return
				case 'get'
					pnet(me.conn,'printf','\n--remote--\n');
					me.flushStatus; % Flush status buffer. Keep last status in readbuffer
					me.putVar(me.conn,varargin);
					varargout=me.getVar;
				case 'close'
					pnet(me.conn,'printf','\n--remote--\n');
					me.flushStatus; % Flush status buffer. Keep last status in readbuffer
					me.putVar(me.conn,'close');
					close(me);
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
		function waitNotBusy(me)
			while strcmp(me.flushStatus,'busy')
				pause(0.01);
			end
			return
		end
		% ===================================================================
		%> @brief checkForEscape
		%>
		%> Check if the user has hit escape
		% ===================================================================
		function out = checkForEscape(me)
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
		function serverLoop(me)
			while pnet(me.rconn,'status')
				ls = true;
				while ls
					okflag = true;
					str = ''; 
					fprintf('Waiting for %s command...',me.remoteCmd);
					while ~strcmpi(str,me.remoteCmd) && pnet(me.rconn,'status')
						pause(0.01);
						str=pnet(me.rconn,'readline',me.readSize,'noblock');
						if checkForEscape(me)
							pnet(me.rconn,'close');
							return;
						end
					end
					if pnet(me.rconn,'status')==0;break;end
					C=getVar(me);
					pnet(me.rconn,'printf',['\n' me.busyCmd '\n']);
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
								DEFAULT_CON__=me.rconn;
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
								pnet_putvar(me.rconn,R);
							case 'close'
								pnet(me.rconn,'close');
								return;
						end %END SWITCH
					else
						disp('Remote Message appeared Empty...');
					end
					
					if okflag
						pnet(me.rconn,'printf','\n--ready--\n');
					else
						pnet(me.rconn,'printf','\n--error--\n');
						fprintf('\nERROR: %s\n\n', lasterr);
					end
					
				end %END WHILE ls
				
			end %END while pnet(me.rconn,'status')
			
		end
		
		
		% ===================================================================
		%> @brief Flush the server messagelist
		%>
		%> Flush the server messagelist
		% ===================================================================
		function stat = flushStatus(me, num)
			if ~exist('number','var'); num = 1; end
			while 1 % Loop that finds, returns and leaves last text line in buffer.
				str=pnet(me.conn,'read', me.readSize,'view','noblock');
				if length(regexp([str,' '],'\n'))<=num
					stat=pnet(me.conn,'readline',me.readSize,'view','noblock'); % The return
					stat=stat(3:end-2);
					return;
				end
				dump=pnet(me.conn,'readline',me.readSize,'noblock'); % Then remove last line
			end
		end
		
		% ===================================================================
		%> @brief putVar
		%>
		%>
		% ===================================================================
		function putVar(me,varargin)
			if ~isempty(varargin)
				if length(varargin)==2 && varargin{1}==0;varargin = varargin{2:end};end
				while iscell(varargin) && length(varargin) == 1
					varargin = varargin{1};
				end
				VAR=varargin;
				switch me.protocol
					case 'udp'
						switch class(VAR)
							case {'double' 'char' 'int8' 'int16' 'int32' 'uint8' 'uint16' 'uint32'}
								pnet(me.conn,'printf','%s',class(VAR));
								me.status = pnet(me.conn, 'writepacket', me.rAddress, me.rPort);
								
								pnet(me.conn,'Write',uint32(ndims(VAR)));
								me.status = pnet(me.conn, 'writepacket', me.rAddress, me.rPort);
								
								pnet(me.conn,'Write',uint32(size(VAR)));
								me.status = pnet(me.conn, 'writepacket', me.rAddress, me.rPort);
								
								pnet(me.conn,'Write',VAR);
								me.status = pnet(me.conn, 'writepacket', me.rAddress, me.rPort);
							otherwise
								try
									bytes = uint32(getByteStreamFromArray(VAR));
									dataLength = uint32(size(bytes)); %#ok<*PROP>
									
									pnet(me.conn,'printf','--bytestream--');
									me.status = pnet(me.conn, 'writepacket', me.rAddress, me.rPort);
									
									pnet(me.conn,'Write',uint32(ndims(bytes)));
									me.status = pnet(me.conn, 'writepacket', me.rAddress, me.rPort);
									
									pnet(me.conn,'Write',dataLength);
									me.status = pnet(me.conn, 'writepacket', me.rAddress, me.rPort);

									pnet(me.conn,'Write',bytes);
									me.status = pnet(me.conn, 'writepacket', me.rAddress, me.rPort);
								end
						end
					case 'tcp'
						switch class(VAR)
							case {'double' 'char' 'int8' 'int16' 'int32' 'uint8' 'uint16' 'uint32'}
								pnet(me.conn,'printf','\n%s\n',class(VAR));
								pnet(me.conn,'Write',uint32(ndims(VAR)));
								pnet(me.conn,'Write',uint32(size(VAR)));
								pnet(me.conn,'Write',VAR);
							otherwise
								try
									bytes = uint32(getByteStreamFromArray(VAR));
									dataLength = uint32(size(bytes));
									pnet(me.conn,'printf','\n--bytestream--\n');
									pnet(me.conn,'Write',uint32(ndims(dataLength)));
									pnet(me.conn,'Write',dataLength);
									pnet(me.conn,'Write',bytes);
									pnet(me.conn,'printf','\n--end--\n');
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
		function varargout = getVar(me)
			VAR='';
			dataclass='';
			switch me.protocol
				case 'udp'
					while me.checkData
						dataclass = pnet(me.conn, 'read', 65536, me.dataType);
						if isempty(dataclass)
							nBytes = pnet(me.conn, 'readpacket');
							if nBytes > 0
								dataclass = pnet(me.conn, 'read', nBytes, me.dataType);
							end
						end
						switch dataclass
							case {'double' 'char' 'int8' 'int16' 'int32' 'uint8' 'uint16' 'uint32'}
								nBytes = pnet(me.conn, 'readpacket');
								datadims=double(pnet(me.conn,'Read',1,'uint32'));
								
								nBytes = pnet(me.conn, 'readpacket');
								datasize=double(pnet(me.conn,'Read',datadims,'uint32'));
								
								nBytes = pnet(me.conn, 'readpacket');
								VAR=pnet(me.conn,'Read',datasize,dataclass);
							case '--matfile--'
								
							case '--bytestream--'
								%tmpfile=[tempname,'.mat'];
								VAR=[];
								try
									nBytes = pnet(me.conn, 'readpacket');
									datadims=double(pnet(me.conn,'Read',1,'uint32'));
									
									nBytes = pnet(me.conn, 'readpacket');
									datasize=double(pnet(me.conn,'Read',datadims,'uint32'));
									
									nBytes = pnet(me.conn, 'readpacket');
									bytes=pnet(me.conn,'Read',datasize,'uint32');
									VAR=getArrayFromByteStream(uint8(bytes));
									fprintf('Reported size: %ix%i | Returned Size: %ix%i\n',...
										datasize(1),datasize(2),size(bytes,1),size(bytes,2));
									%nBytes = pnet(me.conn, 'readpacket');
									%pnet(me.conn,'ReadToFile',tmpfile,bytes);
									%load(tmpfile);
									break;
								end
								%try delete(tmpfile); end
						end
					end
				case 'tcp'
					if me.rconn >= 0
						thisConnection = me.rconn;
					else
						thisConnection = me.conn;
					end
					lp = 25;
					while lp > 0 
						lp = lp - 1;
						dataclass=pnet(thisConnection,'readline',me.readSize);
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
		function delete(me)
			if me.cleanup == true
				me.salutation('dataConnection delete Method','Cleaning up now...');
				me.close;
			else
				me.salutation('dataConnection delete Method','Closing (no cleanup)...');
			end
		end
		
		% ===================================================================
		%> @brief Prints messages dependent on verbosity
		%>
		%> Prints messages dependent on verbosity
		%> @param in the calling function
		%> @param message the message that needs printing to command window
		% ===================================================================
		function salutation(me,in,message)
			if me.verbosity > 0
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
		function parseArgs(me,varargin)
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
					if matches(fnames{i},me.allowedProperties) %only set if allowed property
						me.salutation(fnames{i},'Configuring setting in constructor');
						me.(fnames{i})=varargin.(fnames{i}); %we set up the properies from the arguments as a structure
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