% ========================================================================
%> @brief colourManager Manages a Screen object
%> screenManager manages PTB screen settings for opticka. You can set many
%> properties of this class to control PTB screens, and use it to open and
%> close the screen based on those properties. It also manages movie
%> recording of the screen buffer and some basic drawing commands like grids,
%> spots and the hide flash trick from Mario.
% ========================================================================
classdef colourManager < optickaCore
	
	properties
		%> verbosity
		verbose logical = false
		%>
		deviceSPD char = '~/MatlabFiles/Calibration/PhosphorsDispaly++.mat'
		%>
		sensitivities char = 'ConeSensitivities_SS_2degELin3908301.mat'
		%> background colour
		backgroundColour(1,3) double = [0.5 0.5 0.5]
		%> screen
		screen screenManager
		%> how many times to try to find within gamut value?
		gamutLimit(1,1) double {mustBePositive} = 500
		%> prioritize which value to get back into gamut?
		axisPriority {mustBeMember(axisPriority,{'radius','azimuth','elevation'})} = 'radius'
		%> auto plot last RGB
		autoPlot logical = false
		%> the step to modify radius to get into gamut
		modifyRadius = 0.001;
	end
	
	properties (SetAccess = private, GetAccess = public, Dependent = true)

	end
	
	properties (SetAccess = private, GetAccess = public)
		lastRGB(1,3) double = [1 0 0]
		lastDKL(1,3) double = [0.05 0 0]
	end
	
	properties (SetAccess = private, GetAccess = private)
		%> properties allowed to be modified during construction
		allowedProperties string ='verbose|deviceSPD|sensitivities|backgroundColour|autoPlot|axisPriority|gamutLimit'
	end
	
	%=======================================================================
	methods
	%=======================================================================
	
		% ===================================================================
		%> @brief Class constructor
		%>
		%> screenManager constructor
		%>
		%> @param varargin can be simple name value pairs, a structure or cell array
		%> @return instance of the class.
		% ===================================================================
		function obj = colourManager(varargin)
			if nargin == 0; varargin.name = ''; end
			obj=obj@optickaCore(varargin); %superclass constructor
			if nargin>0
				obj.parseArgs(varargin,obj.allowedProperties);
			end
		end
		
		% ===================================================================
		%> @brief 
		%>
		%> 
		%> @param 
		%> @return 
		% ===================================================================
		function to = DKLtoRGB(obj, source, background)
			if ~exist('source','var')
				error('You must specify a source DKL colour!');
			end
			if ~exist('background','var')
				background = obj.backgroundColour;
			else
				obj.backgroundColour = background;
			end
			[to, ErrorCode] = ctGetColourTrival('CS_DKL','CS_RGB',[background,source],obj.deviceSPD,obj.sensitivities);
			
			loop = 0;
			wTrigger = true;
			axisPriority = obj.axisPriority; %#ok<*PROPLC>
			if ErrorCode == -1
				warning('THE REQUESTED COLOUR IS OUT OF RANGE, will shrink %s',axisPriority);
				while ErrorCode == -1 && loop < obj.gamutLimit
					switch axisPriority
						case 'radius'
							source(1) = source(1) - obj.modifyRadius;
						case 'azimuth'
							source(2) = source(2) - 1;
						case 'elevation'
							if source(3) > 0
								source(3) = source(3)-1;
							elseif source(3) < 0
								source(3) = source(3)+1;
							end
					end
					if source(1) < 0; source(1) = 0; end
					if source(1) == 0 && ~strcmpi(axisPriority,'elevation')
						axisPriority='elevation'; 
						if wTrigger; warning('THE REQUESTED COLOUR IS STILL OUT OF RANGE, switch to %s',axisPriority); end
						wTrigger = false;
					end
					if source(3) == 0 && ~strcmpi(axisPriority,'radius')
						axisPriority='radius'; 
						if wTrigger; warning('THE REQUESTED COLOUR IS STILL OUT OF RANGE, switch to %s',axisPriority); end
						wTrigger = false;
					end
					[to, ErrorCode] = ctGetColourTrival('CS_DKL','CS_RGB',[background,source],obj.deviceSPD,obj.sensitivities);
					loop = loop + 1;
				end
				if ErrorCode == -1
					error('Couldn''t find within gamut value!!!')
				end
			end
			if obj.verbose
				fprintf('\n--->>> DKL source: radius=%f azimuth=%f elevation=%f]\n', source(1), source(2), source(3));
				fprintf('--->>> RGB out: [%f %f %f]\n', to(1), to(2), to(3));
				if loop > 0;fprintf('------>>> Gamut search took %i iterations...\n',loop);end
			end
			to = to';
			obj.lastDKL = source;
			obj.lastRGB = to;
			if obj.autoPlot; obj.plot; end
		end
		
		% ===================================================================
		%> @brief 
		%>
		%> 
		%> @param 
		%> @return 
		% ===================================================================
		function to = RGBtoDKL(obj, source, background)
			if ~exist('source','var')
				error('You must specify a source DKL colour!');
			end
			if ~exist('background','var')
				background = obj.backgroundColour;
			else
				obj.backgroundColour = background;
			end
			[to, ErrorCode] = ctGetColourTrival('CS_RGB','CS_DKL',[background,source],obj.deviceSPD,obj.sensitivities);
			
			if obj.verbose
				fprintf('\n--->>> RGB out: [%f %f %f]\n', source(1), source(2), source(3));
				fprintf('--->>> DKL out: radius=%f azimuth=%f elevation=%f]\n'  , to(1), to(2), to(3));
			end
			
			obj.lastDKL = to;
			obj.lastRGB = source;
			if obj.autoPlot; obj.plot; end
		end
		
		% ===================================================================
		%> @brief 
		%>
		%> 
		%> @param 
		%> @return 
		% ===================================================================
		function plot(obj)
			if isempty(obj.screen)
				obj.screen = screenManager;
			end
			if ~obj.screen.isOpen
				obj.screen.debug = true;
				obj.screen.backgroundColour = [obj.backgroundColour 1];
                if obj.screen.maxScreen > 0
                    obj.screen.windowed = false;
                end
				prepareScreen(obj.screen);
				open(obj.screen,[],[],obj.screen.maxScreen);
			end
			obj.screen.backgroundColour = [obj.backgroundColour 1];
			drawBackground(obj.screen);
			drawSpot(obj.screen,10,obj.lastRGB);
			flip(obj.screen);
		end
		
		% ===================================================================
		%> @brief 
		%>
		%> 
		%> @param 
		%> @return 
		% ===================================================================
		function closeScreen(obj)
			if ~isempty(obj.screen) && obj.screen.isOpen
				close(obj.screen)
				sca
			end
		end
	end
		
	%=======================================================================
	methods (Access = private) %------------------PRIVATE METHODS
	%=======================================================================
	
	end
end