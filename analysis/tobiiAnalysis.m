classdef tobiiAnalysis < analysisCore
	
	properties
		raw
	end
	
	methods
		function me = tobiiAnalysis(varargin)
			if nargin == 0; varargin.name = ''; end
			me=me@analysisCore(varargin); %superclass constructor
			if all(me.measureRange == [0.1 0.2]) %use a different default to superclass
				me.measureRange = [-0.4 0.8];
			end
			if nargin>0; me.parseArgs(varargin, me.allowedProperties); end
			me.ppd; %cache our initial ppd_
		end
	end
end

