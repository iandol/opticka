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
		FSAMPLE
		FEVENT
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
				obj.FEVENT = obj.raw.FEVENT;
				obj.FSAMPLE = obj.raw.FSAMPLE;
			end
		end
		
		% ===================================================================
		%> @brief 
		%>
		%> @param
		%> @return
		% ===================================================================
		function parse(obj)
			tic
			isTrial = false;
			tri = 1;
			obj.trials = struct;
			for i = 1:length(obj.raw.FEVENT)
				isMessage = false;
				evt = obj.raw.FEVENT(i);
				
				if strcmpi(evt.codestring,'MESSAGEEVENT')
					isMessage = true;
				end
				if isMessage && ~isTrial
					id = regexpi(evt.message,'^TRIALID (?<ID>\d+)','names');
					if ~isempty(id)  && ~isempty(id.ID)
						isTrial = true;
						obj.trials(tri).id = id.ID;
						obj.trials(tri).time = evt.time;
						obj.trials(tri).sttime = evt.sttime;
					end
				end
				
				if isTrial
					
					if strcmpi(evt.codestring,'STARTSAMPLES')
						obj.trials(tri).startsampletime = evt.sttime;
					end
					
					if strcmpi(evt.codestring,'STARTFIX')
						obj.trials(tri).startfixtime = evt.sttime;
					end
					
					if isMessage
						uuid = regexpi(evt.message,'^UUID (?<UUID>\d+)','names');
						if ~isempty(uuid) && ~isempty(uuid.UUID)
							obj.trials(tri).uuid = uuid.UUID;
						end
						
						endfix = regexpi(evt.message,'^END_FIX','names');
						if ~isempty(endfix)
							obj.trials(tri).rtstarttime = evt.sttime;
						end
						
						endfix = regexpi(evt.message,'^END_RT','names');
						if ~isempty(endfix)
							obj.trials(tri).rtendtime = evt.sttime;
							if isfield(obj.trials,'rtstarttime')
								obj.trials(tri).rttime = obj.trials(tri).rtendtime - obj.trials(tri).rtstarttime;
							end
						end						
						
						id = regexpi(evt.message,'^TRIAL_RESULT (?<ID>\d+)','names');
						if ~isempty(id) && ~isempty(id.ID)
							obj.trials(tri).entime = evt.sttime;
							obj.trials(tri).result = str2num(id.ID);
							if obj.trials(tri).result == 1
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
			fprintf('Parsing EDF Trials took %g ms\n',toc*1000);
		end
		
		
	end%-------------------------END PUBLIC METHODS--------------------------------%
	
	%=======================================================================
	methods (Access = private) %------------------PRIVATE METHODS
	%=======================================================================
		
		
		
	end
	
end

