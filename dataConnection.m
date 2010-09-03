classdef dataConnection < handle
	%dataConnection Allows send/recieve over Ethernet
	%   This uses the TCP/UDP library to manage connections between servers
	%   and clients in Matlab
	
	properties
		type = 'Client'
		port = '5555'
		autoConnect = 1
	end
	
	properties (SetAccess = private, GetAccess = private)
		conn = []
	end
	
	methods
		function obj = dataConnection(args)
			if nargin>0 && isstruct(args)
				fnames = fieldnames(args); %find our argument names
				for i=1:length(fnames);
					if regexp(fnames{i},obj.allowedProperties) %only set if allowed property
						obj.salutation(fnames{i},'Configuring setting in gratingStimulus constructor');
						obj.(fnames{i})=args.(fnames{i}); %we set up the properies from the arguments as a structure
					end
				end
			end
			pnet('closeall'); %makes sure nothing else interfering and loads mex file in memory
			if obj.autoConnect == 1
				obj.connect;
			end
		end
		
		function connect(obj)
			conn = pnet('udpsocket',obj.port)
		end
	end
end

