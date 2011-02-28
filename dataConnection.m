% ========================================================================
%> @brief dataConnection Connects and manages a socket connection
%>
%> Connects and manages TCP/UDP Communication
%>
% ========================================================================
classdef dataConnection < handle
	%dataConnection Allows send/recieve over Ethernet
	%   This uses the TCP/UDP library to manage connections between servers
	%   and clients in Matlab
	
	properties
		type = 'client'
		protocol = 'tcp'
		lPort = 1111
		rPort = 5678
		lAddress = '127.0.0.1'
		rAddress = '127.0.0.1'
		autoOpen = 0
		dataOut = []
		dataType = 'string'
		verbosity = 1
		autoRead = 1
		autoServer = 0
	end
	
	properties (SetAccess = private, GetAccess = public)
		hasData = 0
		isOpen = 0
		dataIn = []
		status
		statusMessage
		dataLength
		error
	end
	
	properties (SetAccess = private, GetAccess = public)
		conn = -1
		rconn = -1
		allowedProperties='^(type|protocol|lPort|rPort|lAddress|rAddress|autoOpen|dataType|verbosity|autoRead|autoServer)$'
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
		function obj = dataConnection(args)
			if nargin>0 && isstruct(args)
				fnames = fieldnames(args); %find our argument names
				for i=1:length(fnames);
					if regexp(fnames{i},obj.allowedProperties) %only set if allowed property
						obj.salutation(fnames{i},'Configuring setting in constructor');
						obj.(fnames{i})=args.(fnames{i}); %we set up the properies from the arguments as a structure
					end
				end
			end
			if obj.autoServer == 1
				obj.type='server';
				obj.protocol='tcp';
				obj.startServer;
			elseif obj.autoOpen == 1
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
						pnet(obj.conn ,'setwritetimeout', 0);
						pnet(obj.conn ,'setreadtimeout', 0);
						obj.isOpen = 1;
					else
						sprintf('%s cannot open UDP socket (%d)', ...
							mfilename, obj.conn);
						obj.isOpen = 0;
						obj.conn = -1;
					end
					conn = obj.conn;
					
				case 'tcp'
					if strcmpi(obj.type, 'server')
						obj.rconn = pnet('tcpsocket',obj.lPort);
						pnet(obj.rconn ,'setwritetimeout', 0);
						pnet(obj.rconn ,'setreadtimeout', 0);
						obj.checkStatus('rconn')
						if obj.status < 1
							obj.close('rconn')
							warning('%s cannot create remote TCP host (%d)',mfilename,obj.status);
							return
						else
							obj.isOpen = 1;
						end
						conn = obj.rconn;
					else
						while obj.conn == -1
							obj.conn=pnet('tcpconnect',obj.rAddress,obj.rPort);
							if obj.conn==-1,
								fprintf('CAN NOT CONNECT TO HOST: %s PORT: %d\nRETRY....',obj.rAddress,obj.rPort);
								pause(1);
							else
								fprintf('CONNECTED TO HOST: %s PORT: %d !\n',obj.rAddress,obj.rPort);
							end
						end
						if obj.conn >= 0
							% disable blocking
							pnet(obj.conn ,'setwritetimeout', 0);
							pnet(obj.conn ,'setreadtimeout', 0);
							obj.status = pnet(obj.conn,'status');
							if obj.status < 1
								obj.close
								warning('%s cannot connect to remote TCP host (%d)',mfilename,obj.status);
								return
							end
							obj.isOpen = 1;
						else
							sprintf('%s cannot open TCP socket (%d)', ...
								mfilename, obj.conn);
							obj.isOpen = 0;
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
		% Close the given pnet socket.
		function status = close(obj,type)
			if ~exist('type','var')
				type = 'conn';
			end
			
			obj.status = 0;
			switch type
				case 'conn'
					try
						obj.salutation('close Method','Trying to close PNet connection...')
						obj.status = pnet(obj.conn,'status');
						if obj.status <=0;
							obj.isOpen = 0;obj.salutation('close Method','Connection appears closed...');
						else
							try
								pnet(obj.conn, 'close');
							catch ME
								warn('Couldn''t close connection, perhaps closed?');
								obj.status = -1;
								obj.error = ME;
							end
						end
						obj.conn = -1;
						status = 1;
					end
				otherwise
					try
						obj.salutation('close Method','Trying to close PNet connection...')
						obj.status = pnet(obj.conn,'status');
						if obj.status <=0;
							obj.isOpen = 0;obj.salutation('close Method','Connection appears closed...');
						else
							try
								pnet(obj.conn, 'close');
							catch ME
								warn('Couldn''t close connection, perhaps closed?');
								obj.status = -1;
								obj.error = ME;
							end
						end
						obj.conn = -1;
						obj.status = pnet(obj.rconn,'status');
						if obj.status <=0;
							obj.isOpen = 0;obj.salutation('close Method','Connection appears closed...');
						else
							try
								pnet(obj.rconn, 'close');
							catch ME
								warn('Couldn''t close connection, perhaps closed?');
								obj.status = -1;
								obj.error = ME;
							end
						end
						obj.rconn = -1;
						status = 1;
					end
			end
		end
		
		% ===================================================================
		%> @brief Close all connections
		%>
		%> Close all connections
		% ===================================================================
		% Close all pnet sockets.
		function status = closeAll(obj)
			obj.status = 0;
			obj.conn = -1;
			obj.rconn = -1;
			try
				pnet('closeall');
				obj.salutation('closeAll Method','Trying to close all PNet connections')
				
			catch
				obj.salutation('closeAll Method','Failed to close all PNet connections')
				obj.status = -1;
			end
			obj.status = pnet(obj.conn,'status');
			if obj.status <=0;obj.isOpen = 0;obj.salutation('closeAll Method','Connection appears closed...');end
			status = obj.status;
		end
		
		% ===================================================================
		%> @brief Check if there is data non-destructively
		%>
		%> Check if there is data non-destructively
		% ===================================================================
		% Attempt to read from the given pnet socket without consuming
		% available data.
		function hasData = checkData(obj)
			obj.hasData = 0;
			switch obj.protocol
				
				case 'udp'
					data = pnet(obj.conn, 'read', 65536, obj.dataType, 'view');
					if isempty(data)
						obj.hasData = pnet(obj.conn, 'readpacket') > 0;
					else
						obj.hasData = 1;
					end
					
				case 'tcp'
					data = pnet(obj.conn, 'read', 65536, obj.dataType, 'noblock', 'view');
					if ~isempty(data)
						obj.hasData = 1;
					end
					
			end
			hasData = obj.hasData;
		end
		
		% ===================================================================
		%> @brief Read any avalable data from the given pnet socket.
		%>
		%> Read any avalable data from the given pnet socket.
		% ===================================================================
		% Read any avalable data from the given pnet socket.
		function data = read(obj,all,dataType)
			
			if ~exist('all','var')
				all = 1;
			end
			if ~exist('dataType','var')
				dataType=obj.dataType;
			end
			data = [];
			loop = 1;
			olddataType=obj.dataType;
			
			switch obj.protocol
				
				%============================UDP
				case 'udp'
					while loop > 0
						dataIn = pnet(obj.conn, 'read', 65536, dataType);
						if isempty(dataIn)
							nBytes = pnet(obj.conn, 'readpacket');
							if nBytes > 0
								dataIn = pnet(obj.conn, 'read', nBytes, dataType);
							end
							if regexpi(dataIn,'--matfile--')
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
					all = 1;
					while loop > 0
						dataIn=pnet(obj.conn,'read', 65536, obj.dataType,'noblock');
						if all == 0
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
		%> @brief
		%>
		%>
		% ===================================================================
		% Write data to the given pnet socket.
		function status = write(obj, data)
			switch obj.protocol
				
				%============================UDP
				case 'udp'
					if ~exist('data','var')
						data = obj.dataOut;
					end
					pnet(obj.conn, 'write', data);
					obj.status = pnet(obj.conn, 'writepacket', obj.rAddress, obj.rPort);
					
					%============================TCP
				case 'tcp'
					if ~exist('data','var')
						data = obj.dataOut;
					end
					pnet(obj.conn, 'write', data)
			end
		end
		
		% ===================================================================
		%> @brief Read any avalable data from the given pnet socket.
		%>
		%> Read any avalable data from the given pnet socket.
		% ===================================================================
		% Read any avalable data from the given pnet socket.
		function data = readVar(obj)
			tic
			data = obj.getVar;
			toc
		end
		
		% ===================================================================
		%> @brief
		%>
		%>
		% ===================================================================
		% Write data to the given pnet socket.
		function writeVar(obj, varargin)
			tic
			obj.putVar(varargin);
			toc
		end
		
		% ===================================================================
		%> @brief Check client
		%>
		%> Check status
		% ===================================================================
		function isClient = checkClient(obj)
			isClient = 0;
			if strcmpi(obj.type,'server') 
				try
					obj.conn=pnet(obj.rconn,'tcplisten');
					if obj.conn > -1
						[rhost,rport]=pnet(obj.conn,'gethost');
						fprintf('START SERVING NEW CONNECTION FROM IP %d.%d.%d.%d port:%d',rhost,rport)
						pnet(obj.conn ,'setwritetimeout', 0);
						pnet(obj.conn ,'setreadtimeout', 0);
						obj.rPort = rport;
						obj.rAddress = rhost;
						obj.isOpen = 2;
						isClient = 1;
					else
						obj.conn = -1;
						obj.isOpen = 1;
						%obj.salutation('No client available')
					end
					
				catch
					obj.salutation('Couldn''t find client connection');
				end
			end
			
		end
		
		% ===================================================================
		%> @brief Check status
		%>
		%> Check status
		% ===================================================================
		% 		#define STATUS_NOCONNECT   0    // Disconnected pipe that is note closed
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
			try
				if ~exist('conn','var') || obj.conn ~= -1
					conn='conn';
				else
					conn = 'rconn';
				end
				obj.status = pnet(obj.(conn),'status');
				if obj.status <=0;obj.isOpen = 0;obj.salutation('status Method','Connection appears closed...');end
				switch obj.status
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
				end
				obj.salutation(obj.statusMessage,'CheckStatus')
				status = obj.status;
			catch
				fprintf('Couldn''t check status')
			end
		end
		
		% ===================================================================
		%> @brief Initialize the server loop
		%>
		%> Initialize the server loop
		% ===================================================================
		function startServer(obj)
			obj.conn = pnet('tcpsocket',obj.lPort);
			pnet(obj.conn ,'setwritetimeout', 0.5);
			pnet(obj.conn ,'setreadtimeout', 0.5);
			ls = 1;
			msgloop=1;
			while ls
				
				if msgloop == 1;fprintf('WAIT FOR CONNECTION ON PORT: %d\n',obj.lPort);end
				msgloop=2;
				try
					obj.rconn = pnet(obj.conn,'tcplisten');
					pause(1);
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
					catch
						disp 'Server loop initialisation failed';
					end
				end
				
				if obj.checkForEscape == 1
					pnet(obj.rconn,'close')
					pnet(obj.conn,'close')
					obj.conn = -1;
					obj.rconn = -1;
					break
				end
				
			end
			
			obj.close;
			
		end
		
		% ===================================================================
		%> @brief Send command to remote server
		%>
		%> Send command to remote server
		% ===================================================================
		function varargout = sendCommand(obj,varargin)
			if obj.conn < 0
				obj.open;
			end
			switch varargin{1}
				case 'echo'
					
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
			while strcmp(obj.flushStatus,'busy'),
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
			out=0;
			[~,~,key]=KbCheck;
			key=KbName(key);
			if strcmpi(key,'escape') %allow keyboard break
				out=1;
			end
		end
		
		% ===================================================================
		%> @brief Run the server loop
		%>
		%> Run the server loop
		% ===================================================================
		function serverLoop(obj)
			while pnet(obj.rconn,'status')
				ls = 1;
				while ls
					okflag=1;
					str = '';
					drawnow;
					while strcmp(str,obj.remoteCmd)==0 && pnet(obj.rconn,'status'),
						str=pnet(obj.rconn,'readline',1024,[],'noblock');
						pause(0.1);
					end
					if pnet(obj.rconn,'status')==0;break;end
					C=pnet_getvar(obj.rconn);
					pnet(obj.rconn,'printf',['\n' obj.busyCmd '\n']);
					drawnow;
					
					switch lower(C{1})
						case 'eval'
							global DEFAULT_CON__;
							DEFAULT_CON__=obj.rconn;
							try
								fprintf('\n');
								disp(['REMOTE EVAL>> ' C{2:min(2:end)}]);
								evalin('caller',C{2:end},'okflag=0;');
							catch
								okflag=0;
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
									okflag=0;
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
									okflag=0;
								end
							end
							pnet_putvar(obj.rconn,R);
						case 'close'
							pnet(obj.rconn,'close');
							return;
					end %END SWITCH
					
					if okflag,
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
				if length(regexp([str,' '],'\n'))<=1,
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
				while 1
					if length(varargin) == 1
						varargin = varargin{1};
					else
						break
					end
				end
				switch obj.protocol
					case 'udp'
						VAR=varargin{2};
						switch class(VAR),
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
								tmpfile=[tempname,'.mat'];
								try
									save(tmpfile,'VAR');
									filedata=dir(tmpfile);
									%obj.dataLength = filedata.bytes;
									pnet(obj.conn,'printf','--matfile--');
									obj.status = pnet(obj.conn, 'writepacket', obj.rAddress, obj.rPort);
									pnet(obj.conn,'Write',uint32(filedata.bytes));
									obj.status = pnet(obj.conn, 'writepacket', obj.rAddress, obj.rPort);
									pnet(obj.conn,'WriteFromFile',tmpfile);
									obj.status = pnet(obj.conn, 'writepacket', obj.rAddress, obj.rPort);
								end
								try
									delete(tmpfile);
								end
						end
					case 'tcp'
						VAR=varargin{2};
						switch class(VAR),
							case {'double' 'char' 'int8' 'int16' 'int32' 'uint8' 'uint16' 'uint32'}
								pnet(obj.conn,'printf','\n%s\n',class(VAR));
								pnet(obj.conn,'Write',uint32(ndims(VAR)));
								pnet(obj.conn,'Write',uint32(size(VAR)));
								pnet(obj.conn,'Write',VAR);
							otherwise
								tmpfile=[tempname,'.mat'];
								try
									save(tmpfile,'VAR');
									filedata=dir(tmpfile);
									%obj.dataLength = filedata.bytes;
									pnet(obj.conn,'printf','\n--matfile--\n');
									pnet(obj.conn,'Write',uint32(filedata.bytes));
									pnet(obj.conn,'WriteFromFile',tmpfile);
								end
								try
									delete(tmpfile);
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
								return
							case '--matfile--'
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
						end
					end
					varargout{1}=VAR;
				case 'tcp'
					while 1
						dataclass=pnet(obj.conn,'readline',1024);
						switch dataclass,
							case {'double' 'char' 'int8' 'int16' 'int32' 'uint8' 'uint16' 'uint32'}
								datadims=double(pnet(obj.conn,'Read',1,'uint32'));
								datasize=double(pnet(obj.conn,'Read',datadims,'uint32'));
								VAR=pnet(obj.conn,'Read',datasize,dataclass);
								break;
							case '--matfile--'
								tmpfile=[tempname,'.mat'];
								VAR=[];
								try
									bytes=double(pnet(obj.conn,'Read',[1 1],'uint32'));
									pnet(obj.conn,'ReadToFile',tmpfile,bytes);
									load(tmpfile);
								end
								try
									delete(tmpfile);
								end
								break
						end
					end
					varargout{1}=VAR;
					return;
					
			end
			
		end
		
		
		% ===================================================================
		%> @brief Destructor
		%>
		%>
		% ===================================================================
		function delete(obj)
			obj.salutation('DELETE Method','Cleaning up now...')
			obj.close;
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
					fprintf([message ' | ' in '\n']);
				end
			end
		end
	end
end

