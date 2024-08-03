classdef exampleStimulus < baseStimulus
	%> This is a example of how to make a minimal stimulus for Opticka. 
	%> All it does is draw a filled circle. All children
	%> of baseStimulus need to implement setup(), update(), draw(),
	%> animate() and reset(). These are used when running an
	%> experiment, so each type of stimlus can use its own functions
	%> but still give a consistent interface, draw() to draw to the screen,
	%> animate() to update any per-frame values etc.

	properties
		% add variables that you need for your stimulus here:
		testValue			= 'hello'
		% type is trigger for stimuli that can have different types, like
		% 'static', 'flashing' etc.
		type 				= 'simple'
	end

	properties (SetAccess = protected, GetAccess = public)
		% the stimulus family, 'grating','image', 'movie' etc.
		family 				= 'example'
	end

	properties (SetAccess = private, GetAccess = private)
		% which properties should we ignore when allowing variables to be
		% modified during a task
		ignoreProperties	= {'family'}
		% which properties can we pass when constructing the object
		allowedProperties	= {'testValue','type'}
	end

	methods
		% ===================================================================
		function me = exampleStimulus(varargin) % CONSTRUCTOR
			% build our arguments from what is passed in[varargin] and a
			% struct of preset properties
			args = optickaCore.addDefaults(varargin,...
				struct('name','example stimulus'));
			% we call the superclass constructor first
			me=me@baseStimulus(args);
			% we call the superclass constructor first
			me.parseArgs(args, me.allowedProperties);
			% stimuli in PTB have two ways to be drawn, via Rects or via
			% X,Y positon. isRect=true means this is a Rect stimulus, not
			% XY one
			me.isRect = false; % uses a rect for drawing?
			% build our ignored properties combining the baseStimulus and
			% this class into a regex
			me.ignoreProperties = [me.ignorePropertiesBase me.ignoreProperties];
		end

		% ===================================================================
		function setup(me, sM)
			% reset all values and properties
			reset(me);
			% specify we are in setup
			me.inSetup		= true; me.isSetup = false;
			% make sure our stimulus starts visible
			if isempty(me.isVisible); me.show; end
			% copy our screenManager handle
			me.sM			= sM;
			% make sure screen is open
			if ~sM.isOpen; error('Screen needs to be Open!'); end
			% screen values
			me.screenVals	= sM.screenVals;	
			% grab our pixelsPerDegree value from screenManager.
			me.ppd			= sM.ppd;
			
			% opticka uses degrees etc. but PTB needs pixels. So what we do
			% is copy all properties like `size` to a temporary property
			% called sizeOut and we calculate the pixel result in this
			% property and this is what is passed to PTB. THis way we can
			% keep our preferred vision-research friendly units while
			% converting to pixels under-the-hood. We use SetMethods for
			% properties that need modification, like size, xPosition etc.
			% So when we set them this method runs and does the conversion.
			fn = sort(fieldnames(me));
			for j=1:length(fn)
				if ~matches(fn{j}, me.ignoreProperties) % create a temporary dynamic property
					p=me.addprop([fn{j} 'Out']);
					if strcmp(fn{j},'size'); p.SetMethod = @set_sizeOut;end
					if strcmp(fn{j},'xPosition'); p.SetMethod = @set_xPositionOut;end
					if strcmp(fn{j},'yPosition'); p.SetMethod = @set_yPositionOut;end
					me.([fn{j} 'Out']) = me.(fn{j}); %copy our property value to our tempory copy
				end
			end
			% check
			addRuntimeProperties(me);
			
			me.inSetup = false; me.isSetup = true;
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
				Screen('gluDisk',me.sM.win,me.colourOut,me.xFinal,me.yFinal,me.sizeOut/2);
				me.drawTick = me.drawTick + 1;
			end
			if me.isVisible; me.tick = me.tick + 1; end
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
						me.xFinal = me.mouseX;
						me.yFinal = me.mouseY;
					end
				end
				if me.doMotion == true
					me.xFinal = me.xFinal + me.dX_;
					me.yFinal = me.yFinal + me.dY_;
				end
			end
		end

		% ===================================================================
		function reset(me)
			resetTicks(me);
			removeTmpProperties(me);
			me.inSetup = false; me.isSetup = false;
		end

	end
end
