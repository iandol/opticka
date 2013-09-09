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
% ========================================================================
classdef gratingStimulus < baseStimulus
	
	properties %--------------------PUBLIC PROPERTIES----------%
		%> family type
		type = 'sinusoid'
		%> spatial frequency
		sf = 1
		%> temporal frequency
		tf = 1
		%> rotate the object (0/false) or the texture (1/true)?
		rotationMethod = true
		%> phase of grating
		phase = 0
		%> contrast of grating
		contrast = 0.5
		%> use a circular mask?
		mask = true
		%> reverse the drift direction?
		driftDirection = false
		%> the angle which the direction of the grating patch is moving
		motionAngle = 0
		%> Contrast Multiplier, 0.5 gives "standard" 0-1 contrast measure
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
		family = 'grating'
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
		allowedProperties = ['sf|tf|angle|motionAngle|phase|rotationMethod|' ... 
			'contrast|mask|driftDirection|speed|startPosition|aspectRatio|' ... 
			'contrastMult|sigma|useAlpha|smoothMethod|' ...
			'correctPhase|phaseReverseTime|phaseOfReverse']
		%>properties to not create transient copies of during setup phase
		ignoreProperties = 'name|type|scale|phaseIncrement|correctPhase|contrastMult|mask'
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
		function obj = gratingStimulus(varargin)
			%Initialise for superclass, stops a noargs error
			if nargin == 0
				varargin.family = 'grating';
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
		%> @param sM screenManager object for reference
		% ===================================================================
		function setup(obj,sM)
			
			reset(obj); %reset it back to its initial state
			obj.inSetup = true;
			if isempty(obj.isVisible)
				show(obj);
			end
			addlistener(obj,'changeScale',@obj.calculateScale); %use an event to keep scale accurate
			addlistener(obj,'changePhaseIncrement',@obj.calculatePhaseIncrement);
			
			obj.sM = sM;
			obj.ppd=sM.ppd;			

			obj.texture = []; %we need to reset this

			fn = fieldnames(gratingStimulus);
			for j=1:length(fn)
				if isempty(obj.findprop([fn{j} 'Out'])) && isempty(regexp(fn{j},obj.ignoreProperties, 'once')) %create a temporary dynamic property
					p=obj.addprop([fn{j} 'Out']);
					p.Transient = true;p.Hidden = true;
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
			
			if isempty(obj.findprop('rotateMode'));p=obj.addprop('rotateMode');p.Transient=true;p.Hidden=true;end
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
			if obj.aspectRatio < 1
				obj.res = round([obj.gratingSize*obj.aspectRatio obj.gratingSize]);
			else
				obj.res = round([obj.gratingSize obj.gratingSize*obj.aspectRatio]);
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
				obj.texture = CreateProceduralSineSquareGrating(obj.sM.win, obj.res(1),...
					obj.res(2), obj.colourOut, obj.maskValue, obj.contrastMult);
			else
				if obj.sigmaOut > 0
					obj.texture = CreateProceduralSineSmoothedGrating(obj.sM.win, obj.res(1), ...
						obj.res(2), obj.colourOut, obj.maskValue, obj.contrastMult, obj.sigmaOut, ...
						obj.useAlpha, obj.smoothMethod);
				else
					obj.texture = CreateProceduralSineGrating(obj.sM.win, obj.res(1),...
						obj.res(2), obj.colourOut, obj.maskValue, obj.contrastMult);
				end
			end
			
			obj.inSetup = false;
			computePosition(obj);
			setRect(obj);
			
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
			computePosition(obj);
			setRect(obj);
		end
		
		% ===================================================================
		%> @brief Draw this stimulus object for display
		%>
		%> 
		% ===================================================================
		function draw(obj)
			if obj.isVisible && obj.tick >= obj.delayTicks
				Screen('DrawTexture', obj.sM.win, obj.texture, [],obj.mvRect,...
					obj.angleOut, [], [], [], [], obj.rotateMode,...
					[obj.driftPhase, obj.sfOut, obj.contrastOut, obj.sigmaOut]);
				obj.tick = obj.tick + 1;
			end
		end
		
		% ===================================================================
		%> @brief Animate this object for runExperiment
		%>
		% ===================================================================
		function animate(obj)
			if obj.isVisible && obj.tick >= obj.delayTicks
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
		
		% ===================================================================
		%> @brief sfOut Pseudo Get method
		%>
		% ===================================================================
		function sf = getsfOut(obj)
			sf = 0;
			if ~isempty(obj.sfCache)
				sf = obj.sfCache * obj.ppd;
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
			obj.dstRect=Screen('Rect',obj.texture);
			obj.dstRect=ScaleRect(obj.dstRect,obj.scale,obj.scale);
			if obj.mouseOverride && obj.mouseValid
					obj.dstRect = CenterRectOnPointd(obj.dstRect, obj.mouseX, obj.mouseY);
			else
				if isempty(obj.findprop('motionAngleOut'));
					[sx sy]=pol2cart(obj.d2r(obj.motionAngle),obj.startPosition);
				else
					[sx sy]=pol2cart(obj.d2r(obj.motionAngleOut),obj.startPosition);
				end
				obj.dstRect=CenterRectOnPointd(obj.dstRect,obj.sM.xCenter,obj.sM.yCenter);
				if isempty(obj.findprop('xPositionOut'));
					obj.dstRect=OffsetRect(obj.dstRect,(obj.xPosition)*obj.ppd,(obj.yPosition)*obj.ppd);
				else
					obj.dstRect=OffsetRect(obj.dstRect,obj.xPositionOut+(sx*obj.ppd),obj.yPositionOut+(sy*obj.ppd));
				end
			end
			obj.mvRect=obj.dstRect;
			obj.setAnimationDelta();
		end
		
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
				fprintf('CALPhase: %g (%g)\n',obj.driftPhase, obj.phaseIncrement)
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
		
	end
end