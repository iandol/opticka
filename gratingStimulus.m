% ========================================================================
%> @brief single grating stimulus, inherits from baseStimulus
%> GRATINGSTIMULUS single grating stimulus, inherits from baseStimulus
%>   The current properties are:
%>   sf = spatial frequency in degrees
%>   tf = temporal frequency
%>   angle = angle in degrees
%>   rotationMethod = do we rotate the grating texture (1) or the patch
%>   itself (0)
%>   phase = phase of grating
%>   contrast = contrast from 0 - 1
%>   mask = use circular mask (1) or not (0)
%>   gabor = use a gabor rather than grating
% ========================================================================
classdef gratingStimulus < baseStimulus
	
	properties %--------------------PUBLIC PROPERTIES----------%
		family = 'grating'
		type = 'procedural'
		sf = 1
		tf = 1
		rotationMethod = 1
		phase = 0
		contrast = 0.5
		mask = 1
		gabor = 0
		driftDirection=1
		moveAngle = 0
		aspectRatio = 1
		disableNorm = 1
		contrastMult = 0.5
		% a divisor for the size in pixels for the gaussian envelope for a gabor
		spatialConstant = 6
		scale = 1
	end
	
	properties (SetAccess = private, GetAccess = public)
		phaseIncrement = 0
	end
	
	properties (SetAccess = private, GetAccess = private)
		allowedProperties='^(sf|tf|method|angle|phase|rotationMethod|contrast|mask|gabor|driftDirection|speed|startPosition|aspectRatio|disableNorm|contrastMult|spatialConstant)$';
		ignoreProperties='phaseIncrement|disableNorm|gabor|contrastMult|mask'
	end
	
	events
		changeScale %better performance than dependent property
		changePhaseIncrement %better performance than dependent property
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
			obj.ignoreProperties = ['^(' obj.ignorePropertiesBase '|' obj.ignoreProperties ')$'];
			addlistener(obj,'changeScale',@obj.calculateScale);
			addlistener(obj,'changePhaseIncrement',@obj.calculatePhaseIncrement);
			obj.salutation('constructor','Grating Stimulus initialisation complete');
		end
		
		% ===================================================================
		%> @brief Generate an structure for runExperiment
		%>
		%> @param in runExperiment object for reference
		%> @return stimulus structure.
		% ==================================================================
		function setup(obj,rE)

			obj.ppd=rE.ppd;
			obj.ifi=rE.screenVals.ifi;
			obj.xCenter=rE.xCenter;
			obj.yCenter=rE.yCenter;
			obj.win=rE.win;

			obj.texture = []; %we need to reset this

			fn = fieldnames(gratingStimulus);
			for j=1:length(fn)
				if isempty(obj.findprop([fn{j} 'Out'])) && isempty(regexp(fn{j},obj.ignoreProperties, 'once')) %create a temporary dynamic property
					p=obj.addprop([fn{j} 'Out']);
					p.Transient = true;%p.Hidden = true;
					if strcmp(fn{j},'sf');p.SetMethod = @setsfOut;p.GetMethod = @getsfOut;end
					if strcmp(fn{j},'tf');p.SetMethod = @settfOut;end
					if strcmp(fn{j},'driftDirection');p.SetMethod = @setdriftDirectionOut;end
					if strcmp(fn{j},'size');p.SetMethod = @setsizeOut;end
					if strcmp(fn{j},'xPosition');p.SetMethod = @setxPositionOut;end
					if strcmp(fn{j},'yPosition');p.SetMethod = @setyPositionOut;end
				end
				if isempty(regexp(fn{j},obj.ignoreProperties, 'once'))
					obj.([fn{j} 'Out']) = obj.(fn{j}); %copy our property value to our tempory copy
				end
			end
			
			if isempty(obj.findprop('doDots'));p=obj.addprop('doDots');p.Transient = true;end
			if isempty(obj.findprop('doMotion'));p=obj.addprop('doMotion');p.Transient = true;end
			if isempty(obj.findprop('doDrift'));p=obj.addprop('doDrift');p.Transient = true;end
			if isempty(obj.findprop('doFlash'));p=obj.addprop('doFlash');p.Transient = true;end
			obj.doDots = 0;
			obj.doMotion = 0;
			obj.doDrift = 0;
			obj.doFlash = 0;
			
			if obj.tf > 0;obj.doDrift = 1;end
			if obj.speed > 0; obj.doMotion = 1;end
			
			if isempty(obj.findprop('rotateMode'));p=obj.addprop('rotateMode');p.Transient=true;end
			if obj.rotationMethod==1
				obj.rotateMode = kPsychUseTextureMatrixForRotation;
			else
				obj.rotateMode = [];
			end
			
			if isempty(obj.findprop('gratingSize'));p=obj.addprop('gratingSize');p.Transient=true;end
			obj.gratingSize = round(obj.ppd*obj.size);
			
			if isempty(obj.findprop('phaseIncrement'));
				p=obj.addprop('phaseIncrement');
				p.Transient=true;p.GetMethod = @getphaseIncrement;p.Dependent = true;
			end
			
			if isempty(obj.findprop('driftPhase'));p=obj.addprop('driftPhase');p.Transient=true;end
			obj.driftPhase = obj.phaseOut;
			
			if isempty(obj.findprop('res'));p=obj.addprop('res');p.Transient=true;end
			obj.res = [obj.gratingSize obj.gratingSize];
			
			if obj.mask>0
				obj.mask = floor((obj.ppd*obj.size)/2);
			else
				obj.mask = [];
			end
			
			if isempty(obj.findprop('texture'));p=obj.addprop('texture');p.Transient=true;end
			if obj.gabor==0
				obj.texture = CreateProceduralSineGrating(obj.win, obj.res(1),...
					obj.res(2), obj.colour, obj.mask, obj.contrastMult);
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
			
			obj.setRect();
			
		end
		
		% ===================================================================
		%> @brief Update an structure for runExperiment
		%>
		%> @param rE runExperiment object for reference
		%> @return stimulus structure.
		% ===================================================================
		function update(obj)
			obj.setRect();
			obj.driftPhase=obj.phaseOut;
		end
		
		% ===================================================================
		%> @brief Draw an structure for runExperiment
		%>
		%> @param rE runExperiment object for reference
		%> @return stimulus structure.
		% ===================================================================
		function draw(obj)
			if obj.gabor==0
				Screen('DrawTexture', obj.win, obj.texture, [],obj.mvRect,...
					obj.angleOut, [], [], [], [], obj.rotateMode,...
					[obj.driftPhase,obj.sfOut,obj.contrastOut, 0]);
			else
				Screen('DrawTexture', obj.win, obj.texture, [],obj.mvRect,...
					obj.angleOut, [], [], [], [], kPsychDontDoRotation,...
					[obj.driftPhase, obj.sfOut, obj.spatialConstantOut, obj.contrastOut, obj.aspectRatioOut, 0, 0, 0]);
			end
		end
		
		% ===================================================================
		%> @brief Animate an structure for runExperiment
		%>
		%> @param rE runExperiment object for reference
		%> @return stimulus structure.
		% ===================================================================
		function animate(obj)
			if obj.doMotion == 1
				obj.mvRect=OffsetRect(obj.mvRect,obj.dX,obj.dY);
			end
			if obj.doDrift == 1
				obj.driftPhase = obj.driftPhase + obj.phaseIncrement;
			end
		end
		
		% ===================================================================
		%> @brief Reset an structure for runExperiment
		%>
		%> @param rE runExperiment object for reference
		%> @return stimulus structure.
		% ===================================================================
		function reset(obj)
			obj.texture=[];
			obj.removeTmpProperties;
		end
		
		% ===================================================================
		%> @brief sf Set method
		%>
		% ===================================================================
		function set.sf(obj,value)
			if value <= 0
				value = 0.05;
			end
			obj.sf = value;
			obj.salutation(['set sf: ' num2str(value)],'Custom set method')
		end
		
	end %---END PUBLIC METHODS---%
	
	%=======================================================================
	methods ( Access = private ) %-------PRIVATE METHODS-----%
	%=======================================================================
		
		% ===================================================================
		%> @brief sfOut Set method
		%>
		% ===================================================================
		function setsfOut(obj,value)
			obj.sfOut = (value/obj.ppd);
		end
		
		% ===================================================================
		%> @brief sfOut Get method
		%> Spatial frequency depends on whether the grating has been resized, so
		%> we need to take this into account by using the scale value that is set
		%> when sizeOut is changed
		% ===================================================================
		function sfOut = getsfOut(obj)
			sfOut = obj.sfOut * obj.scale;
		end
		
		% ===================================================================
		%> @brief sfOut Set method
		%>
		% ===================================================================
		function settfOut(obj,value)
			obj.tfOut = value;
			notify(obj,'changePhaseIncrement');
		end
		
		% ===================================================================
		%> @brief sfOut Set method
		%>
		% ===================================================================
		function setdriftDirectionOut(obj,value)
			obj.driftDirectionOut = value;
			notify(obj,'changePhaseIncrement');
		end
		
		% ===================================================================
		%> @brief calculateScale 
		%> Use an event to recalculate scale as get method is slower (called
		%> many more times), than an event which is only called on update
		% ===================================================================
		function calculateScale(obj,~,~)
			obj.scale = obj.sizeOut/(obj.size*obj.ppd);
			obj.spatialConstantOut=obj.sizeOut/obj.spatialConstant;
		end
		
		% ===================================================================
		%> @brief calculatePhaseIncrement
		%> Use an event to recalculate as get method is slower (called
		%> many more times), than an event which is only called on update
		% ===================================================================
		function calculatePhaseIncrement(obj,~,~)
			if ~isempty(obj.findprop('tfOut'))
				obj.phaseIncrement = (obj.tfOut * 360) * obj.ifi;
				if ~isempty(obj.findprop('driftDirectionOut'))
					if obj.driftDirectionOut<1
						obj.phaseIncrement = -obj.phaseIncrement;
					end
				end
			end
		end
		
		% ===================================================================
		%> @brief sizeOut Set method
		%> we also need to change scale when sizeOut is changed, used for both
		%setting sfOut and the dstRect properly
		% ===================================================================
		function setsizeOut(obj,value)
			obj.sizeOut = value*obj.ppd;
			notify(obj,'changeScale');
		end
		
		% ===================================================================
		%> @brief xPositionOut Set method
		%>
		% ===================================================================
		function setxPositionOut(obj,value)
			obj.xPositionOut = value*obj.ppd;
			if ~isempty(obj.texture);obj.setRect;end
		end
		
		% ===================================================================
		%> @brief yPositionOut Set method
		%>
		% ===================================================================
		function setyPositionOut(obj,value)
			obj.yPositionOut = value*obj.ppd;
			if ~isempty(obj.texture);obj.setRect;end
		end
		
		% ===================================================================
		%> @brief setRect
		%>  setRect makes the PsychRect based on the texture and screen values
		% ===================================================================
		function setRect(obj)
			if isempty(obj.findprop('angleOut'));
				[dx dy]=pol2cart(obj.d2r(obj.angle),obj.startPosition);
			else
				[dx dy]=pol2cart(obj.d2r(obj.angleOut),obj.startPosition);
			end
			obj.dstRect=Screen('Rect',obj.texture);
			obj.dstRect=ScaleRect(obj.dstRect,obj.scale,obj.scale);
			obj.dstRect=CenterRectOnPoint(obj.dstRect,obj.xCenter,obj.yCenter);
			if isempty(obj.findprop('xPositionOut'));
				obj.dstRect=OffsetRect(obj.dstRect,(obj.xPosition)*obj.ppd,(obj.yPosition)*obj.ppd);
			else
				obj.dstRect=OffsetRect(obj.dstRect,obj.xPositionOut+(dx*obj.ppd),obj.yPositionOut+(dy*obj.ppd));
			end
			obj.mvRect=obj.dstRect;
		end
		
	end
end