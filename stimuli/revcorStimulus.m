% ========================================================================
%> @brief revcorStimulus single bar stimulus, inherits from baseStimulus
%>
%> Copyright ©2014-2022 Ian Max Andolina — released: LGPL3, see LICENCE.md
% ========================================================================
classdef revcorStimulus < baseStimulus
	
	properties %--------------------PUBLIC PROPERTIES----------%
		%> type of bar: 'solid','checkerboard','random','randomColour','randomN','randomBW'
		type char = 'solid'
		%> width of bar
		barWidth double = 1
		%> length of bar
		barHeight double= 4
		%> contrast multiplier
		contrast double = 1
		%> texture scale
		scale double = 1
		%> sf in cycles per degree for checkerboard textures
		sf double = 1
		%> texture interpolation: 'nearest','linear','spline','cubic'
		interpMethod char = 'nearest'
		%> For checkerboard, allow timed phase reversal
		phaseReverseTime double = 0
		%> update() method also regenerates the texture, this can be slow, but 
		%> normally update() is only called after a trial has finished
		regenerateTexture logical = true
		%> for checkerboard: the second colour
		colour2 double = [0 0 0 1];
		%> modulate the colour
		modulateColour double = []
	end

	properties (Hidden = true)
		%> floatprecision defines the precision with which the texture should
		%> be stored and processed. 0=8bit, 1=16bit, 2=32bit
		floatPrecision = 0
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
		baseColour
		screenWidth
		screenHeight
		%> for phase reveral of checkerboard
		matrix2
		%> for phase reveral of checkerboard
		texture2
		%> how many frames between phase reverses
		phaseCounter double = 0
		allowedProperties = {'modulateColour', 'colour2', 'regenerateTexture', ...
			'type', 'barWidth', 'barHeight', 'angle', 'speed', 'contrast', 'scale', ...
			'sf', 'interpMethod', 'phaseReverseTime'}
		ignoreProperties = {'interpMethod', 'matrix', 'matrix2', 'phaseCounter', 'pixelScale'}
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
				struct('name','Bar','colour',[1 1 1 1],'size',0,...
				'speed',2,'startPosition',0));
			me=me@baseStimulus(args); %we call the superclass constructor first
			me.parseArgs(args, me.allowedProperties);
			
			me.isRect = true; %uses a rect for drawing
			
			me.ignoreProperties = [me.ignorePropertiesBase me.ignoreProperties];
			me.salutation('constructor','Bar Stimulus initialisation complete');
		end
		
		% ===================================================================
		%> @brief Setup stimulus using a screenManager object
		%>
		%> @param sM screenManager object for reference
		% ===================================================================
		function setup(me,sM)
			
			reset(me); %reset object back to its initial state
			me.inSetup = true; me.isSetup = false;
			if isempty(me.isVisible); show(me); end
			
			me.sM = sM;
			if ~sM.isOpen; error('Screen needs to be Open!'); end
			me.ppd=sM.ppd;
			me.screenVals = sM.screenVals;
			me.texture = []; %we need to reset this
			me.baseColour = sM.backgroundColour;
			me.screenWidth = sM.screenVals.screenWidth;
			me.screenHeight = sM.screenVals.screenHeight;
			
			if me.size > 0
				me.barHeight = me.size;
				me.barWidth = me.size;
			end
			
			fn = sort(properties(me));
			for j=1:length(fn)
				if ~matches(fn{j}, me.ignoreProperties)
					p = me.addprop([fn{j} 'Out']);
					if strcmp(fn{j},'size'); p.SetMethod = @set_sizeOut; end
					if strcmp(fn{j},'xPosition'); p.SetMethod = @set_xPositionOut; end
					if strcmp(fn{j},'yPosition'); p.SetMethod = @set_yPositionOut; end
					if strcmp(fn{j},'colour'); p.SetMethod = @set_colourOut; end
					if strcmp(fn{j},'alpha'); p.SetMethod = @set_alphaOut; end
					if strcmp(fn{j},'scale'); p.SetMethod = @set_scaleOut; end
					me.([fn{j} 'Out']) = me.(fn{j}); %copy our property value to our tempory copy
				end
			end
			
			addRuntimeProperties(me);
			
			if me.barWidthOut > me.screenWidth; me.barWidthOut=me.screenWidth; end
			if me.barHeightOut > me.screenHeight; me.barHeightOut=me.screenHeight; end
			
			constructMatrix(me); %make our matrix
			%tx=Screen('MakeTexture', win, matrix [, optimizeForDrawAngle=0] [, specialFlags=0] [, floatprecision] [, textureOrientation=0] [, textureShader=0]);
			me.texture = Screen('MakeTexture', me.sM.win, me.matrix, 0, [], me.floatPrecision);
			if me.verbose; fprintf('===>>>Made texture: %i kind: %i\n',me.texture,Screen(me.texture,'WindowKind')); end
			if me.phaseReverseTime > 0
				me.texture2 = Screen('MakeTexture', me.sM.win, me.matrix2, 0, [], me.floatPrecision);
				if me.verbose; fprintf('===>>>Made texture: %i kind: %i\n',me.texture2,Screen(me.texture2,'WindowKind')); end
				me.phaseCounter = round( me.phaseReverseTime / me.sM.screenVals.ifi );
			end
			
			me.inSetup = false; me.isSetup = true;
			computePosition(me);
			setRect(me);

			function set_xPositionOut(me, value)
				me.xPositionOut = value * me.ppd;
			end
			function set_yPositionOut(me,value)
				me.yPositionOut = value * me.ppd; 
			end
			function set_sizeOut(me,value)
				me.sizeOut = value;
				if ~me.inSetup
					me.barHeightOut = me.sizeOut;
					me.barWidthOut = me.sizeOut;
				end
			end
			function set_scaleOut(me,value)
				if value < 1; value = 1; end
				me.scaleOut = round(value);
			end
			function set_colourOut(me, value)
				me.isInSetColour = true;
				[aold,name] = getP(me,'alpha');
				if length(value)==4 && value(4) ~= aold
					alpha = value(4);
				else
					alpha = aold;
				end
				switch length(value)
					case 4
						if alpha ~= aold; me.(name) = alpha; end
					case 3
						value = [value(1:3) alpha];
					case 1
						value = [value value value alpha];
				end
				me.colourOut = value;
				me.isInSetColour = false;
			end
			function set_alphaOut(me, value)
				if me.isInSetColour; return; end
				me.alphaOut = value;
				[v,n] = me.getP('colour');
				me.(n) = [v(1:3) value];
			end
		end
		
		% ===================================================================
		%> @brief Draw this stimulus
		%>
		%> 
		% ===================================================================
		function draw(me)
			if me.isVisible && me.tick >= me.delayTicks && me.tick < me.offTicks
				if ~isempty(me.modulateColourOut)
					colour = me.modulateColourOut;
				else
					colour = [];
				end
				Screen('DrawTexture',me.sM.win, me.texture,[ ],...
					me.mvRect, me.angleOut, [], [], colour);
			end
			me.tick = me.tick + 1;
		end
		
		% ===================================================================
		%> @brief Update our stimulus
		%>
		%> 
		% ===================================================================
		function update(me)
			resetTicks(me);
			if me.sizeOut > 0; me.barHeightOut = me.sizeOut; me.barWidthOut = me.sizeOut; end
			if me.phaseReverseTime > 0 
				me.phaseCounter = round( me.phaseReverseTime / me.sM.screenVals.ifi );
			end
			if me.regenerateTexture && Screen(me.sM.win,'WindowKind') == 1
				refreshTexture(me);
			end
			computePosition(me);
			setRect(me);
		end
		
		% ===================================================================
		%> @brief Animate this stimulus
		%>
		%> 
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
		%> @brief Reset the stimulus back to a default state
		%>
		%> 
		% ===================================================================
		function reset(me)
			if ~isempty(me.texture) && me.texture > 0 && Screen(me.texture,'WindowKind') == -1
				if me.verbose; fprintf('!!!>>>Closing texture: %i kind: %i\n',me.texture,Screen(me.texture,'WindowKind')); end
				try Screen('Close',me.texture); end %#ok<*TRYNC>
			end
			if ~isempty(me.texture2) && me.texture2 > 0 && Screen(me.texture2,'WindowKind') == -1
				if me.verbose; fprintf('!!!>>>Closing texture: %i kind: %i\n',me.texture,Screen(me.texture2,'WindowKind')); end
				try Screen('Close',me.texture2); end %#ok<*TRYNC>
			end
			me.texture=[]; me.texture2 = [];
			me.matrix = [];
			me.mvRect = [];
			me.dstRect = [];
			me.screenWidth = [];
			me.screenHeight = [];
			me.ppd = [];
			removeTmpProperties(me);
			resetTicks(me);
		end
		
		% ===================================================================
		%> @brief Regenerate the texture for the bar, can be called outside
		%> of update
		%>
		%> 
		% ===================================================================
		function refreshTexture(me)
			if ~isempty(me.texture) && me.texture > 0 && Screen(me.texture,'WindowKind') == -1
				%if me.verbose; fprintf('!!!>>>Closing texture: %i kind: %i\n',me.texture,Screen(me.texture,'WindowKind')); end
				try Screen('Close',me.texture); me.texture=[]; end %#ok<*TRYNC>
			end
			if ~isempty(me.texture2) && me.texture2 > 0 && Screen(me.texture2,'WindowKind') == -1
				%if me.verbose; fprintf('!!!>>>Closing texture: %i kind: %i\n',me.texture2,Screen(me.texture2,'WindowKind')); end
				try Screen('Close', me.texture2); me.texture2=[]; end 
			end
			constructMatrix(me);%make our texture matrix
			me.texture = Screen('MakeTexture', me.sM.win, me.matrix, 1, [], me.floatPrecision);
			%if me.verbose; fprintf('===>>>Made texture: %i kind: %i\n',me.texture,Screen(me.texture,'WindowKind')); end
			if me.phaseReverseTime > 0
				me.texture2=Screen('MakeTexture', me.sM.win, me.matrix2, 1, [], me.floatPrecision);
				%if me.verbose; fprintf('===>>>Made texture: %i kind: %i\n',me.texture2,Screen(me.texture2,'WindowKind')); end
				me.phaseCounter = round( me.phaseReverseTime / me.sM.screenVals.ifi );
			end
		end
		
		% ===================================================================
		%> @brief barWidth set method
		%>
		%> @param width of bar in degrees
		%> @return
		% ===================================================================
		function set.scale(me,value)
			if value < 1
				value = 1;
			end
			me.scale = round(value);
		end
		
		% ===================================================================
		%> @brief SET Colour2 method
		%> Allow 1 (R=G=B) 3 (RGB) or 4 (RGBA) value colour
		%> alpha will not be updated is RGBA is used
		% ===================================================================
		function set.colour2(me,value)
			len=length(value);
			switch len
				case 4
					me.colour2 = value(1:4);
				case 3
					me.colour2 = [value(1:3) me.alpha]; %force our alpha to override
				case 1
					me.colour2 = [value value value me.alpha]; %construct RGBA
				otherwise
					me.colour = [1 1 1 me.alpha]; %return white for everything else
			end
			me.colour2(me.colour2<0)=0; me.colour2(me.colour2>1)=1;
		end
		
		% ===================================================================
		%> @brief sfOut Pseudo Get method
		%>
		% ===================================================================
		function sf = getsfOut(me)
			sf = 0;
			if ~isempty(me.findprop('sfOut'))
				sf = me.sfOut;
			end
		end

		
	end %---END PUBLIC METHODS---%
	
	%=======================================================================
	methods ( Access = protected ) %-------PROTECTED METHODS-----%
	%=======================================================================

		% ===================================================================
		%> @brief constructMatrix makes the texture matrix to fill the bar with
		%>
		%> @param ppd use the passed pixels per degree to make a RGBA matrix of
		%> the correct dimensions
		% ===================================================================
		function constructMatrix(me)
			me.matrix=[]; %reset the matrix
			try
				colour = me.getP('colour');
				alpha = me.getP('alpha');
				contrast = me.getP('contrast');
				scale = me.getP('scale');
				bwpixels = round(me.barWidthOut*me.ppd);
				blpixels = round(me.barHeightOut*me.ppd);
				if bwpixels>me.screenWidth*3;bwpixels=me.screenWidth*3;end
				if blpixels>me.screenHeight*3;blpixels=me.screenHeight*3;end
	
				if ~strcmpi(me.type,'checkerboard')
					if rem(bwpixels,2);bwpixels=bwpixels+1;end
					if rem(blpixels,2);blpixels=blpixels+1;end
					% some scales cause rounding errors so find the next
					% best scale
					while rem(bwpixels,scale)>0 && rem(bwpixels,scale)>0
						scale = scale - 1;
					end
					bwscale = round(bwpixels/scale)+1;
					blscale = round(blpixels/scale)+1;
					rmat = ones(blscale,bwscale);
					tmat = repmat(rmat,1,1,3); 
				end
				
				switch me.type
					case 'checkerboard'
						tmat = me.makeCheckerBoard(blpixels,bwpixels,me.sfOut);
					case 'random'
						rmat=rand(blscale,bwscale);
						for i=1:3
							tmat(:,:,i)=tmat(:,:,i).*rmat;
						end
					case 'randomColour'
						for i=1:3
							rmat=rand(blscale,bwscale);
							tmat(:,:,i)=tmat(:,:,i).*rmat;
						end
					case 'randomN'
						rmat=randn(blscale,bwscale);
						for i=1:3
							tmat(:,:,i)=tmat(:,:,i).*rmat;
						end
					case 'randomBW'
						rmat=rand(blscale,bwscale);
						rmat(rmat < 0.5) = 0;
						rmat(rmat >= 0.5) = 1;
						for i=1:3
							tmat(:,:,i)=tmat(:,:,i).*rmat;
						end
					otherwise
						tmat(:,:,1)=ones(blscale,bwscale) * (colour(1) * contrast);
						tmat(:,:,2)=ones(blscale,bwscale) * (colour(2) * contrast);
						tmat(:,:,3)=ones(blscale,bwscale) * (colour(3) * contrast);
				end
				if ~strcmpi(me.type,'checkerboard')
					aw=0:scale:bwpixels;
					al=0:scale:blpixels;
					[a,b]=meshgrid(aw,al);
					[A,B]=meshgrid(0:bwpixels,0:blpixels);
					for i=1:3
						outmat(:,:,i) = interp2(a,b,tmat(:,:,i),A,B,me.interpMethod);
					end
					outmat(:,:,4) = ones(size(outmat,1),size(outmat,2)).*alpha;
					outmat = outmat(1:blpixels,1:bwpixels,:);
				else
					outmat(:,:,1:3) = tmat;
					outmat(:,:,4) = ones(size(outmat,1),size(outmat,2)).*alpha;
				end
				me.matrix = outmat;
				if me.phaseReverseTime > 0
					switch me.type
						case {'solid','checkerboard'}
							c2 = me.mix(me.colour2Out);
							out = zeros(size(outmat));
							for i = 1:3
								tmp = outmat(:,:,i);
								u = unique(tmp);
								if length(u) >= 2
									idx1 = tmp == u(1);
									idx2 = tmp == u(2);
									tmp(idx1) = u(2);
									tmp(idx2) = u(1);
								elseif length(u) == 1 %only 1 colour, probably low sf
									tmp(tmp == u(1)) = c2(i);
								end
								out(:,:,i) = tmp;
							end
							out(:,:,4) = ones(size(out,1),size(out,2)).*alpha;
							me.matrix2 = out;
						otherwise
							me.matrix2 = fliplr(me.matrix);
					end
				end
			catch ME %#ok<CTCH>
				warning('--->>> barStimulus texture generation failed, making plain texture...')
				%getReport(ME)
				bwpixels = round(me.barWidthOut*me.ppd);
				blpixels = round(me.barHeightOut*me.ppd);
				if bwpixels>me.screenWidth*3;bwpixels=me.screenWidth*3;end
				if blpixels>me.screenHeight*3;blpixels=me.screenHeight*3;end
				me.matrix=ones(blpixels,bwpixels,4);
			end
		end
		
		% ===================================================================
		%> @brief make the checkerboard
		%>
		% ===================================================================
		function mout = makeCheckerBoard(me,hh,ww,c)
			c1 = me.mix(me.colourOut);
			c2 = me.mix(me.colour2Out);
			cppd = round(( me.ppd / 2 / c )); %convert to sf cycles per degree
			if cppd == 1; warning('--->>> Checkerboard at resolution limit of monitor (1px) ...'); end
			if cppd < 1 || cppd >= max(me.sM.winRect) || cppd == Inf 
				warning('--->>> Checkerboard spatial frequency exceeds resolution of monitor...');
				mout = zeros(hh,ww,3);
				for i = 1:3
					if cppd < 1
						mout(:,:,i) = mout(:,:,i) + me.baseColour(i);
					else
						mout(:,:,i) = mout(:,:,i) + c1(i);
					end
				end
				return
			end
			hscale = ceil((hh / cppd) / 2); if hscale < 1; hscale = 1; end
			wscale = ceil((ww / cppd) / 2); if wscale < 1; wscale = 1; end
			tile = repelem([0 1; 1 0], cppd, cppd);
			mx = repmat(tile, hscale, wscale);
			mx = mx(1:hh,1:ww);
			mout = repmat(mx,1,1,3);
			for i = 1:3
				tmp = mout(:,:,i);
				tmp(mx==0) = c1(i);
				tmp(mx==1) = c2(i);
				mout(:,:,i) = tmp;
			end
		end
		
		% ===================================================================
		%> @brief linear interpolation between two arrays
		%>
		% ===================================================================
		function out = mix(me,c)
			out = me.baseColour(1:3) * (1 - me.contrastOut) + c(1:3) * me.contrastOut;
		end
		
	end
end
