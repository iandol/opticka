% ========================================================================
%> @brief target inducer stimulus, inherits from baseStimulus
%>
%>
%> Copyright ©2014-2022 Ian Max Andolina — released: LGPL3, see LICENCE.md
% ========================================================================
classdef targetInducerStimulus < baseStimulus
	
	properties %--------------------PUBLIC PROPERTIES----------%
		%> family type
		type = 'sinusoid'
		%> spatial frequency
		sf = 1
		%> temporal frequency
		tf = 1
		%>inducer height multiplier
		inducerHeight = 6
		%> inducer position
		inducerPosition = RectTop
		%> rotate the object (0/false) or the texture (1/true)?
		rotationMethod = true
		%> phase of grating
		phase = 0
		%> phase offset between target and inducer
		phaseOffset = 0
		%> contrast of grating
		contrast = 0.5
		%> contrast of inducer
		inducerContrast = 0.5
		%> use a circular mask?
		mask = false
		%> reverse the drift direction?
		driftDirection = false
		%> the angle which the direction of the grating patch is moving
		direction = 0
		%> Contrast Multiplier, 0.5 gives "standard" 0-1 contrast range
		contrastMult = 0.5
		%> do we need to correct the phase to be relative to center not edge?
		correctPhase = false
		%> reverse phase of grating X times per second?
		phaseReverseTime = 0
		%> What phase to use for reverse?
		phaseOfReverse = 180
		%> cosine smoothing sigma in pixels for circular masked gratings
		sigma = 0.0
		%> use colour or alpha channel for smoothing?
		useAlpha = false
		%> use cosine (0) or hermite interpolation (1)
		smoothMethod = true
		%> aspect ratio of the grating
		aspectRatio = 1;
	end
	
	properties (SetAccess = protected, GetAccess = public)
		%stimulus family
		family = 'targetInducer'
		%> scale is used when changing size as an independent variable to keep sf accurate
		scale = 1
		%> the phase amount we need to add for each frame of animation
		phaseIncrement = 0
	end
	
	properties (SetAccess = private, GetAccess = public, Hidden = true)
		typeList = {'sinusoid';'square'}
	end
	
	properties (SetAccess = protected, GetAccess = protected)
		%> as get methods are slow, we cache sf, then recalculate sf whenever
		%> changeScale event is called
		sfCache = []
		%>to stop a loop between set method and an event
		sfRecurse = false
		%> allowed properties passed to object upon construction
		allowedProperties = {'sf', 'tf', 'sfi', 'tfi', 'angle', 'direction', 'phase', 'phasei', 'rotationMethod', ...
			'inducerHeight', 'inducerPosition', 'inducerContrast', 'phaseOffset' ...
			'contrast', 'mask', 'driftDirection', 'speed', 'startPosition', 'aspectRatio', ... 
			'contrastMult', 'sigma', 'useAlpha', 'smoothMethod', ...
			'correctPhase', 'phaseReverseTime', 'phaseOfReverse'}
		%>properties to not create transient copies of during setup phase
		ignoreProperties = {'name', 'type', 'scale', 'phaseIncrement', 'correctPhase', 'contrastMult', 'mask'}
		%> how many frames between phase reverses 
		phaseCounter = 0
		%> do we generate a square wave?
		squareWave = false
		%> do we generate a square wave?
		gabor = false
		%> mask value
		maskValue
	end
	
	events (ListenAccess = 'protected', NotifyAccess = 'protected') %only this class can access these
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
		function obj = targetInducerStimulus(varargin)
			%Initialise for superclass, stops a noargs error
			if nargin == 0
				varargin.family = 'targetInducer';
			end
			
			obj=obj@baseStimulus(varargin); %we call the superclass constructor first
			
			if nargin>0
				obj.parseArgs(varargin, obj.allowedProperties);
			end
			
			obj.ignoreProperties = ['^(' obj.ignorePropertiesBase '|' obj.ignoreProperties ')$'];
			obj.salutation('constructor method','Stimulus initialisation complete');
		end
		
		% ===================================================================
		%> @brief Setup this object in preperation for use
		%> When displaying a stimulus object, the main properties that are to be
		%> modified are copied into cache copies of the property, both to convert from 
		%> visual description (c/d, Hz, degrees) to
		%> computer metrics, and to be animated and modified as independant
		%> variables. So xPosition is copied to xPositionOut and converyed from
		%> degrees to pixels. The animation and drawing functions use these modified
		%> properties, and when they are updated, for example to change to a new
		%> xPosition, internal methods ensure reconversion and update any dependent
		%> properties. This method initialises the object for display.
		%>
		%> @param rE runExperiment object for reference
		% ===================================================================
		function setup(obj,sM)
			
			obj.reset; %reset it back to its initial state
			obj.inSetup = true;
			if isempty(obj.isVisible)
				obj.show;
			end
			addlistener(obj,'changeScale',@obj.calculateScale); %use an event to keep scale accurate
			addlistener(obj,'changePhaseIncrement',@obj.calculatePhaseIncrement);
			
			obj.sM = sM;
			obj.ppd=sM.ppd;

			obj.texture = []; %we need to reset this

			fn = sort(fieldnames(me));
			for j=1:numel(fn)
				if ~matches(fn{j}, me.ignoreProperties)%create a temporary dynamic property
					p = addprop(me, [fn{j} 'Out']);
					if strcmp(fn{j},'sf');p.SetMethod = @set_sfOut;end
					if strcmp(fn{j},'tf');p.SetMethod = @set_tfOut;end
					if strcmp(fn{j},'driftDirection');p.SetMethod = @set_driftDirectionOut;end
					if strcmp(fn{j},'size');p.SetMethod = @set_sizeOut;end
					if strcmp(fn{j},'xPosition');p.SetMethod = @set_xPositionOut;end
					if strcmp(fn{j},'yPosition');p.SetMethod = @set_yPositionOut;end
					obj.([fn{j} 'Out']) = obj.(fn{j}); %copy our property value to our tempory copy
				end
			end
			
			addRuntimeProperties(me);
			
			if isempty(obj.findprop('rotateMode'));p=obj.addprop('rotateMode');p.Transient=true;p.Hidden=true;end
			if obj.rotationMethod==1
				obj.rotateMode = kPsychUseTextureMatrixForRotation;
			else
				obj.rotateMode = [];
			end
			
			if isempty(obj.findprop('gratingSize'));p=obj.addprop('gratingSize');p.Transient=true;p.Hidden=true;end
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
			if obj.aspectRatio < 1
				obj.res = round([obj.gratingSize*obj.aspectRatio obj.gratingSize]);
			else
				obj.res = round([obj.gratingSize*obj.aspectRatio obj.gratingSize]);
			end
			
			if obj.mask == true
				obj.maskValue = floor((obj.ppd*obj.size)/2);
			else
				obj.maskValue = [];
			end
			
			if isempty(obj.findprop('texture'));p=obj.addprop('texture');p.Transient=true;end
			
			if obj.phaseReverseTime > 0
				obj.phaseCounter = round(obj.phaseReverseTime / obj.sM.screenVals.ifi);
			end
			
			if strcmpi(obj.type,'square')
				obj.texture{1} = CreateProceduralSineSquareGrating(obj.sM.win, obj.res(1),...
					obj.res(2), obj.colourOut, obj.mask, obj.contrastMult);
				obj.texture = CreateProceduralSineSquareGrating(obj.sM.win, obj.res(1),...
					obj.res(2)*obj.inducerHeight, obj.colourOut, obj.mask, obj.contrastMult);
			else
				if obj.sigmaOut > 0
					obj.texture{1} = CreateProceduralSineSmoothedGrating(obj.sM.win, obj.res(1), ...
						obj.res(2), obj.colourOut, obj.mask, obj.contrastMult, obj.sigmaOut, ...
						obj.useAlpha, obj.smoothMethod);
					obj.texture{2} = CreateProceduralSineSmoothedGrating(obj.sM.win, obj.res(1), ...
						obj.res(2)*obj.inducerHeight, obj.colourOut, obj.mask, obj.contrastMult, obj.sigmaOut, ...
						obj.useAlpha, obj.smoothMethod);
				else
					obj.texture{1} = CreateProceduralSineGrating(obj.sM.win, obj.res(1),...
						obj.res(2), obj.colourOut, obj.mask, obj.contrastMult);
					obj.texture{2} = CreateProceduralSineGrating(obj.sM.win, obj.res(1),...
						obj.res(2)*obj.inducerHeight, obj.colourOut, obj.mask, obj.contrastMult);
				end
			end
			
			obj.inSetup = false;
			obj.setRect();

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
			function set_tfOut(obj,value)
				obj.tfOut = value;
				notify(obj,'changePhaseIncrement');
			end
			function set_driftDirectionOut(obj,value)
				obj.driftDirectionOut = value;
				notify(obj,'changePhaseIncrement');
			end
			function set_sizeOut(obj,value)
				obj.sizeOut = value*obj.ppd;
				notify(obj,'changeScale');
			end
			function set_xPositionOut(obj,value)
				obj.xPositionOut = value*obj.ppd;
				if ~isempty(obj.texture);obj.setRect;end
			end
			function set_yPositionOut(obj,value)
				obj.yPositionOut = value*obj.ppd;
				if ~isempty(obj.texture);obj.setRect;end
			end
			
		end
		
		% ===================================================================
		%> @brief Update this stimulus object for display
		%>
		% ===================================================================
		function update(obj)
			resetTicks(obj);
			if obj.correctPhase
				ps=obj.calculatePhase;
				obj.driftPhase=obj.phaseOut-ps;
			else
				obj.driftPhase=obj.phaseOut;
			end
			obj.setRect();
		end
		
		% ===================================================================
		%> @brief Draw this stimulus object for display
		%>
		%> 
		% ===================================================================
		function draw(obj)
			if obj.isVisible == true && obj.tick > obj.delayTicks
				
				dstRect = Screen('Rect',obj.texture{2});
				dstRect = AlignRect(dstRect, obj.mvRect, 'left');
				dstRect = AdjoinRect(dstRect, obj.mvRect, obj.inducerPosition);
				
				Screen('DrawTexture', obj.sM.win, obj.texture{1}, [], obj.mvRect,...
					obj.angleOut, [], [], [], [], obj.rotateMode,...
					[obj.driftPhase, obj.sfOut, obj.contrastOut, obj.sigmaOut]);
				Screen('DrawTexture', obj.sM.win, obj.texture{2}, [], dstRect,...
					obj.angleOut, [], [], [], [], obj.rotateMode,...
					[obj.driftPhase+obj.phaseOffset, obj.sfOut, obj.inducerContrastOut, obj.sigmaOut]);
				obj.tick = obj.tick + 1;
			end
		end
		
		% ===================================================================
		%> @brief Animate this object for runExperiment
		%>
		% ===================================================================
		function animate(obj)
			if obj.mouseOverride
				getMousePosition(obj);
				if obj.mouseValid
					obj.mvRect = CenterRectOnPointd(obj.mvRect, obj.mouseX, obj.mouseY);
				end
			end
			if obj.doMotion == true
				obj.mvRect=OffsetRect(obj.mvRect,obj.dX_,obj.dY_);
			end
			if obj.doDrift == true
				obj.driftPhase = obj.driftPhase + obj.phaseIncrement;
			end
			if mod(obj.tick,obj.phaseCounter) == 0
				obj.driftPhase = obj.driftPhase + obj.phaseOfReverse;
			end
		end
		
		% ===================================================================
		%> @brief Reset an structure for runExperiment
		%>
		%> @param rE runExperiment object for reference
		%> @return stimulus structure.
		% ===================================================================
		function reset(obj)
			resetTicks(obj);
			obj.texture=[];
			if obj.mask > 0
				obj.mask = true;
			end
			obj.maskValue = [];
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
	methods ( Access = protected ) %-------PROTECTED METHODS-----%
	%=======================================================================
	
		% ===================================================================
		%> @brief setRect
		%> setRect makes the PsychRect based on the texture and screen values
		%> this is modified over parent method as gratings have slightly different
		%> requirements.
		% ===================================================================
		function setRect(obj)
			if isempty(obj.findprop('directionOut'));
				[sx sy]=pol2cart(obj.d2r(obj.direction),obj.startPosition);
			else
				[sx sy]=pol2cart(obj.d2r(obj.directionOut),obj.startPosition);
			end
			obj.dstRect=Screen('Rect',obj.texture{1});
			obj.dstRect=ScaleRect(obj.dstRect,obj.scale,obj.scale);
			obj.dstRect=CenterRectOnPointd(obj.dstRect,obj.sM.xCenter,obj.sM.yCenter);
			if isempty(obj.findprop('xPositionOut'));
				obj.dstRect=OffsetRect(obj.dstRect,(obj.xPosition)*obj.ppd,(obj.yPosition)*obj.ppd);
			else
				obj.dstRect=OffsetRect(obj.dstRect,obj.xPositionOut+(sx*obj.ppd),obj.yPositionOut+(sy*obj.ppd));
			end
			obj.mvRect=obj.dstRect;
			obj.setAnimationDelta();
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
		end
		
		% ===================================================================
		%> @brief calculatePhaseIncrement
		%> Use an event to recalculate as get method is slower (called
		%> many more times), than an event which is only called on update
		% ===================================================================
		function calculatePhaseIncrement(obj,~,~)
			if ~isempty(obj.findprop('tfOut'))
				obj.phaseIncrement = (obj.tfOut * 360) * obj.sM.screenVals.ifi;
				if ~isempty(obj.findprop('driftDirectionOut'))
					if obj.driftDirectionOut == false
						obj.phaseIncrement = -obj.phaseIncrement;
					end
				end
			end
		end
		
	end
end