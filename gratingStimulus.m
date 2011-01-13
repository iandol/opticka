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

	properties (SetAccess = private, GetAccess = public)
		scaleup = 1
	end
	
	properties (Dependent = true, SetAccess = private, GetAccess = public)
		scaledown
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
		%> @brief sfOut Set method
		%>
		% ===================================================================
		function setsfOut(obj,value)
			obj.sfOut = (value/obj.ppd) * obj.scaledown;
		end
		
		% ===================================================================
		%> @brief scaledown Get method
		%>
		% ===================================================================
		function value = get.scaledown(obj)
			value = 1/obj.scaleup;
		end
		
		% ===================================================================
		%> @brief phaseIncrement Get method
		%>
		% ===================================================================
		function phaseIncrement = getphaseIncrement(obj)
			phaseIncrement = (obj.tfOut * 360) * obj.ifi;
			if obj.driftDirectionOut<1
				phaseIncrement = -phaseIncrement;
			end
		end
		
		% ===================================================================
		%> @brief Generate an structure for runExperiment
		%>
		%> @param in runExperiment object for reference
		%> @return stimulus structure.
		% ===================================================================
		function out = setup(obj,rE)
			
			obj.ppd=rE.ppd;
			obj.ifi=rE.screenVals.ifi;
			obj.xCenter=rE.xCenter;
			obj.yCenter=rE.yCenter;
			obj.win=rE.win;
			
			fn = fieldnames(gratingStimulus);
			for j=1:length(fn)
				if isempty(obj.findprop([fn{j} 'Out'])) %create a temporary dynamic property
					p=obj.addprop([fn{j} 'Out']);
					p.Transient = true;%p.Hidden = true;
					if strcmp(fn{j},'sf');p.SetMethod = @setsfOut;end
				end
				obj.([fn{j} 'Out']) = obj.(fn{j}); %copy our property value to our tempory copy
			end
			
			if isempty(obj.findprop('doDots'));p=obj.addprop('doDots');p.Transient=true;end
			if isempty(obj.findprop('doMotion'));p=obj.addprop('doMotion');p.Transient=true;end
			if isempty(obj.findprop('doDrift'));p=obj.addprop('doDrift');p.Transient=true;end
			obj.doDots = [];
			obj.doMotion = [];
			obj.doDrift = [];
			
			if isempty(obj.findprop('rotateMode'));p=obj.addprop('rotateMode');p.Transient=true;end
			if obj.rotationMethod==1
				obj.rotateMode = kPsychUseTextureMatrixForRotation;
			else
				obj.rotateMode = [];
			end
			
			if obj.gabor==1
				obj.scaleup=1;%scaling gabors does weird things!!!
			end
			
			if isempty(obj.findprop('gratingSize'));p=obj.addprop('gratingSize');p.Transient=true;end
			obj.gratingSize = round(obj.ppd*obj.size);
			obj.sfOut = obj.sf; %this should use our attached set method to change it automagically
			if isempty(obj.findprop('phaseIncrement'));p=obj.addprop('phaseIncrement');p.Transient=true;p.GetMethod = @getphaseIncrement;p.Dependent = true;end
			
			obj.delta = (obj.speed*obj.ppd) * obj.ifi;
			[obj.dX obj.dY] = obj.updatePosition(obj.delta,obj.angleOut);
			
			if isempty(obj.findprop('res'));p=obj.addprop('res');p.Transient=true;end
			obj.res = [obj.gratingSize obj.gratingSize].*obj.scaleup;
			
			if obj.mask>0
				obj.maskOut = (floor((obj.ppd*obj.size)/2)*obj.scaleup);
			else
				obj.maskOut = [];
			end
			
			if length(obj.colour) == 3
				obj.colour = [obj.colour obj.alpha];
			end
			
			if isempty(obj.findprop('texture'));p=obj.addprop('texture');p.Transient=true;end
			if obj.gabor==0
				obj.texture = CreateProceduralSineGrating(rE.win, obj.res(1),...
					obj.res(2), obj.colour, obj.maskOut, obj.contrastMult);
			else
				if obj.aspectRatio == 1
					nonSymmetric = 0;
				else
					nonSymmetric = 1;
				end
				obj.texture = CreateProceduralGabor(rE.win, obj.res(1),...
					obj.res(2), nonSymmetric, obj.colour, obj.disableNorm,...
					obj.contrastMult);
			end
			
			obj.dstRect=Screen('Rect',obj.texture);
			obj.dstRect=ScaleRect(obj.dstRect,obj.scaledown,obj.scaledown);
			obj.dstRect=CenterRectOnPoint(obj.dstRect,obj.xCenter,obj.yCenter);
			obj.dstRect=OffsetRect(obj.dstRect,(obj.xPositionOut)*obj.ppd,(obj.yPositionOut)*obj.ppd);
			obj.mvRect=obj.dstRect;
			

			out = obj.toStructure;
			
		end
		
		% ===================================================================
		%> @brief Update an structure for runExperiment
		%>
		%> @param rE runExperiment object for reference
		%> @return stimulus structure.
		% ===================================================================
		function out = update(obj,rE)
			
		end
		
		% ===================================================================
		%> @brief Draw an structure for runExperiment
		%>
		%> @param rE runExperiment object for reference
		%> @return stimulus structure.
		% ===================================================================
		function draw(obj,rE)
			if obj.gabor==0
				Screen('DrawTexture', rE.win, obj.texture, [],obj.mvRect,...
					obj.angleOut, [], [], [], [], obj.rotateMode,...
					[obj.phaseOut,obj.sfOut,obj.contrastOut, 0]);
			else
				Screen('DrawTexture', rE.win, obj.texture, [],obj.mvRect,...
					obj.angleOut, [], [], [], [], kPsychDontDoRotation,...
					[obj.phaseOut, obj.sfOut, obj.spatialConstantOut, obj.contrastOut, obj.aspectRatioOut, 0, 0, 0]);
			end
		end
		
		% ===================================================================
		%> @brief Animate an structure for runExperiment
		%>
		%> @param rE runExperiment object for reference
		%> @return stimulus structure.
		% ===================================================================
		function out = animate(obj,rE)
			
		end
		
		% ===================================================================
		%> @brief Reset an structure for runExperiment
		%>
		%> @param rE runExperiment object for reference
		%> @return stimulus structure.
		% ===================================================================
		function out = reset(obj,rE)
			
		end
		
		
	end %---END PUBLIC METHODS---%
	
end