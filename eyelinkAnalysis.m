% ========================================================================
%> @brief eyelinkManager wraps around the eyelink toolbox functions
%> offering a simpler interface
%>
% ========================================================================
classdef eyelinkAnalysis < optickaCore
	
	properties
		file@char = ''
		dir@char = ''
		verbose = true
	end
	
	properties (SetAccess = private, GetAccess = public)
		%> raw data
		raw@struct
		%inidividual trials
		trials@struct
	end
	
	properties (SetAccess = private, GetAccess = private)
		%> allowed properties passed to object upon construction
		allowedProperties@char = 'file|dir|verbose'
	end
	
	methods
		% ===================================================================
		%> @brief 
		%>
		% ===================================================================
		function obj = eyelinkAnalysis(varargin)
			if nargin == 0; varargin.name = 'eyelinkAnalysis';end
			if nargin>0
				obj.parseArgs(varargin,obj.allowedProperties);
			end
			if isempty(obj.file) || isempty(obj.dir)
				[obj.file, obj.dir] = uigetfile('*.edf','Load EDF File:');
			end	
			if ~isempty(obj.file)
				load(obj);
			end
		end
		
		% ===================================================================
		%> @brief 
		%>
		%> @param
		%> @return
		% ===================================================================
		function load(obj)
			if ~isempty(obj.file)
				oldpath = pwd;
				cd(obj.dir)
				obj.raw = edfmex(obj.file);
				cd(oldpath)
			end
		end
		
		% ===================================================================
		%> @brief 
		%>
		%> @param
		%> @return
		% ===================================================================
		function parse(obj)
			isTrial = false;
			tri = 1;
			obj.trials = struct;
			for i = 1:length(obj.raw.FEVENT)
				evt = obj.raw.FEVENT(i);
				id = regexpi(evt.message,'^TRIALID (?<ID>\d+)','names');
				
				if ~isempty(id)  && ~isempty(id.ID)
					isTrial = true;
					obj.trials(tri).id = id.ID;
					obj.trials(tri).time = evt.time;
					obj.trials(tri).sttime = evt.sttime;
				end
				
				if isTrial == true
					
					uuid = regexpi(evt.message,'^UUID (?<UUID>\d+)','names');
					if ~isempty(uuid) && ~isempty(uuid.UUID)
						obj.trials(tri).uuid = uuid.UUID;
					end
					
					id = regexpi(evt.message,'^TRIAL_RESULT (?<ID>\d+)','names');
					if ~isempty(id) && ~isempty(id.ID)
						obj.trials(tri).entime = evt.sttime;
						obj.trials(tri).result = id.ID;
						if id.ID == 1
							obj.trials(tri).correct = true;
						else
							obj.trials(tri).correct = false;
						end
						obj.trials(tri).deltaT = obj.trials(tri).entime - obj.trials(tri).sttime;
						isTrial = false;
						tri = tri + 1;
					end
				end
				
			end
			
		end
		
		
	end%-------------------------END PUBLIC METHODS--------------------------------%
	
	%=======================================================================
	methods (Access = private) %------------------PRIVATE METHODS
	%=======================================================================
		
		
		
	end
	
end

