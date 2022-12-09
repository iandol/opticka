
%>
%> Copyright ©2014-2022 Ian Max Andolina — released: LGPL3, see LICENCE.md
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
%>
%> Copyright ©2014-2022 Ian Max Andolina — released: LGPL3, see LICENCE.md
% ========================================================================
classdef gaborStimulus < baseStimulus
	
	properties %--------------------PUBLIC PROPERTIES----------%
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
		%> reverse the drift direction?
		driftDirection = false
		%> the angle which the direction of the grating patch is moving
		direction = 0
		%> Contrast Multiplier, 0.5 gives "standard" 0-1 contrast measure
		contrastMult = 0.5
		%> aspect ratio of the gabor
		aspectRatio = 1
		%> should we disable normalisation of the gabor (generally TRUE)?
		disableNorm = true
		%> a divisor for the size for the gaussian envelope for a gabor
		spatialConstant = 10
		%> do we need to correct the phase to be relative to center not edge?
		correctPhase = false
		%> reverse phase of grating X times per second?
		phaseReverseTime = 0
		%> What phase to use for reverse?
		phaseOfReverse = 180
		%> type
		type = 'procedural'
	end
	
	properties (SetAccess = protected, GetAccess = public)
		%stimulus family
		family = 'gabor'
		%> scale is used when changing size as an independent variable to keep sf accurate
		scale = 1
		%> the phase amount we need to add for each frame of animation
		phaseIncrement = 0
	end
	
	properties (SetAccess = private, GetAccess = public, Hidden = true)
		typeList = {'procedural'}
	end
	
	properties (SetAccess = protected, GetAccess = protected)
		%> as get methods are slow, we cache sf, then recalculate sf whenever
		%> changeScale event is called
		sfCache = []
		%>to stop a loop between set method and an event
		sfRecurse = false
		%> allowed properties passed to object upon construction
		allowedProperties = ['sf|tf|method|angle|direction|phase|rotationMethod|' ... 
			'contrast|driftDirection|speed|startPosition|aspectRatio|' ... 
			'disableNorm|contrastMult|spatialConstant|' ...
			'correctPhase|phaseReverseTime|phaseOfReverse']
		%>properties to not create transient copies of during setup phase
		ignoreProperties = 'name|scale|phaseIncrement|disableNorm|correctPhase|gabor|squareWave|contrastMult|mask'
		%> how many frames between phase reverses
		phaseCounter = 0
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
		function me = gaborStimulus(varargin)
			args = optickaCore.addDefaults(varargin,...
				struct('name','gabor','colour',[0.5 0.5 0.5]));
			me=me@baseStimulus(args); %we call the superclass constructor first
			me.parseArgs(args, me.allowedProperties);
			
			me.isRect = true; %uses a rect for drawing
			
			me.ignoreProperties = ['^(' me.ignorePropertiesBase '|' me.ignoreProperties ')$'];
			me.salutation('constructor method','Stimulus initialisation complete');
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
		function setup(me,sM)
			
			me.reset(); %reset it back to its initial state
			me.inSetup = true;
			if isempty(me.isVisible)
				me.show();
			end
			addlistener(me,'changeScale',@me.calculateScale); %use an event to keep scale accurate
			addlistener(me,'changePhaseIncrement',@me.calculatePhaseIncrement);
			
			me.sM = sM;
			if ~sM.isOpen; warning('Screen needs to be Open!'); end
			me.screenVals = sM.screenVals;
			me.ppd = sM.ppd;			

			me.texture = []; %we need to reset this

			fn = fieldnames(me);
			for j=1:length(fn)
				if isempty(me.findprop([fn{j} 'Out'])) && isempty(regexp(fn{j},me.ignoreProperties, 'once')) %create a temporary dynamic property
					p=me.addprop([fn{j} 'Out']);
					p.Transient = true;%p.Hidden = true;
					if strcmp(fn{j},'sf');p.SetMethod = @set_sfOut;end
					if strcmp(fn{j},'tf');p.SetMethod = @set_tfOut;end
					if strcmp(fn{j},'driftDirection');p.SetMethod = @set_driftDirectionOut;end
					if strcmp(fn{j},'size');p.SetMethod = @set_sizeOut;end
					if strcmp(fn{j},'xPosition');p.SetMethod = @set_xPositionOut;end
					if strcmp(fn{j},'yPosition');p.SetMethod = @set_yPositionOut;end
				end
				if isempty(regexp(fn{j},me.ignoreProperties, 'once'))
					me.([fn{j} 'Out']) = me.(fn{j}); %copy our property value to our tempory copy
				end
			end
			
			addRuntimeProperties(me);
			
			
			if isempty(me.findprop('rotateMode'));p=me.addprop('rotateMode');p.Transient=true;end
			if me.rotationMethod==1
				me.rotateMode = kPsychUseTextureMatrixForRotation;
			else
				me.rotateMode = [];
			end
			
			if isempty(me.findprop('gratingSize'));p=me.addprop('gratingSize');p.Transient=true;end
			me.gratingSize = round(me.ppd*me.size);
			
			if isempty(me.findprop('phaseIncrement'))
				p=me.addprop('phaseIncrement');
			end
			
			if isempty(me.findprop('driftPhase'));p=me.addprop('driftPhase');p.Transient=true;end
			if me.correctPhase
				ps=me.calculatePhase;
				me.driftPhase=me.phaseOut-ps;
			else
				me.driftPhase=me.phaseOut;
			end
			
			if isempty(me.findprop('res'));p=me.addprop('res');p.Transient=true;end
			me.res = [me.gratingSize me.gratingSize];
			
			if isempty(me.findprop('texture'));p=me.addprop('texture');p.Transient=true;end
			
			if me.phaseReverseTime > 0
				me.phaseCounter = round(me.phaseReverseTime / me.sM.screenVals.ifi);
			end
			
			if me.aspectRatio == 1
				nonSymmetric = 0;
			else
				nonSymmetric = 1;
			end
			me.texture = CreateProceduralGabor(me.sM.win, me.res(1),...
				me.res(2), nonSymmetric, me.colourOut, me.disableNorm,...
				me.contrastMult);
			
			me.inSetup = false;
			computePosition(me);
			me.setRect();

			function set_xPositionOut(me, value)
				me.xPositionOut = value * me.ppd;
			end
			function set_yPositionOut(me,value)
				me.yPositionOut = value*me.ppd;
			end
			function set_sfOut(me,value)
				if me.sfRecurse == false
					me.sfCache = (value/me.ppd);
					me.sfOut = me.sfCache * me.scale;
				else
					me.sfOut = value;
					me.sfRecurse = false;
				end
				%fprintf('\nSET SFOut: %d | cachce: %d | in: %d\n', me.sfOut, me.sfCache, value);
			end
			function set_tfOut(me,value)
				me.tfOut = value;
				notify(me,'changePhaseIncrement');
			end
			function set_driftDirectionOut(me,value)
				me.driftDirectionOut = value;
				notify(me,'changePhaseIncrement');
			end
			function set_sizeOut(me,value)
				me.sizeOut = value*me.ppd;
				notify(me,'changeScale');
			end
			
		end
		
		% ===================================================================
		%> @brief Update this stimulus object for display
		%>
		% ===================================================================
		function update(me)
			resetTicks(me);
			if me.correctPhase
				ps=me.calculatePhase;
				me.driftPhase=me.phaseOut-ps;
			else
				me.driftPhase=me.phaseOut;
			end
			computePosition(me);
			me.setRect();
		end
		
		% ===================================================================
		%> @brief Draw this stimulus object for display
		%>
		%> 
		% ===================================================================
		function draw(me)
			if me.isVisible && me.tick >= me.delayTicks && me.tick < me.offTicks
					Screen('DrawTexture', me.sM.win, me.texture, [],me.mvRect,...
					me.angleOut, [], [], [], [], 2,...
					[me.driftPhase, me.sfOut, me.spatialConstantOut,...
					me.contrastOut, me.aspectRatioOut, 0, 0, 0]); 
				me.drawTick = me.drawTick + 1;
			end
			me.tick = me.tick + 1;
		end
		
		% ===================================================================
		%> @brief Animate this object for runExperiment
		%>
		% ===================================================================
		function animate(me)
			if me.isVisible && me.tick >= me.delayTicks
				if me.mouseOverride
					getMousePosition(me);
					if me.mouseValid
						me.mvRect = CenterRectOnPointd(me.mvRect, me.mouseX, me.mouseY);
					end
				end
				if me.doMotion == true
					me.mvRect=OffsetRect(me.mvRect,me.dX_,me.dY_);
				end
				if me.doDrift == true
					me.driftPhase = me.driftPhase + me.phaseIncrement;
				end
				if mod(me.tick,me.phaseCounter) == 0
					me.driftPhase = me.driftPhase + me.phaseOfReverse;
				end
			end
		end
		
		% ===================================================================
		%> @brief Reset an structure for runExperiment
		%>
		%> @param rE runExperiment object for reference
		%> @return stimulus structure.
		% ===================================================================
		function reset(me)
			resetTicks(me);
			if isprop(me,'texture')
				if ~isempty(me.texture) && me.texture > 0 && Screen(me.texture,'WindowKind') == -1
					try Screen('Close',me.texture); end %#ok<*TRYNC>
				end
				me.texture = []; 
			end
			me.removeTmpProperties;
		end
		
		% ===================================================================
		%> @brief sf Set method
		%>
		% ===================================================================
		function set.sf(me,value)
			if value <= 0
				value = 0.05;
			end
			me.sf = value;
			me.salutation(['set sf: ' num2str(value)],'Custom set method')
		end
		
		% ===================================================================
		%> @brief calculate phase offset
		%>
		% ===================================================================
		function phase = calculatePhase(me)
			phase = 0;
			if me.correctPhase > 0
				ppd = me.ppd;
				size = (me.sizeOut/2); %divide by 2 to get the 0 point
				sfTmp = (me.sfOut/me.scale)*me.ppd;
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
		function setRect(me)
			me.dstRect=Screen('Rect',me.texture);
			me.dstRect=ScaleRect(me.dstRect,me.scale,me.scale);
			if me.mouseOverride
				if me.mouseValid
					me.dstRect = CenterRectOnPointd(me.dstRect, me.mouseX, me.mouseY);
				end
			else
				if isempty(me.findprop('directionOut'));
					[sx sy]=pol2cart(me.d2r(me.direction),me.startPosition);
				else
					[sx sy]=pol2cart(me.d2r(me.directionOut),me.startPosition);
				end
				me.dstRect=CenterRectOnPointd(me.dstRect,me.sM.xCenter,me.sM.yCenter);
				if isempty(me.findprop('xPositionOut'));
					me.dstRect=OffsetRect(me.dstRect,(me.xPosition)*me.ppd,(me.yPosition)*me.ppd);
				else
					me.dstRect=OffsetRect(me.dstRect,me.xPositionOut+(sx*me.ppd),me.yPositionOut+(sy*me.ppd));
				end
			end
			me.mvRect=me.dstRect;
			me.setAnimationDelta();
		end
	
	end %---END PROTECTED METHODS---%
	
	%=======================================================================
	methods ( Access = protected ) %-------PROTECTED METHODS-----%
	%=======================================================================
		
		% ===================================================================
		%> @brief calculateScale 
		%> Use an event to recalculate scale as get method is slower (called
		%> many more times), than an event which is only called on update
		% ===================================================================
		function calculateScale(me,~,~)
			me.scale = me.sizeOut/(me.size*me.ppd);
			me.sfRecurse = true;
			me.sfOut = me.sfCache * me.scale;
			%fprintf('\nCalculate SFOut: %d | in: %d | scale: %d\n', me.sfOut, me.sfCache, me.scale);
			me.spatialConstantOut=me.sizeOut/me.spatialConstant;
		end
		
		% ===================================================================
		%> @brief calculatePhaseIncrement
		%> Use an event to recalculate as get method is slower (called
		%> many more times), than an event which is only called on update
		% ===================================================================
		function calculatePhaseIncrement(me,~,~)
			if ~isempty(me.findprop('tfOut'))
				me.phaseIncrement = (me.tfOut * 360) * me.sM.screenVals.ifi;
				if ~isempty(me.findprop('driftDirectionOut'))
					if me.driftDirectionOut == false
						me.phaseIncrement = -me.phaseIncrement;
					end
				end
			end
		end
		
	end
end