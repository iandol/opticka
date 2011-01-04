classdef gratingStimulus < baseStimulus
%GRATINGSTIMULUS single grating stimulus, inherits from baseStimulus
%   The current properties are:
%   sf = spatial frequency in degrees
%   tf = temporal frequency
%   angle = angle in degrees
%   rotationMethod = do we rotate the grating texture (1) or the patch
%   itself (0)
%   phase = phase of grating
%   contrast = contrast from 0 - 1
%   mask = use circular mask (1) or not (0)
%   gabor = use a gabor rather than grating

   properties %--------------------PUBLIC PROPERTIES----------%
		family = 'grating'
		type = 'procedural'
		sf = 1
		tf = 1
		angle = 0
		rotationMethod = 1
		phase = 0
		contrast = 0.5
		mask = 1
		gabor = 0
		driftDirection=1
		speed = 0
		moveAngle = 0
		aspectRatio = 1
		disableNorm = 1
		contrastMult = 0.5
		spatialConstant = 1
	end
	
	properties (SetAccess = private, GetAccess = private)
		allowedProperties='^(sf|tf|method|angle|phase|rotationMethod|contrast|mask|gabor|driftDirection|speed|startPosition|aspectRatio|disableNorm|contrastMult|spatialConstant)$';
	end
	
	%=======================================================================
	methods %------------------PUBLIC METHODS
	%=======================================================================
		
		% ===================================================================
		%> @brief Class constructor
		%>
		%> More detailed description of what the constructor does.
		%>
		%> @param args are passed as a structure of properties which is
		%> parsed.
		%> @return instance of class.
		% ===================================================================
		function obj = gratingStimulus(args) 
			%Initialise for superclass, stops a noargs error
			if nargin == 0
				args.family = 'grating';
			end
			obj=obj@baseStimulus(args); %we call the superclass constructor first
			%check we are a grating
			if ~strcmp(obj.family,'grating')
				error('Sorry, you are trying to call a gratingStimulus with a family other than grating');
			end
			%start to build our parameters
			if nargin>0 && isstruct(args)
				fnames = fieldnames(args); %find our argument names
				for i=1:length(fnames);
					if regexp(fnames{i},obj.allowedProperties) %only set if allowed property
						obj.salutation(fnames{i},'Configuring setting in gratingStimulus constructor');
						obj.(fnames{i})=args.(fnames{i}); %we set up the properies from the arguments as a structure
					end
				end
			end
			obj.salutation('constructor','Grating Stimulus initialisation complete');
		end
		
		% ===================================================================
		%> @brief sf Set method
		%>
		% ===================================================================
		function set.sf(obj,value)
			if ~(value > 0)
				value = 0.01;
			end
			obj.sf = value;
			obj.salutation(['set sf: ' num2str(value)],'Custom set method')
		end
		
		% ===================================================================
		%> @brief Generate an structure for runExperiment
		%>
		%> @param in runExperiment object for reference
		%> @return stimulus structure.
		% ===================================================================
		function out = setup(obj,rE)
			
			out.doDots = [];
			out.doMation = [];
			out.doDrift = [];
			
			fn = fieldnames(obj);
			for j=1:length(fn)
				out.(fn{j}) = obj.(fn{j});
			end
			
			if obj.rotationMethod==1
				out.rotateMode = kPsychUseTextureMatrixForRotation;
			else
				out.rotateMode = [];
			end
			
			if out.gabor==0
				out.scaledown=0.25;
				out.scaleup=4;
			else
				out.scaledown=1; %scaling gabors does weird things!!!
				out.scaleup=1;
			end
			
			out.gratingSize = round(rE.ppd*obj.size);
			out.sf = (out.sf/rE.ppd)*out.scaledown;
			%if ts.gabor
				%out.contrast = out.contrast*100;
			%end
			out.spatialConstant = out.spatialConstant*rE.ppd;
			out.phaseincrement = (out.tf * 360) * rE.screenVals.ifi;
			out.delta = (obj.speed*rE.ppd) * rE.screenVals.ifi;
			[out.dX out.dY] = obj.updatePosition(out.delta,out.angle);
			
			if obj.driftDirection < 1
				out.phaseincrement = -out.phaseincrement;
			end
			
% 			if out.tf>0 %we need to say this needs animating
% 				out.doDrift=1;
% 				rE.stimIsDrifting=[rE.stimIsDrifting i];
% 			else
% 				out.doDrift=0;
% 			end
% 			
% 			if out.speed>0 %we need to say this needs animating
% 				out.doMotion=1;
%  				rE.task.stimIsMoving=[rE.task.stimIsMoving i];
% 			else
% 				out.doMotion=0;
% 			end

			out.res = [out.gratingSize out.gratingSize]*out.scaleup;
			
			if obj.mask>0
				out.mask = (floor((rE.ppd*obj.size)/2)*out.scaleup);
			else
				out.mask = [];
			end
			
			if length(out.colour) == 3
				out.colour = [out.colour out.alpha];
			end
			
			if obj.gabor==0
				out.texture = CreateProceduralSineGrating(rE.win, out.res(1),...
					out.res(2), out.colour, out.mask, out.contrastMult);
			else
				if out.aspectRatio == 1
					nonSymmetric = 0;
				else
					nonSymmetric = 1;
				end
				out.texture = CreateProceduralGabor(rE.win, out.res(1),...
					out.res(2), nonSymmetric, out.colour, out.disableNorm,...
					out.contrastMult);
			end
			
			out.dstRect=Screen('Rect',out.texture);
			out.dstRect=ScaleRect(out.dstRect,out.scaledown,out.scaledown);
			out.dstRect=CenterRectOnPoint(out.dstRect,rE.xCenter,rE.yCenter);
			out.dstRect=OffsetRect(out.dstRect,(out.xPosition)*rE.ppd,(out.yPosition)*rE.ppd);
			out.mvRect=out.dstRect;
		end
		
	end %---END PUBLIC METHODS---%
	
end