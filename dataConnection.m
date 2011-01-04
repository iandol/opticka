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
		protocol = 'udp'
		lPort = 1111
		rPort = 3333
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
		error
	end
	
	properties (SetAccess = private, GetAccess = public)
		conn = -1
		rconn = -1
		allowedProperties='^(type|protocol|lPort|rPort|lAddress|rAddress|autoOpen|dataType|verbosity|autoRead|autoServer)$'
		remoteCmd = '--remote--'
		breakCmd = '--break--'
		busyCmd = '--busy--'
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
			pnet('closeall'); %makes sure nothing else interfering and loads mex file in memory
			if obj.autoServer == 1
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
			conn = -1;
			switch obj.protocol
				
				case 'udp'
					obj.conn = pnet('udpsocket', obj.lPort);
					if obj.conn >= 0
						obj.status = pnet(obj.conn, 'udpconnect', obj.rAddress, obj.rPort);
						if obj.status < 0
							obj.conn = -2;
							obj.close;
							warning('%s cannot connect to remote UDP host (%d)', ...
								mfilename, status);
							return
						end
						% disable blocking
						pnet(obj.conn ,'setwritetimeout', 0);
						pnet(obj.conn ,'setreadtimeout', 0);
						obj.isOpen = 1;
						conn = obj.conn;
					else
						sprintf('%s cannot open UDP socket (%d)', ...
							mfilename, obj.conn);
						obj.isOpen = 0;
						obj.conn = -1;
					end
					
				case 'tcp'
					obj.conn=pnet('tcpconnect',obj.rAddress,obj.rAddress);
					if obj.conn >= 0
						obj.status = pnet(obj.conn,'status');
						if obj.status < 1
							obj.close
							warning('%s cannot connect to remote TCP host (%d)', ...
								mfilename, status);
							return
						end
						% disable blocking
						pnet(obj.conn ,'setwritetimeout', 0);
						pnet(obj.conn ,'setreadtimeout', 0);
						obj.isOpen = 1;
						conn = obj.conn;
					else
						sprintf('%s cannot open TCP socket (%d)', ...
							mfilename, obj.conn);
						obj.isOpen = 0;
						obj.conn = -1;
					end
					
			end
		end
		
		% ===================================================================
		%> @brief Close the connection
		%>
		%> Close the ethernet connection
		% ===================================================================
		% Close the given pnet socket.
		function status = close(obj)
			obj.status = 0;
			try
				obj.salutation('close Method','Trying to close PNet connection')
				pnet(obj.conn, 'close');
			catch ME
				obj.closeAll;
				obj.status = -1;
				obj.error = ME;
			end
			obj.status = pnet(obj.conn,'status');
			if obj.status <=0;obj.isOpen = 0;obj.salutation('close Method','Connection appears closed...');end
			obj.conn = -1;
			obj.rconn = -1;
			status = obj.status;
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
				obj.salutation('closeAll Method','Trying to close all PNet connections')
				pnet('closeall');
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
			data = pnet(obj.conn, 'read', 65536, obj.dataType, 'view');
			if isempty(data)
				obj.hasData = pnet(obj.conn, 'readpacket') > 0;
			else
				obj.hasData = true;
			end
			hasData = obj.hasData;
		end
		
		% ===================================================================
		%> @brief Read any avalable data from the given pnet socket.
		%>
		%> Read any avalable data from the given pnet socket.
		% ===================================================================
		% Read any avalable data from the given pnet socket.
		function data = read(obj)
			switch obj.protocol
				
				case 'udp'
					obj.dataIn = pnet(obj.conn, 'read', 65536, obj.dataType);
					if isempty(obj.dataIn)
						nBytes = pnet(obj.conn, 'readpacket');
						if nBytes > 0
							obj.dataIn = pnet(obj.conn, 'read', 65536, obj.dataType);
						end
					end
					data = obj.dataIn;
					
				case 'tcp'
					
			end
		end
		
		% ===================================================================
		%> @brief Open the LabJack device
		%>
		%> Open the LabJack device
		% ===================================================================
		% Write data to the given pnet socket.
		function status = write(obj, data)
			switch obj.protocol
				case 'udp'
					if ~exist('data','var')
						data = obj.dataOut;
					end
					pnet(obj.conn, 'write', data);
					obj.status = pnet(obj.conn, 'writepacket');
				case 'tcp'
					if ~exist('data','var')
						data = obj.dataOut;
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
		function status = checkStatus(obj)
			obj.status = pnet(obj.conn,'status');
			if obj.status <=0;obj.isOpen = 0;obj.salutation('status Method','Connection appears closed...');end
			status = obj.status;
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
						fprintf('START SERVING NEW CONNECTION FROM IP %d.%d.%d.%d port:%d',obj.rAddress,obj.rPort);
						obj.serverLoop;
					catch ME
						disp 'Server loop initialisation failed';
					end
				end
				
				if KbCheck %allow keyboard break
					pnet('closeall')
					obj.conn = -1;
					obj.rconn = -1;
					break
				end
				
			end
			
			obj.close;
			
		end
		
		% ===================================================================
		%> @brief Initialize the server loop
		%>
		%> Initialize the server loop
		% ===================================================================
		function sendCommand(obj,cmd)
			if obj.rconn < 0
				obj.open;
			end
			switch cmd.cmd
				case 'echo'
					
				otherwise
					
			end
			
		end
		
		
	end %END METHODS
	
	%=======================================================================
	methods ( Access = private ) % PRIVATE METHODS
		%=======================================================================
		
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
					
					switch upper(C{1})
						case 'EVAL'
							global DEFAULT_CON__;
							DEFAULT_CON__=obj.rconn;
							try
								disp(['REMOTE EVAL>> ' C{2:min(2:end)}]);
								evalin('caller',C{2:end},'okflag=0;');
							catch
								okflag=0;
							end
							DEFAULT_CON__=[];
						case 'PUT'
							C=C(2:end);
							for n=1:2:length(C),
								disp(['REMOTE PUT>> ' C{n}]);
								try
									assignin('caller',C{n:n+1});
								catch
									okflag=0;
								end
							end
						case 'GET'
							C=C(2:end);
							R=cell(size(C));
							for n=1:length(C),
								disp(['REMOTE GET>> ' C{n}]);
								try
									R{n}=evalin('caller',[C{n} ';']);
								catch
									okflag=0;
								end
							end
							pnet_putvar(obj.rconn,R);
						case 'CLOSE'
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
		%> @brief Destructor
		%>
		%> 
		% ===================================================================
		function delete(obj)
			obj.salutation('DELETE Method','Cleaning up...')
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
				else
					fprintf(['\nHello from ' obj.name ' | labJack\n\n']);
				end
			end
		end
	end
end

