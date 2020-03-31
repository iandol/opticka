% ========================================================================
%> @brief barStimulus single bar stimulus, inherits from baseStimulus
% ========================================================================
classdef barStimulus < baseStimulus
	
	properties %--------------------PUBLIC PROPERTIES----------%
		%> type of bar: 'solid','checkerboard','random','randomColour','randomN','randomBW'
		type char = 'solid'
		%> width of bar
		barWidth double = 1
		%> length of bar
		barLength double= 4
		%> contrast multiplier
		contrast double = 1
		%> texture scale
		scale double = 1
		%> checkSize in degrees for checkerboard textures
		checkSize double = 1
		%> texture interpolation: 'nearest','linear','spline','cubic'
		interpMethod char = 'nearest'
		%> For checkerboard, allow timed phase reversal
		phaseReverseTime double = 0
		%> update() method also regenerates the texture, this can be slow, but 
		%> normally update() is only called after a trial has finished
		regenerateTexture logical = true
		%> modulate the colour
		modulateColour double = []
	end
	
	properties (SetAccess = protected, GetAccess = public)
		family char = 'bar'
		%> computed matrix for the bar
		matrix
	end
	
	properties (SetAccess = protected, GetAccess = public, Hidden = true)
		typeList cell = {'solid','checkerboard','random','randomColour','randomN','randomBW'}
		interpMethodList cell = {'nearest','linear','makima','spline','cubic'}
	end
	
	properties (SetAccess = protected, GetAccess = protected)
		%> for phase reveral of checkerboard
		matrix2
		%> for phase reveral of checkerboard
		texture2
		%> how many frames between phase reverses
		phaseCounter double = 0
		allowedProperties = 'type|barWidth|barLength|angle|speed|contrast|scale|checkSize|interpMethod|phaseReverseTime';
		ignoreProperties = 'interpMethod|matrix|matrix2|phaseCounter|pixelScale';
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
			args = optickaCore.addDefaults(varargin,...
				struct('name','Bar','colour',[1 1 1],'size',0,...
				'speed',2,'startPosition',-2));
			me=me@baseStimulus(args); %we call the superclass constructor first
			me.parseArgs(args, me.allowedProperties);
			
			if me.size > 0 %size overrides 
				me.barLength = me.size;
				me.barWidth = me.size;
			end
			
			me.isRect = true; %uses a rect for drawing
			
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
			
			if me.size > 0
				me.barLength = me.size;
				me.barWidth = me.size;
			end
			
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
			
			doProperties(me);
			
			constructMatrix(me) %make our matrix
			me.texture=Screen('MakeTexture',me.sM.win,me.matrix,1,[],2);
			if me.phaseReverseTime > 0
				me.texture2=Screen('MakeTexture',me.sM.win,me.matrix2,1,[],2);
				me.phaseCounter = round(me.phaseReverseTime / me.sM.screenVals.ifi);
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
			if ~isempty(me.texture) && me.texture > 0 && Screen(me.texture,'WindowKind') == -1
					try Screen('Close',me.texture); end %#ok<*TRYNC>
			end
			if ~isempty(me.texture2) && me.texture2 > 0 && Screen(me.texture2,'WindowKind') == -1
					try Screen('Close',me.texture2); end %#ok<*TRYNC>
			end
			if me.regenerateTexture
				constructMatrix(me); %make our matrix
				me.texture=Screen('MakeTexture',me.sM.win,me.matrix,1,[],2);
				if me.phaseReverseTime > 0
					me.texture2=Screen('MakeTexture',me.sM.win,me.matrix2,1,[],2);
					me.phaseCounter = round(me.phaseReverseTime / me.sM.screenVals.ifi);
				end
			end
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
				if me.phaseReverseTime > 0 && mod(me.tick,me.phaseCounter) == 0
					tx = me.texture;
					tx2 = me.texture2;
					me.texture = tx2;
					me.texture2 = tx;
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
			if ~isempty(me.texture) && me.texture > 0 && Screen(me.texture,'WindowKind') == -1
					try Screen('Close',me.texture); end %#ok<*TRYNC>
			end
			if ~isempty(me.texture2) && me.texture2 > 0 && Screen(me.texture2,'WindowKind') == -1
					try Screen('Close',me.texture2); end %#ok<*TRYNC>
			end
			me.texture=[];
			me.mvRect = [];
			me.dstRect = [];
			me.removeTmpProperties;
			resetTicks(me);
		end
		
		% ===================================================================
		%> @brief barLength set method
		%>
		%> @param length of bar
		%> @return
		% ===================================================================
		function set.barLength(me,value)
			if ~(value > 0)
				value = 4;
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
				value = 1;
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
		
		% ===================================================================
		%> @brief constructMatrix makes the texture matrix to fill the bar with
		%>
		%> @param ppd use the passed pixels per degree to make a RGBA matrix of
		%> the correct dimensions
		% ===================================================================
		function constructMatrix(me)
			me.matrix=[]; %reset the matrix
			try
				if isempty(me.findprop('barWidthOut'))
					bwpixels = round(me.barWidth*me.ppd);
				else
					bwpixels = round(me.barWidthOut*me.ppd);
				end
				if isempty(me.findprop('barLengthOut'))
					blpixels = round(me.barLength*me.ppd);
				else
					blpixels = round(me.barLengthOut*me.ppd);
				end
				if isempty(me.findprop('checkSizeOut'))
					checkSize = me.checkSize;
				else
					checkSize = me.checkSizeOut;
				end
				if ~strcmpi(me.type,'checkerboard')
					if rem(bwpixels,2);bwpixels=bwpixels+1;end
					if rem(blpixels,2);blpixels=blpixels+1;end
					bwscale = round(bwpixels/me.scale)+1;
					blscale = round(blpixels/me.scale)+1;
					rmat = ones(blscale,bwscale);
					tmat = repmat(rmat,1,1,4); 
				end
				
				switch me.type
					case 'checkerboard'
						tmat = me.makeCheckerBoard(blpixels,bwpixels,checkSize);
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
				if ~strcmpi(me.type,'checkerboard')
					aw=0:me.scale:bwpixels;
					al=0:me.scale:blpixels;
					[a,b]=meshgrid(aw,al);
					[A,B]=meshgrid(0:bwpixels,0:blpixels);
					for i=1:3
						outmat(:,:,i) = interp2(a,b,tmat(:,:,i),A,B,me.interpMethod);
					end
					outmat(:,:,4) = ones(size(outmat,1),size.outmat(2)).*me.alpha;
					outmat = outmat(1:blpixels,1:bwpixels,:);
				else
					outmat(:,:,1:3) = tmat;
					outmat(:,:,4) = ones(size(outmat,1),size(outmat,2)).*me.alpha;
				end
				me.matrix = outmat;
				if me.phaseReverseTime > 0
					out2mat = outmat;
					out2mat(:,:,1:3) = double(~outmat(:,:,1:3));
					me.matrix2 = out2mat; 
				end
			catch ME %#ok<CTCH>
				getReport(ME)
				if isempty(me.findprop('barWidthOut'))
					bwpixels = round(me.barWidth*me.ppd);
				else
					bwpixels = round(me.barWidthOut*me.ppd);
				end
				if isempty(me.findprop('barLengthOut'))
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
			end
		end
		
		% ===================================================================
		%> @brief make the checkerboard
		%>
		% ===================================================================
		function matrixOut = makeCheckerBoard(me,hh,ww,c)
			cppd = round(c * me.ppd);
			if cppd < 1; cppd = 1; end
			blockB = zeros(cppd,cppd);
			blockW = ones(cppd,cppd);
			hscale = ceil(hh / cppd);
			wscale = ceil(ww / cppd);
			if hscale < 1; hscale = 1; end
			if wscale < 1; wscale = 1; end
			matrix = {};
			for i = 1 : wscale
				for j = 1: hscale
					if (mod(j,2) && mod(i,2)) || (~mod(j,2) && ~mod(i,2))
						matrix{j,i} = blockB;
					else
						matrix{j,i} = blockW;
					end
				end
			end
			matrix = cell2mat(matrix);
			matrix = matrix(1:hh,1:ww);
			if isempty(me.findprop('colourOut'))
				colour = me.colour;
			else
				colour = me.colourOut;
			end
			matrixOut = [];
			for i = 1 : 3
				matrixOut(:,:,i) = matrix(:,:,1) .* colour(i);
			end
		end
		
		
	end
end
