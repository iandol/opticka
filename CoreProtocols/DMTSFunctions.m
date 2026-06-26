% ========================================================================
classdef DMTSFunctions < userFunctions
%> @class myUserFunctions (child of userFunctions)
%> @brief For DMTS task
%>
% ========================================================================

	%% ADD YOUR OWN VARIABLES HERE ↓
	properties
		comment string = "DMTS task functions"
		imageResources string = "~/Code/TaskResources/fractals"
		pfix string = ["A" "B" "C" "D" "E" "F" "G" "H" "I" "J" "K" "L"];
		ps string = "" % folders
		positions % the target + distractor positions
		delayTime = 2 % the delayTime sent to trial
	end

	%% ==================================================================
	methods
	% ===================================================================

		% ===================================================================
		% Class constructor (should be same name as class)
		function me = DMTSFunctions()
		% ===================================================================
			me = me@userFunctions(); %we call the superclass constructor first
			fprintf("===>>> Custom User Functions for DMTS Task Initialised...\n")
			% check the folder is valid
			DMTSFunctions.checkFilePath(me.imageResources);
			% Get 5 equidistant points from fixation
			me.positions = screenManager.equidistantPoints(5, 10, 0, 180, [0 0]);
			tS.DMTSpositions = me.positions; % save a copy of these values
		end

		% ===================================================================
		% Initial setup to run BEFORE the task starts
		function initialSetup(me)
		% ===================================================================
			updateStimuliImages(me);
			updateLocations(me);
			updateDelayTime(me);
		end

		% ===================================================================
		% After the task finishes
		function shutdown(me)
		% ===================================================================
			fprintf("===>>> DMTS Task ended: %s", me.comment);
		end

		%% ADD YOUR FUNCTIONS BELOW ↓

		% ===================================================================
		% set the image stimuli to our randomised folder paths
		function updateStimuliImages(me)
		% ===================================================================	
			if isempty(me.stims); return; end

			randomiseFolders(me);
			
			% sample
			me.stims{1}.filePath = me.ps(1); checkfilePath(me.stims{1})

			% target
			me.stims{2}.filePath = me.stims{1}.filePath; checkfilePath(me.stims{2})

			% distractors
			me.stims{3}.filePath = me.ps(2); checkfilePath(me.stims{3});
			me.stims{4}.filePath = me.ps(3); checkfilePath(me.stims{4});
			me.stims{5}.filePath = me.ps(4); checkfilePath(me.stims{5});
			me.stims{6}.filePath = me.ps(5); checkfilePath(me.stims{6});

			% we need to fix the selection for sample and target
			edit(me.stims, 1:2, 'randomiseSelection', false);
			me.stims{1}.selection = randi(me.stims{1}.nImages);
			me.stims{2}.selection = me.stims{1}.selection;
			% distractors can choose a random image from their folder
			edit(me.stims, 3:6, 'randomiseSelection', true);
		end

		% ===================================================================
		% set the distractor locations for the next trial based on where the target is
		function updateLocations(me)
		% ===================================================================
		 	% get all possible x positions
			idx = contains({me.task.nVar.name},'abstractPosition','IgnoreCase',true);
			list = me.task.nVar(idx).values;
			pos = me.positions;

			% get the current trial index for the target
			thisIdx = me.task.outValues{me.task.totalRuns, idx}; % randomised trial value for XY position for target
			% update target location (this is already done by updateVariables() so may not strictly be needed here)
			updateXY(me.stims{2}, pos(1,thisIdx), pos(2,thisIdx), true);

			% get the x positions that are NOT the target, and assign those to the distractors
			list = setxor(list,thisIdx); % get the x positions that are NOT the target
			[thisIdx, list] = me.pickAndRemove(list); updateXY(me.stims{3}, pos(1,thisIdx), pos(2,thisIdx), true);
			[thisIdx, list] = me.pickAndRemove(list); updateXY(me.stims{4}, pos(1,thisIdx), pos(2,thisIdx), true);
			[thisIdx, list] = me.pickAndRemove(list); updateXY(me.stims{5}, pos(1,thisIdx), pos(2,thisIdx), true);
			[thisIdx, ~]    = me.pickAndRemove(list); updateXY(me.stims{6}, pos(1,thisIdx), pos(2,thisIdx), true);
		end

		% ===================================================================
		% update the delay time for the next trial based on the trial condition
		function updateDelayTime(me)
		% ===================================================================
			idx = contains({me.task.nVar.name},'Delay','IgnoreCase',true);
			me.delayTime = me.task.outValues{me.task.totalRuns, idx}; % randomised trial value for XY position for target
			tS.delayFixTime = me.delayTime;
		end

		% ===================================================================
		% method to get the current delay time
		function delayTime = getDelayTime(me)
		% ===================================================================
			delayTime = me.delayTime;
			t = sprintf('delayTime: %0.2f', me.delayTime);
			addMessage(me.tL, [], [], [], t, [], 'Experimental-note, Delay'); % HED message to store timing parameters in timeLogger
			disp(t);
		end


	end

	%% ==================================================================
	methods (Static)
	% ===================================================================

		% ===================================================================
		% this is a function to check if the file path for our stimuli is valid
		function checkFilePath(fp)
		% ===================================================================
			if ~isfolder(fp)
				error(['The file path for your stimuli is not valid: ' fp]);
			end
		end

	end

	% ===================================================================
	methods (Access = private)
	% ===================================================================
	
		% ===================================================================
		% we keep different families of images in different folders
		% we randomise which folders without replacement are used
		function randomiseFolders(me)
		% ===================================================================
			% random choose 5 folders
			me.ps = [];
			pfix = me.pfix;
			[p, pfix] = me.pickAndRemove(pfix);
			me.ps(1) = fullfile(me.imageResources, p);
			[p, pfix] = me.pickAndRemove(pfix);
			me.ps(2) = fullfile(me.imageResources, p);
			[p, pfix] = me.pickAndRemove(pfix);
			me.ps(3) = fullfile(me.imageResources, p);
			[p, pfix] = me.pickAndRemove(pfix);
			me.ps(4) = fullfile(me.imageResources, p);
			[p, ~] = me.pickAndRemove(pfix);
			me.ps(5) = fullfile(me.imageResources, p);
		end

		% ===================================================================
		% this is a helper function to pick a random element from an array
		% and return the leftover elements
		function [pick, leftover] = pickAndRemove(~,in)
			% ===================================================================
			pick = in(randi(length(in)));
			leftover = setxor(in,pick);
		end

	end

end