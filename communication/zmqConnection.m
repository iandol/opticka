classdef zmqConnection < optickaCore
	%> zmqConnection is a class to handle ØMQ connections for opticka class
	%> communication. We use matlab-zmq (a basic libzmq binding), 
	%> and a REQ-REP pattern for main communication.

	properties
		%> ØMQ connection type, e.g. 'REQ', 'REP', 'PUB', 'SUB', 'PUSH', 'PULL'
		type			= 'REQ'
		%> transport for the socket, tcp | ipc | inproc
		transport		= 'tcp'
		%> the address to open, use * for a server to bind to all interfaces
		address			= 'localhost'
		%> the port to open
		port			= 6666
		%> default size of chunk to read/write for tcp
		frameSize		= 2^20
		%> default read timeout in ms, -1 is blocking
		readTimeOut		= 3e4
		%> default write timeout in ms, -1 is blocking
		writeTimeOut	= 3e4
		%> do we log to the command window?
		verbose			= false
		%> for sendCommand and receiveCommand use zmq.core.poll?
		alwaysPoll		= false
		
	end

	properties (Dependent = true)
		%> connection endpoint
		endpoint
	end
	
	properties (SetAccess = private, GetAccess = public, Transient = true)
		%> is this connection open?
		isOpen			= false
		%> zmq.Context()
		context			= []
		%> zmq.Socket()
		socket			= []
	end
	
	properties (SetAccess = private, GetAccess = private)
		sendState			= false
		recState			= false
		allowedProperties = {'type','protocol','port','address', 'alwaysPoll',...
			'verbose','readTimeOut','writeTimeOut','frameSize','cleanup'};
	end
	
	methods

		% ===================================================================
		function me = zmqConnection(varargin)
		%> @brief Class constructor for zmqConnection.
		%>
		%> @details Initializes a zmqConnection object, setting up default
		%>   properties and parsing any provided arguments using the optickaCore
		%>   superclass constructor and argument parsing.
		%>
		%> @param varargin Optional name-value pairs to override default properties.
		%>   Allowed properties are defined in `me.allowedProperties`.
		%>
		%> @return me An instance of the zmqConnection class.
		% ===================================================================
			args = optickaCore.addDefaults(varargin,struct('name','zmqConnection'));
			me = me@optickaCore(args); %superclass constructor
			me.parseArgs(args, me.allowedProperties);
		end

		
		% ===================================================================
		function status = open(me)
		%> @brief Opens the ØMQ socket connection.
		%> @details Creates the ØMQ context if it doesn't exist, creates the
		%>   socket based on the `type` property, sets socket options like
		%>   `RCVTIMEO`, `SNDTIMEO`, and `LINGER`, and then either binds (for
		%>   server types like REP, PUB, PUSH) or connects (for client types)
		%>   to the specified `endpoint`. Sets the `isOpen` flag to true.
		%> @note Does nothing if the connection `isOpen` is already true.
		% ===================================================================
			status = -1;
			if me.isOpen; return; end
			if ~isa(me.context, 'zmq.Context')
				me.context = zmq.Context();
			else
				me.context.close;
			end
			me.socket = me.context.socket(me.type);
			me.socket.defaultBufferLength = me.frameSize;
			if me.readTimeOut ~= -1
				me.set('RCVTIMEO', me.readTimeOut);
			end
			if me.writeTimeOut ~= -1
				me.set('SNDTIMEO', me.writeTimeOut);
			end
			me.set('LINGER', 1000);
			me.set('RCVBUF', me.frameSize);
			switch me.type 
				case {'REP','PUB','PUSH'}
					status = me.socket.bind(me.endpoint);
				otherwise
					status = me.socket.connect(me.endpoint);
			end
			if status == 0
				me.isOpen = true;
			else
				try me.socket.close(); end
				error('Socket failed to bind/connect!!!');
			end
		end

		% ===================================================================
		function revents = poll(me, events, time)
		%> @brief poll socket to identify whether we can send ('out') or receive ('in')
		%>
		%> @param events string 'in' 'out' or 'both'
		%> @param time in ms, 0 = no wait, -1 = block until response
		% ===================================================================
			revents = 0;
			if ~exist('events','var') || isempty(events); events = 'both'; end
			if ~exist('time','var') || isempty(time); time = 0; end
			if ~me.isOpen; return; end
			revents = me.socket.poll(events,time);
		end

		% ===================================================================
		function [rep, dataOut, status, nbytes, msg] = sendCommand(me, command, data, getReply)
		%> @brief Sends a command and optional data, then waits for a reply.
		%> 
		%> @details Primarily for REQ/REP patterns. Uses `sendObject` to send the
		%>   command string and serialized data. If successful, it then calls
		%>   `receiveObject` to wait for and receive the reply command and data.
		%>
		%> @param command The command string to send.
		%> @param data (Optional) MATLAB data to serialize and send along with the command. Defaults to empty.
		%> 
		%> @return rep The reply command string received from the peer.
		%> @return dataOut The deserialized MATLAB data received in the reply.
		%> @return status 0 on success (send and receive completed), -1 on failure (send or receive failed).
		%> @note Updates `sendState` and `recState` properties. Logs reply if verbose.
		% ===================================================================
			rep = ''; dataOut = []; status = -1;
			if ~me.isOpen; return; end
			if ~exist('getReply','var') || isempty(getReply); getReply = true; end
			try
				[status, nbytes, msg] = sendObject(me, command, data);
				if status ~= 0
					me.sendState = false; me.recState = false;
					warning(msg);
				else
					me.sendState = true; me.recState = false;
				end
			catch ME
				fprintf('Receive status %i did not return any command: %s - %s...\n', status, ME.identifier, ME.message);
				me.sendState = false; me.recState = false;
			end
			if status == 0 && getReply
				[rep, dataOut] = receiveObject(me);
				fprintf('\n=== Reply was: %s ===\n', rep);
				disp(dataOut);
				me.sendState = false; me.recState = true;
			end
		end

		% ===================================================================
		function [command, data, msg] = receiveCommand(me, sendReply)
		%> @brief Receives a command and associated data, optionally sending an 'ok' reply.
		%> @details Calls `receiveObject` to get the command string and any
		%>   serialized data. If `sendReply` is true (default) and a command was
		%>   successfully received, it sends back an 'ok' command using `sendObject`.
		%> @param sendReply (Optional) Logical flag. If true (default), sends an
		%>   'ok' reply upon successful receipt of a command. If false, no reply
		%>   is sent by this function. Defaults to true.
		%> @return command The received command string. Empty if receive failed or timed out.
		%> @return data The deserialized MATLAB data received with the command. Empty if no data part or on error.
		%> @note Updates `sendState` and `recState` properties. Logs received command/data if verbose.
		% ===================================================================
			command = ''; data = []; msg = '';
			if ~me.isOpen; return; end
			if nargin < 2
				sendReply = true; % Default behavior: send 'ok' reply
			end
			try
				[command, data, msg] = receiveObject(me);
				me.sendState = false; me.recState = true; % Update state after successful receive attempt
				if isempty(command) && ~isempty(msg)
					fprintf('Receive problem: %s\n', msg); % Log if receiveObject reported an issue
					me.recState = false; % Indicate receive wasn't fully successful
				elseif ~isempty(command) && me.verbose > 0
					fprintf('Received command: «%s»\n', command);
					if ~isempty(data) && me.verbose
						disp('Received data:');
						disp(data);
					end
				end
			catch ME
				fprintf('Error during receiveCommand: cmd: %s msg: %s err: %s - %s\n', command, msg, ME.identifier, ME.message);
				me.sendState = false; me.recState = false; % Reset state on error
				command = ''; data = []; % Ensure empty return on error
				return % Exit function on critical error
			end
			
			% Send 'ok' reply only if requested and a command was actually received
			if sendReply && ~isempty(command) && me.recState
				status = sendObject(me, 'ok', {});
				if status ~= 0
					warning('Default "ok" reply failed for command "%s"', command);
					me.sendState = false; % Update state on send failure
				else
					me.sendState = true; me.recState = false; % Update state on send success
				end
			elseif ~isempty(command) && me.recState
				% If reply is not sent here, the caller is responsible.
				% The state remains sendState=false, recState=true.
			end
		end

		% ===================================================================
		function flush(me)
		%> @brief Flushes the receive buffer of the socket.
		%> @details Temporarily sets the receive timeout (`RCVTIMEO`) to 0 (non-blocking)
		%>   and enters a loop calling `receive` until it returns a status of -1
		%>   (indicating no more messages or an error). It then restores the
		%>   original `readTimeOut`. This is useful for discarding any pending
		%>   messages in the socket's incoming queue.
		% ===================================================================
			try
				me.set('RCVTIMEO', 0);
				N = 1000;
				while N > 0
					status = 0;
					if verifyEvent('in'); [~, status] = receive(me); end
					if status == -1; N = 0; end
				end
			catch ME
				if me.verbose; fprintf('Flush error: %s %s', ME.identifier, ME.message); end
			end
			me.set('RCVTIMEO', me.readTimeOut);
		end

		% ===================================================================
		function value = get(me, option)
		%> @brief Gets the value of a ØMQ socket option.
		%> @details A wrapper around the `zmq.Socket.get` method.
		%> @param option The name of the socket option to retrieve (e.g., 'RCVTIMEO', 'SNDHWM').
		%>   Case-insensitive, 'ZMQ_' prefix is optional.
		%> @return value The current value of the specified socket option.
		%> @warning Issues a warning if `option` is not provided.
		% ===================================================================
			if ~exist('option','var'); warning('No option given...'); return; end
			value = me.socket.get(option);
		end

		% ===================================================================
		function status = set(me, option, value)
		%> @brief Sets the value of a ØMQ socket option.
		%> @details A wrapper around the `zmq.Socket.set` method.
		%> @param option The name of the socket option to set (e.g., 'RCVTIMEO', 'LINGER').
		%>   Case-insensitive, 'ZMQ_' prefix is optional.
		%> @param value The value to assign to the socket option.
		%> @return status 0 on success, non-zero on failure.
		%> @warning Issues warnings if `option` or `value` are not provided.
		% ===================================================================
			if ~exist('option','var'); warning('No option given...'); return; end
			if ~exist('value','var'); warning('No value given...'); return; end
			status = me.socket.set(option, value);
			if status ~= 0
				warning('zmqConnection:set:failure','Failed to set %s', option)
			end
		end

		% ===================================================================
		function status = send(me, data)
		%> @brief Sends raw data over the socket.
		%> @details Determines the type of data and calls the appropriate
		%>   `zmq.Socket` send method (`send_string` for char/string, `send` for
		%>   uint8). If the data type is different, it attempts to use the
		%>   private `sendObject` method (which might not be intended for raw data).
		%> @param data The data to send. Can be a character array, string, or uint8 array.
		%> @return status 0 on success, -1 on failure (e.g., timeout, incorrect socket state).
		%> @note Updates `sendState` and `recState`. Logs errors to the console.
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
		%> @brief Receives raw data from the socket.
		%> @details Calls `zmq.Socket.recv_multipart` to receive data. If the
		%>   result is a single-element cell array, it extracts the content.
		%> @return data The received data, typically as a uint8 array or potentially
		%>   a cell array for true multipart messages. Empty on failure or timeout.
		%> @return status 0 on success (implied, not explicitly returned on success),
		%>   -1 on failure (e.g., timeout).
		%> @note Updates `sendState` and `recState`. Logs errors to the console.
		% ===================================================================
			data = []; status = -1;
			try
				data = me.socket.recv_multipart();
				if iscell(data) && isscalar(data)
					data = data{:};
				end
				status = 0;
				me.sendState = false; me.recState = true;
			catch ME
				fprintf('No data received: %s - %s...\n', ME.identifier, ME.message);
				me.sendState = false; me.recState = false;
			end
		end

		% ===================================================================
		function close(me, keepContext)
		%> @brief Closes the ØMQ socket and optionally the context.
		%> @details Closes the underlying `zmq.Socket` if it's open. If
		%>   `keepContext` is false (default), it also closes the `zmq.Context`.
		%>   Sets the `isOpen` flag to false.
		%> @param keepContext (Optional) Logical flag. If true, the ØMQ context
		%>   is kept open; otherwise (default), the context is also closed.
		%>   Defaults to false.
		%> @note Uses `try...end` blocks to suppress errors during closure.
		% ===================================================================
			if ~exist('keepContext','var'); keepContext = false; end
			try me.socket.close(); end %#ok<*TRYNC>
			try me.context.close(); end
			if ~keepContext
				try me.context.term(); end
			end
			me.isOpen = false;
		end
		function delete(me)
		%> @brief Class destructor.
		%> @details Ensures the socket and context are closed by calling `close(me, false)`
		%>   when the object is destroyed.
		% ===================================================================
			close(me, false);
		end

		% ===================================================================
		function endpoint = get.endpoint(me)
		%> @brief Gets the full endpoint string for the connection.
		%> @details Constructs the endpoint string (e.g., 'tcp://localhost:5555')
		%>   based on the `transport`, `address`, and `port` properties.
		%> @return endpoint The formatted endpoint string.
		% ===================================================================
			endpoint = sprintf('%s://%s:%i',me.transport,me.address,me.port);
		end

		% ===================================================================
		function [status, nbytes, msg] = sendObject(me, command, data, options)
		%> @brief (Private) Sends a command string and optional serialized MATLAB data.
		%> @details This is the core sending method used by public methods like
		%>   `sendCommand` and `receiveCommand` (for replies). It checks if the
		%>   socket is open, validates the command is a string, serializes the
		%>   `data` using `getByteStreamFromArray` (if provided), and sends the
		%>   command and data as a two-part message using `zmq.Socket.send` with
		%>   the 'sndmore' flag if both parts exist. Handles sending only command,
		%>   only data, or an empty message if both are empty.
		%> @param command The command string to send. Must be char or string.
		%> @param data (Optional) MATLAB data to serialize and send.
		%> @param options (Optional) Cell array of additional flags for the final `send` call (e.g., {'ZMQ_DONTWAIT'}).
		%> @return status 0 on success, -1 on failure.
		%> @return nbytes The total number of bytes sent across all parts.
		%> @return msg An error message string if `status` is -1.
		%> @note This is a private method. Throws errors for invalid input or unopened socket.
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
		%> @brief (Private) Receives a command string and optional serialized MATLAB data.
		%> @details This is the core receiving method. It calls `zmq.Socket.recv`
		%>   to get the first part (expected to be the command string). It checks
		%>   the 'rcvmore' socket option to see if a second part (data) exists.
		%>   If so, it calls `zmq.Socket.recv_multipart` to get the remaining part(s),
		%>   concatenates them if necessary, and deserializes the result using
		%>   `getArrayFromByteStream`.
		%> @param options (Optional) Cell array of flags for the initial `recv` call (e.g., {'ZMQ_DONTWAIT'}).
		%> @return command The received command string. Empty on failure or timeout.
		%> @return data The deserialized MATLAB data. Empty if no data part, deserialization fails, or on error.
		%> @return msg An error message string if receiving the command failed or deserialization failed.
		%> @note This is a private method. Throws an error if the socket is not open. Logs deserialization errors.
		% ===================================================================
			% Check if the socket is open
			if ~me.isOpen
				error('Socket is not open. Please open the socket before sending data.');
			end

			if nargin < 2
				options = {};
			end

			command = ''; data = []; msg = ''; frames = {};

			try
				frames = me.socket.recv_multipart(options{:});
			catch ME
				warning('Failed to get object: %s - %s', ME.identifier, ME.message);
				if matches(ME.identifier,'zmq:core:recv:EFSM')
					fprintf('EFSM error, let''s try to flush and send');
					me.flush;
					me.sendObject('error',{''});
				end
			end
			if isempty(frames); return; end

			command = frames{1};
			if command == -1 
				msg = 'No data received...';
				command = '';
				return
			end
			command = char(command);
			
			if length(frames) > 1
				data = frames{2:end};
				if iscell(data)
					data = [data{:}];
				end
				% Deserialize the object if it's not empty
				if ~isempty(data)
					try
						data = getArrayFromByteStream(data);
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

	methods (Access = private)
		
		function out = verifyEvent(me, events)
			if ~me.alwaysPoll; out = true; return; end
			out = false;
			r = poll(me,'both',0);
			switch events
				case 'in'
					if matches(r,{'in','both'}) 
						out = true; 
					end
				case 'out'
					if matches(r,{'out','both'})
						out = true; 
					end
				case 'none'
					if matches(r,'none')
						out = true;
					end
			end
		end
		
	end
	
end
