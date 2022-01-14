% ========================================================================
%> @brief logGaborStimulus: orientation & SF band-pass limited filter
%>
%> If you use this in published research please cite  "Horizontal information drives the
%> behavioral signatures of face processing" Goffaux & Dakin (2010) Frontiers in Perception
%> Science v1, 143 | May 2015,  Steven Dakin, s.dakin@auckland.ac.nz
%>
%> Copyright ©2014-2022 Ian Max Andolina — released: LGPL3, see LICENCE.md
% ========================================================================	
classdef logGaborStimulus < baseStimulus	
	properties %--------------------PUBLIC PROPERTIES----------%
		%> filename to load, if empty use random noise
		fileName char		= ''
		%> peak spatial frequency
		sf double			= 1;
		%> spatial frequency SD 
		sfSigma double		= 0.01;
		%> orientation SD
		angleSigma double	= 10;
		%> contrast multiplier
		contrast double		= 1
		%> the direction of the whole grating object - i.e. the object can
		%> move (speed property) as well as the grating texture rotate within the object.
		direction double	= 0
		%> do we lock the angle to the direction? If so what is the offset
		%> (0 = parallel, 90 = orthogonal etc.)
		lockAngle double	= []
		%> seed for random textures
		seed uint32
		%> use mask?
		mask logical		= true
		%> colour of the mask, empty sets mask colour to = screen manager background
		maskColour			= []
		%> smooth the alpha edge of the mask by this number of pixels
		maskSmoothing		= 55
		%> type
		type char			= 'image'
		modulateColour		= []
		%> update() method also regenerates the texture, this can be slow but 
		%> normally update() is only called after a trial has finished
		regenerateTexture logical = true
		%> For checkerboard, allow timed phase reversal
		phaseReverseTime double = 0
	end
	
	properties (SetAccess = protected, GetAccess = public)
		%> scale is set by size
		scale = 1
		%>
		family = 'texture'
		%>
		matrix
		width
		height
	end
	
	properties (SetAccess = private, GetAccess = public, Hidden = true)
		typeList = {'image','logGabor'}
		fileNameList = 'filerequestor';
	end
	
	properties (SetAccess = private, GetAccess = private)
		reversePhase
		%> how many frames between phase reverses
		phaseCounter double = 0
		shader
		%> mask OpenGL blend modes
		msrcMode			= 'GL_SRC_ALPHA'
		mdstMode			= 'GL_ONE_MINUS_SRC_ALPHA'
		%> we must scale the dots larger than the mask by this factor
		fieldScale	= 1.05
		%> resultant size of the mask after scaling
		fieldSize
		%> this holds the mask texture
		maskTexture
		%> the stimulus rect of the mask
		maskRect
		%> was mask blank when initialised?
		wasMaskColourBlank = false
		randomTexture = true;
		%> allowed properties passed to object upon construction
		allowedProperties=['type|direction|lockAngle|fileName|contrast|'...
			'sf|sfSigma|angleSigma|scale|seed|mask|maskColour|'...
			'maskSmoothing|modulateColour|regenerateTexture|phaseReverseTime'];
		%>properties to not create transient copies of during setup phase
		ignoreProperties = 'scale|fileName|interpMethod|pixelScale|mask'
	end
	
	%=======================================================================
	methods %------------------PUBLIC METHODS
	%=======================================================================
	
		% ===================================================================
		%> @brief Class constructor
		%>
		%> This parses any input values and initialises the object.
		%>
		%> @param varargin are passed as a list of parametoer or a structure 
		%> of properties which is parsed.
		%>
		%> @return instance of opticka class.
		% ===================================================================
		function me = logGaborStimulus(varargin)
			args = optickaCore.addDefaults(varargin,struct('size',10,...
				'name','logGabor'));
			me=me@baseStimulus(args); %we call the superclass constructor first
			me.parseArgs(args, me.allowedProperties);

			me.isRect = true; %uses a rect for drawing

			checkFileName(me);

			me.ignoreProperties = ['^(' me.ignorePropertiesBase '|' me.ignoreProperties ')$'];
			me.salutation('constructor','logGabor Stimulus initialisation complete');
		end
		
		% ===================================================================
		%> @brief Setup this object in preperation for use
		%> When displaying a stimulus object, the main properties that are to be
		%> modified are copied into cache copies of the property, both to convert from 
		%> visual description (c/d, Hz, degrees) to
		%> computer metrics; and to be animated and modified as independant
		%> variables. So xPosition is copied to xPositionOut and converted from
		%> degrees to pixels. The animation and drawing functions use these modified
		%> properties, and when they are updated, for example to change to a new
		%> xPosition, internal methods ensure reconversion and update any dependent
		%> properties. This method initialises the object in preperation for display.
		%>
		%> @param sM screenManager object for reference
		%> @param in matrix for conversion to a PTB texture
		% ===================================================================
		function setup(me,sM,in)
			if ~exist('in','var'); in = []; end
			reset(me);
			me.inSetup = true;

			checkFileName(me);

			if isempty(me.isVisible)
				me.show;
			end

			me.sM = sM;
			me.ppd=sM.ppd;

			me.texture = []; %we need to reset this

			fn = fieldnames(me);
			for j=1:length(fn)
				if isempty(me.findprop([fn{j} 'Out'])) && isempty(regexp(fn{j},me.ignoreProperties, 'once')) %create a temporary dynamic property
					p=me.addprop([fn{j} 'Out']);
					p.Transient = true;%p.Hidden = true;
					if strcmp(fn{j},'xPosition');p.SetMethod = @set_xPositionOut;end
					if strcmp(fn{j},'yPosition');p.SetMethod = @set_yPositionOut;end
					if strcmp(fn{j},'size');p.SetMethod = @set_sizeOut;end
				end
				if isempty(regexp(fn{j},me.ignoreProperties, 'once'))
					me.([fn{j} 'Out']) = me.(fn{j}); %copy our property value to our tempory copy
				end
			end

			if me.angleSigma == 0; me.angleSigmaOut = 0.001; end

			loadImage(me, in);

			%build the mask
			if me.mask
				makeMask(me);
			end

			doProperties(me);

			if me.sizeOut > 0
				me.scale = me.sizeOut / (me.width / me.ppd);
			end

			if me.phaseReverseTime > 0
				me.reversePhase = false;
				shad = LoadGLSLProgramFromFiles(which('invert.frag'), 1);
				glUseProgram(shad);
				glUniform1i(glGetUniformLocation(shad, 'Image'), 0);
				glUseProgram(0);
				me.shader = shad;
				me.phaseCounter = round( me.phaseReverseTime / me.sM.screenVals.ifi );
			end

			me.inSetup = false;
			computePosition(me);
			setRect(me);
			if me.doAnimator; setup(me.animator,me); end
		end
		
		% ===================================================================
		%> @brief Update this stimulus object structure for screenManager
		%>
		% ===================================================================
		function update(me)
			if me.sizeOut > 0
				%me.scale = me.sizeOut / (me.width / me.ppd);
			end
			if me.regenerateTexture
				if ~isempty(me.texture) && me.texture > 0 && Screen(me.texture,'WindowKind') == -1
					try Screen('Close',me.texture); end %#ok<*TRYNC>
				end
				loadImage(me, []);
			end
			if me.phaseReverseTime > 0
				me.phaseCounter = round( me.phaseReverseTime / me.sM.screenVals.ifi );
			end
			resetTicks(me);
			computePosition(me);
			setRect(me);
		end
		
		% ===================================================================
		%> @brief Draw this stimulus object
		%>
		% ===================================================================
		function draw(me)
			if me.isVisible && me.tick >= me.delayTicks && me.tick < me.offTicks
				if ~isempty(me.lockAngle); angle = me.directionOut+me.lockAngle; else; angle = me.angleOut; end
				if me.mask
					Screen('BlendFunction', me.sM.win, me.msrcMode, me.mdstMode);
					if me.reversePhase
						Screen('DrawTexture',me.sM.win,me.texture,[],me.mvRect,angle,...
							me.alphaOut,me.modulateColourOut,[],me.shader);
					else
						Screen('DrawTexture',me.sM.win,me.texture,[],me.mvRect,angle,...
							me.alphaOut,me.modulateColourOut);
					end
					Screen('DrawTexture', me.sM.win, me.maskTexture, [], me.maskRect,...
							angle, [], 1, me.maskColour);
					Screen('BlendFunction', me.sM.win, me.sM.srcMode, me.sM.dstMode);
				else
					if me.reversePhase
						Screen('DrawTexture',me.sM.win,me.texture,[],me.mvRect,angle,[],...
						me.alphaOut,me.modulateColourOut,[],me.shader);
					else
						Screen('DrawTexture',me.sM.win,me.texture,[],me.mvRect,angle,[],...
						me.alphaOut,me.modulateColourOut);
					end
				end
			end
			me.tick = me.tick + 1;
		end
		
		% ===================================================================
		%> @brief Animate an structure for screenManager
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
				if me.doMotion && me.doAnimator
					me.mvRect=OffsetRect(me.mvRect,me.dX_,me.dY_);
					me.maskRect=OffsetRect(me.maskRect,me.dX_,me.dY_);
				elseif me.doMotion && ~me.doAnimator
					me.mvRect=OffsetRect(me.mvRect,me.dX_,me.dY_);
					me.maskRect=OffsetRect(me.maskRect,me.dX_,me.dY_);
				end
				if me.phaseReverseTime > 0 && mod(me.tick,me.phaseCounter) == 0
					me.reversePhase = ~me.reversePhase;
				end
			end
		end
		
		% ===================================================================
		%> @brief Reset an structure for screenManager
		%>
		% ===================================================================
		function reset(me)
			if ~isempty(me.texture) && me.texture > 0 && Screen(me.texture,'WindowKind') == -1
				try Screen('Close',me.texture); end %#ok<*TRYNC>
			end
			if ~isempty(me.maskTexture) && me.maskTexture > 0 && Screen(me.maskTexture,'WindowKind') == -1
				try Screen('Close',me.maskTexture); end %#ok<*TRYNC>
			end
			if me.wasMaskColourBlank;me.maskColour=[];end
			resetTicks(me);
			me.texture=[]; me.maskTexture = [];
			me.scale = 1;
			me.mvRect = [];
			me.dstRect = [];
			me.removeTmpProperties;
		end
		
		% ===================================================================
		%> @brief Load an image
		%>
		% ===================================================================
		function loadImage(me,in)
			ialpha = [];
			if ~exist('in','var'); in = []; end
			if me.randomTexture
				if ~isempty(me.seed) && isnumeric(me.seed); rng(me.seed);end
				if isprop(me,'sizeOut')
					in = randn(round(me.ppd * me.size));
				else
					in = randn(me.size);
				end
				if ~isempty(me.seed) && isnumeric(me.seed); rng('shuffle'); end
				%in = me.makeGrating(me.ppd*me.size);
			end
			if ~isempty(in) && ischar(in)
				[in, ~, ialpha] = imread(in);
				%in(:,:,4) = ialpha;
			elseif ~isempty(in) && isnumeric(in)
				in = in;
			elseif ~isempty(me.fileName) && exist(me.fileName,'file') == 2
				[in, ~, ialpha] = imread(me.fileName);
				%me.matrix(:,:,4) = ialpha;
			else
				in = randn(me.size*me.ppd); %texture
				in = me.scaleRand(in);
			end
			
			me.width = size(in,2);
			me.height = size(in,1);
			
			mul = me.width / me.ppd;
			
			if isprop(me,'sfOut') && isprop(me,'angleSigmaOut')
				out = me.doLogGabor(in,me.sfOut*me.size,me.sfSigmaOut*10,deg2rad(me.angleOut+90),deg2rad(me.angleSigmaOut));
			else
				out = me.doLogGabor(in,me.sf*me.size,me.sfSigma*10,deg2rad(me.angle+90),deg2rad(me.angleSigma));		
			end
			out = real(out);
			out = me.scaleRange(out); %handles contrast and scale to 0 - 1
			me.matrix = out;
			
			if isinteger(me.matrix(1))
				specialFlags = 4; %4 is optimization for uint8 textures. 0 is default
			else
				specialFlags = 0; %4 is optimization for uint8 textures. 0 is default
			end
			me.texture = Screen('MakeTexture', me.sM.win, me.matrix, 1, specialFlags);
		end

		% ===================================================================
		%> @brief Load an image
		%>
		% ===================================================================
		function out = scaleRange(me, in)
			out = rescale(in, -1, 1);
			out = out * me.contrast;
			out = rescale(out,'InputMin',-1,'InputMax',1);
			
			%out = normalize(in,'center','mean');
			%out = normalize(out,'range',[-1 1]); 
			%iMin = min(in(:));
			%rangeI = max(in(:)) - iMin;
			%out = (in - iMin) / rangeI;
			
		end
		
	end %---END PUBLIC METHODS---%
	
	
	%=======================================================================
	methods ( Static )
	%=======================================================================
		
		function [resFinal,varargout]=doLogGabor(im,FreqPeak,FreqSigma,ThetaPeak,ThetaSigma)
			[n, m, p]=size(im);
			for pLoop=1:p                                       % loop on third dimension of image
				iFT = fft2(im(:,:,pLoop));                      % we'll need the fft of the image
				if length(ThetaSigma)< length(ThetaPeak)        % pad parameter lists if necessary so they're all the same length
					 ThetaSigma = ThetaSigma(1)+ 0.*ThetaPeak;
				end
				if length(FreqSigma) < length(FreqPeak)         % pad parameter lists if necessary so they're all the same length
					 FreqSigma  = FreqSigma(1) + 0.*FreqPeak;
				end
				[X,Y]                                   = meshgrid((-m/2: (m/2-1))/(m/2),(-n/2 : (n/2 - 1))/(n/2)); % the grid we'll use to make the filter in the Fourier domain
				CentreDist                              = sqrt(X.^2 + Y.^2);    % distance from centre for computing frequency
				CentreDist(round(n/2+1),round(m/2+1))   = 1;                    % Set 0 dist to be one (a hack to avoid 1/0: we fix this later)
				CentreAng                               = pi/2+atan2(-Y,X);          % angle from centre for computing filter orientation
				for OrLoop = 1:length(ThetaPeak)                                % loop on filter orientations
					 % first compute the angular band-pass component of the filter and put it in the variable 'AngSpread'
					 ds      = sin(CentreAng) * cos(ThetaPeak(OrLoop)) - cos(CentreAng) * sin(ThetaPeak(OrLoop)); % need this for dtheta calc
					 dc      = cos(CentreAng) * cos(ThetaPeak(OrLoop)) + sin(CentreAng) * sin(ThetaPeak(OrLoop)); % need this for dtheta calc
					 dtheta  = atan(ds./dc);                            %  angular difference.
					 AngSpread  = exp((-dtheta.^2) /(2*ThetaSigma(OrLoop)^2));  % a Fourier-domain filter that is  bandpass in the angular domain
					 % now add in the spatial-frequency bandpass component
					 for s = 1:length(FreqPeak) % loop on filter SF
						  FreqSdAbsolute = (1/(2.^(FreqSigma(s))));       % compute bandwidth from parameter (which is in octaves)
						  rfo = (FreqPeak(s)./min([m n]))/0.5;            % Radius from centre of frequency plane
						  sfSpread = exp((-(log(CentreDist/rfo)).^2) / (2 * log(FreqSdAbsolute)^2)); % a log Gaussian i.e. bandpass in the log-SF domain
						  sfSpread(round(n/2+1),round(m/2+1)) = 0;                                % Impose zero d.c. on the filter (sorts out the hack above)
						  filter1                             = (sfSpread.*AngSpread);               % Multiply by angular AngSpread
						  tmp1                                = ifft2(iFT.*fftshift(filter1));    % compute result
						  res(:,:,s,OrLoop)                   = tmp1;                        % pop the result in an array
						  energy(s,OrLoop)                    = std(tmp1(:));                % compute RMS contrast and store it
					 end
				end
				if nargout>1  % if you give an extra output argument it will return the energy
					 varargout{1}=energy';
				end
				if nargout>2  % if you another output arguments it will return the filters
					 varargout{2}=fftshift(filter1);
				end
				if (length(FreqSigma)<2) && (length(ThetaSigma)<2)
					 resFinal(:,:,pLoop)=res;
				else
					 resFinal=(res);
				end
			end
		end
		
		function out = makeGrating(size)
			phase=0;
			size = round(abs(size)/2);
			[x,y]=meshgrid(-size:size,-size:size);
			angle=45*pi/180; 
			f=0.1*2*pi; 
			a=cos(angle)*f;
			b=sin(angle)*f;
			out=exp(-((x/90).^2)-((y/90).^2)).*sin(a*x+b*y+phase);
			%tex(i)=Screen('MakeTexture', w, round(gray+inc*m)); %#ok<AGROW
		end
		
	end %---END STATIC METHODS---%
	
	
	%=======================================================================
	methods ( Access = protected ) %-------PROTECTED METHODS-----%
	%=======================================================================
	
		% ===================================================================
		%> @brief Make circular mask 
		%>
		% ===================================================================
		function makeMask(me)
			if isempty(me.maskColour)
				me.wasMaskColourBlank = true;
				me.maskColour = me.sM.backgroundColour;
				me.maskColour(4) = 1; %set alpha to 1
			else
				me.wasMaskColourBlank = false;
			end
			[me.maskTexture, me.maskRect] = CreateProceduralSmoothedDisc(me.sM.win,...
				me.fieldSize, me.fieldSize, [], round(me.sizeOut/2), me.maskSmoothing, true, 2);
		end
		
		% ===================================================================
		%> @brief setRect
		%>  setRect makes the PsychRect based on the texture and screen values
		%>  This is overridden from parent class so we can scale texture
		%>  using the size value
		% ===================================================================
		function setRect(me)
			if ~isempty(me.texture)
				me.dstRect=Screen('Rect',me.texture);
				if me.mouseOverride && me.mouseValid
					me.dstRect = CenterRectOnPointd(me.dstRect, me.mouseX, me.mouseY);
				else
					me.dstRect=CenterRectOnPointd(me.dstRect, me.xOut, me.yOut);
				end
				me.mvRect = me.dstRect;
				if ~isempty(me.maskTexture)
					dstRect2= [ 0 0 me.fieldSize me.fieldSize];
					if me.mouseOverride && me.mouseValid
						dstRect2 = CenterRectOnPointd(dstRect2, me.mouseX, me.mouseY);
					else
						dstRect2=CenterRectOnPointd(dstRect2, me.xOut, me.yOut);
					end
					me.maskRect=dstRect2;
				end
			end
		end
		
		% ===================================================================
		%> @brief sizeOut Set method
		%>
		% ===================================================================
		function set_sizeOut(me,value)
			me.sizeOut = value * me.ppd;
			if me.mask == true
				me.fieldSize = round(me.sizeOut + me.maskSmoothing); %mask needs to be bigger!
			else
				me.fieldSize = me.sizeOut;
			end
		end
		
		% ===================================================================
		%> @brief 
		%>
		% ===================================================================
		function checkFileName(me)
			if isempty(me.fileName) || exist(me.fileName,'file') ~= 2 %use our default
				me.randomTexture = true;
			elseif exist(me.fileName,'file') == 2
				me.randomTexture = false;
				me.fileNames{1} = me.fileName;
			elseif exist(me.fileName,'dir') == 7
				findFiles(me);
			end
		end
		
		% ===================================================================
		%> @brief findFiles
		%>  
		% ===================================================================
		function findFiles(me)	
			if exist(me.fileName,'dir') == 7
				d = dir(me.fileName);
				n = 0;
				for i = 1: length(d)
					if d(i).isdir;continue;end
					[~,f,e]=fileparts(d(i).name);
					if regexpi(e,'png|jpeg|jpg|bmp|tif')
						n = n + 1;
						me.fileNames{n} = [me.fileName filesep f e];
					end
				end
			end
		end
		
	end %---END PROTECTED METHODS---%
	
	
	%=======================================================================
	methods ( Access = private ) %-------PRIVATE METHODS-----%
	%=======================================================================
		
	end
end