% ========================================================================
%> @brief revcorStimulus stimulus, inherits from baseStimulus
%>
%> Copyright ©2014-2024 Ian Max Andolina — released: LGPL3, see LICENCE.md
% ========================================================================
classdef revcorStimulus < baseStimulus
	
	properties %--------------------PUBLIC PROPERTIES----------%
		%> type, 'trinary' or 'binary'
		type char			= 'trinary'
		%> texture scale size in degrees for each pixel of noise
		pixelScale double	= 1
		%> frameTime in ms (to nearest frame dependant on fps)
		frameTime double	= 64
		%> texture interpolation: 0 = Nearest neighbour filtering, 1 = Bilinear
		%> filtering - this is the default. Values 2 or 3 select use of OpenGL mip-mapping
		%> for improved quality: 2 = Bilinear filtering for nearest mipmap level, 3 =
		%> Trilinear filtering across mipmap lev
		interpolation double	= 0
		%> length of trial used to calculate the number of noise frames
		%> properly. For most experiments you should set this to the
		%> maximum time a trial may last as this is determined by eyetracker
		%> etc.
		trialLength double	= 2
	end
	
	properties (SetAccess = protected, GetAccess = public)
		family char = 'revcor'
		%> framelog
		frameLog
		%> computed matrix for the bar
		trialMatrix
		%>
		trialTick double = 0
	end

	properties (SetAccess = protected, GetAccess = public, Hidden = true)
		typeList = {'trinary','binary'}
	end

	properties (SetAccess = ?baseStimulus, GetAccess = ?baseStimulus)
		baseColour
		screenWidth
		screenHeight
		%> properties to not show in the UI panel
		ignorePropertiesUI = {'colour','speed','startPosition'}
	end
	
	properties (Access = protected)
		allowedProperties = {'type', 'size', 'angle', 'pixelScale', ...
			'interpMethod'}
		ignoreProperties = {'interpMethod', 'matrix', 'matrix2', 'phaseCounter', ...
			'pixelScale','trialLength','trialTick','interpMethod','frameTime','frameLog'}
		nFrames
		nFrame
		nStimuli
		nStim
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
		function me = revcorStimulus(varargin)
			args = optickaCore.addDefaults(varargin,...
				struct('name','RevCor','size',10,...
				'speed',0,'startPosition',0));
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
			resetLog(me);
			reset(me); %reset object back to its initial state
			me.inSetup = true; me.isSetup = false;
			if isempty(me.isVisible); show(me); end
			
			me.sM = sM;
			if ~sM.isOpen; error('Screen needs to be Open!'); end
			me.ppd=sM.ppd;
			me.screenVals = sM.screenVals;
			
			me.baseColour = sM.backgroundColour;
			me.screenWidth = sM.screenVals.screenWidth;
			me.screenHeight = sM.screenVals.screenHeight;

			fn = sort(properties(me));
			for j=1:length(fn)
				if ~matches(fn{j}, me.ignoreProperties)
					p = me.addprop([fn{j} 'Out']);
					if strcmp(fn{j},'size'); p.SetMethod = @set_sizeOut; end
					if strcmp(fn{j},'xPosition'); p.SetMethod = @set_xPositionOut; end
					if strcmp(fn{j},'yPosition'); p.SetMethod = @set_yPositionOut; end
					me.([fn{j} 'Out']) = me.(fn{j}); %copy our property value to our tempory copy
				end
			end
			
			addRuntimeProperties(me);
			
			if me.sizeOut > me.screenWidth*2; me.sizeOut=me.screenWidth*2; end
			
			constructMatrix(me); %make our matrix
			
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
				me.sizeOut = value * me.ppd;
				me.szPx = me.sizeOut;
			end
		end
		
		% ===================================================================
		%> @brief Draw this stimulus
		%>
		%> 
		% ===================================================================
		function draw(me)
			if me.isVisible && me.tick >= me.delayTicks && me.tick < me.offTicks
				if (me.nFrame+1 > me.nFrames)
					me.nFrame = 0;
					if me.nStim < length(me.texture)
						me.nStim = me.nStim + 1;
					else
						me.nStim = 1;
					end
				end
				Screen('DrawTexture',me.sM.win, me.texture(me.nStim),[ ],...
					me.mvRect, me.angleOut,me.interpolation,me.alphaOut);
				me.drawTick = me.drawTick + 1;
				me.nFrame = me.nFrame + 1;
				try 
					me.frameLog(me.trialTick).nFrame(end+1) = me.nFrame;
					me.frameLog(me.trialTick).nStim(end+1) = me.nStim;
				end
			end
			me.tick = me.tick + 1;
		end
		
		% ===================================================================
		%> @brief Update our stimulus
		%>
		%> 
		% ===================================================================
		function update(me)
			closeTextures(me);
			saveFrames(me);
			resetTicks(me);
			constructMatrix(me);
			me.nStim = 1; me.nFrame = 0;
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
			end
		end
		
		% ===================================================================
		%> @brief Reset the stimulus back to a default state
		%>
		%> resetLog
		% ===================================================================
		function reset(me)
			saveFrames(me);
			closeTextures(me);
			me.mvRect = [];
			me.dstRect = [];
			me.screenWidth = [];
			me.screenHeight = [];
			me.ppd = [];
			me.trialTick = 0;
			me.nStim = 0; me.nFrame = 0;
			removeTmpProperties(me);
			resetTicks(me);
		end

		% ===================================================================
		%> @brief Reset the stimulus back to a default state
		%>
		%> 
		% ===================================================================
		function resetLog(me)
			me.trialTick = 0;
			me.frameLog = [];
		end

		% ===================================================================
		%> @brief add a tag to the frameLog
		%>
		%> 
		% ===================================================================
		function addTag(me, tag)
			if ~exist('tag','var'); return; end
			try me.frameLog(me.trialTick).tag = tag; end
		end
		
	end %---END PUBLIC METHODS---%
	
	%=======================================================================
	methods ( Access = protected ) %-------PROTECTED METHODS-----%
	%=======================================================================

		% ===================================================================
		%> @brief setRect
		%> setRect makes the PsychRect based on the texture and screen
		%> values, you should call computePosition() first to get xOut and
		%> yOut
		% ===================================================================
		function setRect(me)
			if ~isempty(me.texture)
				me.dstRect = Screen('Rect',me.texture(1));
				blockSize = round(me.pixelScale * me.ppd);
				me.dstRect = ScaleRect(me.dstRect,round(blockSize),round(blockSize));
				if me.mouseOverride && me.mouseValid
					me.dstRect = CenterRectOnPointd(me.dstRect, me.mouseX, me.mouseY);
				else
					me.dstRect=CenterRectOnPointd(me.dstRect, me.xFinal, me.yFinal);
				end
				me.mvRect=me.dstRect;
				me.szPx = RectWidth(me.mvRect);
			end
		end

		% ===================================================================
		%> @brief 
		%>
		%> @param 
		% ===================================================================
		function saveFrames(me)
			if me.trialTick > 0
				me.frameLog(me.trialTick).tick = me.tick;
				me.frameLog(me.trialTick).drawTick = me.drawTick;
			end
		end
		% ===================================================================
		%> @brief 
		%>
		%> @param 
		% ===================================================================
		function closeTextures(me)
			if ~isempty(me.texture) 
				for i = 1:length(me.texture)
					if me.verbose; fprintf('!!!>>>Closing texture: %i kind: %i\n',me.texture,Screen(me.texture,'WindowKind')); end
					try Screen('Close',me.texture(i)); end %#ok<*TRYNC>
				end
				me.texture = [];
			end
		end
		% ===================================================================
		%> @brief constructMatrix makes the texture matrix to fill the bar with
		%>
		%> @param ppd use the passed pixels per degree to make a RGBA matrix of
		%> the correct dimensions
		% ===================================================================
		function constructMatrix(me)
			me.nStim = 1; me.nFrame = 0;
			me.trialTick = me.trialTick + 1;
			
			blockSize = round(me.pixelScale * me.ppd);
			me.nFrames = analysisCore.findNearest((1:60)*(me.screenVals.ifi*1e3), me.frameTime);
			me.nStimuli = round(me.trialLength*round(me.screenVals.fps/me.nFrames));

			noiseType = 1;
			pxLength = round(me.sizeOut * (1/blockSize));
			mx = uint8(rand(pxLength,pxLength,me.nStimuli)*255);
			if matches(me.type,'trinary')
				mx(mx < (1/3*255)) = 0;
				mx(mx > 0 & mx < (2/3*255)) = 127;
				mx(mx > 0.5*255 ) = 255;
			else
				mx(mx < 0.5*255) = 0;
				mx(mx > 0) = 255;
			end
			% Screen('MakeTexture', WindowIndex, imageMatrix [, optimizeForDrawAngle=0] [, specialFlags=0]
			% [, floatprecision] [, textureOrientation=0] [, textureShader=0]);
			me.frameLog(me.trialTick).nFrames = me.nFrames;
			me.frameLog(me.trialTick).nStimuli = me.nStimuli;
			me.frameLog(me.trialTick).mx = mx;
			me.frameLog(me.trialTick).nFrame = [];
			me.frameLog(me.trialTick).nStim = [];
			me.frameLog(me.trialTick).tickInit = me.tick;
			me.frameLog(me.trialTick).drawTickInit = me.drawTick;
			me.frameLog(me.trialTick).tag = '';
			texture = zeros(1, me.nStimuli);
			for i = 1:me.nStimuli
				texture(i) = Screen('MakeTexture', me.sM.win, mx(:,:,i));
			end
			me.texture = texture;
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
