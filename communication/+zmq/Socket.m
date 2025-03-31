classdef Socket < handle
	%Socket  Encapsulates a ZeroMQ socket.
	%   The Socket class provides a high-level interface for interacting with
	%   ZeroMQ sockets in MATLAB. It handles socket creation, binding,
	%   connection, message sending and receiving, and socket closure.

	properties (Access = public)
		%bindings  Cell array of endpoints the socket is bound to.
		%   This property stores the endpoints that the socket is currently
		%   bound to. It is used for cleanup when the socket is closed.
		bindings
		%connections  Cell array of endpoints the socket is connected to.
		%   This property stores the endpoints that the socket is currently
		%   connected to. It is used for cleanup when the socket is closed.
		connections
		%defaultBufferLength  Default buffer length for receiving messages.
		%   This property specifies the default buffer length used when
		%   receiving messages from the socket.
		defaultBufferLength
	end

	properties (GetAccess = public, SetAccess = private)
		%socketPointer  Pointer to the underlying ZeroMQ socket.
		%   This pointer is used by the core functions to interact with the
		%   ZeroMQ library.
		socketPointer = 0
	end

	methods
		function obj = Socket(contextPointer, socketType)
			%Socket  Constructs a Socket object.
			%   obj = Socket(contextPointer, socketType) creates a ZeroMQ socket
			%   of the specified type within the given context.
			%
			%   Inputs:
			%       contextPointer - Pointer to the ZeroMQ context.
			%       socketType   - Type of the socket (e.g., 'ZMQ_PUB', 'ZMQ_SUB').
			%
			%   Outputs:
			%       obj          - A Socket object.
			socketType = obj.normalize_const_name(socketType);
			% Core API
			obj.socketPointer = zmq.core.socket(contextPointer, socketType);
			% Init properties
			obj.bindings = {};
			obj.connections = {};
			obj.defaultBufferLength = 255*12;
		end

		function bind(obj, endpoint)
			%bind  Binds the socket to a network endpoint.
			%   bind(obj, endpoint) binds the ZeroMQ socket to the specified
			%   endpoint.
			%
			%   Inputs:
			%       obj      - A Socket object.
			%       endpoint - The network endpoint to bind to (e.g., 'tcp://*:5555').
			status = zmq.core.bind(obj.socketPointer, endpoint);
			if (status == 0)
				% Add endpoint to the tracked bindings
				% this is important to the cleanup process
				obj.bindings{end+1} = endpoint;
			end
		end

		function connect(obj, endpoint)
			%connect  Connects the socket to a network endpoint.
			%   connect(obj, endpoint) connects the ZeroMQ socket to the specified
			%   endpoint.
			%
			%   Inputs:
			%       obj      - A Socket object.
			%       endpoint - The network endpoint to connect to (e.g., 'tcp://localhost:5555').
			status = zmq.core.connect(obj.socketPointer, endpoint);
			if (status == 0)
				% Add endpoint to the tracked connections
				% this is important to the cleanup process
				obj.connections{end+1} = endpoint;
			end
		end

		function disconnect(obj, endpoint)
			%disconnect  Disconnects the socket from a network endpoint.
			%   disconnect(obj, endpoint) disconnects the ZeroMQ socket from the specified
			%   endpoint.
			%
			%   Inputs:
			%       obj      - A Socket object.
			%       endpoint - The network endpoint to disconnect from.
			status = zmq.core.disconnect(obj.socketPointer, endpoint);
			if (status == 0)
				% Remove endpoint from the tracked connections
				% to avoid double cleaning
				index = find(strcmp(obj.connections, endpoint));
				obj.connections(index) = [];
			end
		end

		function option = get(obj, name)
			%get  Gets a socket option.
			%   option = get(obj, name) retrieves the value of the specified
			%   socket option.
			%
			%   Inputs:
			%       obj  - A Socket object.
			%       name - The name of the socket option (e.g., 'RCVTIMEO').
			%
			%   Outputs:
			%       option - The value of the socket option.
			optName = obj.normalize_const_name(name);
			option = zmq.core.getsockopt(obj.socketPointer, optName);
		end

		function message = recv_multipart(obj, varargin)
			%recv_multipart  Receives a multipart message.
			%   message = recv_multipart(obj, varargin) receives a multipart
			%   message from the socket.
			%
			%   Inputs:
			%       obj      - A Socket object.
			%       varargin - Optional arguments for receiving the message.
			%
			%   Outputs:
			%       message  - A cell array containing the message parts.
			[buffLen, options] = obj.normalize_msg_options(varargin{:});
		
			message = [];
		
			keepReceiving = 1;
		
			while keepReceiving > 0
				part = obj.recv(buffLen, options{:});
				message = [message part];
				keepReceiving = obj.get('rcvmore');
			end
		end

		function message = recv_string(obj, varargin)
			%recv_string  Receives a message as a string.
			%   message = recv_string(obj, varargin) receives a message from the
			%   socket and converts it to a string.
			%
			%   Inputs:
			%       obj      - A Socket object.
			%       varargin - Optional arguments for receiving the message.
			%
			%   Outputs:
			%       message  - The received message as a string.
			message = char(obj.recv_multipart(varargin{:}));
		end

		function varargout = recv(obj, varargin)
			%recv  Receives a message.
			%   message = recv(obj, varargin) receives a message from the socket.
			%
			%   Inputs:
			%       obj      - A Socket object.
			%       varargin - Optional arguments for receiving the message.
			%
			%   Outputs:
			%       message  - The received message.
			[buffLen, options] = obj.normalize_msg_options(varargin{:});
			[varargout{1:nargout}] = zmq.core.recv(obj.socketPointer, buffLen, options{:});
		end

		function send_multipart(obj, message, varargin)
			%send_multipart  Sends a multipart message.
			%   send_multipart(obj, message, varargin) sends a multipart message
			%   through the socket.
			%
			%   Inputs:
			%       obj      - A Socket object.
			%       message  - A cell array containing the message parts to send.
			%       varargin - Optional arguments for sending the message.
			[buffLen, options] = obj.normalize_msg_options(varargin{:});
		
			offset = 1;
		
			L = length(message);  % length of original message
			N = floor(L/buffLen); % number of multipart messages
		
			for m = 1:N
				part = message(offset:(offset+buffLen-1));
				offset = offset+buffLen;
				obj.send(part, 'sndmore');
			end
		
			part = message(offset:end);
			obj.send(part);
		end

		function send_string(obj, message, varargin)
			%send_string  Sends a string message.
			%   send_string(obj, message, varargin) sends a string message
			%   through the socket.
			%
			%   Inputs:
			%       obj      - A Socket object.
			%       message  - The string to send.
			%       varargin - Optional arguments for sending the message.
			obj.send_multipart(uint8(message), varargin{:});
		end

		function nbytes = send(obj, data, varargin)
			%send  Sends a message.
			%   send(obj, data, varargin) sends a message through the socket.
			%
			%   Inputs:
			%       obj      - A Socket object.
			%       data     - The data to send.
			%       varargin - Optional arguments for sending the message.
			%
			%   Outputs:
			%       nbytes   - The number of bytes sent.
			[~, options] = obj.normalize_msg_options(varargin{:});
			nbytes = zmq.core.send(obj.socketPointer, data, options{:});
		end

		function status = set(obj, name, value)
			%set  Sets a socket option.
			%   set(obj, name, value) sets the value of the specified socket
			%   option.
			%
			%   Inputs:
			%       obj   - A Socket object.
			%       name  - The name of the socket option (e.g., 'RCVTIMEO').
			%       value - The value to set for the option.
			optName = obj.normalize_const_name(name);
			status = zmq.core.setsockopt(obj.socketPointer, optName, value);
			if status ~= 0
				warning('Setting %s did not succeed!',optName);
			end
		end

		function unbind(obj, endpoint)
			%unbind  Unbinds the socket from a network endpoint.
			%   unbind(obj, endpoint) unbinds the ZeroMQ socket from the specified
			%   endpoint.
			%
			%   Inputs:
			%       obj      - A Socket object.
			%       endpoint - The network endpoint to unbind from.
			status = zmq.core.unbind(obj.socketPointer, endpoint);
			if (status == 0)
				% Remove endpoint from the tracked bindings
				% to avoid double cleaning
				index = find(strcmp(obj.bindings, endpoint));
				obj.bindings(index) = [];
			end
		end

		function close(obj)
			%close  Closes the socket.
			%   close(obj) closes the ZeroMQ socket.
			%
			%   Inputs:
			%       obj - A Socket object.
			if (obj.socketPointer ~= 0)
				% Disconnect/Unbind all the endpoints
				cellfun(@(b) obj.unbind(b), obj.bindings, 'UniformOutput', false);
				cellfun(@(c) obj.disconnect(c), obj.connections, 'UniformOutput', false);
				% Avoid linger time
				obj.set('linger', 0);
			end
			status = zmq.core.close(obj.socketPointer);
			if (status == 0)
				obj.socketPointer = 0; % ensure NULL pointer
			end
		end

		function delete(obj)
			%delete  Destructor for the Socket object.
			%   delete(obj) is the destructor for the Socket object. It closes the
			%   socket and releases any associated resources.
			obj.close();
		end
	end

	methods (Access = protected)
		function normalized = normalize_const_name(~, name)
			%normalize_const_name  Normalizes a constant name.
			%   normalized = normalize_const_name(name) converts a constant name
			%   to a normalized form (e.g., 'rcvtimeo' to 'ZMQ_RCVTIMEO').
			%
			%   Inputs:
			%       name - The constant name to normalize.
			%
			%   Outputs:
			%       normalized - The normalized constant name.
			normalized = strrep(upper(name), 'ZMQ_', '');
			normalized = strcat('ZMQ_', normalized);
		end

		function [buffLen, options] = normalize_msg_options(obj, varargin)
			%normalize_msg_options  Normalizes message options.
			%   [buffLen, options] = normalize_msg_options(obj, varargin)
			%   normalizes the message options, extracting the buffer length and
			%   formatting the options as a cell array.
			%
			%   Inputs:
			%       obj      - A Socket object.
			%       varargin - Variable-length input argument list.
			%
			%   Outputs:
			%       buffLen  - The buffer length.
			%       options  - A cell array containing the normalized options.
			buffLen = obj.defaultBufferLength;
			options = cell(0);
			if (nargin > 1)
				if (isnumeric(varargin{1}))
					options = cell(1, nargin-2);
					buffLen = varargin{1};
					offset = 1;
				else
					options = cell(1, nargin-1);
					offset = 0;
				end
		
				for n = 1:nargin-offset-1
					options{n} = obj.normalize_const_name(varargin{n+offset});
				end
			end
		end
	end

end
