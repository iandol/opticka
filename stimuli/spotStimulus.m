% ========================================================================
%> @brief single bar stimulus, inherits from baseStimulus
%> SPOTSTIMULUS single bar stimulus, inherits from baseStimulus
%>   The current properties are:
% ========================================================================
classdef spotStimulus < baseStimulus

   properties %--------------------PUBLIC PROPERTIES----------%
		family = 'spot'
		type = 'simple'
		flashTime = [0.5 0.5]
		flashOn = true
		contrast = 1
	end
	
	properties (Dependent = true, SetAccess = private, GetAccess = private)
		flashSwitch
	end
	
	properties (SetAccess = private, GetAccess = private)
		flashCounter = 1
		flashBG = [0.5 0.5 0.5]
		flashFG = [1 1 1]
		currentColour = [1 1 1]
		allowedProperties='^(type|flashTime|flashOn|contrast|backgroundColour)$'
		ignoreProperties = 'flashSwitch|FlashOn';
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
		%> @return instance of the class.
		% ===================================================================
		function obj = spotStimulus(args) 
			%Initialise for superclass, stops a noargs error
			if nargin == 0
				args.family = 'spot';
			end
			obj=obj@baseStimulus(args); %we call the superclass constructor first
			if nargin>0 && isstruct(args)
				fnames = fieldnames(args); %find our argument names
				for i=1:length(fnames);
					if regexp(fnames{i},obj.allowedProperties) %only set if allowed property
						obj.salutation(fnames{i},'Configuring setting in spotStimulus constructor');
						obj.(fnames{i})=args.(fnames{i}); %we set up the properies from the arguments as a structure
					end
				end
			end
			obj.ignoreProperties = ['^(' obj.ignorePropertiesBase '|' obj.ignoreProperties ')$'];
			obj.salutation('constructor','Spot Stimulus initialisation complete');
		end
		
		% ===================================================================
		%> @brief Setup an structure for runExperiment
		%>
		%> @param rE runExperiment object for reference
		%> @return
		% ===================================================================
		function setup(obj,rE)
			
			if isempty(obj.isVisible)
				obj.show;
			end
			
			if exist('rE','var')
				obj.ppd=rE.ppd;
				obj.ifi=rE.screenVals.ifi;
				obj.xCenter=rE.xCenter;
				obj.yCenter=rE.yCenter;
				obj.win=rE.win;
			end

			fn = fieldnames(spotStimulus);
			for j=1:length(fn)
				if isempty(obj.findprop([fn{j} 'Out'])) && isempty(regexp(fn{j},obj.ignoreProperties, 'once'))%create a temporary dynamic property
					p=obj.addprop([fn{j} 'Out']);
					p.Transient = true;%p.Hidden = true;
					if strcmp(fn{j},'size');p.SetMethod = @setsizeOut;end
					if strcmp(fn{j},'xPosition');p.SetMethod = @setxPositionOut;end
					if strcmp(fn{j},'yPosition');p.SetMethod = @setyPositionOut;end
					if strcmp(fn{j},'colour');p.GetMethod = @getcolourOut;end
				end
				if isempty(regexp(fn{j},obj.ignoreProperties, 'once'))
					obj.([fn{j} 'Out']) = obj.(fn{j}); %copy our property value to our tempory copy
				end
			end
			
			if isempty(obj.findprop('doFlash'));p=obj.addprop('doFlash');p.Transient = true;end
			if isempty(obj.findprop('doDots'));p=obj.addprop('doDots');p.Transient = true;end
			if isempty(obj.findprop('doMotion'));p=obj.addprop('doMotion');p.Transient = true;end
			if isempty(obj.findprop('doDrift'));p=obj.addprop('doDrift');p.Transient = true;end
			obj.doDots = 0;
			obj.doMotion = 0;
			obj.doDrift = 0;
			obj.doFlash = 0;
			
			if obj.speedOut > 0; obj.doMotion = 1; end
			
			if strcmp(obj.type,'flash')
				obj.doFlash = 1;
				bg = [rE.backgroundColour(1:3) obj.alpha];
				obj.setupFlash(bg);
			end

			if isempty(obj.findprop('xTmp'));p=obj.addprop('xTmp');p.Transient = true;end
			if isempty(obj.findprop('yTmp'));p=obj.addprop('yTmp');p.Transient = true;end
			obj.computePosition;
			
		end
		
		% ===================================================================
		%> @brief Update a structure for runExperiment
		%>
		%> @param 
		%> @return 
		% ===================================================================
		function update(obj)
			obj.computePosition;
			if obj.doFlash
				obj.resetFlash;
			end
		end
		
		% ===================================================================
		%> @brief Draw an structure for runExperiment
		%>
		%> @param rE runExperiment object for reference
		%> @return stimulus structure.
		% ===================================================================
		function draw(obj)
			if obj.doFlash == 0
				Screen('gluDisk',obj.win,obj.colourOut,obj.xTmp,obj.yTmp,obj.sizeOut);
			else
				Screen('gluDisk',obj.win,obj.currentColour,obj.xTmp,obj.yTmp,obj.sizeOut);
			end
		end

		% ===================================================================
		%> @brief Animate an structure for runExperiment
		%>
		%> @param rE runExperiment object for reference
		%> @return stimulus structure.
		% ===================================================================
		function animate(obj)
			if obj.doMotion == 1
				obj.xTmp = obj.xTmp + obj.dX;
				obj.yTmp = obj.yTmp + obj.dY;
			end
			if obj.doFlash == 1
				if obj.flashCounter <= obj.flashSwitch
					obj.flashCounter=obj.flashCounter+1;
				else
					obj.flashCounter = 1;
					obj.flashOnOut = ~obj.flashOnOut;
					if obj.flashOnOut == true
						obj.currentColour = obj.flashFG;
					else
						obj.currentColour = obj.flashBG;
						%fprintf('Current: %s | %s\n',num2str(obj.colourOut), num2str(obj.flashOnOut));
					end
				end
			end
		end
		
		% ===================================================================
		%> @brief Reset an structure for runExperiment
		%>
		%> @param rE runExperiment object for reference
		%> @return stimulus structure.
		% ===================================================================
		function reset(obj)
			obj.texture=[];
			obj.removeTmpProperties;
		end
		
		% ===================================================================
		%> @brief flashSwitch Get method
		%>
		% ===================================================================
		function flashSwitch = get.flashSwitch(obj)
			if isempty(obj.findprop('flashOnOut'))
				trigger = obj.flashOn;
			else
				trigger = obj.flashOnOut;
			end
			if trigger
				flashSwitch = round(obj.flashTime(1) / obj.ifi);
			else
				flashSwitch = round(obj.flashTime(2) / obj.ifi);
			end
		end
		
		
	end %---END PUBLIC METHODS---%
	
	%=======================================================================
	methods ( Access = private ) %-------PRIVATE METHODS-----%
	%=======================================================================
		% ===================================================================
		%> @brief sizeOut Set method
		%>
		% ===================================================================
		function setsizeOut(obj,value)
			obj.sizeOut = (value*obj.ppd) / 2; %divide by 2 to get diameter
		end
		
		% ===================================================================
		%> @brief xPositionOut Set method
		%>
		% ===================================================================
		function setxPositionOut(obj,value)
			obj.xPositionOut = (value*obj.ppd) + obj.xCenter;
			if ~isempty(obj.findprop('xTmp'));obj.computePosition;end
		end

		% ===================================================================
		%> @brief yPositionOut Set method
		%>
		% ===================================================================
		function setyPositionOut(obj,value)
			obj.yPositionOut = (value*obj.ppd) + obj.yCenter;
			if ~isempty(obj.findprop('xTmp'));obj.computePosition;end
		end
		
		% ===================================================================
		%> @brief colourOut GET method
		%>
		% ===================================================================
		function value = getcolourOut(obj)
			if isempty(obj.findprop('contrastOut')) 
				value = [(obj.colourOut(1:3) .* obj.contrast) obj.alpha];
			else
				value = [(obj.colourOut(1:3) .* obj.contrastOut) obj.alpha];
			end
		end
		
		% ===================================================================
		%> @brief setupFlash
		%>
		% ===================================================================
		function setupFlash(obj,bg)
			obj.flashFG = obj.colourOut;
			obj.flashBG = bg;
			obj.flashCounter = 1;
			if obj.flashOnOut == true
				obj.currentColour = obj.flashFG;
			else
				obj.currentColour = obj.flashBG;
			end
		end
		
		% ===================================================================
		%> @brief resetFlash
		%>
		% ===================================================================
		function resetFlash(obj)
			obj.flashFG = obj.colourOut;
			obj.flashOnOut = obj.flashOn;
			if obj.flashOnOut == true
				obj.currentColour = obj.flashFG;
			else
				obj.currentColour = obj.flashBG;
			end
			obj.flashCounter = 1;
		end
		
		% ===================================================================
		%> @brief compute xTmp and yTmp
		%>
		% ===================================================================
		function computePosition(obj)
			if isempty(obj.findprop('angleOut'));
				[dx dy]=pol2cart(obj.d2r(obj.angle),obj.startPosition);
			else
				[dx dy]=pol2cart(obj.d2r(obj.angleOut),obj.startPositionOut);
			end
			obj.xTmp = obj.xPositionOut + (dx * obj.ppd); 
			obj.yTmp = obj.yPositionOut + (dy * obj.ppd);
		end
			
	end
end