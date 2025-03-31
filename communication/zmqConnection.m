classdef zmqConnection < optickaCore
	%> zmqConnection is a class to handle ØMQ connections for opticka class
	%> communication

	properties
		%> ØMQ connection type, e.g. 'REQ', 'REP', 'PUB', 'SUB', 'PUSH', 'PULL'
		type			= 'REQ'
		%> the port to open
		port			= 5555
		%> the address to open, use * for a server to bind to all interfaces
		address			= 'localhost'
		%> transport for the socket, tcp | ipc | inproc
		transport		= 'tcp'
		%> default size of chunk to read for tcp
		frameSize		= 2^20
		%> do we log to the command window?
		verbose			= 0
		%> default read timeout, -1 is blocking
		readTimeOut		= 10000
		%> default write timeout, -1 is blocking
		writeTimeOut	= 10000
	end
	
	properties (SetAccess = private, GetAccess = public, Transient = true)
		%> is this connection open?
		isOpen			= false
		%> zmq.Context()
		context			= []
		%> zmq.Socket()
		socket			= []
	end

	properties (Dependent = true)
		%> connection endpoint
		endpoint
	end
	
	properties (SetAccess = private, GetAccess = private)
		sendState			= false
		recState			= false
		allowedProperties = {'type','protocol','port','address', ...
			'verbose','readTimeOut','writeTimeOut','frameSize','cleanup'};
	end
	
	methods

		% ===================================================================
		function me = zmqConnection(varargin)
		%> @brief CONSTRUCTOR
		%>
		%> Configures input structure to assign properties
		% ===================================================================
			args = optickaCore.addDefaults(varargin,struct('name','zmqConnection'));
			me = me@optickaCore(args); %superclass constructor
			me.parseArgs(args, me.allowedProperties);
		end

		
		% ===================================================================
		function open(me)
		%> @brief open
		%>
		%> 
		% ===================================================================
			if me.isOpen; return; end
			if ~isa(me.context, 'zmq.Context')
				me.context = zmq.Context();
			end
			me.socket = me.context.socket(me.type);
			if me.readTimeOut ~= -1
				me.set('RCVTIMEO', me.readTimeOut);
			end
			if me.writeTimeOut ~= -1
				me.set('SNDTIMEO', me.writeTimeOut);
			end
			me.set('LINGER', 1000);
			switch me.type 
				case {'REP','PUB','PUSH'}
					me.socket.bind(me.endpoint);
				otherwise
					me.socket.connect(me.endpoint);
			end
			me.isOpen = true;
		end

		% ===================================================================
		function [rep, dataOut, status] = sendCommand(me, command, data)
		%> @brief 
		%>
		%> 
		% ===================================================================
			rep = ''; dataOut = []; status = -1;
			try
				[status, ~, msg] = sendObject(me, command, data);
				if status == -1
					me.sendState = false; me.recState = false;
					warning(msg);
				else
					me.sendState = true; me.recState = false;
				end
			catch ME
				fprintf('Receive status %i did not return any command: %s - %s...\n', status, ME.identifier, ME.message);
				me.sendState = false; me.receiveState = false;
			end
			if status == 0
				[rep, dataOut] = receiveObject(me);
				fprintf('Reply was: %s\n', rep);disp(dataOut);
				me.sendState = false; me.recState = true;
			end
		end

		% ===================================================================
		function [command, data] = receiveCommand(me)
		%> @brief receiveCommand
		%>
		%> 
		% ===================================================================
			command = ''; data = [];
			try
				[command, data, msg] = receiveObject(me);
				me.sendState = false; me.recState = true;
				if isempty(command)
					fprintf(msg);
				end
			catch ME
				fprintf('Receive did not return any command: %s - %s...\n', ME.identifier, ME.message);
				return
			end
			if ~isempty(command)
				fprintf('Received: «%s»\n',command);
				disp(data);
				status = sendObject(me, 'ok', {''});
				if status ~= 0
					warning('Reply failed');
					me.sendState = false;
				else
					me.sendState = true; me.recState = false;
				end
			end
		end

		% ===================================================================
		function receiveCommands(me)
		%> @brief receiveCommands
		%>
		%> 
		% ===================================================================
			stop = false;
			fprintf('Will loop receiving commands...\n');
			while ~stop
				[command, ~] = receiveCommand(me);
				if matches(command,{'exit','quit'})
					stop = true;
				else 
					WaitSecs('YieldSecs', 0.1);
				end
			end
		end

		% ===================================================================
		function flush(me)
			try
				me.set('RCVTIMEO', 0);
				loop = true;
				while loop
					[~, status] = receive(me);
					if status == -1
						loop = false;
					end
				end
			end
			me.set('RCVTIMEO', me.readTimeOut);
		end

		% ===================================================================
		function value = get(me, option)
		%> @brief get
		%>
		%> 
		% ===================================================================
			if ~exist('option','var'); warning('No option given...'); return; end
			value = me.socket.get(option);
		end

		% ===================================================================
		function status = set(me, option, value)
		%> @brief set
		%>
		%> 
		% ===================================================================
			if ~exist('option','var'); warning('No option given...'); return; end
			if ~exist('value','var'); warning('No value given...'); return; end
			status = me.socket.set(option, value);
		end

		% ===================================================================
		function status = send(me, data)
		%> @brief send
		%>
		%> 
		% ===================================================================
			try
				status = 0;
				if ischar(data) || isstring(data)
					me.socket.send_string(data);
				elseif isa(data,'uint8')
					me.socket.send(data);
				else
					sendObject(me, data);
				end
				me.sendState = true; me.recState = false;
			catch ME
				status = -1;
				fprintf('Couldn''t send, perhaps need to receive first: %s - %s\n', ME.identifier, ME.message);
			end
		end

		% ===================================================================
		function [data, status] = receive(me)
		%> @brief send
		%>
		%> 
		% ===================================================================
			data = [];
			try
				data = me.socket.recv_multipart();
				if iscell(data) && isscalar(data)
					data = data{:};
				end
				me.sendState = false; me.recState = true;
			catch ME
				fprintf('No data received: %s - %s...\n', ME.identifier, ME.message);
				me.sendState = false; me.recState = false;
				status = -1;
			end
		end

		% ===================================================================
		function close(me, keepContext)
		%> @brief close
		%>
		%> 
		% ===================================================================
			if ~exist('keepContext','var'); keepContext = false; end
			if me.isOpen
				try me.socket.close(); end %#ok<*TRYNC>
				if ~keepContext
					try me.context.close(); end
				end
				me.isOpen = false;
			end
		end
		function delete(me)
			close(me, false);
		end

		% ===================================================================
		function endpoint = get.endpoint(me)
		%> @brief get endpoint
		%>
		%> 
		% ===================================================================
			endpoint = sprintf('%s://%s:%i',me.transport,me.address,me.port);
		end

	end

	methods (Access = private)
		% ===================================================================
		function [status, nbytes, msg] = sendObject(me, command, data, options)
		%> @brief send a text command with serialized MATLAB object
		%>
		%> 
		% ===================================================================
			
			status = -1; nbytes = 0; msg = '';
		
			% Check if the socket is open
			if ~me.isOpen
				error('Socket is not open. Please open the socket before sending data.');
			end

			% Check if the command is a string
			if ~exist('command','var') || ~ischar(command) && ~isstring(command)
				error('Command must be a string or character array.');
			end

			if nargin < 3
				data = [];
			end
			
			if nargin < 4
				options = {};
			end
			
			% Serialize the object if it's not empty
			if ~isempty(data)
				serialData = getByteStreamFromArray(data);
			else
				% If no data, just send an empty array
				serialData = uint8([]);
			end
			try
				if ~isempty(command) && ~isempty(serialData)
					n1 = me.socket.send(uint8(command), 'sndmore');
					n2 = me.socket.send(serialData, options{:});
					nbytes = n1 + n2;
				elseif ~isempty(command)
					% Just send text
					nbytes = me.socket.send(uint8(command), options{:});
				elseif ~isempty(serialData)
					% Just send data
					nbytes = me.socket.send(serialData, options{:});
				else
					% Send empty message
					nbytes = me.socket.send(uint8(''), options{:});
				end
				status = 0;
			catch ME
				status = -1;
				msg = [ME.identifier, ME.message];
			end
		end
		
		% ===================================================================
		function [command, data, msg] = receiveObject(me, options)
		%> @brief Receive a command with serialized MATLAB object
		%>
		%> 
		% ===================================================================
			% Check if the socket is open
			if ~me.isOpen
				error('Socket is not open. Please open the socket before sending data.');
			end

			if nargin < 2
				options = {};
			end

			command = ''; data = []; msg = '';
			
			% Receive the first part (command/text)
			[command, len] = me.socket.recv(options{:});
			if command == -1 
				msg = 'No data received...';
				command = '';
				return
			end
			command = char(command);
			
			% Check if there's more parts (the object)
			hasMoreParts = me.socket.get('rcvmore');
			
			if hasMoreParts
				% Receive the serialized object
				serialData = [];
				data = me.socket.recv_multipart(options{:});
				if iscell(data)
					serialData = [data{:}];
				end
				% Deserialize the object if it's not empty
				if ~isempty(serialData)
					try
						data = getArrayFromByteStream(serialData);
					catch ME
						msg = sprintf('Failed to deserialize object: %s - %s', ME.identifier, ME.message);
						warning(msg);
						data = [];
					end
				else
					data = [];
				end
			else
				% No object part in the message
				data = [];
			end
		end
	end
	
end
