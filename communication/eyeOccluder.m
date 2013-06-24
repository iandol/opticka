classdef eyeOccluder < optickaCore
	%UNTITLED Summary of this class goes here
	%   Detailed explanation goes here
	
	properties
		verbose = true
		address@char = '/dev/tty.usbmodem5d11'
	end
	
	properties (SetAccess = private, GetAccess = public)
		serialLink@serial
		isOpen = false
	end
	
	methods
		
		function obj = eyeOccluder(varargin)
			if nargin>0
				obj.parseArgs(varargin,obj.allowedProperties);
			end
			obj.name = 'eyeOccluder';
			open(obj)
			
		end
		
		function open(obj)
			if obj.isOpen == false
				obj.serialLink = serial(obj.address);
				try
					fopen(obj.serialLink);
					obj.isOpen = true;
				catch
					obj.salutation('Can''t open USB serial object');
					obj.isOpen = false;
				end
			end
			bothEyesOpen(obj)
		end
		
		function close(obj)
			if obj.isOpen
				fclose(obj.serialLink);
			end
		end
		
		function bothEyesOpen(obj)
			if obj.isOpen
				fprintf(obj.serialLink,'C');
			end
		end
		
		function bothEyesClosed(obj)
			if obj.isOpen
				fprintf(obj.serialLink,'B');
			end
		end
		
		function leftEyeClosed(obj)
			if obj.isOpen
				fprintf(obj.serialLink,'D');
			end
		end
		
		function rightEyeClosed(obj)
			if obj.isOpen
				fprintf(obj.serialLink,'A');
			end
		end
			
		
	end
	
end

