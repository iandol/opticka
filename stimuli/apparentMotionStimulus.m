% ========================================================================
%> @brief apparentMotionStimulus, inherits from baseStimulus
%>
%> apparentMotionStimulus is a simple apparent motion stimulus, comprising
%> of a bar which flashes on and off across a series of spatial positions.
%>
%> Copyright ©2014-2022 Ian Max Andolina — released: LGPL3, see LICENCE.md
% ========================================================================
classdef apparentMotionStimulus < baseStimulus

   properties %--------------------PUBLIC PROPERTIES----------%
		type = 'solid'
		%> scale up the texture in the bar
		pixelScale = 1 
		%> width of bar
		barWidth = 1
		%> length of bar
		barHeight = 4
		%>number of bars
		nBars = 4
		%> spacing
		barSpacing = 3;
		%> time on and gap
		timing = [0.2 0.1]
		%> direction of apparent motion
		direction = 'right'
		%> contrast multiplier
		contrast = 1
		%> texture scale
		scale = 1
		%> texture interpolation
		interpMethod = 'nearest'
		%>
		textureAspect = 1
		%> modulate the colour
		modulateColour = []
	end
	
	properties (SetAccess = protected, GetAccess = public)
		family = 'apparentMotion'
		%> computed matrix for the bar
		matrix
		%> random matrix used for texture generation
		rmatrix
		%> for each bar the position
		mvRects
		%> frame timings for bars
		frameTimes
		%> which tick stage are we in?
		stage
		%> the next tick to run the next stage
		nextTick
	end
	
	properties (SetAccess = private, GetAccess = public, Hidden = true)
		typeList = {'solid','random','randomColour','randomN','randomBW'}
		interpMethodList = {'nearest','linear','spline','cubic'}
	end
	
	properties (SetAccess = private, GetAccess = private)
		firstDraw = false
		allowedProperties='barSpacing|nBars|timing|direction|type|pixelScale|barWidth|barHeight|angle|speed|contrast|scale|interpMethod';
		ignoreProperties = 'interpMethod|matrix|rmatrix|pixelScale';
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
		%> @return instance of opticka class.
		% ===================================================================
		function obj = apparentMotionStimulus(varargin) 
			%Initialise for superclass, stops a noargs error
			if nargin == 0;varargin.family = 'apparentMotion';end
			
			obj = obj@baseStimulus(varargin); %we call the superclass constructor first
			obj.size = 0;
			obj.colour = [1 1 1];
			obj.speed = 0;
			obj.startPosition = 0;
			
			if nargin>0
				obj.parseArgs(varargin, obj.allowedProperties);
			end
			
			if obj.size > 0
				obj.barHeight = obj.size;
				obj.barWidth = obj.size;
			end
			
			obj.ignoreProperties = ['^(' obj.ignorePropertiesBase '|' obj.ignoreProperties ')$'];
			obj.salutation('constructor','apparentMotion Stimulus initialisation complete');
		end
		
		% ===================================================================
		%> @brief Generate an structure for runExperiment
		%>
		%> @param sM screenManager object for reference
		%> @return stimulus structure.
		% ===================================================================
		function setup(obj,sM)
			
			reset(obj);
			obj.inSetup = true;
			
			obj.sM = sM;
			obj.ppd=sM.ppd;
			
			fn = sort(properties(me));
			for j=1:length(fn)
				if ~matches(fn{j}, me.ignoreProperties)
					p=me.addprop([fn{j} 'Out']);
					if strcmp(fn{j},'xPosition');p.SetMethod = @set_xPositionOut;end
					if strcmp(fn{j},'yPosition');p.SetMethod = @set_yPositionOut;end
					if strcmp(fn{j},'size');p.SetMethod = @set_sizeOut;end
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
			
			constructMatrix(obj) %make our matrix
			obj.texture=Screen('MakeTexture',obj.sM.win,obj.matrix,1,[],2);
			if obj.speed>0 %we need to say this needs animating
				obj.doMotion=true;
			else
				obj.doMotion=false;
			end
			
			obj.inSetup = false;
			makeTiming(obj);
			obj.isVisible = true;
			obj.nextTick = obj.frameTimes(1);
			computePosition(obj);
			setRect(obj);
			
		end
		
		% ===================================================================
		%> @brief Update an structure for runExperiment
		%>
		%> @param in runExperiment object for reference
		%> @return stimulus structure.
		% ===================================================================
		function update(obj)
			resetTicks(obj);
			obj.stage = 1;
			obj.nextTick = obj.frameTimes(1);
			obj.firstDraw = false;
			constructMatrix(obj) %make our matrix
			obj.texture=Screen('MakeTexture',obj.sM.win,obj.matrix,1,[],2);
			computePosition(obj);
			obj.setRect();
		end
		
		% ===================================================================
		%> @brief Draw an structure for runExperiment
		%>
		%> @param rE runExperiment object for reference
		%> @return stimulus structure.
		% ===================================================================
		function draw(obj)
			if obj.isVisible && obj.tick >= obj.delayTicks && obj.tick < obj.offTicks
				Screen('DrawTexture',obj.sM.win, obj.texture,[ ], obj.mvRect, obj.angleOut, [], [], obj.modulateColourOut);
			end
			obj.tick = obj.tick + 1;
		end
		
		% ===================================================================
		%> @brief Animate an structure for runExperiment
		%>
		%> @param rE runExperiment object for reference
		%> @return stimulus structure.
		% ===================================================================
		function animate(obj)
			if obj.tick < obj.delayTicks; obj.isVisible = false; end
			if obj.tick < obj.offTicks
				if obj.tick > obj.nextTick && obj.stage <= obj.nBars*2
					obj.stage = obj.stage+1;
					if rem(obj.stage,2)==0
						obj.nextTick = obj.nextTick + obj.frameTimes(2);
						if obj.tick >= obj.delayTicks;obj.isVisible = false;end
					else
						obj.nextTick = obj.nextTick + obj.frameTimes(1);
						if ceil(obj.stage/2) <= length(obj.mvRects)
							obj.mvRect = obj.mvRects{ceil(obj.stage/2)};
							if obj.tick >= obj.delayTicks;obj.isVisible = true;end
						else
							if obj.tick >= obj.delayTicks;obj.isVisible = false;end
						end
						
					end
					%fprintf('TICK=%i STAGE: %i NEXTTICK: %i VISIBLE: %i\n',obj.tick,obj.stage,obj.nextTick,obj.isVisible)
				end
				if obj.doMotion == 1
					obj.mvRect=OffsetRect(obj.mvRect,obj.dX_,obj.dY_);
				end
			end
		end
		
		% ===================================================================
		%> @brief Reset an structure for runExperiment
		%>
		%> @param rE runExperiment object for reference
		%> @return
		% ===================================================================
		function reset(obj)
			obj.texture=[];
			obj.stage = 1;
			obj.nextTick = 0;
			obj.frameTimes = [];
			obj.mvRect = [];
			obj.mvRects = [];
			obj.dstRect = [];
			removeTmpProperties(obj);
			resetTicks(obj);
		end
		
		% ===================================================================
		%> @brief constructMatrix makes the texture matrix to fill the bar with
		%>
		%> @param ppd use the passed pixels per degree to make a RGBA matrix of
		%> the correct dimensions
		% ===================================================================
		function constructMatrix(obj)
			obj.matrix=[]; %reset the matrix			
			try
				if isempty(obj.findprop('barWidthOut'));
					bwpixels = round(obj.barWidth*obj.ppd);
				else
					bwpixels = round(obj.barWidthOut*obj.ppd);
				end
				if isempty(obj.findprop('barLengthOut'));
					blpixels = round(obj.barHeight*obj.ppd);
				else
					blpixels = round(obj.barLengthOut*obj.ppd);
				end
				if rem(bwpixels,2);bwpixels=bwpixels+1;end
				if rem(blpixels,2);blpixels=blpixels+1;end
				bwscale = round(bwpixels/obj.scale)+1;
				blscale = round(blpixels/obj.scale)+1;

				tmat = ones(blscale,bwscale,4); %allocate the size correctly
				rmat=ones(blscale,bwscale);
				switch obj.type
					case 'random'
						rmat=rand(blscale,bwscale);
						for i=1:3
							tmat(:,:,i)=tmat(:,:,i).*rmat;
						end
						tmat(:,:,4)=ones(blscale,bwscale)*obj.alpha;
					case 'randomColour'
						for i=1:3
							rmat=rand(blscale,bwscale);
							tmat(:,:,i)=tmat(:,:,i).*rmat;
						end
						tmat(:,:,4)=ones(blscale,bwscale)*obj.alpha;
					case 'randomN'
						rmat=randn(blscale,bwscale);
						for i=1:3
							tmat(:,:,i)=tmat(:,:,i).*rmat;
						end
						tmat(:,:,4)=ones(blscale,bwscale)*obj.alpha;
					case 'randomBW'
						rmat=rand(blscale,bwscale);
						rmat(rmat < 0.5) = 0;
						rmat(rmat >= 0.5) = 1;
						for i=1:3
							tmat(:,:,i)=tmat(:,:,i).*rmat;
						end
						tmat(:,:,4)=ones(blscale,bwscale)*obj.alpha;
					otherwise
						tmat(:,:,1)=ones(blscale,bwscale) * (obj.colour(1) * obj.contrastOut);
						tmat(:,:,2)=ones(blscale,bwscale) * (obj.colour(2) * obj.contrastOut);
						tmat(:,:,3)=ones(blscale,bwscale) * (obj.colour(3) * obj.contrastOut);
						tmat(:,:,4)=ones(blscale,bwscale)*obj.alpha;
				end
				aw=0:obj.scale:bwpixels;
				al=0:obj.scale:blpixels;
				[a,b]=meshgrid(aw,al);
				[A,B]=meshgrid(0:bwpixels,0:blpixels);
				for i=1:4
					outmat(:,:,i) = interp2(a,b,tmat(:,:,i),A,B,obj.interpMethod);
				end
				obj.matrix = outmat(1:blpixels,1:bwpixels,:);
				obj.rmatrix = rmat;
			catch %#ok<CTCH>
				if isempty(obj.findprop('barWidthOut'));
					bwpixels = round(obj.barWidth*obj.ppd);
				else
					bwpixels = round(obj.barWidthOut*obj.ppd);
				end
				if isempty(obj.findprop('barLengthOut'));
					blpixels = round(obj.barHeight*obj.ppd);
				else
					blpixels = round(obj.barLengthOut*obj.ppd);
				end
				tmat = ones(blpixels,bwpixels,4); %allocate the size correctly
				tmat(:,:,1)=ones(blpixels,bwpixels)*obj.colour(1);
				tmat(:,:,2)=ones(blpixels,bwpixels)*obj.colour(2);
				tmat(:,:,3)=ones(blpixels,bwpixels)*obj.colour(3);
				tmat(:,:,4)=ones(blpixels,bwpixels)*obj.colour(4);
				rmat=ones(blpixels,bwpixels);
				obj.matrix=tmat;
				obj.rmatrix=rmat;
			end
		end
		
		
		% ===================================================================
		%> @brief barHeight set method
		%>
		%> @param length of bar
		%> @return
		% ===================================================================
		function set.barHeight(obj,value)
			if ~(value > 0)
				value = 0.25;
			end
			obj.barHeight = value;
		end
		
		% ===================================================================
		%> @brief barWidth set method
		%>
		%> @param width of bar in degrees
		%> @return
		% ===================================================================
		function set.barWidth(obj,value)
			if ~(value > 0)
				value = 0.05;
			end
			obj.barWidth = value;
		end
		
	end %---END PUBLIC METHODS---%
	
	%=======================================================================
	methods ( Access = protected ) %-------PRIVATE (protected) METHODS-----%
	%=======================================================================
	
		% ===================================================================
		%> @brief setRect
		%> setRect makes the PsychRect based on the texture and screen
		%> values, you should call computePosition() first to get xOut and
		%> yOut
		% ===================================================================
		function setRect(obj)
			if ~isempty(obj.texture)
				obj.dstRect=Screen('Rect',obj.texture);
				pos = 0:obj.barSpacing:obj.barSpacing*(obj.nBars-1);
				pos = pos - ((obj.barSpacing*obj.nBars)/2-(obj.barSpacing/2));
				pos = pos * obj.ppd;
				pos = pos + obj.xOut;
				if strcmpi(obj.directionOut,'left')
					pos = fliplr(pos);
				end
				for i = 1:obj.nBars;
					obj.mvRects{i} = CenterRectOnPointd(obj.dstRect, pos(i), obj.yFinal);
				end
				obj.mvRect=obj.mvRects{1};
			end
		end
		
		% ===================================================================
		%> @brief sizeOut Set method
		%>
		% ===================================================================
		function makeTiming(obj)
			obj.frameTimes = round(obj.timing/obj.sM.screenVals.ifi);
		end

		% ===================================================================
		%> @brief sizeOut Set method
		%>
		% ===================================================================
		function set_sizeOut(obj,value)
			obj.sizeOut = (value*obj.ppd);
			if ~obj.inSetup
				obj.barLengthOut = obj.sizeOut;
				obj.barWidthOut = obj.sizeOut;
			end
		end
	
	end
end