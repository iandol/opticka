classdef parseOpxSpikes < handle
	%UNTITLED4 Summary of this class goes here
	%   Detailed explanation goes here
	
	properties
		stimulus
	end
	properties (SetAccess = private, GetAccess = public)
		sValues %stimulus list
		sMap %stimulus index
		sIndex %stimulus number sent to be strobed.
		trialTime
		thisRun = 0
		thisIndex
		ts
		run
		nVars
		nTrials
		nRuns
		nDisp
		matrixSize
		units
		parameters
		xValues
		yValues
		zValues
		xLength
		yLength
		zLength
		unit
		error
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
			end
			
			obj.unit = cell(obj.units.totalCells,1);
			
			if isa(opx.stimulus,'runExperiment')
				obj.stimulus = opx.stimulus;
				obj.sValues = obj.stimulus.task.outValues;
				obj.sMap = obj.stimulus.task.outMap;
				obj.sIndex = obj.stimulus.task.outIndex;
				obj.nVars = obj.stimulus.task.nVars;
				obj.nTrials = obj.stimulus.task.nTrials;
				obj.nRuns = obj.stimulus.task.nRuns;
				obj.nDisp = obj.nRuns / obj.nTrials;
				obj.trialTime = obj.stimulus.task.trialTime;
				if obj.nVars == 0
					obj.xLength = 1;
					obj.yLength = 1;
					obj.zLength = 1;
				elseif obj.nVars == 1
					obj.xValues = obj.stimulus.task.nVar(1).values;
					obj.xLength = length(obj.stimulus.task.nVar(1).values);
					obj.yLength = 1;
					obj.zLength = 1;
				elseif obj.nVars == 2
					obj.xValues = obj.stimulus.task.nVar(1).values;
					obj.xLength = length(obj.stimulus.task.nVar(1).values);
					obj.yValues = obj.stimulus.task.nVar(2).values;
					obj.yLength = length(obj.stimulus.task.nVar(2).values);
					obj.zLength = 1;
				else
					obj.xValues = obj.stimulus.task.nVar(1).values;
					obj.xLength = length(obj.stimulus.task.nVar(1).values);
					obj.yValues = obj.stimulus.task.nVar(2).values;
					obj.yLength = length(obj.stimulus.task.nVar(2).values);
					obj.zValues = obj.stimulus.task.nVar(3).values;
					obj.zLength = length(obj.stimulus.task.nVar(3).values);
				end
				
				raw = cell(obj.yLength,obj.xLength,obj.zLength);
				obj.matrixSize = obj.xLength * obj.yLength;
				
				for i = 1:length(obj.unit)
					obj.unit{i}.raw = raw;
					obj.unit{i}.trial = cell(obj.nRuns,1);
					obj.unit{i}.trials = raw;
					[obj.unit{i}.trials{:}]=deal(zeros);
					obj.unit{i}.map = raw;
					obj.unit{i}.label = raw;
					for k = 1:(size(raw,1)*size(raw,2))
						obj.unit{i}.map{k} = k;
						iidx=find(obj.sIndex == k);
						iidx=iidx(1);
						str=num2str(obj.sValues(iidx,:))
						str=regexprep(str,'\s+','|');
						obj.unit{i}.label{k} = str;
					end
				end
			
			end
		end
		
		% ===================================================================
		%> @brief
		%>
		%>
		% ===================================================================
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
			
			obj.thisIndex = obj.stimulus.task.outIndex(num);
			
			startTime = data.trial(num).eventList(1,1);
			endTime = data.trial(num).eventList(end,1);
			raw = data.trial(num).spikeList;
			
			x = 1;
			y = 1;
			z = 1;
			switch obj.nVars
				case 1
					x=obj.sMap(num,1);
				case 2
					x=obj.sMap(num,1);
					y=obj.sMap(num,2);
				case 3
					x=obj.sMap(num,1);
					y=obj.sMap(num,2);
					z=obj.sMap(num,3);
			end
			obj.ts.x = x;
			obj.ts.y = y;
			obj.ts.z = z;
			fprintf('\nRUN: %d = x: %d | y: %d | z: %d > ',num,x,y,z);
			fprintf('map: %d',obj.sMap(num,:));
			fprintf('\n')
					
			for j=1:obj.units.totalCells
				obj.unit{j}.trial{num}.raw=raw;
				obj.unit{j}.trial{num}.startTime=startTime;
				obj.unit{j}.trial{num}.endTime=endTime;
				s = raw(raw(:,2)==obj.units.chlist(j),:);
				s = s(s(:,3)==obj.units.celllist(j));
				s = (s-startTime)./obj.parameters.timedivisor;
				obj.unit{j}.trial{num}.spikes = s;
				obj.unit{j}.trials{y,x,z}=obj.unit{j}.trials{y,x,z}+1;
				obj.unit{j}.raw{y,x,z} = sort([obj.unit{j}.raw{y,x,z}; obj.unit{j}.trial{num}.spikes]);
			end
			
			obj.thisRun = num;
			
		end
		
		% ===================================================================
		%> @brief
		%>
		%>
		% ===================================================================
		function parseNextRun(obj,data)
			try
				if isempty(data)
					return
				end
				obj.parseRun(data,obj.thisRun+1);
			catch ME
				fprintf('parseRun error at: %d',obj.thisRun+1);
				obj.error = ME;
			end
		end
		
		% ===================================================================
		%> @brief
		%>
		%>
		% ===================================================================
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
	
	methods ( Static )
		% ===================================================================
		%> @brief Parse a time*** into bursts
		%>
		%> Prints messages dependent on verbosity
		%> @param in the calling function
		%> @param message the message that needs printing to command window
		% ===================================================================
		function out = parseBursts(in)
			
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

