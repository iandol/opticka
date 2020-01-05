% ========================================================================
%> @brief barStimulus single bar stimulus, inherits from baseStimulus
% ========================================================================
classdef barStimulus < baseStimulus

   properties %--------------------PUBLIC PROPERTIES----------%
		type = 'solid'
		%> scale up the texture in the bar
		pixelScale = 1 
		%> width of bar
		barWidth = 1
		%> length of bar
		barLength = 4
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
		family = 'bar'
		%> computed matrix for the bar
		matrix
		%> random matrix used for texture generation
		rmatrix
	end
	
	properties (SetAccess = private, GetAccess = public, Hidden = true)
		typeList = {'solid','random','randomColour','randomN','randomBW'}
		interpMethodList = {'nearest','linear','spline','cubic'}
	end
	
	properties (SetAccess = private, GetAccess = private)
		allowedProperties='type|pixelScale|barWidth|barLength|angle|speed|contrast|scale|interpMethod';
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
		function me = barStimulus(varargin) 
			if nargin == 0;varargin.name = 'bar stimulus';end
			args = optickaCore.addDefaults(varargin,...
				struct('colour',[1 1 1],'size',0,...
				'speed',2,'startPosition',-2));
			me=me@baseStimulus(args); %we call the superclass constructor first
			me.parseArgs(args, me.allowedProperties);
			
			if me.size > 0
				me.barLength = me.size;
				me.barWidth = me.size;
			end
			
			me.ignoreProperties = ['^(' me.ignorePropertiesBase '|' me.ignoreProperties ')$'];
			me.salutation('constructor','Bar Stimulus initialisation complete');
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
			me.ppd = sM.ppd;
			
			fn = fieldnames(me);
			for j=1:length(fn)
				if isempty(me.findprop([fn{j} 'Out'])) && isempty(regexpi(fn{j},me.ignoreProperties, 'once'))%create a temporary dynamic property
					p=me.addprop([fn{j} 'Out']);
					p.Transient = true;%p.Hidden = true;
					if strcmp(fn{j},'xPosition');p.SetMethod = @set_xPositionOut;end
					if strcmp(fn{j},'yPosition');p.SetMethod = @set_yPositionOut;end
					if strcmp(fn{j},'size');p.SetMethod = @set_sizeOut;end
					if isempty(regexpi(fn{j},me.ignoreProperties, 'once'))
						me.([fn{j} 'Out']) = me.(fn{j}); %copy our property value to our tempory copy
					end
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
				if isempty(me.modulateColourOut)
					colour = me.colourOut;
				else
					colour = me.modulateColourOut;
				end
				Screen('DrawTexture',me.sM.win, me.texture,[ ],...
					me.mvRect, me.angleOut, [], [], colour);
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
			if me.isVisible && me.tick >= me.delayTicks
				if me.mouseOverride
					getMousePosition(me);
					if me.mouseValid
						me.mvRect = CenterRectOnPointd(me.mvRect, me.mouseX, me.mouseY);
					end
				else
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
			me.mvRect = [];
			me.dstRect = [];
			me.removeTmpProperties;
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
					blpixels = round(me.barLength*me.ppd);
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
					blpixels = round(me.barLength*me.ppd);
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
		%> @brief barLength set method
		%>
		%> @param length of bar
		%> @return
		% ===================================================================
		function set.barLength(me,value)
			if ~(value > 0)
				value = 0.25;
			end
			me.barLength = value;
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
	methods ( Access = protected ) %-------PROTECTED METHODS-----%
	%=======================================================================
	
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