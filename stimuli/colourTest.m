% ========================================================================
%> @brief colour test is a simple RGB colour blender for teaching
%>
%> Copyright ©2014-2022 Ian Max Andolina — released: LGPL3, see LICENCE.md
% ========================================================================
classdef colourTest < spotStimulus
	
	properties %--------------------PUBLIC PROPERTIES----------%
		
	end
	
	properties (SetAccess = private, GetAccess = public)
		buttons = []
		rchar = ''
		backgroundColour = [0 0 0 0];
	end
	
	properties (SetAccess = private, GetAccess = private)
		fhandle
		sizeCache = 5;
		dStartTick = 1
		dEndTick = 1
		colourIndex = 1
		bgcolourIndex = 2
		colourList = {[1 1 1];[0 0 0];[1 0 0];[0 1 0];[0 0 1];[1 1 0];[1 0 1];[0 1 1];[.5 .5 .5]}
		allowedProperties='type|screen|blend|antiAlias'
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
		function obj = colourTest(varargin)
			%Initialise for superclass, stops a noargs error
			if nargin == 0
				varargin.family = 'colourTest';
			end
			
			obj=obj@spotStimulus(varargin); %we call the superclass constructor first
			
			if nargin>0
				obj.parseArgs(varargin, obj.allowedProperties);
			end
			
			obj.backgroundColour = [0 0 0 0];
			obj.colour = [0.2 0.2 0.2];
			obj.family = 'colourTest';
			obj.salutation('constructor','colourTest initialisation complete');
		end
		
		% ===================================================================
		%> @brief
		%>
		% ===================================================================
		function run(obj,rE)
			if exist('rE','var')
				obj.sM = rE.screen;
			end
			
			obj.sM.windowed = false;
			obj.mouseOverride = false;
			
			try
				%obj.sM.debug = true;
				open(obj.sM);
				obj.colour = [0.2 0.2 0.2];
				setup(obj, obj.sM);
				resetTicks(obj);
				
				obj.buttons = [0 0 0]; % When the user clicks the mouse, 'buttons' becomes nonzero.
				mX = 0; % The x-coordinate of the mouse cursor
				mY = 0; % The y-coordinate of the mouse cursor
				xOut = 0;
				yOut = 0;
				obj.rchar='';
				Priority(MaxPriority(obj.sM.win)); %bump our priority to maximum allowed
				FlushEvents;
				ListenChar(2);
				obj.tick = 1;
				Finc = 3;
				keyHold = 1;
				
				vbl = Screen('Flip', obj.sM.win);
				
				while isempty(regexpi(obj.rchar,'^esc'))
					
					Screen('FillRect',obj.sM.win,obj.backgroundColour,[]); %draw background
					draw(obj);
					Screen('DrawingFinished', obj.sM.win); % Tell PTB that no further drawing commands will follow before Screen('Flip')

					%[obj.xOut, obj.yFinal, obj.buttons] = GetMouse(obj.sM.screen);
					if obj.mouseOverride
						getMousePosition(obj);
						if obj.mouseValid
							obj.xOut = obj.mouseX;
							obj.yFinal = obj.mouseY;
						end
					end
					keyHold = checkKeys(obj,mX,mY,keyHold,Finc);
					
					FlushEvents('keyDown');
					
					vbl = Screen('Flip', obj.sM.win, vbl + obj.sM.screenVals.halfisi);

					obj.tick = obj.tick + 1;
				end
				
				close(obj.sM);
				Priority(0);
				ListenChar(0);
				ShowCursor;
				sca;
				
			catch ME
				close(obj.sM)
				Priority(0);
				ListenChar(0);
				ShowCursor;
				sca;
				%psychrethrow(psychlasterror);
				rethrow(ME);
			end
		end
		
		% ===================================================================
		%> @brief
		%>
		%> @param
		%> @return
		% ===================================================================
		function set.colourIndex(obj,value)
			obj.colourIndex = value;
			if obj.colourIndex > length(obj.colourList) %#ok<*MCSUP>
				obj.colourIndex = 1;
			end
		end
		
		% ===================================================================
		%> @brief
		%>
		%> @param
		%> @return
		% ===================================================================
		function set.bgcolourIndex(obj,value)
			obj.bgcolourIndex = value;
			if obj.bgcolourIndex > length(obj.colourList)
				obj.bgcolourIndex = 1;
			end
		end
		
		% ===================================================================
		%> @brief
		%>
		%> @param
		%> @return
		% ===================================================================
		function keyHold = checkKeys(obj,mX,mY,keyHold,Finc)
			[keyIsDown, ~, keyCode] = KbCheck;
			if keyIsDown == 1
				obj.rchar = KbName(keyCode);
				if iscell(obj.rchar);obj.rchar=obj.rchar{1};end
				switch obj.rchar
					case 'm' %increase size
						if obj.tick > keyHold
							if obj.sizeOut/obj.ppd < 50
								obj.sizeCache = obj.sizeOut/obj.ppd;
								obj.sizeOut = 50;
								disp(['Size is: ' num2str(obj.sizeOut) 'px'])
							end
							keyHold = obj.tick + Finc;
						end
					case 'n' %decrease size
						if obj.tick > keyHold
							if obj.sizeOut/obj.ppd > 5
								obj.sizeOut = obj.sizeCache;
								disp(['Size is: ' num2str(obj.sizeOut) 'px']);
							end
							keyHold = obj.tick + Finc;
						end
					case {'LeftArrow','left'}
						if obj.tick > keyHold
							sTemp = obj.sizeOut / obj.ppd;
							obj.sizeOut = sTemp * 0.95;
							disp(['Size is: ' num2str(obj.sizeOut) 'px'])
							keyHold = obj.tick + Finc;
						end
					case {'RightArrow','right'}
						if obj.tick > keyHold
							sTemp = obj.sizeOut / obj.ppd;
							obj.sizeOut = sTemp * 1.05;
							disp(['Size is: ' num2str(obj.sizeOut) 'px'])
							keyHold = obj.tick + Finc;
						end
					case {'UpArrow','up'}
						if obj.tick > keyHold
							obj.alphaOut = obj.alphaOut * 1.1;
							if obj.alphaOut > 1;obj.alphaOut = 1;end
							keyHold = obj.tick + Finc;
						end
					case {'DownArrow','down'}
						if obj.tick > keyHold
							obj.alphaOut = obj.alphaOut * 1.1;
							if obj.alphaOut > 1;obj.alphaOut = 1;end
							keyHold = obj.tick + Finc;
						end
					case ',<'
						if obj.tick > keyHold
							obj.mouseOverride = false;
							ShowCursor;
							keyHold = obj.tick + Finc;
						end
					case '.>'
						if obj.tick > keyHold
							obj.mouseOverride = true;
							HideCursor;
							keyHold = obj.tick + Finc;
						end
					case 'r'
						if obj.tick > keyHold
							obj.colourOut(1) = obj.colourOut(1) + 0.01;
							if obj.colourOut(1) > 1
								obj.colourOut(1) = 1;
							end
							disp(['Colour is: ' num2str(obj.colourOut) ' [' num2str(keyHold) ' ' num2str(obj.tick) ']']);
							keyHold = obj.tick + Finc;
						end

					case 'g'
						if obj.tick > keyHold
							obj.colourOut(2) = obj.colourOut(2) + 0.01;
							if obj.colourOut(2) > 1
								obj.colourOut(2) = 1;
							end
							disp(['Colour is: ' num2str(obj.colourOut) ' [' num2str(keyHold) ' ' num2str(obj.tick) ']']);
							keyHold = obj.tick + Finc;
						end
					case 'b'
						if obj.tick > keyHold
							obj.colourOut(3) = obj.colourOut(3) + 0.01;
							if obj.colourOut(3) > 1
								obj.colourOut(3) = 1;
							end
							disp(['Colour is: ' num2str(obj.colourOut) ' [' num2str(keyHold) ' ' num2str(obj.tick) ']']);
							keyHold = obj.tick + Finc;
						end
					case 'e'
						if obj.tick > keyHold
							obj.colourOut(1) = obj.colourOut(1) - 0.01;
							if obj.colourOut(1) < 0.01
								obj.colourOut(1) = 0;
							end
							disp(['Colour is: ' num2str(obj.colourOut) ' [' num2str(keyHold) ' ' num2str(obj.tick) ']']);
							keyHold = obj.tick + Finc;
						end
					case 'f'
						if obj.tick > keyHold
							obj.colourOut(2) = obj.colourOut(2) - 0.01;
							if obj.colourOut(2) < 0.01
								obj.colourOut(2) = 0;
							end
							disp(['Colour is: ' num2str(obj.colourOut) ' [' num2str(keyHold) ' ' num2str(obj.tick) ']']);
							keyHold = obj.tick + Finc;
						end
					case 'v'
						if obj.tick > keyHold
							obj.colourOut(3) = obj.colourOut(3) - 0.01;
							if obj.colourOut(3) < 0.01
								obj.colourOut(3) = 0;
							end
							disp(['Colour is: ' num2str(obj.colourOut) ' [' num2str(keyHold) ' ' num2str(obj.tick) ']']);
							keyHold = obj.tick + Finc;
						end
					case '1!'
						if obj.tick > keyHold
							obj.colourOut = [0 0 0];
							disp(['Colour is: ' num2str(obj.colourOut)]);
							keyHold = obj.tick + Finc;
						end
					case '2@'
						if obj.tick > keyHold
							obj.colourOut = [0.25 0.25 0.25];
							disp(['Colour is: ' num2str(obj.colourOut)]);
							keyHold = obj.tick + Finc;
						end
					case '3#'
						if obj.tick > keyHold
							obj.colourOut = [0.5 0.5 0.5];
							disp(['Colour is: ' num2str(obj.colourOut)]);
							keyHold = obj.tick + Finc;
						end
					case '4$'
						if obj.tick > keyHold
							obj.colourOut = [0.75 0.75 0.75];
							disp(['Colour is: ' num2str(obj.colourOut)]);
							keyHold = obj.tick + Finc;
						end
					case '5%'
						if obj.tick > keyHold
							obj.colourOut = [1 1 1];
							disp(['Colour is: ' num2str(obj.colourOut)]);
							keyHold = obj.tick + Finc;
						end
					case '6^'
						if obj.tick > keyHold
							obj.colourOut = [1 0 0];
							disp(['Colour is: ' num2str(obj.colourOut)]);
							keyHold = obj.tick + Finc;
						end
					case '7&'
						if obj.tick > keyHold
							obj.colourOut = [0 1 0];
							disp(['Colour is: ' num2str(obj.colourOut)]);
							keyHold = obj.tick + Finc;
						end
					case '8*'
						if obj.tick > keyHold
							obj.colourOut = [0 0 1];
							disp(['Colour is: ' num2str(obj.colourOut)]);
							keyHold = obj.tick + Finc;
						end
					case 'space'
						if obj.tick > keyHold
							keyHold = obj.tick + Finc;
						end
					case {';:',';'}
						if obj.tick > keyHold
							keyHold = obj.tick + Finc;
						end
					case {'''"',''''}
						if obj.tick > keyHold
							keyHold = obj.tick + Finc;
						end
				end
			end
		end
		
		
	end
	
	%=======================================================================
	methods ( Access = private ) %-------PRIVATE METHODS-----%
	%=======================================================================
		% ===================================================================
		%> @brief setColours
		%>  sets the colours based on the current index
		% ===================================================================
		function setColours(obj)
			obj.colour = obj.colourList{obj.colourIndex};
			obj.backgroundColour = obj.colourList{obj.bgcolourIndex};
		end
		
		% ===================================================================
		%> @brief regenerate
		%>  regenerates the texture
		% ===================================================================
		function regenerate(obj)
			Screen('Close',obj.texture);
			obj.constructMatrix(obj.ppd) %make our matrix
			obj.texture=Screen('MakeTexture',obj.sM.win,obj.matrix,1,[],2);
		end
	end
end