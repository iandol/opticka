classdef Context < handle
	% Context  Encapsulates a ØMQ context.
	%   A context is the container for all sockets in a single process,
	%   and acts as the transport for messages between sockets.

	properties (GetAccess = public, SetAccess = private)
		% pointer  Pointer to the underlying ØMQ context.
		pointer
		% spawnedSockets  Cell array of sockets spawned from this context.
		spawnedSockets
		% date  Date and time when the context was created.
		date
	end

	methods
		function obj = Context(varargin)
			% Context  Constructs a ØMQ context.
			%   obj = zmq.Context() creates a new ØMQ context.
			%
			%   Example:
			%       ctx = zmq.Context();
			if (nargin ~= 0)
				warning('zmq:Context:extraConstructArgs','Extraneous constructor arguments.');
			end
			obj.date = datetime;
			% Core API
			obj.pointer = zmq.core.ctx_new();
			% Initi properties
			obj.spawnedSockets = {};
		end

		function option = get(obj, name)
			% get  Gets a context option.
			%   option = obj.get(name) gets the value of the context option specified by name.
			%   name is a string representing the option name (e.g., 'IO_THREADS').
			%
			%   Example:
			%       threads = ctx.get('IO_THREADS');
			optName = obj.normalize_const_name(name);
			option = zmq.core.ctx_get(obj.pointer, optName);
		end

		function set(obj, name, value)
			% set  Sets a context option.
			%   obj.set(name, value) sets the context option specified by name to the given value.
			%   name is a string representing the option name (e.g., 'IO_THREADS').
			%   value is the value to set the option to.
			%
			%   Example:
			%       ctx.set('IO_THREADS', 4);
			optName = obj.normalize_const_name(name);
			zmq.core.ctx_set(obj.pointer, optName, value);
		end

		function newSocket = socket(obj, socketType)
			% socket  Creates a new socket associated with this context.
			%   newSocket = obj.socket(socketType) creates a new socket of the specified type
			%   and associates it with this context.  socketType is a string representing the socket type
			%   (e.g., 'ZMQ_PUB', 'ZMQ_SUB').
			%
			%   Example:
			%       socket = ctx.socket('ZMQ_PUB');
			% Spawns a socket from the context
			newSocket = zmq.Socket(obj.pointer, socketType);
			% Keep tracking of spawned sockets
			% this is important to the cleanup process
			obj.spawnedSockets{end+1} = newSocket;
		end

		% This exposes the underlying context pointer.
		function ptr = getPointer(obj)
			% getPointer  Returns the pointer to the underlying ØMQ context.
			%   ptr = obj.getPointer() returns the pointer to the underlying ØMQ context.
			%
			%   Example:
			%       ptr = ctx.getPointer();
			ptr = obj.pointer;
		end

		function close(obj)
			% close  Closes all associated sockets.
			%   obj.close() closes all sockets spawned from it.
			%   This method should be called when the sockets are no longer needed.
			%
			%   Example:
			%       ctx.close();
			if obj.pointer ~= 0
				for n = length(obj.spawnedSockets):-1:1
					skt = obj.spawnedSockets{n};
					try %#ok<*TRYNC>
						skt.close();
					catch ME
						getReport(ME)
					end
					obj.spawnedSockets(n) = [];
				end
				obj.spawnedSockets = {};
			end
		end

		function term(obj)
			% term  Terminates the context.
			%   obj.term() terminates the context, releasing any resources held by it.
			%   This method is similar to close(), but does not close the associated sockets.
			%
			%   Example:
			%       ctx.term();
			if (obj.pointer ~= 0)
				try zmq.core.ctx_term(obj.pointer); end
				obj.pointer = 0;  % ensure NULL pointer
			end
		end

		function delete(obj)
			% delete  Destructor for the Context class.
			%   delete(obj) is the destructor for the Context class.  It calls the close() method
			%   to ensure that the context and all associated sockets are properly closed.
			%
			%   Example:
			%       delete(ctx);
			close(obj);
			term(obj);
		end

	end

	methods (Access = protected)
		function normalized = normalize_const_name(~, name)
			% normalize_const_name  Normalizes a constant name.
			%   normalized = obj.normalize_const_name(name) normalizes the constant name by converting it to uppercase,
			%   removing the 'ZMQ_' prefix (if present), and adding the 'ZMQ_' prefix back.
			%   This ensures that the constant name is in the correct format for use with the ØMQ API.
			%
			%   Example:
			%       normalizedName = obj.normalize_const_name('io_threads');
			normalized = strrep(upper(name), 'ZMQ_', '');
			normalized = strcat('ZMQ_', normalized);
		end
	end
end
