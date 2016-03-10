% ========================================================================
%> @brief movieStimulus is the class for movie based stimulus objects
%>
%>
% ========================================================================	
classdef movieStimulus < baseStimulus	
	properties %--------------------PUBLIC PROPERTIES----------%
		type = 'movie'
		fileName = ''
	end
	
	properties (SetAccess = protected, GetAccess = public)
		%> scale is set by size
		scale = 1
		family = 'texture'
		movie
	end
	
	properties (SetAccess = private, GetAccess = public, Hidden = true)
		typeList = {'movie'}
		fileNameList = 'filerequestor';
		interpMethodList = {'nearest','linear','spline','cubic'}
	end
	
	properties (SetAccess = private, GetAccess = private)
		%> allowed properties passed to object upon construction
		allowedProperties='type|fileName|contrast|interpMethod|pixelScale';
		%>properties to not create transient copies of during setup phase
		ignoreProperties = 'scale|fileName|interpMethod|pixelScale'
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
		function obj = movieStimulus(varargin)
			if nargin == 0;varargin.family = 'texture';end
			obj=obj@baseStimulus(varargin); %we call the superclass constructor first
			obj.size = 1; %override default
			if nargin>0
				obj.parseArgs(varargin, obj.allowedProperties);
			end
			
			if isempty(obj.fileName) %use our default
				obj.fileName = [ PsychtoolboxRoot 'PsychDemos/MovieDemos/DualDiscs.mov' ];
			end
			
			obj.ignoreProperties = ['^(' obj.ignorePropertiesBase '|' obj.ignoreProperties ')$'];
			obj.salutation('constructor','Texture Stimulus initialisation complete');
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
		function setup(obj,sM,in)
			
			reset(obj);
			obj.inSetup = true;
			if isempty(obj.isVisible)
				obj.show;
			end
			
			if ~exist('in','var')
				in = [];
			end
			
			if isempty(obj.isVisible)
				obj.show;
			end
			
			obj.sM = sM;
			obj.ppd=sM.ppd;

			fn = fieldnames(movieStimulus);
			for j=1:length(fn)
				if isempty(obj.findprop([fn{j} 'Out'])) && isempty(regexp(fn{j},obj.ignoreProperties, 'once')) %create a temporary dynamic property
					p=obj.addprop([fn{j} 'Out']);
					p.Transient = true;%p.Hidden = true;
					if strcmp(fn{j},'xPosition');p.SetMethod = @set_xPositionOut;end
					if strcmp(fn{j},'yPosition');p.SetMethod = @set_yPositionOut;end
				end
				if isempty(regexp(fn{j},obj.ignoreProperties, 'once'))
					obj.([fn{j} 'Out']) = obj.(fn{j}); %copy our property value to our tempory copy
				end
			end
			
			obj.movie = Screen('OpenMovie', obj.sM.win, obj.fileName);
			
			if isempty(obj.findprop('doDots'));p=obj.addprop('doDots');p.Transient = true;end
			if isempty(obj.findprop('doMotion'));p=obj.addprop('doMotion');p.Transient = true;end
			if isempty(obj.findprop('doDrift'));p=obj.addprop('doDrift');p.Transient = true;end
			if isempty(obj.findprop('doFlash'));p=obj.addprop('doFlash');p.Transient = true;end
			obj.doDots = false;
			obj.doMotion = false;
			obj.doDrift = false;
			obj.doFlash = false;
			
			if obj.speed>0 %we need to say this needs animating
				obj.doMotion=true;
 				%sM.task.stimIsMoving=[sM.task.stimIsMoving i];
			else
				obj.doMotion=false;
			end
			
			obj.scale = obj.sizeOut;
			
			obj.inSetup = false;
			
			%computePosition(obj);
			%setRect(obj);
			Screen('PlayMovie', obj.movie, 1, 1);
		end

		% ===================================================================
		%> @brief Update this stimulus object structure for screenManager
		%>
		% ===================================================================
		function update(obj)
			obj.scale = obj.sizeOut;
			resetTicks(obj);
			computePosition(obj);
			setRect(obj);
			Screen('SetMovieTimeIndex', obj.movie, 0); %reset movie
		end
		
		% ===================================================================
		%> @brief Draw this stimulus object
		%>
		% ===================================================================
		function draw(obj)
			if obj.isVisible && obj.tick >= obj.delayTicks && obj.tick < obj.offTicks
				obj.texture = Screen('GetMovieImage', obj.sM.win, obj.movie);
				Screen('DrawTexture',obj.sM.win,obj.texture);
				Screen('Close',obj.texture);
				obj.tick = obj.tick + 1;
			end
		end
		
		% ===================================================================
		%> @brief Animate an structure for screenManager
		%>
		% ===================================================================
		function animate(obj)
			if obj.isVisible && obj.tick >= obj.delayTicks
				if obj.mouseOverride
					getMousePosition(obj);
					if obj.mouseValid
						obj.mvRect = CenterRectOnPointd(obj.mvRect, obj.mouseX, obj.mouseY);
					end
				end
				if obj.doMotion == 1
					obj.mvRect=OffsetRect(obj.mvRect,obj.dX_,obj.dY_);
				end
			end
		end
		
		% ===================================================================
		%> @brief Reset an structure for screenManager
		%>
		% ===================================================================
		function reset(obj)
			resetTicks(obj);
			obj.texture=[];
			obj.scale = 1;
			obj.mvRect = [];
			obj.dstRect = [];
			obj.removeTmpProperties;
			if ~isempty(obj.movie)
				try Screen('CloseMovie', obj.movie); end
			end
			obj.movie = [];
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
		function setRect(obj)
			if ~isempty(obj.texture)
				%setRect@baseStimulus(obj) %call our superclass version first
				obj.dstRect=Screen('Rect',obj.texture);
				obj.dstRect = ScaleRect(obj.dstRect, obj.scale, obj.scale);
				if obj.mouseOverride && obj.mouseValid
					obj.dstRect = CenterRectOnPointd(obj.dstRect, obj.mouseX, obj.mouseY);
				else
					obj.dstRect=CenterRectOnPointd(obj.dstRect, obj.xOut, obj.yOut);
				end
				if obj.verbose
					fprintf('---> stimulus TEXTURE dstRect = %5.5g %5.5g %5.5g %5.5g\n',obj.dstRect(1), obj.dstRect(2),obj.dstRect(3),obj.dstRect(4));
				end
				obj.mvRect = obj.dstRect;
			end
		end
		
	end
	
	
	%=======================================================================
	methods ( Access = private ) %-------PRIVATE METHODS-----%
	%=======================================================================
		
	end
end