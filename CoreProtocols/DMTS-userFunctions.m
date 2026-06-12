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


	end

	methods (Access = private)
		function [p, leftover] = pickAndRemove(me, in)
			p = in(randi(length(in)));
			leftover = setxor(in,p);
		end
	end

end