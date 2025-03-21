classdef zmqConnection < optickaCore
	% zmqConnection is a class to handle ØMQ connections
	properties
		%> ØMQ connection type, e.g. 'REQ', 'REP', 'PUB', 'SUB', 'PUSH', 'PULL'
		type			= 'REP'
		%> the port to open
		port			= 5555
		%> the address to open
		address		= '127.0.0.1'
		%> do we log to the command window?
		verbose		= 0
		%> default read timeout
		readTimeOut		= 0
		%> default write timeout
		writeTimeOut	= 0
		%> default size of chunk to read for tcp
		frameSize		= 2^20
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
		context			= []
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
		%> @brief CONSTRUCTOR
		%>
		%> Configures input structure to assign properties
		% ===================================================================
		function me = zmqConnection(varargin)
			args = optickaCore.addDefaults(varargin,struct('name','zmqConnection'));
			me = me@optickaCore(args); %superclass constructor
			me.parseArgs(args, me.allowedProperties);
		end

		function open(me)
			if me.isOpen; me.close; end
			me.context = zmqContext();
			me.socket = zmqSocket(me.context, me.type);
			me.socket.setsockopt('ZMQ_RCVTIMEO', me.readTimeOut);
			me.socket.setsockopt('ZMQ_SNDTIMEO', me.writeTimeOut);
			me.socket.connect(sprintf('tcp://%s:%i',me.address,me.port));
			me.isOpen = true;
		end

		function close(me)
			if me.isOpen
				me.socket.close();
				me.context.close();
				me.isOpen = false;
			end
		end

		
	end
end
