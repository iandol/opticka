% ========================================================================
%> @class imageStimulus
%> @brief Show images or directories full of images
%>
%> Class providing basic structure for image (texture) stimulus classes.
%> You can control multiple aspects of the image presentation, and scale
%> images to values in degrees, rotate them, animate them etc.
%>
%> Copyright ©2014-2024 Ian Max Andolina — released: LGPL3, see LICENCE.md
% ========================================================================
classdef imageStimulus < baseStimulus
	properties %--------------------PUBLIC PROPERTIES----------%
		%> stimulus type: 'picture'
		type char					= 'picture'
		%> filePath to load, if it is a directory use all images within
		filePath char				= ''
		%> if you pass a directory of images, which one is selected
		selection double			= 0
		%> contrast multiplier to the image
		contrast double				= 1
		%> precision: 0 = 8bit | 1 = 16bit | 2 = 32bit
		precision					= 0
		%> special flags: 0 = hardware filter, 2 = PTB
		%> filter, 4 = fast texture creation, 8 = prevent
		%> auto mip-map generation, 32 = stop Screen('Close')
		%> clearing texture
		specialFlags				= []
		%> How to compute the pixel color values when the texture is drawn 
		%> magnified, minified or drawn shifted, e.g., if
		%> sourceRect and destinationRect do not have the same size or if
		%> sourceRect specifies fractional pixel values. 0 = Nearest
		%> neighbour filtering, 1 = Bilinear filtering - this is the
		%> default. Values 2 or 3 select use of OpenGL mip-mapping for
		%> improved quality: 2 = Bilinear filtering for nearest mipmap
		%> level, 3 = Trilinear filtering across mipmap levels, 4 = Nearest
		%> neighbour filtering for nearest mipmap level, 5 = nearest
		%> neighbour filtering with linear interpolation between mipmap
		%> levels. Mipmap filtering is only supported for GL_TEXTURE_2D
		%> textures (see description of 'specialFlags' flag 1 below). A
		%> negative filterMode value will also use mip-mapping for fast
		%> drawing of blurred textures if the GL_TEXTURE_2D format is used:
		%> Mip-maps are essentially image resolution pyramids, the
		%> filterMode value selects a specific layer in that pyramid. A
		%> value of -1 draws the highest resolution layer, a value of -2
		%> draws a half-resolution layer, a value of -3 draws a quarter
		%> resolution layer and so on. Each layer has half the resolution of
		%> the preceeding layer. This allows for very fast drawing of
		%> blurred or low-pass filtered images, e.g., for gaze-contingent
		%> displays.
		filter						= 1
		%> crop: none | square | vertical | horizontal
		crop						= 'none'
		%> direction for motion of the image, different to angle
		direction					= []
	end

	properties (SetAccess = protected, GetAccess = public, Transient = true)
		%> list of imagenames if selection > 0
		filePaths					= {};
		%> current randomly selected image
		currentImage				= ''
		%> scale is set by size
		scale						= 1
		%>
		matrix
		%> pixel width
		width
		%> pixel height
		height
	end

	properties (SetAccess = protected, GetAccess = public)
		family						= 'texture'
		chosenImages				= []
	end

	properties(Dependent)
		%> number of images in the filePath directory
		nImages						= 0
	end

	properties (SetAccess = protected, GetAccess = public, Hidden = true)
		typeList			= {'picture'}
		filePathList		= 'filerequestor';
		interpMethodList	= {'nearest','linear','spline','cubic'}
		%> properties to ignore in the UI
		ignorePropertiesUI	= {'nImages','type'}
	end

	properties (Access = protected)
		%> allowed properties passed to object upon construction
		allowedProperties = {'type', 'filePath', 'selection', 'contrast', ...
			'precision','filter','crop','specialFlags'}
		%>properties to not create transient copies of during setup phase
		ignoreProperties = {'type', 'scale', 'filePath','nImages','chosenImages'}
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
		%> @return instance of class.
		% ===================================================================
		function me = imageStimulus(varargin)
			args = optickaCore.addDefaults(varargin,struct('size',0,...
				'name','Image'));
			me=me@baseStimulus(args); %we call the superclass constructor first
			me.parseArgs(args, me.allowedProperties);

			me.isRect = true; %uses a rect for drawing

			checkfilePath(me);

			me.ignoreProperties = [me.ignorePropertiesBase me.ignoreProperties];
			me.logOutput('constructor','Image Stimulus initialisation complete');
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
		function setup(me, sM, in)

			reset(me); %reset object back to its initial state
			if ~exist('in','var');in = []; end
			me.inSetup = true; me.isSetup = false;
			if isempty(me.isVisible); show(me); end

			me.chosenImages = [];

			checkfilePath(me);

			me.sM = sM;
			if ~sM.isOpen; error('Screen needs to be Open!'); end
			me.ppd = sM.ppd;
			me.screenVals = sM.screenVals;
			me.texture = []; %we need to reset this

			if isempty(me.direction); me.direction = me.angle; end

			fn = sort(properties(me));
			for j=1:length(fn)
				if ~matches(fn{j}, me.ignoreProperties) %create a temporary dynamic property
					p = me.addprop([fn{j} 'Out']);
					if strcmp(fn{j},'xPosition'); p.SetMethod = @set_xPositionOut; end
					if strcmp(fn{j},'yPosition'); p.SetMethod = @set_yPositionOut; end
					me.([fn{j} 'Out']) = me.(fn{j}); %copy our property value to our tempory copy
				end
			end

			addRuntimeProperties(me);

			loadImage(me, in);
			me.inSetup = false; me.isSetup = true;
			if me.sizeOut > 0
				me.scale = me.sizeOut / (me.width / me.ppd);
				me.szPx = me.sizeOut * me.ppd;
			else
				me.szPx = (me.width+me.height)/2;
			end
			computePosition(me);
			if me.doAnimator
				setup(me.animator, me);
			end
			setRect(me);

			function set_xPositionOut(me, value)
				me.xPositionOut = value * me.ppd;
			end
			function set_yPositionOut(me,value)
				me.yPositionOut = value * me.ppd; 
			end
			
		end

		% ===================================================================
		%> @brief Load an image
		%>
		% ===================================================================
		function loadImage(me,in)
			ialpha = uint8([]);
			tt = tic;
			if ~exist('in','var'); in = []; end
			if ~isempty(in) && ischar(in)
				% assume a file path
				[me.matrix, ~, ialpha] = imread(in);
				me.currentImage = in;
			elseif ~isempty(in) && isnumeric(in) && max(size(in))==1 && ~isempty(me.filePaths) && in <= length(me.filePaths)
				% assume an index to filePaths
				me.currentImage = me.filePaths{in};
				[me.matrix, ~, ialpha] = imread(me.currentImage);
			elseif ~isempty(in) && isnumeric(in) && size(in,3)==3
				% assume a raw matrix
				me.matrix = in;
				me.currentImage = '';
			elseif ~isempty(me.filePaths)
				% try to load from filePaths
				im = me.getP('selection');
				if im < 1 || im > me.nImages
					im = randi(length(me.filePaths));
				end
				if exist(me.filePaths{im},'file')
					me.currentImage = me.filePaths{im};
					fprintf('File %s\n',me.currentImage);
					[me.matrix, ~, ialpha] = imread(me.currentImage);
					if isinteger(me.matrix) && isfloat(ialpha)
						ialpha = uint8(ialpha .* 255);
					end
				end
			else
				if me.sizeOut <= 0; sz = 2; else; sz = me.sizeOut; end
				me.matrix = uint8(ones(sz*me.ppd,sz*me.ppd,3)*255); %white texture
				me.currentImage = '';
			end

			if me.precision > 0
				me.matrix = double(me.matrix)/255;
			end

			me.matrix = me.matrix .* me.contrastOut;
			w = size(me.matrix,2);
			h = size(me.matrix,1);

			switch me.crop
				case 'square'
					if w < h
						p = floor((h - w)/2);
						me.matrix = me.matrix(p+1:w+p, :, :);
						if ~isempty(ialpha)
							ialpha = ialpha(p+1:w+p, :);
						end
					elseif w > h
						p = floor((w - h)/2);
						me.matrix = me.matrix(:, p+1:h+p, :);
						if ~isempty(ialpha)
							ialpha = ialpha(:, p+1:h+p);
						end
					end
				case 'vertical'
					if w < h
						p = floor((h - w)/2);
						me.matrix = me.matrix(p+1:w+p, :, :);
						if ~isempty(ialpha)
							ialpha = ialpha(p+1:w+p, :);
						end
					end
				case 'horizontal'
					if w > h
						p = floor((w - h)/2);
						me.matrix = me.matrix(:, p+1:h+p, :);
						if ~isempty(ialpha)
							ialpha = ialpha(:, p+1:h+p);
						end
					end
			end

			me.width = size(me.matrix,2);
			me.height = size(me.matrix,1);

			if isempty(ialpha)
				if isfloat(me.matrix)
					me.matrix(:,:,4) = me.alphaOut;
				else
					me.matrix(:,:,4) = uint8(me.alphaOut .* 255);
				end
			else
				if isfloat(me.matrix)
					me.matrix(:,:,4) = double(ialpha);
				else
					me.matrix(:,:,4) = ialpha;
				end
			end

			if isempty(me.specialFlags) && isinteger(me.matrix(1))
				me.specialFlags = 4; %4 is optimization for uint8 textures. 0 is default
			end
			if ~isempty(me.sM) && me.sM.isOpen == true
				me.texture = Screen('MakeTexture', me.sM.win, me.matrix, 1, me.specialFlags, me.precision);
			end
			if me.isSetup; me.chosenImages = [me.chosenImages string(regexprep(me.currentImage,'\\','/'))]; end
			me.logOutput('loadImage',['Load: ' regexprep(me.currentImage,'\\','/') 'in ' num2str(toc(tt)) ' secs']);
		end

		% ===================================================================
		%> @brief Update this stimulus object structure for screenManager
		%>
		% ===================================================================
		function update(me)
			s = me.getP('selection');
			if s > 0 && ~strcmp(me.currentImage,me.filePaths{s})
				if ~isempty(me.texture) && me.texture > 0 && Screen(me.texture,'WindowKind') == -1
					try Screen('Close',me.texture); end %#ok<*TRYNC>
				end
				loadImage(me);
			end
			if me.sizeOut > 0
				me.scale = me.sizeOut / (me.width / me.ppd);
			end
			resetTicks(me);
			computePosition(me);
			setRect(me);
		end

		% ===================================================================
		%> @brief Draw this stimulus object
		%>
		% ===================================================================
		function draw(me, win)
			if me.isVisible && me.tick >= me.delayTicks && me.tick < me.offTicks
				if ~exist('win','var');win = me.sM.win; end
				% Screen('DrawTexture', windowPointer, texturePointer [,sourceRect] [,destinationRect] [,rotationAngle]
				% [, filterMode] [, globalAlpha] [, modulateColor] [, textureShader] [, specialFlags] [, auxParameters]);
				Screen('DrawTexture', win, me.texture, [], me.mvRect,...
					me.angleOut, me.filter, me.alphaOut, me.colourOut);
			end
			me.tick = me.tick + 1;
		end

		% ===================================================================
		%> @brief Animate this stimulus object
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
				if me.doAnimator
					animate(me.animator);
					me.updateXY(me.animator.x, me.animator.y, true);
					me.angleOut = -rad2deg(me.animator.angle);
				elseif me.doMotion == 1
					me.mvRect=OffsetRect(me.mvRect,me.dX_,me.dY_);
				end
			end
		end

		% ===================================================================
		%> @brief Reset this object
		%>
		% ===================================================================
		function reset(me)
			if ~isempty(me.texture) && me.texture > 0 && Screen(me.texture,'WindowKind') == -1
				try Screen('Close',me.texture); end %#ok<*TRYNC>
			end
			if isprop(me,'doAnimator') && me.doAnimator; reset(me.animator); end
			resetTicks(me);
			me.texture=[];
			me.matrix = [];
			me.scale = 1;
			me.mvRect = [];
			me.dstRect = [];
			removeTmpProperties(me);
		end

		% ===================================================================
		%> @brief nImages
		%>
		% ===================================================================
		function out = get.nImages(me)
			out = length(me.filePaths);
		end

		% ===================================================================
		%> @brief checkfilePath - loads a file or sets up a directory
		%>
		% ===================================================================
		function checkfilePath(me)
			if isempty(me.filePath) || (me.selection==0 && exist(me.filePath,'file') ~= 2 && exist(me.filePath,'file') ~= 7)%use our default
				p = mfilename('fullpath');
				p = fileparts(p);
				me.filePath = [p filesep 'Bosch.jpeg'];
				me.filePaths{1} = me.filePath;
				me.selection = 1;
			elseif exist(me.filePath,'dir') == 7
				findFiles(me);
			elseif me.selection > 1
				[p,f,e]=fileparts(me.filePath);
				for i = 1:me.selection
					me.filePaths{i} = [p filesep f num2str(i) e];
					if ~exist(me.filePaths{i},'file');warning('Image %s not available!',me.filePaths{i});end
				end
			elseif exist(me.filePath,'file') == 2
				me.filePath = regexprep(me.filePath,'\~',getenv('HOME'));
				me.filePaths = {};
				me.filePaths{1} = me.filePath;
				me.selection = 1;
			end
			if exist(me.filePath,'file') ~= 2 && exist(me.filePath,'file') ~= 7
				p = mfilename('fullpath');
				p = fileparts(p);
				me.filePath = [p filesep 'Bosch.jpeg'];
				me.filePaths{1} = me.filePath;
				me.selection = 1;
				warning('--->>> imageStimulus couldn''t find correct image, reverted to default!')
			end
			me.currentImage = me.filePaths{me.selection};
		end

	end %---END PUBLIC METHODS---%

	%=======================================================================
	methods ( Access = protected ) %-------PROTECTED METHODS-----%
	%=======================================================================

		% ===================================================================
		%> @brief setRect
		%>  setRect makes the PsychRect based on the texture and screen values
		%>  This is overridden from parent class so we can scale texture
		%>  using the size value
		% ===================================================================
		function setRect(me)
			if ~isempty(me.texture)
				%setRect@baseStimulus(me) %call our superclass version first
				me.dstRect=Screen('Rect',me.texture);
				me.dstRect = ScaleRect(me.dstRect, me.scale, me.scale);
				if me.mouseOverride && me.mouseValid
					me.dstRect = CenterRectOnPointd(me.dstRect, me.mouseX, me.mouseY);
				else
					me.dstRect=CenterRectOnPointd(me.dstRect, me.xFinal, me.yFinal);
				end
				if me.verbose
					fprintf('---> stimulus TEXTURE dstRect = %5.5g %5.5g %5.5g %5.5g width = %.2f height = %.2f\n',...
						me.dstRect(1), me.dstRect(2),me.dstRect(3),me.dstRect(4),...
						me.dstRect(3)-me.dstRect(1),me.dstRect(4)-me.dstRect(2));
				end
				me.szPx = RectWidth(me.dstRect);
				me.mvRect = me.dstRect;
			end
		end

		% ===================================================================
		%> @brief findFiles
		%>
		% ===================================================================
		function findFiles(me)
			if exist(me.filePath,'dir') == 7
				d = dir(me.filePath);
				n = 0;
				for i = 1: length(d)
					if d(i).isdir; continue; end
					[~,f,e]=fileparts(d(i).name);
					if regexpi(e,'png|jpeg|jpg|bmp|tif|tiff')
						n = n + 1;
						me.filePaths{n} = [me.filePath filesep f e];
						me.filePaths{n} = regexprep(me.filePaths{n},'\/\/','/');
					end
				end
				if me.selection < 1 || me.selection > me.nImages; me.selection = 1; end
			end
		end

	end

end
