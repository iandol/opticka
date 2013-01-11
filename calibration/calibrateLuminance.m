% ========================================================================
%> @brief calibrateLuminance manaul / automatic luminance calibration
%>
%> calibrateLuminance manaul / automatic luminance calibration
%> To enter settings use a structure:
%>
%> >> mycal = calibrateLuminance(struct('nMeasures',25,'useCCal',true))
%>
%> calibrateLuminance will ask if you need to zero calibrate, you only need
%> to do this after first plugging in the ColorCal. Then simply place the
%> ColorCalII in front of the monitor and follow instructions. After doing
%> nMeasures of luminance steps, it will fit the raw luminance values using a
%> variety of methods and then plot these out to a figure (it will ask you for 
%> comments to enter for the calibration, you should enter monitor type, 
%> lighting conditions etc). You can then save mycal to disk for later use by
%> your programs. To use in PTB, choose the preffered fit (1 is the gamma 
%> function and the rest are the various model options listed in analysisMethods). 
%> you need to expand the selected model fit to 3 columns before passing to
%> LoadNormalizedGammaTable:
%> 
%> gTmp = repmat(mycal.gammaTable{choiceofmodel},1,3);
%> Screen('LoadNormalizedGammaTable', theScreen, gTmp);
%>
% ========================================================================
classdef calibrateLuminance < handle
	
	properties
		%> how much detail to show on commandline
		verbosity = 0
		%> allows the constructor to run the open method immediately
		runNow = true
		%> number of measures (default = 20)
		nMeasures = 20
		%> screen to calibrate
		screen
		%> use ColorCalII automatically
		useCCal = true
		%> comments to note about this calibration
		comments = {''}
		%> which gamma table should opticka select?
		choice = 1
		%> methods list to fit to raw luminance values
		analysisMethods = {'pchipinterp';'smoothingspline';'cubicinterp';'splineinterp';'cubicspline'}
		%> filename this was saved as
		filename
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
				else
					reply = input('Do you need to calibrate the ColorCalII first? Y/N (N): ','s');
					if strcmpi(reply,'Y')
						reply = input('*ZERO CALIBRATION* -- please cover the ColorCalII then press enter...','s');
						if isempty(reply)
							obj.zeroCalibration;
						end
					end
				end
			end
			if obj.runNow == true
				obj.run;
			end
		end
		
		% ===================================================================
		%> @brief run
		%>	run the main calibration loop, uses the max # screen by default
		%>
		% ===================================================================
		function run(obj)
			
			if obj.useCCal == false
				input(sprintf(['When black screen appears, point photometer, \n' ...
					'get reading in cd/m^2, input reading using numpad and press enter. \n' ...
					'A screen of higher luminance will be shown. Repeat %d times. ' ...
					'Press enter to start'], obj.nMeasures));
			else
				input('Please place ColorCalII in front of monitor then press enter...');
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
					WaitSecs(0.5);
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
			analyze(obj);
			test(obj);
			
		end
		
		% ===================================================================
		%> @brief analyze
		%>	once the raw data is collected, this analyzes (fits) the data
		%>
		% ===================================================================
		function test(obj)
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
				gTmp = repmat(obj.gammaTable{obj.choice},1,3);
				Screen('LoadNormalizedGammaTable', obj.win, gTmp);
				
				obj.ramp = [0:1/(obj.nMeasures - 1):1]; %#ok<NBRAK>
				obj.ramp(end) = 1;
				obj.inputValues = zeros(1,length(obj.ramp));
				a=1;
				
				for i = obj.ramp
					Screen('FillRect',obj.win,i);
					Screen('Flip',obj.win);
					WaitSecs(0.5);
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
			
			plot(obj);
			
		end
		
		% ===================================================================
		%> @brief getCCalxyY
		%>	Uses the ColorCalII to return the current xyY values
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
		%> @brief analyze
		%>	once the raw data is collected, this analyzes (fits) the data
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
				[fittedmodel, gof, output] = fit(obj.rampNorm',obj.inputValuesNorm',g,fo);
				obj.displayGamma = fittedmodel.g;
				obj.gammaTable{1} = ((([0:1/255:1]'))).^(1/fittedmodel.g);
				
				obj.modelFit{1}.method = 'Gamma';
				obj.modelFit{1}.table = fittedmodel([0:1/255:1]);
				obj.modelFit{1}.gof = gof;
				obj.modelFit{1}.output = output;
				
				for i = 1:length(obj.analysisMethods)					
					method = obj.analysisMethods{i};
					%fo = fitoptions('MaxIter',1000);
					[fittedmodel,gof,output] = fit(obj.rampNorm',obj.inputValuesNorm', method);
					obj.modelFit{i+1}.method = method;
					obj.modelFit{i+1}.table = fittedmodel([0:1/255:1]);
					obj.modelFit{i+1}.gof = gof;
					obj.modelFit{i+1}.output = output;
					%Invert interpolation
					x = obj.inputValuesNorm;
					x = obj.makeUnique(x);
					[fittedmodel,gof] = fit(x',obj.rampNorm',method);
					obj.gammaTable{i+1} = fittedmodel([0:1/255:1]);
				end
				
				ans = questdlg('Do you want to add comments to this calibration?');
				if strcmpi(ans,'Yes')
					if iscell(obj.comments)
						cmts = obj.comments;
					else
						cmts = {obj.comments};
					end
					cmt = inputdlg('Please enter a description for this calibration run:','Gamma Calibration',10,cmts);
					if ~isempty(cmt)
						obj.comments = cmt{1};
					end
				end

				obj.plot;
				
			end
		end
		
		% ===================================================================
		%> @brief plot
		%>	This plots the calibration results
		%>
		% ===================================================================
		function plot(obj)
			obj.plotHandle = figure;
			%obj.p = panel(obj.plotHandle,'defer');
			scnsize = get(0,'ScreenSize');
			pos=get(gcf,'Position');
			
			%obj.p.pack(2,2);
			%obj.p.margin = [15 20 5 15];
			%obj.p.fontsize = 12;
			
			%obj.p(1,1).select();
			subplot(2,2,1)
			plot(obj.ramp, obj.inputValues, 'k.-');
			axis tight
			xlabel('Indexed Values');
			ylabel('Luminance cd/m^2');
			title('Input -> Output Raw Data');
			
			%obj.p(1,2).select();
			subplot(2,2,2)
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
			
			legendtext=[];
			subplot(2,2,3)
			%obj.p(2,1).select();
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
			
			subplot(2,2,4)
			%obj.p(2,2).select();
			hold all
			for i=1:length(obj.gammaTable)
				plot(obj.modelFit{i}.output.residuals);
				legendtext{i} = obj.modelFit{i}.method;
			end
			hold off
			axis tight
			xlabel('Indexed Values')
			ylabel('Residual Values');
			legend(legendtext,'Location','Best');
			title('Model Residuals');
			
			if scnsize(3) > 2000
				scnsize(3) = scnsize(3)/2;
			end
			newpos = [scnsize(3)/2-scnsize(3)/3 1 scnsize(3)/1.5 scnsize(4)];
			set(gcf,'Position',newpos);
			
			if isempty(obj.comments)
				t = obj.filename;
			else
				t = obj.comments;
			end
			%obj.p.title(t);
			%obj.p.refresh();
			
		end
		
		% ===================================================================
		%> @brief zeroCalibration
		%> This performs a zero calibration and only needs doing the first
		%> time the ColorCalII is plugged in
		%>
		% ===================================================================
		function zeroCalibration(obj)
			ColorCal2('ZeroCalibration');
			fprintf('\n-- Dark Calibration Done! --\n');
		end

	end
	
	%=======================================================================
	methods ( Access = private ) % PRIVATE METHODS
		%=======================================================================
		
		%===============Destructor======================%
		function delete(obj)
			obj.salutation('DELETE Method','Closing calibrateLuminance')
		end
		
		% ===================================================================
		%> @brief Converts properties to a structure
		%>
		%> @return out the structure
		% ===================================================================
		function out=toStructure(obj)
			fn = fieldnames(obj);
			for j=1:length(fn)
				out.(fn{j}) = obj.(fn{j});
			end
		end
		
		% ===================================================================
		%> @brief Converts properties to a structure
		%>
		%> @return out the structure
		% ===================================================================
		function x = makeUnique(obj,x)
			for i = 1:length(x)
				idx = find(x==x(i));
				if length(idx) > 1
					x(i) = x(i) - rand/1e5;
				end
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