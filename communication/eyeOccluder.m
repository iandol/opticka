classdef eyeOccluder < optickaCore
	%UNTITLED Summary of this class goes here
	%   Detailed explanation goes here
	
	properties
		verbose = true
		address@cell = {'/dev/tty.usbmodemfa231','/dev/tty.usbmodem5d11'}
	end
	
	properties (SetAccess = private, GetAccess = public)
		serialLink
		isOpen = false
	end
	
	methods
		
		function obj = eyeOccluder(varargin)
			if nargin>0
				obj.parseArgs(varargin,obj.allowedProperties);
			end
			obj.name = 'eyeOccluder';
			open(obj);
		end
		
		function open(obj)
			if obj.isOpen == false
				if isempty(obj.serialLink) || ~isa(obj.serialLink,'serial');
					obj.serialLink = serial(obj.address{1});
				end
				for i=1:length(obj.address)
					obj.serialLink.Port = obj.address{i};
					try
						fopen(obj.serialLink);
						obj.isOpen = true;
						break
					catch
						obj.salutation(['Can''t open USB serial object: ' obj.serialLink.Port]);
						close(obj);
						return
					end
				end
				bothEyesOpen(obj)
			end
		end
		
		function close(obj)
			try %#ok<TRYNC>
				fclose(obj.serialLink);
			end
			obj.isOpen = false;
		end
		
		function bothEyesOpen(obj)
			if obj.isOpen
				obj.salutation('Both Eyes open!','',1);
				fprintf(obj.serialLink,'C');
			end
		end
		
		function bothEyesClosed(obj)
			if obj.isOpen
				obj.salutation('Both Eyes closed!','',1);
				fprintf(obj.serialLink,'B');
			end
		end
		
		function leftEyeClosed(obj)
			if obj.isOpen
				obj.salutation('Left Eye closed!','',1);
				fprintf(obj.serialLink,'D');
			end
		end
		
		function rightEyeClosed(obj)
			if obj.isOpen
				obj.salutation('Right Eye closed!','',1);
				fprintf(obj.serialLink,'A');
			end
		end
		
		function delete(obj)
			close(obj);
			obj.serialLink = [];
		end
			
		
	end
	
end

