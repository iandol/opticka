classdef barStimulus < baseStimulus
%BARSTIMULUS single bar stimulus, inherits from baseStimulus
%   The current properties are:

   properties %--------------------PUBLIC PROPERTIES----------%
		family = 'bar'
		type = 'solid'
		pixelScale = 1 %scale up the texture in the bar
		barWidth = 1
		barLength = 2
		contrast = []
		scale = 1
		interpMethod = 'nearest'
	end
	
	properties (SetAccess = private, GetAccess = public)
		%> computed matrix for the bar
		matrix
		%> random matrix used for texture generation
		rmatrix
	end
	
	properties (SetAccess = private, GetAccess = private)
		allowedProperties='^(type|barWidth|barLength|angle|speed|contrast|scale|interpMethod)$';
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
		function obj = barStimulus(args) 
			%Initialise for superclass, stops a noargs error
			if nargin == 0
				args.family = 'bar';
			end
			obj=obj@baseStimulus(args); %we call the superclass constructor first
			if nargin>0 && isstruct(args)
				fnames = fieldnames(args); %find our argument names
				for i=1:length(fnames);
					if regexp(fnames{i},obj.allowedProperties) %only set if allowed property
						obj.salutation(fnames{i},'Configuring setting in barStimulus constructor');
						obj.(fnames{i})=args.(fnames{i}); %we set up the properies from the arguments as a structure
					end
				end
			end
			obj.family='bar';
			obj.salutation('constructor','Bar Stimulus initialisation complete');
		end
		
		% ===================================================================
		%> @brief Generate an structure for runExperiment
		%>
		%> @param rE runExperiment object for reference
		%> @return stimulus structure.
		% ===================================================================
		function constructMatrix(obj,ppd)
			%use the passed pixels per degree to make a RGBA matrix of the
			%correct dimensions
			obj.matrix=[]; %reset the matrix
			if length(obj.colour) == 3
				obj.colour(4) = obj.alpha;
			end
			
			try
				bwpixels = round(obj.barWidth*ppd);
				blpixels = round(obj.barLength*ppd);
				if rem(bwpixels,2);bwpixels=bwpixels+1;end
				if rem(blpixels,2);blpixels=blpixels+1;end
				bwscale = (bwpixels/obj.scale)+1;
				blscale = (blpixels/obj.scale)+1;

				tmat = ones(blscale,bwscale,4); %allocate the size correctly
				tmat(:,:,1)=ones(blscale,bwscale)*obj.colour(1);
				tmat(:,:,2)=ones(blscale,bwscale)*obj.colour(2);
				tmat(:,:,3)=ones(blscale,bwscale)*obj.colour(3);
				tmat(:,:,4)=ones(blscale,bwscale)*obj.colour(4);
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
			catch
				bwpixels = round(obj.barWidth*ppd);
				blpixels = round(obj.barLength*ppd);
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
		%> @brief Generate an structure for runExperiment
		%>
		%> @param rE runExperiment object for reference
		%> @return stimulus structure.
		% ===================================================================
		function out = setup(obj,rE)
			
			obj.ppd=rE.ppd;
			obj.ifi=rE.screenVals.ifi;
			obj.xCenter=rE.xCenter;
			obj.yCenter=rE.yCenter;
			obj.win=rE.win;
			
			fn = fieldnames(barStimulus);
			for j=1:length(fn)
				if isempty(obj.findprop([fn{j} 'Out'])) && isempty(regexp(fn{j},obj.ignoreProperties, 'once'))%create a temporary dynamic property
					p=obj.addprop([fn{j} 'Out']);
					p.Transient = true;%p.Hidden = true;
					if strcmp(fn{j},'xPosition');p.SetMethod = @setxPositionOut;end
					if strcmp(fn{j},'yPosition');p.SetMethod = @setyPositionOut;end
				end
				if isempty(regexp(fn{j},obj.ignoreProperties, 'once'))
					obj.([fn{j} 'Out']) = obj.(fn{j}); %copy our property value to our tempory copy
				end
			end
			
			if isempty(obj.findprop('doDots'));p=obj.addprop('doDots');p.Transient = true;end
			if isempty(obj.findprop('doMotion'));p=obj.addprop('doMotion');p.Transient = true;end
			if isempty(obj.findprop('doDrift'));p=obj.addprop('doDrift');p.Transient = true;end
			if isempty(obj.findprop('doFlash'));p=obj.addprop('doFlash');p.Transient = true;end
			obj.doDots = [];
			obj.doMotion = [];
			obj.doDrift = [];
			obj.doFlash = [];
			
			obj.constructMatrix(obj.ppd) %make our matrix
			obj.texture=Screen('MakeTexture',obj.win,obj.matrix,1,[],2);
			
			if obj.speed>0 %we need to say this needs animating
				obj.doMotion=1;
 				%rE.task.stimIsMoving=[rE.task.stimIsMoving i];
			else
				obj.doMotion=0;
			end
			
			obj.setRect();
			
			out = obj.toStructure;
		end
		
		% ===================================================================
		%> @brief Update an structure for runExperiment
		%>
		%> @param in runExperiment object for reference
		%> @return stimulus structure.
		% ===================================================================
		function update(obj)
			
		end
		
		% ===================================================================
		%> @brief Draw an structure for runExperiment
		%>
		%> @param rE runExperiment object for reference
		%> @return stimulus structure.
		% ===================================================================
		function draw(obj)
			Screen('DrawTexture',obj.win,obj.texture,[],obj.mvRect,obj.angleOut);
		end
		
		% ===================================================================
		%> @brief Animate an structure for runExperiment
		%>
		%> @param rE runExperiment object for reference
		%> @return stimulus structure.
		% ===================================================================
		function animate(obj)
			
		end
		
		% ===================================================================
		%> @brief Reset an structure for runExperiment
		%>
		%> @param rE runExperiment object for reference
		%> @return
		% ===================================================================
		function reset(obj)
			
		end
		
		% ===================================================================
		%> @brief barLength set method
		%>
		%> @param length of bar
		%> @return
		% ===================================================================
		function set.barLength(obj,value)
			if ~(value > 0)
				value = 0.1;
			end
			obj.barLength = value;
			if obj.barLength>obj.barWidth
				obj.salutation('WARNING:','Length is smaller than width');
			end
			obj.salutation(['set length: ' num2str(value)],'Custom set method')
		end
		
		% ===================================================================
		%> @brief barWidth set method
		%>
		%> @param width of bar in degrees
		%> @return
		% ===================================================================
		function set.barWidth(obj,value)
			if ~(value > 0)
				value = 0.1;
			end
			obj.barWidth = value;
			if obj.barWidth<obj.barLength
				obj.salutation('WARNING:','Width is larger than length');
			end
			obj.salutation(['set width: ' num2str(value)],'Custom set method')
		end
		
	end %---END PUBLIC METHODS---%
	
	%=======================================================================
	methods ( Access = private ) %-------PRIVATE METHODS-----%
	%=======================================================================
		% ===================================================================
		%> @brief xPositionOut Set method
		%>
		% ===================================================================
		function setxPositionOut(obj,value)
			obj.xPositionOut = value*obj.ppd;
			obj.setRect(); %make sure our psychrect is updated 
		end
		
		% ===================================================================
		%> @brief yPositionOut Set method
		%>
		% ===================================================================
		function setyPositionOut(obj,value)
			obj.yPositionOut = value*obj.ppd;
			obj.setRect(); %make sure our psychrect is updated 
		end
		
		% ===================================================================
		%> @brief setRect
		%>  setRect makes the PsychRect based on the texture and screen values
		% ===================================================================
		function setRect(obj)
			obj.dstRect=Screen('Rect',obj.texture);
			obj.dstRect=ScaleRect(obj.dstRect,obj.scaledown,obj.scaledown);
			obj.dstRect=CenterRectOnPoint(obj.dstRect,obj.xCenter,obj.yCenter);
			if isempty(obj.findprop('xPositionOut'));
				obj.dstRect=OffsetRect(obj.dstRect,(obj.xPosition)*obj.ppd,(obj.yPosition)*obj.ppd);
			else
				obj.dstRect=OffsetRect(obj.dstRect,obj.xPositionOut,obj.yPositionOut);
			end
			obj.mvRect=obj.dstRect;
		end
	end
end