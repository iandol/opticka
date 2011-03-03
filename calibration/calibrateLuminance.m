% ========================================================================
%> @brief calibrateLuminance manaul / automatic luminance calibration
%>
%> calibrateLuminance manaul / automatic luminance calibration
%>
% ========================================================================
classdef calibrateLuminance < handle
	
	properties
		%> how much detail to show
		verbosity = 0
		%> allows the constructor to run the open method immediately
		runNow = 1
		%> number of measures (default = 9)
		nMeasures = 9
		%> screen to calibrate
		screen
		%> select a fitting method for gammaTable2 (see obj.analysisMethods)
		analysis = 1
		%> use ColorCalII automatically
		useCCal = 0
		%> comments to note about this calibration
		comments
	end
	
	properties (SetAccess = private, GetAccess = public)
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
		gammaTable1
		gammaTable2
		displayGamma
		analysisMethods = {'splineinterp';'pchipinterp'}
		firstFit
		secondFit
	end
	
	properties (SetAccess = private, GetAccess = private)
		win
		canAnalyze
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
			if obj.runNow == 1
				obj.run;
			end
		end
		
		% ===================================================================
		%> @brief run
		%>	run the main calibration loop
		%>
		% ===================================================================
		function run(obj)
			input(sprintf(['When black screen appears, point photometer, \n' ...
				'get reading in cd/m^2, input reading using numpad and press enter. \n' ...
				'A screen of higher luminance will be shown. Repeat %d times. ' ...
				'Press enter to start'], obj.nMeasures));
			
			obj.initialClut = repmat([0:255]'/255,1,3); %#ok<NBRAK>
			psychlasterror('reset');
			
			try
				obj.win = Screen('OpenWindow', obj.screen, 0);
				
				[obj.oldClut, obj.dacBits,obj.lutSize] = Screen('ReadNormalizedGammaTable', obj.screen);
				BackupCluts;
				Screen('LoadNormalizedGammaTable', obj.win, obj.initialClut );
				
				obj.inputValues = [];
				obj.ramp = [0:256/(obj.nMeasures - 1):256]; %#ok<NBRAK>
				obj.ramp(end) = 255;
				for i = obj.ramp
					Screen('FillRect',obj.win,i);
					Screen('Flip',obj.win);
					
					% MK: Deprecated as not reliable: resp = input('Value?');
					fprintf('Value? ');
					beep
					resp = GetNumber;
					fprintf('\n');
					obj.inputValues = [obj.inputValues resp];
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
				obj.rampNorm = obj.ramp/255;
				
				if ~exist('fittype'); %#ok<EXIST>
					fprintf('This function needs fittype() for automatic fitting. This function is missing on your setup.\n');
				end
				
				%Gamma function fitting
				g = fittype('x^g');
				fittedmodel = fit(obj.rampNorm',obj.inputValuesNorm',g);
				obj.displayGamma = fittedmodel.g;
				obj.gammaTable1 = ((([0:255]'/255))).^(1/fittedmodel.g); %#ok<NBRAK>
				
				obj.firstFit = fittedmodel([0:255]/255); %#ok<NBRAK>
				
				method = obj.analysisMethods{obj.analysis};
				%Spline interp fitting
				fittedmodel = fit(obj.rampNorm',obj.inputValuesNorm',method);
				obj.secondFit = fittedmodel([0:255]/255); %#ok<NBRAK>
				
				%Invert interpolation
				fittedmodel = fit(obj.inputValuesNorm',obj.rampNorm',method);
				obj.gammaTable2 = fittedmodel([0:255]/255); %#ok<NBRAK>
				
				obj.plot;
			end
		end
		
		% ===================================================================
		%> @brief run
		%>	run the main calibration loop
		%>
		% ===================================================================
		function plot(obj)
			figure;
			scnsize = get(0,'ScreenSize');
			pos=get(gcf,'Position');
			
			subplot(2,1,1);
			plot(obj.rampNorm, obj.inputValuesNorm, '.', [0:255]/255, obj.firstFit, '--', [0:255]/255, obj.secondFit, '-.'); %#ok<NBRAK>
			legend('Raw Data', 'Gamma model', obj.analysisMethods{obj.analysis});
			title(sprintf('Gamma model x^{%.2f} vs. Interpolation', obj.displayGamma));
			
			subplot(2,1,1);
			plot(1:length(obj.gammaTable1),obj.gammaTable1,'k-',1:length(obj.gammaTable2),obj.gammaTable2,'r-')
			legend('Gamma model', obj.analysisMethods{obj.analysis});
			title('Plot of the actual output Gamma curves');
			
			newpos = [pos(1) 1 pos(3) scnsize(4)];
			set(gcf,'Position',newpos);
			
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