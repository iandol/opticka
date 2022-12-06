classdef exampleStimulus < baseStimulus
	%> This is a example of how to make a minimal stimulus for Opticka. 
	%> All it does is draw a filled circle. All children
	%> of baseStimulus need to implement setup(), update(), draw(),
	%> animate() and reset(). These are used when running an
	%> experiment, so each type of stimlus can use its own functions
	%> but still give a consistent interface, draw() to draw to the screen,
	%> animate() to update any per-frame values etc.

	properties
		% add variables that you need here:
		testValue			= 'hello'
		type 				= 'simple'
	end

	properties (SetAccess = protected, GetAccess = public)
		% stimulus family
		family 				= 'example'
	end

	properties (SetAccess = private, GetAccess = private)
		ignoreProperties	= 'family';
		allowedProperties	= 'type'
	end

	methods
		% ===================================================================
		function me = exampleStimulus() % CONSTRUCTOR
			args = optickaCore.addDefaults(varargin,...
				struct('name','example stimulus'));
			me=me@baseStimulus(args); %we call the superclass constructor first
			me.parseArgs(args, me.allowedProperties);
			
			me.isRect = false; % uses a rect for drawing?
			
			me.ignoreProperties = ['^(' me.ignorePropertiesBase '|' me.ignoreProperties ')$'];
			me.salutation('constructor method','Stimulus initialisation complete');
		end

		% ===================================================================
		function setup(me, sM)
			reset(me);
			me.inSetup = true;
			if isempty(me.isVisible); me.show; end
			
			me.sM = sM;
			if ~sM.isOpen; warning('Screen needs to be Open!'); end
			me.ppd=sM.ppd;
			
			% opticka uses degrees etc. but PTB needs pixels. So what we do
			% is copy all properties like `size` to a temporary property
			% called sizeOut and we calculate the pixel result in this
			% property and this is what is passed to PTB. THis way we can
			% keep our preferred vision-research friendly units while
			% converting to pixels under-the-hood. We use SetMethods for
			% properties that need modification, like size, xPosition etc.
			% So when we set them this method runs and does the conversion.
			fn = fieldnames(testStimulus);
			for j=1:length(fn)
				if isempty(me.findprop([fn{j} 'Out'])) && isempty(regexp(fn{j},me.ignoreProperties, 'once'))%create a temporary dynamic property
					p=me.addprop([fn{j} 'Out']);
					p.Transient = true;
					if strcmp(fn{j},'size');p.SetMethod = @set_sizeOut;end
					if strcmp(fn{j},'xPosition');p.SetMethod = @set_xPositionOut;end
					if strcmp(fn{j},'yPosition');p.SetMethod = @set_yPositionOut;end
				end
				if isempty(regexp(fn{j},me.ignoreProperties, 'once'))
					me.([fn{j} 'Out']) = me.(fn{j}); %copy our property value to our tempory copy
				end
			end
			
			doProperties(me);
			
			me.inSetup = false;
			
			computePosition(me); %used for non-rect type stimuli

			function set_xPositionOut(me, value)
				me.xPositionOut = value * me.ppd;
			end
			function set_yPositionOut(me,value)
				me.yPositionOut = value*me.ppd;
			end
			function set_sizeOut(me,value)
				me.sizeOut = value * me.ppd; 
			end

		end

		% ===================================================================
		function draw(me)
			if me.isVisible && me.tick >= me.delayTicks && me.tick < me.offTicks
				Screen('gluDisk',me.sM.win,me.colourOut,me.xOut,me.yOut,me.sizeOut/2);
			end
			me.tick = me.tick + 1;
		end

		% ===================================================================
		function update(me)
			resetTicks(me);
			computePosition(me);
		end

		% ===================================================================
		function animate(me)
			if me.isVisible && me.tick >= me.delayTicks
				if me.mouseOverride
					getMousePosition(me);
					if me.mouseValid
						me.xOut = me.mouseX;
						me.yOut = me.mouseY;
					end
				end
				if me.doMotion == true
					me.xOut = me.xOut + me.dX_;
					me.yOut = me.yOut + me.dY_;
				end
			end
		end

		% ===================================================================
		function reset(me)
			resetTicks(me);
			me.removeTmpProperties;
			me.inSetup = false;
		end

	end
end