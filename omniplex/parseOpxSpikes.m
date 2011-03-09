classdef parseOpxSpikes < handle
	%UNTITLED4 Summary of this class goes here
	%   Detailed explanation goes here
	
	properties
		stimulus
		thisRun = 0
		run
		nVars
		units
		parameters
		xValues
		yValues
		zValues
		raw
	end
	
	properties (SetAccess = private, GetAccess = private)
		allowedProperties='^(stimulus)$'
	end
	
	methods
		function obj = parseOpxSpikes(args)
			
		end
		
		function initialize(obj,opx)
			if isa(opx,'opxOnline')
				obj.units = opx.units;
				obj.parameters = opx.parameters;
			end
			
			if isa(opx.stimulus,'runExperiment')
				obj.stimulus = opx.stimulus;
				obj.nVars = obj.stimulus.task.nVars;
				if obj.nVars == 0
					obj.raw = cell(1,1,1);
				elseif obj.nVars == 1
					obj.raw = cell(1,length(obj.stimulus.task.nVar(1).values),1);
					obj.xValues = obj.stimulus.task.nVar(1).values;
				elseif obj.nVars == 2
					obj.raw = cell(length(obj.stimulus.task.nVar(2).values),length(obj.stimulus.task.nVar(1).values),1);
					obj.xValues = obj.stimulus.task.nVar(1).values;
					obj.yValues = obj.stimulus.task.nVar(2).values;
				else
					obj.raw = cell(length(obj.stimulus.task.nVar(2).values),length(obj.stimulus.task.nVar(1).values),length(obj.stimulus.task.nVar(3).values));
					obj.xValues = obj.stimulus.task.nVar(1).values;
					obj.yValues = obj.stimulus.task.nVar(2).values;
					obj.zValues = obj.stimulus.task.nVar(3).values;
				end
			end
			
			

		end
		
		
		function parseRun(obj,data)
			if isempty(data)
				return
			end
			
			l=length(data.trial);
			
			if obj.thisRun == 0
				obj.thisRun = obj.thisRun + 1;
				obj.units = data.units;
				obj.parameters = data.parameters;
			end
			
			if l > obj.thisRun
				for i = obj.thisRun:l
					obj.run.startTime = data.trial(i).eventList(1);
					obj.run.endTime = data.trial(i).eventList(end);
					obj.run.raw = data.trial(i).spikeList;
					for j = 1:obj.units.totalCells
						
					end
				end
			end
			
			
				
			
		end
		
		function parseAllRuns(obj,data)
		
		end
		
				
	end
	
end

