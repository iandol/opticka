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
		ps string = ""
	end

	methods

		% Class constructor (should be same name as class)
		function me = DMTSFunctions()
			randomiseFolders(me)
		end

		%% ADD YOUR FUNCTIONS BELOW ↓

		% we keep different families of images in different folders
		% we randomise which folders without replacement are used
		function randomiseFolders(me)
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

		% set the image stimuli to our randomised folder paths
		function updateStimuliImages(me)
			if isempty(me.stims); return; end

			randomiseFolders(me);
			
			%sample
			me.stims{1}.filePath = me.ps(1);
			checkFilePath(me.stims{1}.filePath);

			%target
			me.stims{2}.filePath = me.stims{1}.filePath;
			checkFilePath(me.stims{2}.filePath);

			% distractors
			me.stims{3}.filePath = me.ps(2); checkFilePath(me.stims{3}.filePath);
			me.stims{4}.filePath = me.ps(3); checkFilePath(me.stims{4}.filePath);
			me.stims{5}.filePath = me.ps(4); checkFilePath(me.stims{5}.filePath);
			me.stims{6}.filePath = me.ps(5); checkFilePath(me.stims{6}.filePath);

			% we need to fix the selection for sample and target
			edit(me.stims, 1:2, 'randomiseSelection', false);
			me.stims{1}.selection = randi(me.stims{1}.nImages);
			me.stims{2}.selection = me.stims{1}.selection;
			% distractors can choose a random image from their folder
			edit(me.stims, 3:6, 'randomiseSelection', true);
		end


	end

	methods (Access = private)
		
		function [p, leftover] = pickAndRemove(me, in)
			p = in(randi(length(in)));
			leftover = setxor(in,p);
		end
	end

end