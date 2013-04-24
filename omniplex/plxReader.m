classdef plxReader < optickaCore
	%TIMELOG Simple class used to store the timing data from an experiment
	%   timeLogger stores timing data for a taskrun and optionally graphs the
	%   result.
	
	properties
		verbose	= true
	end
	
	properties (SetAccess = private, GetAccess = public)
		file@char
		dir@char
		eventList@struct
		strobeList@struct
	end
	
	properties (SetAccess = private, GetAccess = private)
		oldDir
		%> allowed properties passed to object upon construction
		allowedProperties@char = 'verbose'
	end
	
	%=======================================================================
	methods %------------------PUBLIC METHODS
	%=======================================================================

		% ===================================================================
		%> @brief Constructor
		%>
		%> @param varargin
		%> @return
		% ===================================================================
		function obj=plxReader(varargin)
			if nargin == 0; varargin.name = 'plxReader';end
			if nargin>0; obj.parseArgs(varargin,obj.allowedProperties); end
			if isempty(obj.name);obj.name = 'plxReader'; end
			[obj.file, obj.dir] = uigetfile('*.plx');
		end
		
		function sd = parseToSD(obj)
			obj.oldDir = pwd;
			cd(obj.dir);
			obj.getStrobes;
		end

	end %---END PUBLIC METHODS---%
	
	%=======================================================================
	methods ( Access = private ) %-------PRIVATE METHODS-----%
	%=======================================================================
		
		function getStrobes(obj)
			[a,b,c]=plx_event_ts(obj.file,257);
			if a > 0
				obj.strobeList.n = a;
				obj.strobeList.times = b;
				obj.strobeList.values = c;
				obj.strobeList.unique = unique(c);
				for i = 1:length(obj.strobeList.unique)-1
					name = ['var' num2str(i)];
					idx = find(obj.strobeList.values == obj.strobeList.unique(i));
					idxend = idx+1;
					obj.strobeList.(name).index = idx;
					obj.strobeList.(name).timesStart = obj.strobeList.times(idx);
					obj.strobeList.(name).timesEnd = obj.strobeList.times(idxend);
				end
			else
				obj.strobeList = struct();
			end
		end
		
		% ===================================================================
		%> @brief 
		%>
		%> @param
		%> @return
		% ===================================================================
		function [avg,err] = stderr(obj,data)
			avg=mean(data);
			err=std(data);
			err=sqrt(err.^2/length(data));
		end
		
	end
	
end

