% ========================================================================
%> @class aprilTagStimulus
%> @brief Texture-backed binary checkerboard / AprilTag-style stimulus.
%>
%> This stimulus builds a binary MATLAB array either from a user-defined
%> `patternMatrix` or by randomly generating 0/1 values for `rows` x
%> `columns`. It then maps the binary values to `colour` and `colour2`,
%> creates a PTB texture via `Screen('MakeTexture',...)`, and draws it as a
%> standard texture stimulus.
%>
%> Copyright ©2014-2026 Ian Max Andolina — released: LGPL3, see LICENCE.md
% ========================================================================
classdef aprilTagStimulus < baseStimulus

	properties %--------------------PUBLIC PROPERTIES----------%
		%> stimulus type
		type char					= 'aprilTag'
		%> number of rows for generated patterns
		rows double				= 6
		%> number of columns for generated patterns
		columns double			= 6
		%> user supplied binary matrix of 0s and 1s, if empty generate one
		patternMatrix				= []
		%> generate a new random pattern on update if no fixed patternMatrix is set
		randomisePattern logical	= true
		%> second colour used for binary value 1
		colour2 double			= [1 1 1 1]
		%> filter mode for DrawTexture, 0 keeps edges crisp
		filter						= 0
		%> texture precision: 0=8-bit | 1=16-bit | 2=32-bit
		precision				= 0
		%> special flags passed to MakeTexture / DrawTexture
		specialFlags				= []
		%> direction for motion of the texture object
		direction double		= []
		%> number of pixels per binary cell in the generated texture matrix
		cellSize double			= 24
	end

	properties (SetAccess = protected, GetAccess = public, Transient = true)
		%> current binary matrix used to generate the texture
		binaryMatrix
		%> RGBA matrix passed to MakeTexture
		matrix
		%> texture width in pixels
		width double			= []
		%> texture height in pixels
		height double			= []
		%> scale used when size is set in degrees
		scale double			= 1 
		%> width in degrees at native texture scale
		widthD double			= []
		%> height in degrees at native texture scale
		heightD double			= []
	end

	properties (SetAccess = protected, GetAccess = public)
		%> stimulus family
		family char				= 'texture'
	end

	properties (SetAccess = protected, GetAccess = public, Hidden = true)
		%> visible in UI lists
		typeList cell				= {'aprilTag'}
		%> properties to ignore in the UI panel
		ignorePropertiesUI		= {'type'}
	end

	properties (Access = protected)
		%> allowed properties passed to object upon construction
		allowedProperties = {'type','rows','columns','patternMatrix',...
			'randomisePattern','colour2','filter','precision',...
			'specialFlags','direction','cellSize'}
		%> properties to not create transient copies of during setup phase
		ignoreProperties = {'type','binaryMatrix','matrix','width','height',...
			'widthD','heightD','scale'}
	end

	properties (Constant = true)
		tag36_11 = [1 1 1 1 1 1 1 1 1 1; 1 0 0 0 0 0 0 0 0 1; 1 0 0 0 1 1 1 1 0 1; 1 0 1 1 1 1 1 1 0 1; 1 0 1 0 0 1 0 1 0 1; 1 0 1 0 0 0 1 0 0 1; 1 0 1 1 0 0 1 1 0 1; 1 0 0 1 0 1 0 1 0 1; 1 0 0 0 0 0 0 0 0 1; 1 1 1 1 1 1 1 1 1 1]
		tag36_20 = [1 1 1 1 1 1 1 1 1 1; 1 0 0 0 0 0 0 0 0 1; 1 0 1 0 0 0 0 0 0 1; 1 0 0 1 1 1 0 1 0 1; 1 0 1 0 1 0 0 1 0 1; 1 0 0 0 1 0 0 1 0 1; 1 0 0 1 0 0 1 0 0 1; 1 0 1 0 1 1 1 1 0 1; 1 0 0 0 0 0 0 0 0 1; 1 1 1 1 1 1 1 1 1 1]
		tag36_34 = [1 1 1 1 1 1 1 1 1 1; 1 0 0 0 0 0 0 0 0 1; 1 0 0 1 1 0 0 1 0 1; 1 0 0 0 1 1 0 0 0 1; 1 0 0 1 0 0 0 1 0 1; 1 0 1 1 1 1 1 1 0 1; 1 0 1 0 1 0 0 1 0 1; 1 0 1 0 0 1 0 1 0 1; 1 0 0 0 0 0 0 0 0 1; 1 1 1 1 1 1 1 1 1 1]
		tag36_46 = [1 1 1 1 1 1 1 1 1 1; 1 0 0 0 0 0 0 0 0 1; 1 0 0 0 0 1 1 0 0 1; 1 0 0 0 0 0 0 1 0 1; 1 0 1 0 1 0 1 0 0 1; 1 0 0 0 0 0 0 1 0 1; 1 0 0 1 0 1 0 0 0 1; 1 0 0 1 1 0 1 0 0 1; 1 0 0 0 0 0 0 0 0 1; 1 1 1 1 1 1 1 1 1 1]
		tag36_52 = [1 1 1 1 1 1 1 1 1 1; 1 0 0 0 0 0 0 0 0 1; 1 0 1 0 0 0 1 1 0 1; 1 0 0 1 0 0 1 1 0 1; 1 0 1 0 0 0 1 0 0 1; 1 0 0 0 1 1 0 0 0 1; 1 0 1 1 0 1 1 0 0 1; 1 0 1 1 1 0 1 0 0 1; 1 0 0 0 0 0 0 0 0 1; 1 1 1 1 1 1 1 1 1 1]
		tag36_65 = [1 1 1 1 1 1 1 1 1 1; 1 0 0 0 0 0 0 0 0 1; 1 0 1 0 1 1 1 0 0 1; 1 0 0 1 0 1 0 1 0 1; 1 0 0 1 0 1 1 0 0 1; 1 0 0 0 1 0 1 0 0 1; 1 0 0 1 1 0 1 1 0 1; 1 0 0 1 0 1 0 0 0 1; 1 0 0 0 0 0 0 0 0 1; 1 1 1 1 1 1 1 1 1 1]
	end

	methods %------------------PUBLIC METHODS

		% ===================================================================
		%> @brief Class constructor
		%>
		%> @param varargin are passed as a list of parameter/value pairs or a
		%> structure of properties which is parsed.
		%>
		%> @return instance of class.
		% ===================================================================
		function me = aprilTagStimulus(varargin)
			args = optickaCore.addDefaults(varargin, struct('name','AprilTag',...
				'colour',[0 0 0 1],'colour2',[1 1 1 1],'size',5));
			me = me@baseStimulus(args);
			me.parseArgs(args, me.allowedProperties);

			me.isRect = true;
			me.szIsPx = false;

			if isempty(me.direction)
				me.direction = me.angle;
			end

			me.ignoreProperties = [me.ignorePropertiesBase me.ignoreProperties];
			me.logOutput('constructor','AprilTag stimulus initialisation complete');
		end

		% ===================================================================
		%> @brief Setup this stimulus object in preparation for display.
		%>
		%> @param sM screenManager object for reference.
		% ===================================================================
		function setup(me, sM)

			reset(me);
			me.inSetup = true;
			me.isSetup = false;
			if isempty(me.isVisible); show(me); end

			me.sM = sM;
			if ~sM.isOpen; error('Screen needs to be Open!'); end
			me.ppd = sM.ppd;
			me.screenVals = sM.screenVals;
			me.texture = [];

			if isempty(me.direction)
				me.direction = me.angle;
			end

			fn = sort(properties(me));
			for j = 1:length(fn)
				if ~matches(fn{j}, me.ignoreProperties)
					p = me.addprop([fn{j} 'Out']);
					if strcmp(fn{j},'xPosition'); p.SetMethod = @set_xPositionOut; end
					if strcmp(fn{j},'yPosition'); p.SetMethod = @set_yPositionOut; end
					if strcmp(fn{j},'alpha'); p.SetMethod = @set_alphaOut; end
					me.([fn{j} 'Out']) = me.(fn{j});
				end
			end

			addRuntimeProperties(me);
			buildTexture(me);

			me.inSetup = false;
			me.isSetup = true;
			computePosition(me);
			setRect(me);

			function set_xPositionOut(me, value)
				me.xPositionOut = value * me.ppd;
			end
			function set_yPositionOut(me, value)
				me.yPositionOut = value * me.ppd;
			end
			function set_alphaOut(me, value)
				me.alphaOut = value;
				if isprop(me,'colourOut'); me.colourOut(4) = value; end
				if isprop(me,'colour2Out'); me.colour2Out(4) = value; end
			end
		end

		% ===================================================================
		%> @brief Update this stimulus object for display.
		% ===================================================================
		function update(me)
			resetTicks(me);
			computePosition(me);
			setRect(me);
		end

		% ===================================================================
		%> @brief Draw this stimulus object.
		%>
		%> @param win optional offscreen window pointer.
		% ===================================================================
		function draw(me, win)
			if me.isVisible && me.tick >= me.delayTicks && me.tick < me.offTicks
				if ~exist('win','var'); win = me.sM.win; end
				Screen('DrawTexture', win, me.texture, [], me.mvRect, me.angleOut,...
					me.filter, me.alphaOut, [], [], me.specialFlags);
				me.drawTick = me.drawTick + 1;
			end
			if me.isVisible; me.tick = me.tick + 1; end
		end

		% ===================================================================
		%> @brief Animate this stimulus object.
		% ===================================================================
		function animate(me)
			if me.isVisible && me.tick >= me.delayTicks
				if me.mouseOverride
					getMousePosition(me);
					if me.mouseValid
						me.mvRect = CenterRectOnPointd(me.mvRect, me.mouseX, me.mouseY);
					end
				elseif me.doMotion == 1
					me.mvRect = OffsetRect(me.mvRect, me.dX_, me.dY_);
				end
			end
		end

		% ===================================================================
		%> @brief Reset this object back to pre-setup state.
		% ===================================================================
		function reset(me)
			if ~isempty(me.texture) && me.texture > 0 && Screen(me.texture,'WindowKind') == -1
				try Screen('Close',me.texture); end %#ok<TRYNC>
			end
			resetTicks(me);
			me.texture = [];
			me.binaryMatrix = [];
			me.matrix = [];
			me.width = [];
			me.height = [];
			me.widthD = [];
			me.heightD = [];
			me.scale = 1;
			me.mvRect = [];
			me.dstRect = [];
			removeTmpProperties(me);
		end

		% ===================================================================
		%> @brief SET colour2 method.
		%>
		%> Allow 1 (R=G=B), 3 (RGB) or 4 (RGBA) values.
		% ===================================================================
		function set.colour2(me,value)
			len = length(value);
			switch len
				case {4,3}
					me.colour2 = [value(1:3) me.alpha];
				case 1
					me.colour2 = [value value value me.alpha];
				otherwise
					me.colour2 = [0 0 0 me.alpha];
			end
			me.colour2(me.colour2 < 0) = 0;
			me.colour2(me.colour2 > 1) = 1;
		end

		% ===================================================================
		%> @brief 
		%>
		%> 
		% ===================================================================
		function [matrix,txt] = getAprilTag(me, tagID)
			matrix = []; txt = [];
			baseUrl = 'https://raw.githubusercontent.com/AprilRobotics/apriltag-imgs/master/tag36h11/';
	
			% Construct the full URL (note: 5-digit zero-padded format)
			url = sprintf('%stag36_11_%05d.png', baseUrl, tagID);
	
			% Try to download the image and convert to binary
			try
				% Read the PNG image directly from the web
				img = imread(url);

				matrix = img(:,:,1) > 128;
				matrix = double(matrix);

				txt = "[";
				for ii = 1:size(matrix,1)
					txt = txt + fprintf("%i ",matrix(ii,:));
					txt = txt + ";";
				end
				txt = txt + "]";
				disp(txt);

			catch ME
				getReport(ME)
				warning('Could not download or process tag ID %d: %s', tagID, ME.message);
			end
	
			% Save the binary matrices to a .mat file for later use
			me.patternMatrix = matrix;
		end

	end

	methods (Access = protected)

		% ===================================================================
		%> @brief Create or rebuild the binary texture.
		% ===================================================================
		function buildTexture(me)
			if ~isempty(me.texture) && me.texture > 0 && Screen(me.texture,'WindowKind') == -1
				try Screen('Close',me.texture); end %#ok<TRYNC>
				me.texture = [];
			end

			binaryPattern = me.resolvePattern();
			me.binaryMatrix = binaryPattern;
			me.rows = size(binaryPattern,1);
			me.columns = size(binaryPattern,2);

			me.matrix = me.makePatternMatrix(binaryPattern);
			me.width = size(me.matrix,2);
			me.height = size(me.matrix,1);
			me.widthD = me.width / me.ppd;
			me.heightD = me.height / me.ppd;

			if me.sizeOut > 0
				me.scale = me.sizeOut / me.widthD;
				me.szPx = round(me.sizeOut * me.ppd);
				me.szD = me.sizeOut;
			else
				me.scale = 1;
				me.szPx = me.width;
				me.szD = me.widthD;
			end

			if ~isempty(me.sM) && me.sM.isOpen == true
				me.texture = Screen('MakeTexture', me.sM.win, me.matrix, 1,...
					me.specialFlags, me.precision);
			end
		end

		% ===================================================================
		%> @brief Resolve the active binary pattern.
		%>
		%> @return out binary 0/1 matrix.
		% ===================================================================
		function out = resolvePattern(me)
			rows = max(1, round(me.getP('rows')));
			columns = max(1, round(me.getP('columns')));
			if ~isempty(me.patternMatrix)
				out = me.validatePattern(me.patternMatrix);
			elseif ~me.getP('randomisePattern') && ~isempty(me.binaryMatrix) && ...
					all(size(me.binaryMatrix) == [rows columns])
				out = me.binaryMatrix;
			else
				out = randi([0 1], rows, columns);
			end
		end

		% ===================================================================
		%> @brief Validate a binary pattern matrix.
		%>
		%> @param in candidate pattern matrix.
		%> @return out validated binary matrix.
		% ===================================================================
		function out = validatePattern(me, in)
			if ~(isnumeric(in) || islogical(in)) || isempty(in) || ndims(in) ~= 2
				error('aprilTagStimulus:patternMatrix',...
					'patternMatrix must be a non-empty 2D numeric or logical matrix.');
			end
			out = double(in);
			if ~all(out(:) == 0 | out(:) == 1)
				error('aprilTagStimulus:patternMatrix',...
					'patternMatrix must only contain binary values 0 or 1.');
			end
			me.rows = size(out,1);
			me.columns = size(out,2);
		end

		% ===================================================================
		%> @brief Convert the binary pattern to an RGBA texture matrix.
		%>
		%> @param pattern binary 0/1 matrix.
		%> @return out RGBA image matrix.
		% ===================================================================
		function out = makePatternMatrix(me, pattern)
			rows = size(pattern,1);
			columns = size(pattern,2);
			cellSize = max(1, round(me.getP('cellSize')));
			pattern = kron(pattern, ones(cellSize, cellSize));

			if me.precision > 0
				out = zeros(size(pattern,1), size(pattern,2), 4);
				colourA = me.colourOut;
				colourB = me.colour2Out;
			else
				out = zeros(size(pattern,1), size(pattern,2), 4, 'uint8');
				colourA = uint8(round(me.colourOut .* 255));
				colourB = uint8(round(me.colour2Out .* 255));
			end

			maskA = pattern == 0;
			maskB = pattern == 1;
			for i = 1:4
				channel = out(:,:,i);
				channel(maskA) = colourA(i);
				channel(maskB) = colourB(i);
				out(:,:,i) = channel;
			end

			me.logOutput('makePatternMatrix',...
				sprintf('Built %dx%d pattern (%dx%d px cells)',...
					rows, columns, cellSize, cellSize));
		end

		% ===================================================================
		%> @brief setRect makes the PsychRect based on the texture and screen values.
		% ===================================================================
		function setRect(me)
			if ~isempty(me.texture)
				me.dstRect = Screen('Rect',me.texture);
				if me.scale ~= 1
					me.dstRect = ScaleRect(me.dstRect, me.scale, me.scale);
				end
				if me.mouseOverride && me.mouseValid
					me.dstRect = CenterRectOnPointd(me.dstRect, me.mouseX, me.mouseY);
				else
					me.dstRect = CenterRectOnPointd(me.dstRect, me.xFinal, me.yFinal);
				end
				me.szPx = RectWidth(me.dstRect);
				me.szD = me.szPx / me.ppd;
				me.mvRect = me.dstRect;
			end
		end
	end
end
