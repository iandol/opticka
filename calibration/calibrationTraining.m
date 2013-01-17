classdef calibrationTraining < optickaCore
	%UNTITLED Summary of this class goes here
	%   Detailed explanation goes here
	
	properties
		eM = []
		family = 'trainer'
		verbose = true
	end
	
	methods
		function obj = calibrationTraining(obj)
			global lj
			if ~isa(lj,'labJack')
				lj = labJack('readResponse', false, 'verbose', obj.verbose,'name','calibrationTrainer');
			end
			obj.eM = eyelinkManager('name','calibrationTrainer','verbose', obj.verbose);
			run(obj);
		end
		
		function run(obj)
			if isa(obj.eM,'eyelinkManager')
				obj.eM.calibrationStyle = 'HV9';
				obj.eM.modify.calibrationtargetcolour = [1 1 0];
				obj.eM.modify.calibrationtargetsize = 5;
				obj.eM.modify.calibrationtargetwidth = 3;
				obj.eM.modify.waitformodereadytime = 500;
				obj.eM.modify.devicenumber = -1;
				runDemo(obj.eM)
			end
		end
	end
	
end