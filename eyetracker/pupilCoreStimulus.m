classdef pupilCoreStimulus < handle
	%UNTITLED Summary of this class goes here
	%   Detailed explanation goes here

	properties
		type = 'calibration'
		family = 'calibration'
		size = 8
		sM = []
		screenVals = []
		ppd = 36
		xPositionOut = 0
		yPositionOut = 0
		stop = false
		isVisible = true
	end

	methods
		function me = pupilCoreStimulus()
			
		end

		function setup(me,sM)
			me.sM = sM;
			if ~sM.isOpen; error('Screen needs to be Open!'); end
			me.ppd = sM.ppd;
			me.screenVals = sM.screenVals;
		end

		function draw(me,varargin)
			if me.isVisible
				me.sM.drawPupilCoreMarker(me.size,me.xPositionOut,me.yPositionOut,me.stop);
			end
		end

		function animate(me)

		end

		function update(me)

		end

		function reset(me)
			me.sM = [];
			me.ppd = 36;
		end

		function hide(me)
			me.isVisible = false;
		end

		function show(me)
			me.isVisible = true;
		end

		function set.xPositionOut(me, value)
				me.xPositionOut = value;
			end
		function set.yPositionOut(me,value)
			me.yPositionOut = value; 
		end
	end
end