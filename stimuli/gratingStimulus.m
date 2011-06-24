
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
		%> spatial frequency
		sf = 1
		%> temporal frequency
		tf = 1
		%> rotate the object (0) or the texture (1)?
		rotationMethod = true
		%> phase of grating
		phase = 0
		%> contrast of grating
		contrast = 0.5
		%> use a circular mask?
		mask = true
		%> generate a gabor?
		gabor = false
		%> which direction to drift?
		driftDirection = true
		%> the angle which the direction of the grating patch is moving
		motionAngle = 0
		%> aspect ratio of the gabor
		aspectRatio = 1
		%> should we disable normalisation of the gabor (generally YES)?
		disableNorm = true
		%> Contrast Multiplier, 0.5 gives "standard" 0-1 contrast measure
		contrastMult = 0.5
		%> a divisor for the size for the gaussian envelope for a gabor
		spatialConstant = 6
		%> cosine smoothing sigma in pixels for circular masked gratings
		sigma = 0.0
		%> use colour or alpha channel for smoothing?
		useAlpha = false
		%> use cosine (0) or hermite interpolation (1)
		smoothMethod = true
		%> do we need to correct the phase to be relative to center not edge?
		correctPhase = false
		%> do we generate a square wave?
		squareWave = false
	end
	
	properties (SetAccess = private, GetAccess = public)
		%> scale is used when changing size as an independent variable to keep sf accurate
		scale = 1
		%> the phase amount we need to add for each frame of animation
		phaseIncrement = 0
	end
	
	properties (SetAccess = private, GetAccess = private)
		%> as get methods are slow, we cache sf, then recalculate sf whenever
		%> changeScale event is called
		sfCache = []
		%>to stop a loop between set method and an event
		sfRecurse = false
		%> allowed properties passed to object upon construction
		allowedProperties = ['^(sf|tf|method|angle|motionAngle|phase|rotationMethod|' ... 
			'contrast|mask|gabor|driftDirection|speed|startPosition|aspectRatio|' ... 
			'disableNorm|contrastMult|spatialConstant|sigma|useAlpha|smoothMethod|' ...
			'correctPhase|squareWave)$']
		%>properties to not create transient copies of during setup phase
		ignoreProperties = 'scale|phaseIncrement|disableNorm|correctPhase|gabor|contrastMult|mask'
	end
	
	events
		%> triggered when changing size, so we can change sf etc to compensate
		changeScale 
		%> triggered when changing tf or drift direction
		changePhaseIncrement 
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
			obj.salutation('constructor','Grating Stimulus initialisation complete');
		end
		
		% ===================================================================
		%> @brief Generate an structure for runExperiment
		%>
		%> @param in runExperiment object for reference
		%> @return stimulus structure.
		% ==================================================================
		function setup(obj,rE)
			
			obj.reset;
			if isempty(obj.isVisible)
				obj.show;
			end
			addlistener(obj,'changeScale',@obj.calculateScale);
			addlistener(obj,'changePhaseIncrement',@obj.calculatePhaseIncrement);
			
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
					if strcmp(fn{j},'sf');p.SetMethod = @set_sfOut;end
					if strcmp(fn{j},'tf');p.SetMethod = @set_tfOut;end
					if strcmp(fn{j},'driftDirection');p.SetMethod = @set_driftDirectionOut;end
					if strcmp(fn{j},'size');p.SetMethod = @set_sizeOut;end
					if strcmp(fn{j},'xPosition');p.SetMethod = @set_xPositionOut;end
					if strcmp(fn{j},'yPosition');p.SetMethod = @set_yPositionOut;end
				end
				if isempty(regexp(fn{j},obj.ignoreProperties, 'once'))
					obj.([fn{j} 'Out']) = obj.(fn{j}); %copy our property value to our tempory copy
				end
			end
			
			if isempty(obj.findprop('doDots'));p=obj.addprop('doDots');p.Transient = true;end
			if isempty(obj.findprop('doMotion'));p=obj.addprop('doMotion');p.Transient = true;end
			if isempty(obj.findprop('doDrift'));p=obj.addprop('doDrift');p.Transient = true;end
			if isempty(obj.findprop('doFlash'));p=obj.addprop('doFlash');p.Transient = true;end
			obj.doDots = false;
			obj.doMotion = false;
			obj.doDrift = false;
			obj.doFlash = false;
			
			if obj.tf > 0;obj.doDrift = true;end
			if obj.speed > 0; obj.doMotion = true;end
			
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
			end
			
			if isempty(obj.findprop('driftPhase'));p=obj.addprop('driftPhase');p.Transient=true;end
			if obj.correctPhase
				ps=obj.calculatePhase;
				obj.driftPhase=obj.phaseOut-ps;
			else
				obj.driftPhase=obj.phaseOut;
			end
			
			if isempty(obj.findprop('res'));p=obj.addprop('res');p.Transient=true;end
			obj.res = [obj.gratingSize obj.gratingSize];
			
			if obj.mask == true
				obj.mask = floor((obj.ppd*obj.size)/2);
			else
				obj.mask = false;
			end
			
			if isempty(obj.findprop('texture'));p=obj.addprop('texture');p.Transient=true;end
			
			if obj.gabor==false
				if obj.squareWave == true
					obj.texture = CreateProceduralSineSquareGrating(obj.win, obj.res(1),...
						obj.res(2), obj.colourOut, obj.mask, obj.contrastMult);
				else
					if obj.sigmaOut > 0
						obj.texture = CreateProceduralSineSmoothedGrating(obj.win, obj.res(1), ...
							obj.res(2), obj.colourOut, obj.mask, obj.contrastMult, obj.sigmaOut, ...
							obj.useAlpha, obj.smoothMethod);
					else
						obj.texture = CreateProceduralSineGrating(obj.win, obj.res(1),...
							obj.res(2), obj.colourOut, obj.mask, obj.contrastMult);
					end
				end
			else
				if obj.aspectRatio == 1
					nonSymmetric = 0;
				else
					nonSymmetric = 1;
				end
				obj.texture = CreateProceduralGabor(rE.win, obj.res(1),...
					obj.res(2), nonSymmetric, obj.colourOut, obj.disableNorm,...
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
			if obj.correctPhase
				ps=obj.calculatePhase;
				obj.driftPhase=obj.phaseOut-ps;
			else
				obj.driftPhase=obj.phaseOut;
			end
		end
		
		% ===================================================================
		%> @brief Draw an structure for runExperiment
		%>
		%> @param rE runExperiment object for reference
		%> @return stimulus structure.
		% ===================================================================
		function draw(obj)
			if obj.isVisible == true
				if obj.gabor == false
					Screen('DrawTexture', obj.win, obj.texture, [],obj.mvRect,...
						obj.angleOut, [], [], [], [], obj.rotateMode,...
						[obj.driftPhase, obj.sfOut, obj.contrastOut, obj.sigmaOut]);
				else
					%2 = kPsychDontDoRotation
					Screen('DrawTexture', obj.win, obj.texture, [],obj.mvRect,...
						obj.angleOut, [], [], [], [], 2,...
						[obj.driftPhase, obj.sfOut, obj.spatialConstantOut, obj.contrastOut, obj.aspectRatioOut, 0, 0, 0]); 
				end
			end
		end
		
		% ===================================================================
		%> @brief Animate an structure for runExperiment
		%>
		%> @param rE runExperiment object for reference
		%> @return stimulus structure.
		% ===================================================================
		function animate(obj)
			if obj.doMotion == true
				obj.mvRect=OffsetRect(obj.mvRect,obj.dX,obj.dY);
			end
			if obj.doDrift == true
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
			if obj.mask > 0
				obj.mask = true;
			end
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
		
		% ===================================================================
		%> @brief calculate phase offset
		%>
		% ===================================================================
		function phase = calculatePhase(obj)
			phase = 0;
			if obj.correctPhase > 0
				ppd = obj.ppd;
				size = (obj.sizeOut/2); %divide by 2 to get the 0 point
				sfTmp = (obj.sfOut/obj.scale)*obj.ppd;
				md = size / (ppd/sfTmp);
				md=md-floor(md);
				phase = (360*md);
			end
		end
		
	end %---END PUBLIC METHODS---%
	
	%=======================================================================
	methods ( Access = private ) %-------PRIVATE METHODS-----%
	%=======================================================================
		
		% ===================================================================
		%> @brief sfOut Set method
		%>
		% ===================================================================
		function set_sfOut(obj,value)
			if obj.sfRecurse == false
				obj.sfCache = (value/obj.ppd);
				obj.sfOut = obj.sfCache * obj.scale;
			else
				obj.sfOut = value;
				obj.sfRecurse = false;
			end
			%fprintf('\nSET SFOut: %d | cachce: %d | in: %d\n', obj.sfOut, obj.sfCache, value);
		end
		
		% ===================================================================
		%> @brief tfOut Set method
		%>
		% ===================================================================
		function set_tfOut(obj,value)
			obj.tfOut = value;
			notify(obj,'changePhaseIncrement');
		end
		
		% ===================================================================
		%> @brief driftDirectionOut Set method
		%>
		% ===================================================================
		function set_driftDirectionOut(obj,value)
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
			obj.sfRecurse = true;
			obj.sfOut = obj.sfCache * obj.scale;
			%fprintf('\nCalculate SFOut: %d | in: %d | scale: %d\n', obj.sfOut, obj.sfCache, obj.scale);
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
					if obj.driftDirectionOut == false
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
		function set_sizeOut(obj,value)
			obj.sizeOut = value*obj.ppd;
			notify(obj,'changeScale');
		end
		
		% ===================================================================
		%> @brief xPositionOut Set method
		%>
		% ===================================================================
		function set_xPositionOut(obj,value)
			obj.xPositionOut = value*obj.ppd;
			if ~isempty(obj.texture);obj.setRect;end
		end
		
		% ===================================================================
		%> @brief yPositionOut Set method
		%>
		% ===================================================================
		function set_yPositionOut(obj,value)
			obj.yPositionOut = value*obj.ppd;
			if ~isempty(obj.texture);obj.setRect;end
		end
		
		% ===================================================================
		%> @brief setRect
		%>  setRect makes the PsychRect based on the texture and screen values
		% ===================================================================
		function setRect(obj)
			if isempty(obj.findprop('motionAngleOut'));
				[sx sy]=pol2cart(obj.d2r(obj.motionAngle),obj.startPosition);
			else
				[sx sy]=pol2cart(obj.d2r(obj.motionAngleOut),obj.startPosition);
			end
			obj.dstRect=Screen('Rect',obj.texture);
			obj.dstRect=ScaleRect(obj.dstRect,obj.scale,obj.scale);
			obj.dstRect=CenterRectOnPoint(obj.dstRect,obj.xCenter,obj.yCenter);
			if isempty(obj.findprop('xPositionOut'));
				obj.dstRect=OffsetRect(obj.dstRect,(obj.xPosition)*obj.ppd,(obj.yPosition)*obj.ppd);
			else
				obj.dstRect=OffsetRect(obj.dstRect,obj.xPositionOut+(sx*obj.ppd),obj.yPositionOut+(sy*obj.ppd));
			end
			obj.mvRect=obj.dstRect;
		end
		
	end
end