% ========================================================================
%> @brief calibrateLuminance manaul / automatic luminance calibration
%>
%> calibrateLuminance manaul / automatic luminance calibration
%>
% ========================================================================
classdef calibrateLuminance < handle
	
	properties
		%> how much detail to show
		verbosity = false
		%> allows the constructor to run the open method immediately
		runNow = true
		%> number of measures (default = 20)
		nMeasures = 21
		%> screen to calibrate
		screen
		%> use ColorCalII automatically
		useCCal = true
		%> comments to note about this calibration
		comments
		%> which gamma table opticka selects?
		choice = 1
		analysisMethods = {'pchipinterp';'smoothingspline';'cubicinterp';'splineinterp';'cubicspline'}
	end
	
	properties (SetAccess = private, GetAccess = public)
		cMatrix
		thisx
		thisy
		thisY
		ramp
		inputValues
		rampNorm
		inputValuesNorm
		initialClut
		oldClut
		dacBits
		lutSize
		displayRange
		displayBaseline
		gammaTable
		displayGamma
		modelFit
	end
	
	properties (SetAccess = private, GetAccess = private)
		win
		canAnalyze
		p
		plotHandle
		allowedPropertiesBase='^(verbosity|runNow|screen|nMeasures)$'
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
		%> @return instance of labJack class.
		% ===================================================================
		function obj = calibrateLuminance(args)
			if nargin>0 && isstruct(args)
				if nargin>0 && isstruct(args)
					fnames = fieldnames(args); %find our argument names
					for i=1:length(fnames);
						if regexp(fnames{i},obj.allowedPropertiesBase) %only set if allowed property
							obj.salutation(fnames{i},'Configuring property in LabJack constructor');
							obj.(fnames{i})=args.(fnames{i}); %we set up the properies from the arguments as a structure
						end
					end
				end
			end
			if isempty(obj.screen)
				obj.screen = max(Screen('Screens'));
			end
			if obj.useCCal == true
				obj.cMatrix = ColorCal2('ReadColorMatrix');
				if isempty(obj.cMatrix)
					obj.useCCal = false;
				end
			end
			if obj.runNow == true
				obj.run;
			end
		end
		
		% ===================================================================
		%> @brief run
		%>	run the main calibration loop
		%>
		% ===================================================================
		function run(obj)
			
			if obj.useCCal == false
				input(sprintf(['When black screen appears, point photometer, \n' ...
					'get reading in cd/m^2, input reading using numpad and press enter. \n' ...
					'A screen of higher luminance will be shown. Repeat %d times. ' ...
					'Press enter to start'], obj.nMeasures));
			end
			
			obj.initialClut = repmat([0:255]'/255,1,3); %#ok<NBRAK>
			psychlasterror('reset');
			
			try
				Screen('Preference', 'SkipSyncTests', 1);
				Screen('Preference', 'VisualDebugLevel', 0);
				PsychImaging('PrepareConfiguration');
				PsychImaging('AddTask', 'General', 'UseFastOffscreenWindows');
				PsychImaging('AddTask', 'General', 'FloatingPoint32BitIfPossible');
				PsychImaging('AddTask', 'General', 'NormalizedHighresColorRange');
				if obj.screen == 0
					rec = [0 0 800 600];
				else
					rec = [];
				end
				obj.win = PsychImaging('OpenWindow', obj.screen, 0, rec);
				[obj.oldClut, obj.dacBits, obj.lutSize] = Screen('ReadNormalizedGammaTable', obj.screen);
				BackupCluts;
				Screen('LoadNormalizedGammaTable', obj.win, obj.initialClut);
				
				obj.ramp = [0:1/(obj.nMeasures - 1):1]; %#ok<NBRAK>
				obj.ramp(end) = 1;
				obj.inputValues = zeros(1,length(obj.ramp));
				a=1;
				
				for i = obj.ramp
					Screen('FillRect',obj.win,i);
					Screen('Flip',obj.win);
					if obj.useCCal == true
						[obj.thisx,obj.thisy,obj.thisY] = obj.getCCalxyY;
						obj.inputValues(a) = obj.thisY;
					else
						% MK: Deprecated as not reliable: resp = input('Value?');
						fprintf('Value? ');
						beep
						resp = GetNumber;
						fprintf('\n');
						obj.inputValues = [obj.inputValues resp];
					end
					a = a + 1;
				end
				
				RestoreCluts;
				Screen('CloseAll');
			catch %#ok<CTCH>
				RestoreCluts;
				Screen('CloseAll');
				psychrethrow(psychlasterror);
			end
			
			obj.canAnalyze = 1;
			obj.analyze;
			
		end
		
		% ===================================================================
		%> @brief useCCal
		%>	run the main calibration loop
		%>
		% ===================================================================
		function [x,y,Y] = getCCalxyY(obj)
			s = ColorCal2('MeasureXYZ');
			correctedValues = obj.cMatrix(1:3,:) * [s.x s.y s.z]';
			X = correctedValues(1);
			Y = correctedValues(2);
			Z = correctedValues(3);
			x = X / (X + Y + Z);
			y = Y / (X + Y + Z);
		end
		
		% ===================================================================
		%> @brief run
		%>	run the main calibration loop
		%>
		% ===================================================================
		function analyze(obj)
			if obj.canAnalyze == 1
				
				obj.displayRange = (max(obj.inputValues) - min(obj.inputValues));
				obj.displayBaseline = min(obj.inputValues);
				
				%Normalize values
				obj.inputValuesNorm = (obj.inputValues - obj.displayBaseline)/(max(obj.inputValues) - min(obj.inputValues));
				obj.rampNorm = obj.ramp;
				
				if ~exist('fittype'); %#ok<EXIST>
					fprintf('This function needs fittype() for automatic fitting. This function is missing on your setup.\n');
				end
				
				%Gamma function fitting
				g = fittype('x^g');
				fo = fitoptions('Method','NonlinearLeastSquares',...
					'Display','iter','MaxIter',1000,...
					'Upper',3,'Lower',0,'StartPoint',1.5);
				[fittedmodel, gof] = fit(obj.rampNorm',obj.inputValuesNorm',g,fo);
				obj.displayGamma = fittedmodel.g;
				obj.gammaTable{1} = ((([0:1/255:1]'))).^(1/fittedmodel.g);
				
				obj.modelFit{1}.method = 'Gamma';
				obj.modelFit{1}.table = fittedmodel([0:1/255:1]);
				obj.modelFit{1}.gof = gof;
				
				for i = 1:length(obj.analysisMethods)
					
					method = obj.analysisMethods{i};
					%fo = fitoptions('Display','iter','MaxIter',1000);
					[fittedmodel,gof] = fit(obj.rampNorm',obj.inputValuesNorm', method);
					obj.modelFit{i+1}.method = method;
					obj.modelFit{i+1}.table = fittedmodel([0:1/255:1]);
					obj.modelFit{i+1}.gof = gof;
					%Invert interpolation
					[fittedmodel,gof] = fit(obj.inputValuesNorm',obj.rampNorm',method);
					obj.gammaTable{i+1} = fittedmodel([0:1/255:1]); 
				
				end
				
				obj.plot;
				
			end
		end
		
		% ===================================================================
		%> @brief run
		%>	run the main calibration loop
		%>
		% ===================================================================
		function plot(obj)
			obj.plotHandle = figure;
			obj.p = panel(obj.plotHandle,'defer');
			scnsize = get(0,'ScreenSize');
			pos=get(gcf,'Position');
			
			obj.p.pack(3,1);
			obj.p.margin = [15 20 5 15];
			obj.p.fontsize = 12;
			
			obj.p(1,1).select();
			plot(obj.ramp, obj.inputValues, 'k.-');
			axis tight
			xlabel('Indexed Values (0 - 255)');
			ylabel('Luminance cd/m^2');
			title('Input -> Output Raw Data');
			
			obj.p(2,1).select();
			hold all
				for i=1:length(obj.modelFit)
					plot([0:1/255:1], obj.modelFit{i}.table);
					legendtext{i} = obj.modelFit{i}.method;
				end
				plot(obj.rampNorm, obj.inputValuesNorm, 'r.')
				legendtext{end+1} = 'Raw Data';
			hold off
			axis tight
			xlabel('Normalised Luminance Input');
			ylabel('Normalised Luminance Output');
			legend(legendtext,'Location','NorthWest');
			title(sprintf('Gamma model x^{%.2f} vs. Interpolation', obj.displayGamma));
			
			obj.p(3,1).select();
			hold all
			for i=1:length(obj.gammaTable)
				plot(1:length(obj.gammaTable{i}),obj.gammaTable{i});
				legendtext{i} = obj.modelFit{i}.method;
			end
			hold off
			axis tight
			xlabel('Indexed Values')
			ylabel('Normalised Luminance Output');
			legend(legendtext,'Location','NorthWest');
			title('Plot of output Gamma curves');
			
			newpos = [pos(1) 1 pos(3) scnsize(4)];
			set(gcf,'Position',newpos);
			
			obj.p.refresh();
			
		end
		
		% ===================================================================
		%> @brief zeroCalibration
		%>
		%>
		% ===================================================================
		function zeroCalibration(obj)
			ColorCal2('ZeroCalibration');
			helpdlg('Dark Calibration Done!');
		end
		
		
	end
	
	%=======================================================================
	methods ( Access = private ) % PRIVATE METHODS
		%=======================================================================
		
		%===============Destructor======================%
		function delete(obj)
			obj.verbosity = 1;
			obj.salutation('DELETE Method','Closing calibrateLuminance')
		end
		
		% ===================================================================
		%> @brief Converts properties to a structure
		%>
		%> Prints messages dependent on verbosity
		%> @param tmp is whether to use the temporary or permanent properties
		%> @return out the structure
		% ===================================================================
		function out=toStructure(obj)
			fn = fieldnames(obj);
			for j=1:length(fn)
				out.(fn{j}) = obj.(fn{j});
			end
		end
		
		%===========Salutation==========%
		function salutation(obj,in,message)
			if obj.verbosity > 0
				if ~exist('in','var')
					in = 'General Message';
				end
				if exist('message','var')
					fprintf([message ' | ' in '\n']);
				else
					fprintf(['\nHello from ' obj.name ' | labJack\n\n']);
				end
			end
		end
	end
end