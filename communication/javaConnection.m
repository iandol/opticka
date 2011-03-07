% ========================================================================
%> @brief dataConnection Connects and manages a socket connection
%>
%> Connects and manages TCP/UDP Communication
%>
% ========================================================================
classdef javaConnection
	%UNTITLED2 Summary of this class goes here
	%   Detailed explanation goes here
	
	properties
		type = 'client'
		protocol = 'udp'
		lPort = 9898
		lAddress = 'localhost'
		rPort = 9899
		rAddress = 'localhost'
		conn
		rconn
	end
	
	methods
		
		% ===================================================================
		%> @brief CONSTRUCTOR
		%>
		%> Configures input structure to assign properties
		% ===================================================================
		function obj = javaConnection(args)
			
			import java.net.Socket
			import java.io.*
			
			if nargin>0 && isstruct(args)
				fnames = fieldnames(args); %find our argument names
				for i=1:length(fnames);
					if regexp(fnames{i},obj.allowedProperties) %only set if allowed property
						obj.salutation(fnames{i},'Configuring setting in constructor');
						obj.(fnames{i})=args.(fnames{i}); %we set up the properies from the arguments as a structure
					end
				end
			end
		end
		
		function status = open(obj)
			
			
			
		end
		
	end
	
	methods ( Access = private )
		
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

