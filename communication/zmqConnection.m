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
		verbose		= 0
		%> default read timeout, -1 is block
		readTimeOut		= -1
		%> default write timeout, -1 is block
		writeTimeOut	= -1
		%> sometimes we shouldn't cleanup connections on delete, e.g. when we pass this
		%> object to another matlab instance as we will close the wrong connections!!!
		cleanup			= true
	end

	properties (Dependent = true)
		%> connection endpoint
		endpoint
		%> 
	end
	
	properties (SetAccess = private, GetAccess = public, Transient = true)
		%> zmq.Context()
		context			= []
		%> zmq.Socket()
		socket			= []
		%> is this connection open?
		isOpen			= false
	end
	
	properties (SetAccess = private, GetAccess = private)
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
				me.socket.setsockopt('ZMQ_RCVTIMEO', me.readTimeOut);
			end
			if me.writeTimeOut ~= -1
				me.socket.setsockopt('ZMQ_SNDTIMEO', me.writeTimeOut);
			end
			switch me.type 
				case {'REP','PUB','PUSH'}
					me.socket.bind(me.endpoint);
				otherwise
					me.socket.connect(me.endpoint);
			end
			me.isOpen = true;
		end

		% ===================================================================
		function rep = sendCommand(me, command, data)
		%> @brief 
		%>
		%> 
		% ===================================================================
			me.sendObject(command,data);
			[rep, ~] = me.receiveObject();
			if ~strcmpi(rep,'ok')
				fprintf('Send was OK\n');
			end

		end

		% ===================================================================
		function [command, data] = receiveCommand(me)
		%> @brief receiveCommand
		%>
		%> 
		% ===================================================================
			command = ''; data = [];
			[command, data] = me.receiveObject();
			if ~isempty(command)
				fprintf('Received: %s\n',command);
				disp(data);
				me.send('ok');
			end
		end

		% ===================================================================
		function receiveCommands(me)
		%> @brief receiveCommands
		%>
		%> 
		% ===================================================================
			stop = false;
			while ~stop
				command = ''; data = [];
				[command, data] = me.receiveObject();
				if ~isempty(command)
					fprintf('Received %s\n',command);
					disp(data);
					if strcmpi(command,'exit')
						stop = true;
					end
				end
				me.socket.send_string('ok');
				WaitSecs('YieldSecs', 0.1);
			end
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
			status = me.socket.set(option, value);
		end

		% ===================================================================
		function status = send(me, data)
		%> @brief send
		%>
		%> 
		% ===================================================================
			try
				if ischar(data) || isstring(data)
					me.socket.send_string(data);
				elseif isa(data,'uint8')
					me.socket.send(data);
				else
					sendObject(me, data);
				end
			catch ME
				warning('Couldn''t send, perhaps need to receive first');
			end
			
			try
				me.socket.r
			catch ME
				
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
		function sendObject(me, command, data, options)
		%> @brief send a text command with serialized MATLAB object
		%>
		%> 
		% ===================================================================
			% Check if the socket is open
			if ~me.isOpen
				error('Socket is not open. Please open the socket before sending data.');
			end

			% Check if the command is a string
			if ~ischar(command) && ~isstring(command)
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
				serializedObj = getByteStreamFromArray(data);
			else
				% If no data, just send an empty array
				serializedObj = uint8([]);
			end
			
			% Send command part with SNDMORE flag if we have both command and data
			if ~isempty(command) && ~isempty(serializedObj)
				me.socket.send(uint8(command), 'sndmore');
				me.socket.send(serializedObj, options{:});
			elseif ~isempty(command)
				% Just send text
				me.socket.send(uint8(command), options{:});
			elseif ~isempty(serializedObj)
				% Just send data
				me.socket.send(serializedObj, options{:});
			else
				% Send empty message
				me.socket.send(uint8(''), options{:});
			end
		end
		
		% ===================================================================
		function [command, data] = receiveObject(me, options)
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
			
			% Receive the first part (command/text)
			message = me.socket.recv(options{:});
			command = char(message);
			
			% Check if there's more parts (the object)
			hasMoreParts = me.socket.get('rcvmore');
			
			if hasMoreParts
				% Receive the serialized object
				serializedObj = me.socket.recv(options{:});
				
				% Deserialize the object if it's not empty
				if ~isempty(serializedObj)
					try
						data = getArrayFromByteStream(serializedObj);
					catch ME
						warning('Failed to deserialize object: %s', ME.message);
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
