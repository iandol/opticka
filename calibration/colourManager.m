% ========================================================================
%> @brief colourManager manages colours wrapping the CRS Color Toolbox
%>
%> Copyright ©2014-2022 Ian Max Andolina — released: LGPL3, see LICENCE.md
% ========================================================================
classdef colourManager < optickaCore
	
	properties
		%> verbosity
		verbose = true
		%>
		deviceSPD char = '/home/psychww/MatlabFiles/Calibration/PhosphorsDisplay++Color++.mat'
		%>
		sensitivities char = 'ConeSensitivities_SS_2degELin3908301.mat'
		%> 
		sensitivitiesCIE char = 'CMF_CIE1931_2deg3608301.mat'
		%> background colour
		backgroundColour(1,3) double = [0.5 0.5 0.5]
		%> screen
		screen screenManager
		%> how many times to try to find within gamut value?
		gamutLimit(1,1) double {mustBePositive} = 1e3
		%> prioritize which value to get back into gamut?
		axisPriority {mustBeMember(axisPriority,{'radius','azimuth','elevation'})} = 'radius'
		%> auto plot last RGB
		autoPlot logical = false
		%> the step to modify radius to get into gamut
		modifyRadius double = 0.5e-2;
		lastRGB(1,3) double = [1 0 0]
		lastDKL(1,3) double = [0.05 0 0]
		lastMB(1,3) double = [1 0 0]
		lastxyY(1,3) double = [0 0 0]
	end
	
	properties (SetAccess = private, GetAccess = public, Dependent = true)

	end
	
	properties (SetAccess = private, GetAccess = public)
		
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
			if obj.verbose; t1=tic; end
			if ErrorCode == -1
				warning('THE REQUESTED COLOUR IS OUT OF RANGE, will shrink %s',axisPriority);
				while ErrorCode == -1 && loop < obj.gamutLimit
					switch axisPriority
						case 'radius'
							source(1) = source(1) - obj.modifyRadius;
							if source(1) < 0; source(1) = 0; end
						case 'azimuth'
							source(2) = source(2) - 1;
							if source(2) < 0; source = 360; end
							if source(2) > 360; source = 0; end
						case 'elevation'
							if source(3) > 90
								source(3) = source(3)-1;
							elseif source(3) < -90
								source(3) = source(3)+1;
							end
					end
					if source(1) == 0 && ~strcmpi(axisPriority,'elevation')
						axisPriority='elevation'; 
						if wTrigger; warning('THE REQUESTED COLOUR IS STILL OUT OF RANGE, switch to %s',axisPriority); end
						wTrigger = false; loop = 0;
					end
					if source(3) == 0 && ~strcmpi(axisPriority,'radius')
						axisPriority='radius'; 
						if wTrigger; warning('THE REQUESTED COLOUR IS STILL OUT OF RANGE, switch to %s',axisPriority); end
						wTrigger = false; loop = 0;
					end
					[to, ErrorCode] = ctGetColourTrival('CS_DKL','CS_RGB',[background,source],obj.deviceSPD,obj.sensitivities);
					loop = loop + 1;
				end
				if ErrorCode == -1
					if obj.verbose;fprintf('------>>> Gamut search took %i iterations in %.1f secs...\n',loop, toc(t1));end
					error('Couldn''t optimise to be within gamut value!!!')
				end
			end
			if obj.verbose
				fprintf('\n--->>> DKL source: radius=%f azimuth=%f elevation=%f]\n', source(1), source(2), source(3));
				fprintf('--->>> RGB out: [%f %f %f]\n', to(1), to(2), to(3));
				if loop > 0;fprintf('------>>> Gamut search took %i iterations in %.1f secs...\n',loop, toc(t1));end
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
				error('You must specify a source RGB colour!');
			end
			if ~exist('background','var')
				background = obj.backgroundColour;
			else
				obj.backgroundColour = background;
			end
			[to, ErrorCode] = ctGetColourTrival('CS_RGB','CS_DKL',[background,source],obj.deviceSPD,obj.sensitivities);
			
			if ErrorCode == -1
				warning('OUT OF GAMUT!!!')
			end 
			
			if obj.verbose
				fprintf('\n--->>> RGB source: [%f %f %f]\n', source(1), source(2), source(3));
				fprintf('--->>> DKL out: radius=%f azimuth=%f elevation=%f\n'  , to(1), to(2), to(3));
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
		function to = RGBtoxyY(obj, source)
			if ~exist('source','var')
				error('You must specify a source xyY colour!');
			end
			
			[to, ErrorCode] = ctGetColourTrival('CS_RGB','CS_CIE1931xyY',source,obj.deviceSPD,obj.sensitivitiesCIE);
			
			if ErrorCode == -1
				warning('OUT OF GAMUT!!!')
			end
			
			if obj.verbose
				fprintf('\n--->>> RGB source: [%f %f %f]\n', source(1), source(2), source(3));
				fprintf('--->>> xyY out: x=%f y=%f Y=%f\n'  , to(1), to(2), to(3));
			end
			
			obj.lastRGB = source;
			obj.lastxyY = to;
			if obj.autoPlot; obj.plot; end
		end
		
		% ===================================================================
		%> @brief 
		%>
		%> 
		%> @param 
		%> @return 
		% ===================================================================
		function to = RGBtoMB(obj, source)
			if ~exist('source','var')
				error('You must specify a source RGB colour!');
			end
			[to, ErrorCode] = ctGetColourTrival('CS_RGB','CS_MB',source,obj.deviceSPD,obj.sensitivities);
			
			if ErrorCode == -1
				warning('OUT OF GAMUT!!!')
			end 
			
			if obj.verbose
				fprintf('\n--->>> RGB source: [%f %f %f]\n', source(1), source(2), source(3));
				fprintf('--->>> MB out: A=%f B=%f C=%f\n'  , to(1), to(2), to(3));
			end
			
			obj.lastMB = to;
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
		function to = MBtoRGB(obj, source)
			if ~exist('source','var')
				error('You must specify a source MB colour!');
			end
			[to, ErrorCode] = ctGetColourTrival('CS_MB','CS_RGB',source,obj.deviceSPD,obj.sensitivities);
			
			if ErrorCode == -1
				warning('OUT OF GAMUT!!!')
			end 
			
			if obj.verbose
				fprintf('\n--->>> RGB source: [%f %f %f]\n', source(1), source(2), source(3));
				fprintf('--->>> DKL out: radius=%f azimuth=%f elevation=%f\n'  , to(1), to(2), to(3));
			end
			
			obj.lastMB = source;
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
		function to = DKLtoxyY(obj, source, background)
			if ~exist('source','var')
				error('You must specify a source DKL colour!');
			end
			if ~exist('background','var')
				background = obj.backgroundColour;
			else
				obj.backgroundColour = background;
			end
			
			rgb = obj.DKLtoRGB(source,background);
			to = obj.RGBtoxyY(rgb);
			
			if obj.verbose
				fprintf('\n--->>> DKL source:\t\tradius=%f azimuth=%f elevation=%f\n', source(1), source(2), source(3));
				fprintf('--->>> RGB intermediate:\t\t[%f %f %f]\n', rgb(1), rgb(2), rgb(3));
				fprintf('--->>> xyY out:\t\tx=%f y=%f Y=%f\n', to(1), to(2), to(3));
			end
			
			obj.lastRGB = rgb;
			obj.lastxyY = to;
			obj.lastDKL = source;
			if obj.autoPlot; obj.plot; end
		end
		
		% ===================================================================
		%> @brief 
		%>
		%> 
		%> @param 
		%> @return 
		% ===================================================================
		function to = xyYtoRGB(obj, source)
			if ~exist('source','var')
				error('You must specify a source xyY colour!');
			end
			
			[to, ErrorCode] = ctGetColourTrival('CS_CIE1931xyY','CS_RGB',source,obj.deviceSPD,obj.sensitivitiesCIE);
			
			if ErrorCode == -1
				warning('OUT OF GAMUT!!!')
			end
			
			if obj.verbose
				fprintf('\n--->>> xyY source: [%f %f %f]\n', source(1), source(2), source(3));
				fprintf('--->>> RGB out: [%f %f %f]\n'  , to(1), to(2), to(3));
			end
			
			obj.lastRGB = to;
			obj.lastxyY = source;
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
                if obj.screen.screen > 0
                    obj.screen.windowed = false;
				else
					obj.screen.windowed = [0 0 600 600];
                end
				prepareScreen(obj.screen);
				open(obj.screen,[],[]);
			end
			%obj.screen.backgroundColour = [obj.backgroundColour 1];
			obj.screen.backgroundColour = [obj.lastRGB 1];
			drawBackground(obj.screen);
			%drawSpot(obj.screen,15,obj.lastRGB);
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