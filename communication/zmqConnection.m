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
			if me.isOpen; me.close; end
			me.context = zmq.Context();
			me.socket = me.context.socket(me.type);
			%me.socket.setsockopt('ZMQ_RCVTIMEO', me.readTimeOut);
			%me.socket.setsockopt('ZMQ_SNDTIMEO', me.writeTimeOut);
			switch me.type 
				case {'REP','PUB','PUSH'}
					me.socket.bind(me.endpoint);
				otherwise
					me.socket.connect(me.endpoint);
			end
			me.isOpen = true;
		end

		% ===================================================================
		function sendCommand(me, command, data)
		%> @brief open
		%>
		%> 
		% ===================================================================
			
		end

		% ===================================================================
		function [command, data] = receiveCommand(me)
		%> @brief open
		%>
		%> 
		% ===================================================================

		end

		% ===================================================================
		function open(me)
		%> @brief open
		%>
		%> 
		% ===================================================================

		end

		% ===================================================================
		function open(me)
		%> @brief open
		%>
		%> 
		% ===================================================================

		end

		% ===================================================================
		function open(me)
		%> @brief open
		%>
		%> 
		% ===================================================================

		end

		% ===================================================================
		function open(me)
		%> @brief open
		%>
		%> 
		% ===================================================================

		end

		% ===================================================================
		function close(me)
		%> @brief close
		%>
		%> 
		% ===================================================================
			if me.isOpen
				try me.socket.close(); end %#ok<*TRYNC>
				try me.context.close(); end
				me.isOpen = false;
			end
		end
		function delete(me)
			close(me);
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
end
