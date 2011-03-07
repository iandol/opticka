classdef parseOpxSpikes
	%UNTITLED4 Summary of this class goes here
	%   Detailed explanation goes here
	
	properties
		stimulus
		thisRun = 0
		run
		nVars
		input
		units
		parameters
	end
	
	properties (SetAccess = private, GetAccess = private)
		allowedProperties='^(stimulus)$'
	end
	
	methods
		function obj = parseOpxSpikes(args)
			
		end
		
		function parseRun(obj,data)
			if isempty(data)
				return
			end
			
			l=length(data.trial);
			
			if obj.thisRun == 0
				obj.thisRun = obj.thisRun + 1;
				obj.units
			end
			
			if l > obj.thisRun
				for i = obj.thisRun:l
					obj.run.startTime = data.trial(i).eventList(1);
					obj.run.endTime = data.trial(i).eventList(end);
					for j = 1:nUnits
						
					end
				end
			end
			
			
				
			
		end
		
		function parseAllRuns(obj.data)
			
		end
		
				
	end
	
end

