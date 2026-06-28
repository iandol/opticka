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
		function me = apparentMotionStimulus(varargin) 
			%Initialise for superclass, stops a noargs error
			if nargin == 0;varargin.family = 'apparentMotion';end
			
			me = me@baseStimulus(varargin); %we call the superclass constructor first
			me.size = 0;
			me.colour = [1 1 1];
			me.speed = 0;
			me.startPosition = 0;
			
			if nargin>0
				me.parseArgs(varargin, me.allowedProperties);
			end
			
			if me.size > 0
				me.barHeight = me.size;
				me.barWidth = me.size;
			end
			
			me.ignoreProperties = ['^(' me.ignorePropertiesBase '|' me.ignoreProperties ')$'];
			me.salutation('constructor','apparentMotion Stimulus initialisation complete');
		end
		
		% ===================================================================
		%> @brief Generate an structure for runExperiment
		%>
		%> @param sM screenManager object for reference
		%> @return stimulus structure.
		% ===================================================================
		function setup(me,sM)
			
			reset(me);
			me.inSetup = true;
			
			me.sM = sM;
			me.ppd=sM.ppd;
			
			fn = sort(properties(me));
			for j=1:length(fn)
				if ~matches(fn{j}, me.ignoreProperties)
					p=me.addprop([fn{j} 'Out']);
					if strcmp(fn{j},'xPosition');p.SetMethod = @set_xPositionOut;end
					if strcmp(fn{j},'yPosition');p.SetMethod = @set_yPositionOut;end
					if strcmp(fn{j},'size');p.SetMethod = @set_sizeOut;end
					me.([fn{j} 'Out']) = me.(fn{j}); %copy our property value to our tempory copy
				end
			end
			
			if isempty(me.findprop('doDots'));p=me.addprop('doDots');p.Transient = true;end
			if isempty(me.findprop('doMotion'));p=me.addprop('doMotion');p.Transient = true;end
			if isempty(me.findprop('doDrift'));p=me.addprop('doDrift');p.Transient = true;end
			if isempty(me.findprop('doFlash'));p=me.addprop('doFlash');p.Transient = true;end
			me.doDots = false;
			me.doMotion = false;
			me.doDrift = false;
			me.doFlash = false;
			
			constructMatrix(me) %make our matrix
			me.texture=Screen('MakeTexture',me.sM.win,me.matrix,1,[],2);
			if me.speed>0 %we need to say this needs animating
				me.doMotion=true;
			else
				me.doMotion=false;
			end
			
			me.inSetup = false;
			makeTiming(me);
			me.isVisible = true;
			me.nextTick = me.frameTimes(1);
			computePosition(me);
			setRect(me);
			
		end
		
		% ===================================================================
		%> @brief Update an structure for runExperiment
		%>
		%> @param in runExperiment object for reference
		%> @return stimulus structure.
		% ===================================================================
		function update(me)
			resetTicks(me);
			me.stage = 1;
			me.nextTick = me.frameTimes(1);
			me.firstDraw = false;
			constructMatrix(me) %make our matrix
			me.texture=Screen('MakeTexture',me.sM.win,me.matrix,1,[],2);
			computePosition(me);
			me.setRect();
		end
		
		% ===================================================================
		%> @brief Draw an structure for runExperiment
		%>
		%> @param rE runExperiment object for reference
		%> @return stimulus structure.
		% ===================================================================
		function draw(me)
			if me.isVisible && me.tick >= me.delayTicks && me.tick < me.offTicks
				Screen('DrawTexture',me.sM.win, me.texture,[ ], me.mvRect, me.angleOut, [], [], me.modulateColourOut);
			end
			me.tick = me.tick + 1;
		end
		
		% ===================================================================
		%> @brief Animate an structure for runExperiment
		%>
		%> @param rE runExperiment object for reference
		%> @return stimulus structure.
		% ===================================================================
		function animate(me)
			if me.tick < me.delayTicks; me.isVisible = false; end
			if me.tick < me.offTicks
				if me.tick > me.nextTick && me.stage <= me.nBars*2
					me.stage = me.stage+1;
					if rem(me.stage,2)==0
						me.nextTick = me.nextTick + me.frameTimes(2);
						if me.tick >= me.delayTicks;me.isVisible = false;end
					else
						me.nextTick = me.nextTick + me.frameTimes(1);
						if ceil(me.stage/2) <= length(me.mvRects)
							me.mvRect = me.mvRects{ceil(me.stage/2)};
							if me.tick >= me.delayTicks;me.isVisible = true;end
						else
							if me.tick >= me.delayTicks;me.isVisible = false;end
						end
						
					end
					%fprintf('TICK=%i STAGE: %i NEXTTICK: %i VISIBLE: %i\n',me.tick,me.stage,me.nextTick,me.isVisible)
				end
				if me.doMotion == 1
					me.mvRect=OffsetRect(me.mvRect,me.dX_,me.dY_);
				end
			end
		end
		
		% ===================================================================
		%> @brief Reset an structure for runExperiment
		%>
		%> @param rE runExperiment object for reference
		%> @return
		% ===================================================================
		function reset(me)
			me.texture=[];
			me.stage = 1;
			me.nextTick = 0;
			me.frameTimes = [];
			me.mvRect = [];
			me.mvRects = [];
			me.dstRect = [];
			removeTmpProperties(me);
			resetTicks(me);
		end
		
		% ===================================================================
		%> @brief constructMatrix makes the texture matrix to fill the bar with
		%>
		%> @param ppd use the passed pixels per degree to make a RGBA matrix of
		%> the correct dimensions
		% ===================================================================
		function constructMatrix(me)
			me.matrix=[]; %reset the matrix			
			try
				if isempty(me.findprop('barWidthOut'));
					bwpixels = round(me.barWidth*me.ppd);
				else
					bwpixels = round(me.barWidthOut*me.ppd);
				end
				if isempty(me.findprop('barLengthOut'));
					blpixels = round(me.barHeight*me.ppd);
				else
					blpixels = round(me.barLengthOut*me.ppd);
				end
				if rem(bwpixels,2);bwpixels=bwpixels+1;end
				if rem(blpixels,2);blpixels=blpixels+1;end
				bwscale = round(bwpixels/me.scale)+1;
				blscale = round(blpixels/me.scale)+1;

				tmat = ones(blscale,bwscale,4); %allocate the size correctly
				rmat=ones(blscale,bwscale);
				switch me.type
					case 'random'
						rmat=rand(blscale,bwscale);
						for i=1:3
							tmat(:,:,i)=tmat(:,:,i).*rmat;
						end
						tmat(:,:,4)=ones(blscale,bwscale)*me.alpha;
					case 'randomColour'
						for i=1:3
							rmat=rand(blscale,bwscale);
							tmat(:,:,i)=tmat(:,:,i).*rmat;
						end
						tmat(:,:,4)=ones(blscale,bwscale)*me.alpha;
					case 'randomN'
						rmat=randn(blscale,bwscale);
						for i=1:3
							tmat(:,:,i)=tmat(:,:,i).*rmat;
						end
						tmat(:,:,4)=ones(blscale,bwscale)*me.alpha;
					case 'randomBW'
						rmat=rand(blscale,bwscale);
						rmat(rmat < 0.5) = 0;
						rmat(rmat >= 0.5) = 1;
						for i=1:3
							tmat(:,:,i)=tmat(:,:,i).*rmat;
						end
						tmat(:,:,4)=ones(blscale,bwscale)*me.alpha;
					otherwise
						tmat(:,:,1)=ones(blscale,bwscale) * (me.colour(1) * me.contrastOut);
						tmat(:,:,2)=ones(blscale,bwscale) * (me.colour(2) * me.contrastOut);
						tmat(:,:,3)=ones(blscale,bwscale) * (me.colour(3) * me.contrastOut);
						tmat(:,:,4)=ones(blscale,bwscale)*me.alpha;
				end
				aw=0:me.scale:bwpixels;
				al=0:me.scale:blpixels;
				[a,b]=meshgrid(aw,al);
				[A,B]=meshgrid(0:bwpixels,0:blpixels);
				for i=1:4
					outmat(:,:,i) = interp2(a,b,tmat(:,:,i),A,B,me.interpMethod);
				end
				me.matrix = outmat(1:blpixels,1:bwpixels,:);
				me.rmatrix = rmat;
			catch %#ok<CTCH>
				if isempty(me.findprop('barWidthOut'));
					bwpixels = round(me.barWidth*me.ppd);
				else
					bwpixels = round(me.barWidthOut*me.ppd);
				end
				if isempty(me.findprop('barLengthOut'));
					blpixels = round(me.barHeight*me.ppd);
				else
					blpixels = round(me.barLengthOut*me.ppd);
				end
				tmat = ones(blpixels,bwpixels,4); %allocate the size correctly
				tmat(:,:,1)=ones(blpixels,bwpixels)*me.colour(1);
				tmat(:,:,2)=ones(blpixels,bwpixels)*me.colour(2);
				tmat(:,:,3)=ones(blpixels,bwpixels)*me.colour(3);
				tmat(:,:,4)=ones(blpixels,bwpixels)*me.colour(4);
				rmat=ones(blpixels,bwpixels);
				me.matrix=tmat;
				me.rmatrix=rmat;
			end
		end
		
		
		% ===================================================================
		%> @brief barHeight set method
		%>
		%> @param length of bar
		%> @return
		% ===================================================================
		function set.barHeight(me,value)
			if ~(value > 0)
				value = 0.25;
			end
			me.barHeight = value;
		end
		
		% ===================================================================
		%> @brief barWidth set method
		%>
		%> @param width of bar in degrees
		%> @return
		% ===================================================================
		function set.barWidth(me,value)
			if ~(value > 0)
				value = 0.05;
			end
			me.barWidth = value;
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
		function setRect(me)
			if ~isempty(me.texture)
				me.dstRect=Screen('Rect',me.texture);
				pos = 0:me.barSpacing:me.barSpacing*(me.nBars-1);
				pos = pos - ((me.barSpacing*me.nBars)/2-(me.barSpacing/2));
				pos = pos * me.ppd;
				pos = pos + me.xOut;
				if strcmpi(me.directionOut,'left')
					pos = fliplr(pos);
				end
				for i = 1:me.nBars;
					me.mvRects{i} = CenterRectOnPointd(me.dstRect, pos(i), me.yFinal);
				end
				me.mvRect=me.mvRects{1};
			end
		end
		
		% ===================================================================
		%> @brief sizeOut Set method
		%>
		% ===================================================================
		function makeTiming(me)
			me.frameTimes = round(me.timing/me.sM.screenVals.ifi);
		end

		% ===================================================================
		%> @brief sizeOut Set method
		%>
		% ===================================================================
		function set_sizeOut(me,value)
			me.sizeOut = (value*me.ppd);
			if ~me.inSetup
				me.barLengthOut = me.sizeOut;
				me.barWidthOut = me.sizeOut;
			end
		end
	
	end
end