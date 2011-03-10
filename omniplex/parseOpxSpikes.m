classdef parseOpxSpikes < handle
	%UNTITLED4 Summary of this class goes here
	%   Detailed explanation goes here
	
	properties
		stimulus
		sValues %stimulus list
		sMap %stimulus index
		sIndex %stimulus number sent to be strobed.
		trialTime
		thisRun = 0
		run
		nVars
		nTrials
		units
		parameters
		xValues
		yValues
		zValues
		unit
	end
	
	properties (SetAccess = private, GetAccess = private)
		allowedProperties='^(stimulus)$'
	end
	
	methods
		% ===================================================================
		%> @brief CONSTRUCTOR
		%>
		%> Configures input structure to assign properties
		% ===================================================================
		function obj = parseOpxSpikes(args)
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
		
		% ===================================================================
		%> @brief CONSTRUCTOR
		%>
		%> Configures input structure to assign properties
		% ===================================================================
		function initialize(obj,opx)
			
			obj.thisRun = 0;
			
			if isa(opx,'opxOnline')
				obj.units = opx.units;
				obj.parameters = opx.parameters;
				obj.units.celllist=[1 2 3 1 2 1];
				obj.units.chlist=[1 1 1 2 2 3];
			end
			
			obj.unit = cell(obj.units.totalCells,1);
			
			if isa(opx.stimulus,'runExperiment')
				obj.stimulus = opx.stimulus;
				obj.sValues = obj.stimulus.task.outValues;
				obj.sMap = obj.stimulus.task.outMap;
				obj.sIndex = obj.stimulus.task.outIndex;
				obj.nVars = obj.stimulus.task.nVars;
				obj.nTrials = obj.stimulus.task.nTrials;
				obj.trialTime = obj.stimulus.task.trialTime;
				if obj.nVars == 0
					raw = cell(1,1,1);
				elseif obj.nVars == 1
					raw = cell(1,length(obj.stimulus.task.nVar(1).values),1);
					obj.xValues = obj.stimulus.task.nVar(1).values;
				elseif obj.nVars == 2
					raw = cell(length(obj.stimulus.task.nVar(2).values),length(obj.stimulus.task.nVar(1).values),1);
					obj.xValues = obj.stimulus.task.nVar(1).values;
					obj.yValues = obj.stimulus.task.nVar(2).values;
				else
					raw = cell(length(obj.stimulus.task.nVar(2).values),length(obj.stimulus.task.nVar(1).values),length(obj.stimulus.task.nVar(3).values));
					obj.xValues = obj.stimulus.task.nVar(1).values;
					obj.yValues = obj.stimulus.task.nVar(2).values;
					obj.zValues = obj.stimulus.task.nVar(3).values;
				end
			end
			
			for i = 1:length(obj.unit)
				obj.unit{i}.raw = raw;
				obj.unit{i}.trial = cell(opx.totalRuns,1);
				obj.unit{i}.trials = raw;
				obj.unit{i}.map = raw;
				[obj.unit{i}.trials{:}]=deal(zeros);
			end
			
		end
		
		function parseRun(obj,data,num)
			
			if isempty(data)
				return
			end
			
			if obj.thisRun > num
				error('asked to analyse a value smaller than our current parsed run');
			end
	
			l=length(data.trial);
			
			if isempty(num)
				num=l;
			end
			
			startTime = data.trial(num).eventList(1,1);
			endTime = data.trial(num).eventList(end,1);
			raw = data.trial(num).spikeList;
					
			for j=1:obj.units.totalCells
				obj.unit{j}.trial{num}.raw=raw;
				obj.unit{j}.trial{num}.startTime=startTime;
				obj.unit{j}.trial{num}.endTime=endTime;
				s = raw(raw(:,2)==obj.units.chlist(j),:);
				s = s(s(:,3)==obj.units.celllist(j));
				s = (s-startTime)./obj.parameters.timedivisor;
				obj.unit{j}.trial{num}.spikes = s;
				x=obj.sMap(num,1);
				y=obj.sMap(num,2);
				obj.unit{j}.trials{y,x}=obj.unit{j}.trials{y,x}+1;
				obj.unit{j}.raw{y,x} = sort([obj.unit{j}.raw{y,x}; obj.unit{j}.trial{num}.spikes]);
			end
			
			obj.thisRun = obj.thisRun+1;
			
		end
		
		function parseNextRun(data)
			if isempty(data)
				return
			end
			tic
			obj.parseRun(data,obj.thisRun+1);
			toc
		end
		
		function parseAllRuns(obj,data)
			if isempty(data)
				return
			end
			obj.thisRun=1;
			tic
			for i = 1:length(data.trial)
				obj.parseRun(data,i)
			end
			toc
		end
		
				
	end
	
	%=======================================================================
	methods ( Access = private ) % PRIVATE METHODS
	%=======================================================================
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

