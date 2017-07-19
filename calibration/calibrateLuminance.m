% ========================================================================
%> @brief calibrateLuminance manaul / automatic luminance calibration
%>
%> calibrateLuminance manaul / automatic luminance calibration
%> To enter settings use a structure:
%>
%> >> mycal = calibrateLuminance(struct('nMeasures',25,'useCCal2',true))
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
%> you may need to expand the selected model fit to 3 columns before passing to
%> LoadNormalizedGammaTable:
%> 
%> gTmp = repmat(mycal.gammaTable{choiceofmodel},1,3);
%> Screen('LoadNormalizedGammaTable', theScreen, gTmp);
%>
% ========================================================================
classdef calibrateLuminance < handle
	
	properties
		%> comments to note about this calibration
		comments = {''}
		%> logging to the commandline?
		verbose = false
		%> allows the constructor to run the open method immediately
		runNow = false
		%> number of measures (default = 30)
		nMeasures = 15
		%> screen to calibrate
		screen
		%> use ColorCalII automatically
		useCCal2 = false
		%> use i1Pro?
		useI1Pro = false
		%> choose I1Pro over CCal if both connected?
		preferI1Pro = false
		%> test R G and B as seperate curves?
		testColour = false
		%> correct overall luminance or the R G B seperately
		correctColour = false
		%> which gamma model should opticka select: 1 is simple gamma,
		%> 2:n are the analysisMethods chosen
		choice = 2
		%> methods list to fit to raw luminance values
		analysisMethods = {'pchipinterp';'smoothingspline'}
		%> filename this was saved as
		filename
		%> EXTERNAL data as a N x 2 matrix
		externalInput
		%> length of gamma table
		tableLength = 1024
		%> wavelengths to test with i1Pro
		wavelengths = 380:10:730
	end
	
	%--------------------VISIBLE PROPERTIES-----------%
	properties (SetAccess = protected, GetAccess = public)
		finalCLUT = []
		displayGamma = []
		gammaTable = []
		modelFit = []
		cMatrix = []
		thisx = []
		thisy = []
		thisY = []
		ramp = []
		inputValues = []
		inputValuesI1 = []
		inputValuesTest = []
		inputValuesI1Test = []
		spectrum = []
		spectrumTest = []
		rampNorm = []
		inputValuesNorm = []
		initialCLUT = []
		oldCLUT = []
		dacBits = []
		lutSize = []
		displayRange = []
		displayBaseline = []
		%> clock() dateStamp set on construction
		dateStamp@double
		%> universal ID
		uuid@char
	end
	
	properties (SetAccess = private, GetAccess = private)
		isTested = false
		isAnalyzed = false
		canAnalyze = false
		win
		p
		plotHandle
		allowedPropertiesBase='^(preferI1Pro|useCCal2|useI1Pro|correctColour|testColour|filename|tableLength|verbose|runNow|screen|nMeasures)$'
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
		%> @return instance of class.
		% ===================================================================
		function obj = calibrateLuminance(args)
			if nargin>0 && isstruct(args)
				if nargin>0 && isstruct(args)
					fnames = fieldnames(args); %find our argument names
					for i=1:length(fnames)
						if regexp(fnames{i},obj.allowedPropertiesBase) %only set if allowed property
							obj.salutation(fnames{i},'Configuring property constructor');
							obj.(fnames{i})=args.(fnames{i}); %we set up the properies from the arguments as a structure
						end
					end
				end
			end
			obj.dateStamp = clock();
			obj.uuid = num2str(dec2hex(floor((now - floor(now))*1e10))); %obj.uuid = char(java.util.UUID.randomUUID)%128bit uuid
			if isempty(obj.screen)
				obj.screen = max(Screen('Screens'));
			end
			if obj.useI1Pro && I1('IsConnected') == 0
				obj.useI1Pro = false;
				fprintf('---> Couldn''t connect to I1Pro!!!\n');
			end
			if obj.runNow == true
				obj.calibrate();
				obj.run();
				obj.analyze();
			end
		end
		
		% ===================================================================
		%> @brief calibrate
		%>	run the calibration loop, uses the max # screen by default
		%>
		% ===================================================================
		function calibrate(obj)
			reply = input('Do you need to calibrate sensors (Y/N) = ','s');
			if ~strcmpi(reply,'y')
				return;
			end
			if obj.useI1Pro == true
				if I1('IsConnected') == 0
					obj.useI1Pro = false;
					fprintf('---> Couldn''t connect to I1Pro!!!\n');
					return
				end
				fprintf('Place i1 onto its white calibration tile, then press i1 button to continue:\n');
				while I1('KeyPressed') == 0
					WaitSecs(0.01);
				end
				fprintf('Calibrating ... ');
				I1('Calibrate');
				fprintf('FINISHED\n');
				resetAll(obj)
			elseif obj.useCCal2 == true
				obj.cMatrix = ColorCal2('ReadColorMatrix');
				if isempty(obj.cMatrix)
					obj.useCCal2 = false;
				else
					obj.zeroCalibration;
				end
				resetAll(obj)
			else
				input('Please run manual calibration, then press enter to continue');
				resetAll(obj)
			end
		end
		
		% ===================================================================
		%> @brief run all options
		%>	runs,  analyzes (fits) and tests the monitor
		%>
		% ===================================================================
		function runAll(obj)
			resetAll(obj)
			calibrate(obj);
			run(obj);
			analyze(obj);
			test(obj);
		end
		
		% ===================================================================
		%> @brief run
		%>	run the main calibration loop, uses the max # screen by default
		%>
		% ===================================================================
		function run(obj)
			resetAll(obj)
			if ~obj.useCCal2 && ~obj.useI1Pro
				input(sprintf(['When black screen appears, point photometer, \n' ...
					'get reading in cd/m^2, input reading using numpad and press enter. \n' ...
					'A screen of higher luminance will be shown. Repeat %d times. ' ...
					'Press enter to start'], obj.nMeasures));
			elseif obj.useI1Pro == true && obj.useCCal2 == true
				fprintf('\nPlace i1 and Cal over light source, then press i1 button to measure: ');
				while I1('KeyPressed') == 0
					WaitSecs(0.01);
				end
			elseif obj.useI1Pro == true && obj.useCCal2 == false
				input('Please place i1Pro in front of monitor then press enter...');
			end
			
			obj.initialCLUT = repmat([0:1/(obj.tableLength-1):1]',1,3); %#ok<NBRAK>
			psychlasterror('reset');
			
			try
				Screen('Preference', 'SkipSyncTests', 2);
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
				[obj.oldCLUT, obj.dacBits, obj.lutSize] = Screen('ReadNormalizedGammaTable', obj.screen);
				BackupCluts;
				%Screen('LoadNormalizedGammaTable', obj.win, obj.initialCLUT);
				
				obj.ramp = [0:1/(obj.nMeasures - 1):1]; %#ok<NBRAK>
				obj.ramp(end) = 1;
				
				obj.inputValues(1).in = zeros(1,length(obj.ramp));
				obj.inputValues(2).in = obj.inputValues(1).in; 
				obj.inputValues(3).in = obj.inputValues(1).in; 
				obj.inputValues(4).in = obj.inputValues(1).in;
				
				if obj.useI1Pro
					obj.inputValuesI1(1).in = zeros(1,length(obj.ramp));
					obj.inputValuesI1(2).in = obj.inputValuesI1(1).in; 
					obj.inputValuesI1(3).in = obj.inputValuesI1(1).in; 
					obj.inputValuesI1(4).in = obj.inputValuesI1(1).in;
				end
				
				if obj.testColour
					obj.spectrum(1).in = zeros(36,length(obj.ramp));
					obj.spectrum(2).in = obj.spectrum(1).in; 
					obj.spectrum(3).in = obj.spectrum(1).in; 
					obj.spectrum(4).in = obj.spectrum(1).in;
				end
				
				if obj.testColour
					loop=1:4;
				else
					loop = 1;
				end
				for col = loop
					vals = obj.ramp';
					valsl = length(vals);
					cout = zeros(valsl,3);
					if col == 1
						cout(:,1) = vals;
						cout(:,2) = vals;
						cout(:,3) = vals;
					elseif col == 2
						cout(:,1) = vals;
					elseif col == 3
						cout(:,2) = vals;
					elseif col == 4
						cout(:,3) = vals;
					end
					a=1;
					for i = 1:valsl
						Screen('FillRect',obj.win,cout(i,:));
						Screen('Flip',obj.win);
						if ~obj.useCCal2 && ~obj.useI1Pro
							WaitSecs('YieldSecs',1);
							obj.inputValues(col).in(a) = input(['Enter luminance for value=' num2str(cout(i,:)) ': ']);
							fprintf('\t--->>> Result: %.3g cd/m2\n', obj.inputValues(col).in(a));
						else
							WaitSecs('YieldSecs',0.1);
							if obj.useCCal2 == true
								[obj.thisx,obj.thisy,obj.thisY] = obj.getCCalxyY;
								obj.inputValues(col).in(a) = obj.thisY;
							end
							if obj.useI1Pro == true
								I1('TriggerMeasurement');
								Lxy = I1('GetTriStimulus');
								obj.inputValuesI1(col).in(a) = Lxy(1);
								%obj.inputValues(col).in(a) = obj.inputValuesI1(col).in(a);
								sp = I1('GetSpectrum')';
								obj.spectrum(col).in(:,a) = sp;
							end
							fprintf('---> Testing value: %g: CCAL:%g / I1Pro:%g cd/m2\n', i, obj.inputValues(col).in(a), obj.inputValuesI1(col).in(a));
						end
						a = a + 1;
					end
					if col == 1 % assign the RGB values to each channel by default
						obj.inputValues(2).in = obj.inputValues(1).in;
						obj.inputValues(3).in = obj.inputValues(1).in;
						obj.inputValues(4).in = obj.inputValues(1).in;
					end		
				end
				RestoreCluts;
				Screen('CloseAll');
				obj.canAnalyze = true;
			catch %#ok<CTCH>
				resetAll(obj);
				RestoreCluts;
				Screen('CloseAll');
				psychrethrow(psychlasterror);
			end
		end
		
		% ===================================================================
		%> @brief test
		%>	once the models are analyzed, lets test the corrected luminance
		%>
		% ===================================================================
		function test(obj)
			if obj.isAnalyzed == false
				disp('Cannot test until you run analyze() first...')
				return
			end
			try
				resetTested(obj)
				reply = input('Set 0 for SimpleGamma or a Model number 1:N for the standard correction: ');
				if reply == 0
					doPipeline = true;
				else
					doPipeline = false;
					obj.choice = reply;
				end
				Screen('Preference', 'SkipSyncTests', 2);
				Screen('Preference', 'VisualDebugLevel', 0);
				PsychImaging('PrepareConfiguration');
				PsychImaging('AddTask', 'General', 'UseFastOffscreenWindows');
				PsychImaging('AddTask', 'General', 'FloatingPoint32BitIfPossible');
				PsychImaging('AddTask', 'General', 'NormalizedHighresColorRange');
				if doPipeline == true
					PsychImaging('AddTask', 'FinalFormatting', 'DisplayColorCorrection', 'SimpleGamma');
				end
				if obj.screen == 0
					rec = [0 0 800 600];
				else
					rec = [];
				end
				obj.win = PsychImaging('OpenWindow', obj.screen, 0, rec);
				[obj.oldCLUT, obj.dacBits, obj.lutSize] = Screen('ReadNormalizedGammaTable', obj.screen);
				BackupCluts;
				if doPipeline == true
					PsychColorCorrection('SetEncodingGamma', obj.win, 1/obj.displayGamma);
					fprintf('LOAD SetEncodingGamma using PsychColorCorrection to: %g\n',1/obj.displayGamma)
				else
					fprintf('LOAD GammaTable Model: %i\n',obj.choice)
					if isprop(obj,'finalCLUT') && ~isempty(obj.finalCLUT)
						gTmp = obj.finalCLUT;
					else
						gTmp = repmat(obj.gammaTable{obj.choice},1,3);
					end
					Screen('LoadNormalizedGammaTable', obj.win, gTmp);
				end
				
				obj.ramp = [0:1/(obj.nMeasures - 1):1]; %#ok<NBRAK>
				obj.ramp(end) = 1;
				
				obj.inputValuesTest(1).in = zeros(1,length(obj.ramp));
				obj.inputValuesTest(2).in = obj.inputValuesTest(1).in; obj.inputValuesTest(3).in = obj.inputValuesTest(1).in; obj.inputValuesTest(4).in = obj.inputValuesTest(1).in;

				obj.inputValuesI1Test(1).in = zeros(1,length(obj.ramp));
				obj.inputValuesI1Test(2).in = obj.inputValuesI1Test(1).in; obj.inputValuesI1Test(3).in = obj.inputValuesI1Test(1).in; obj.inputValuesI1Test(4).in = obj.inputValuesI1Test(1).in;
				
				obj.spectrumTest(1).in = zeros(36,length(obj.ramp));
				obj.spectrumTest(2).in = obj.spectrumTest(1).in; obj.spectrumTest(3).in = obj.spectrumTest(1).in; obj.spectrumTest(4).in = obj.spectrumTest(1).in;

				if obj.testColour
					loop=1:4;
				else
					loop = 1;
				end
				for col = loop
					vals = obj.ramp';
					valsl = length(vals);
					cout = zeros(valsl,3);
					if col == 1
						cout(:,1) = vals;
						cout(:,2) = vals;
						cout(:,3) = vals;
					elseif col == 2
						cout(:,1) = vals;
					elseif col == 3
						cout(:,2) = vals;
					elseif col == 4
						cout(:,3) = vals;
					end
					a=1;
					for i = 1:valsl
						Screen('FillRect',obj.win,cout(i,:));
						Screen('Flip',obj.win);
						if ~obj.useCCal2 && ~obj.useI1Pro
							WaitSecs('YieldSecs',1);
							obj.inputValuesTest(col).in(a) = input(['LUM: ' num2str(cout(i,:)) ' = ']);
							fprintf('\t--->>> Result: %.3g cd/m2\n', obj.inputValues(col).in(a));
						else
							WaitSecs('YieldSecs',0.1);
							if obj.useCCal2 == true
								[obj.thisx,obj.thisy,obj.thisY] = obj.getCCalxyY;
								obj.inputValuesTest(col).in(a) = obj.thisY;
							end
							if obj.useI1Pro == true
								I1('TriggerMeasurement');
								Lxy = I1('GetTriStimulus');
								obj.inputValuesI1Test(col).in(a) = Lxy(1);
								%obj.inputValuesTest(col).in(a) = obj.inputValuesI1Test(col).in(a);
								sp = I1('GetSpectrum')';
								obj.spectrumTest(col).in(:,a) = sp;
							end
							fprintf('---> Testing value: %g: CCAL:%g / I1Pro:%g cd/m2\n', i, obj.inputValuesI1Test(col).in(a), obj.inputValuesI1Test(col).in(a));
						end
						a = a + 1;
					end
				end
				RestoreCluts;
				Screen('CloseAll');
				obj.isTested = true;
				plot(obj);
			catch %#ok<CTCH>
				resetTested(obj);
				RestoreCluts;
				Screen('CloseAll');
				psychrethrow(psychlasterror);
			end
			
		end
		
		% ===================================================================
		%> @brief analyze
		%>	once the raw data is collected, this analyzes (fits) the data
		%>
		% ===================================================================
		function analyze(obj)
			if ~obj.canAnalyze && isempty(obj.inputValues)
				disp('You must use the run() method first!')
				return;
			end
			
			obj.modelFit = [];
			obj.gammaTable = []; obj.inputValuesNorm = []; obj.rampNorm = [];
			resetTested(obj);
			
			obj.inputValuesNorm = struct('in',[]); 
			obj.rampNorm = struct('in',[]);
			
			if isstruct(obj.inputValuesI1)
				ii = length(obj.inputValuesI1);
			elseif obj.correctColour
				ii = length(obj.inputValues);
			else
				ii = 1;
			end
			
			for loop = 1:ii
				if obj.preferI1Pro == true
					if isstruct(obj.inputValuesI1)
						inputValues = obj.inputValuesI1(loop).in;
					else
						inputValues = obj.inputValuesI1;
					end
				elseif ~obj.useCCal2 && ~obj.correctColour
					if isstruct(obj.inputValues)
						inputValues = obj.inputValues(loop).in;
					else
						inputValues = obj.inputValues;
					end
				elseif ~obj.useCCal2 && obj.correctColour
					if isstruct(obj.inputValues)
						inputValues = obj.inputValues(loop).in;
					else
						inputValues = obj.inputValues;
					end
				else
					if isstruct(obj.inputValues)
						inputValues = obj.inputValues(loop).in;
					else
						inputValues = obj.inputValues;
					end
				end
				
				if loop == 1
					obj.displayRange = (max(inputValues) - min(inputValues));
					obj.displayBaseline = min(inputValues);
				end

				%Normalize values
				obj.inputValuesNorm(loop).in = (inputValues - obj.displayBaseline)/(max(inputValues) - min(inputValues));
				obj.rampNorm(loop).in = obj.ramp;
				inputValuesNorm = obj.inputValuesNorm(loop).in; %#ok<*NASGU>
				rampNorm = obj.rampNorm(loop).in;

				if ~exist('fittype') %#ok<EXIST>
					error('This function needs fittype() for automatic fitting. This function is missing on your setup.\n');
				end

				%Gamma function fitting
				g = fittype('x^g');
				fo = fitoptions('Method','NonlinearLeastSquares',...
					'Display','iter','MaxIter',1000,...
					'Upper',3,'Lower',0,'StartPoint',1.5);
				[fittedmodel, gof, output] = fit(rampNorm',inputValuesNorm',g,fo);
				obj.displayGamma = fittedmodel.g;
				obj.gammaTable{1,loop} = ((([0:1/(obj.tableLength-1):1]'))).^(1/fittedmodel.g);

				obj.modelFit{1,loop}.method = 'Gamma';
				obj.modelFit{1,loop}.table = fittedmodel([0:1/(obj.tableLength-1):1]');
				obj.modelFit{1,loop}.gof = gof;
				obj.modelFit{1,loop}.output = output;

				for i = 1:length(obj.analysisMethods)					
					method = obj.analysisMethods{i};
					%fo = fitoptions('MaxIter',1000);
					[fittedmodel,gof,output] = fit(rampNorm',inputValuesNorm', method);
					obj.modelFit{i+1,loop}.method = method;
					obj.modelFit{i+1,loop}.table = fittedmodel([0:1/(obj.tableLength-1):1]');
					obj.modelFit{i+1,loop}.gof = gof;
					obj.modelFit{i+1,loop}.output = output;
					%Invert interpolation
					x = inputValuesNorm;
					x = obj.makeUnique(x);
					[fittedmodel,gof] = fit(x',rampNorm',method);
					g = fittedmodel([0:1/(obj.tableLength-1):1]');
					g = obj.normalize(g); %make sure we are from 0 to 1
					obj.gammaTable{i+1,loop} = g;
				end

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
			obj.isAnalyzed = true;
			makeFinalCLUT(obj);
			plot(obj);
		end
		
		% ===================================================================
		%> @brief plot
		%>	This plots the calibration results
		%>
		% ===================================================================
		function plot(obj)
			if ~obj.isAnalyzed
				disp('You must use the run() then analyse() methods first...')
				return;
			end

			obj.plotHandle = figure;
			figpos(1,[1200 1200]);
			obj.p = panel(obj.plotHandle);
			
			if obj.useI1Pro
				obj.p.pack(2,3);
			else
				obj.p.pack(2,2);
			end
			obj.p.margin = [15 20 10 15];
			obj.p.fontsize = 12;
			
			
			obj.p(1,1).select();
			
			if  isstruct(obj.inputValues) || obj.useI1Pro
				if obj.useI1Pro == true
					inputValues = obj.inputValuesI1; %#ok<*PROP>
					inputTest = obj.inputValuesI1Test;
				else
					inputValues = obj.inputValues;
					inputTest = obj.inputValuesTest;
				end
				if ~obj.testColour
					plot(obj.ramp, inputValues(1).in, 'k.-');
					leg = {'RAW'};
					if ~isempty(inputTest)
						obj.p(1,1).hold('on')
						plot(obj.ramp, inputTest(1).in, 'ko-');
						obj.p(1,1).hold('off')
						leg = [leg,{'Corrected'}];
					end
				else
					plot(obj.ramp, inputValues(1).in, 'k.-',obj.ramp, inputValues(2).in, 'r.-',obj.ramp, inputValues(3).in, 'g.-',obj.ramp, inputValues(4).in, 'b.-');
					leg = {'Luminance','Red','Green','Blue'};
					if ~isempty(inputTest)
						obj.p(1,1).hold('on')
						plot(obj.ramp, inputTest(1).in, 'ko-',obj.ramp, inputTest(2).in, 'ro-',obj.ramp, inputTest(3).in, 'go-',obj.ramp, inputTest(4).in, 'bo-');
						obj.p(1,1).hold('off')
						leg = [leg,{'CLum','CRed','CGreen','CBlue'}];
					end
				end
				
				legend(leg,'Location','northwest')
				axis tight; grid on; grid minor; box on
				
				xlabel('Indexed Values');
				ylabel('Luminance cd/m^2');
				title('Input -> Output / Tested Luminance');
			else %legacy plot
				plot(obj.ramp, obj.inputValues, 'k.-');
				legend('CCal')
				if max(obj.inputValuesI1) > 0
					obj.p(1,1).hold('on')
					plot(obj.ramp, obj.inputValuesI1, 'b.-');
					obj.p(1,1).hold('on')
					legend('CCal','I1Pro')
				end
				if max(obj.inputValuesTest) > 0
					obj.p(1,1).hold('on')
					plot(obj.ramp, obj.inputValuesTest, 'r.-');
					obj.p(1,1).hold('on')
					legend('CCal','CCalCorrected')
				end
				if max(obj.inputValuesI1Test) > 0
					obj.p(1,1).hold('on')
					plot(obj.ramp, obj.inputValuesI1Test, 'g.-');
					obj.p(1,1).hold('on')
					legend('CCal','I1Pro','CCalCorrected','I1ProCorrected')
				end
				axis tight; grid on; grid minor; box on
				xlabel('Indexed Values');
				ylabel('Luminance cd/m^2');
				title('Input -> Output Raw Data');
			end
			
			colors = {[0 0 0], [0.7 0 0],[0 0.7 0],[0 0 0.7]};
			linestyles = {':','-','-.','-.d',':.',':x',':*',':^'};
			if isstruct(obj.inputValuesI1)
				ii = length(obj.inputValuesI1);
			elseif obj.correctColour
				ii = length(obj.inputValues);
			else
				ii = 1;
			end
			for loop = 1:ii
				if isstruct(obj.inputValues)
					rampNorm = obj.rampNorm(loop).in;
					inputValuesNorm = obj.inputValuesNorm(loop).in;
				else
					rampNorm = obj.rampNorm;
					inputValuesNorm = obj.inputValuesNorm;
				end
				obj.p(1,2).select();
				obj.p(1,2).hold('on');
				legendtext = cell(1);
				for i=1:size(obj.modelFit,1)
					plot([0:1/(obj.tableLength-1):1]', obj.modelFit{i,loop}.table,linestyles{i},'Color',colors{loop});
					legendtext{i} = obj.modelFit{i,loop}.method;
				end
				plot(rampNorm, inputValuesNorm,'-.o','Color',[0.5 0.5 0.5])
				legendtext{end+1} = 'RAW';
				obj.p(1,2).hold('off')
				axis tight; grid on; box on; if loop == 1; grid minor; end
				ylim([0 1])
				xlabel('Normalised Luminance Input');
				ylabel('Normalised Luminance Output');
				legend(legendtext,'Location','NorthWest');
				title(sprintf('Gamma model x^{%.2f} vs. Interpolation', obj.displayGamma));

				legendtext={};
				obj.p(2,1).select();
				obj.p(2,1).hold('on');
				for i=1:size(obj.gammaTable,1)
					plot(1:length(obj.gammaTable{i,loop}),obj.gammaTable{i,loop},linestyles{i},'Color',colors{loop});
					legendtext{i} = obj.modelFit{i}.method;
				end
				obj.p(2,1).hold('off');
				axis tight; grid on; box on; if loop == 1; grid minor; end
				ylim([0 1])
				xlabel('Indexed Values')
				ylabel('Normalised Luminance Output');
				legend(legendtext,'Location','NorthWest');
				title('Plot of output Gamma curves');

				obj.p(2,2).select();
				obj.p(2,2).hold('on');
				for i=1:size(obj.gammaTable,1)
					plot(obj.modelFit{i,loop}.output.residuals,linestyles{i},'Color',colors{loop});
					legendtext{i} = obj.modelFit{i}.method;
				end
				obj.p(2,2).hold('off');
				axis tight; grid on; box on; if loop == 1; grid minor; end
				xlabel('Indexed Values')
				ylabel('Residual Values');
				legend(legendtext,'Location','Best');
				title('Model Residuals');
			end
			
			if isempty(obj.comments)
				t = obj.filename;
			else
				t = [obj.filename obj.comments];
			end
			
			if obj.useI1Pro && isstruct(obj.inputValuesI1)
				spectrum = obj.spectrum(loop).in;
				if ~isempty(obj.spectrumTest)
					spectrumTest = obj.spectrumTest(loop).in;
				else
					spectrumTest = [];
				end
			else
				spectrum = obj.spectrum;
				spectrumTest = obj.spectrumTest;
			end
			if obj.useI1Pro && ~isempty(spectrum)
				if isstruct(obj.inputValuesI1)
					
				else
					obj.p(1,3).select();
				end
				obj.p(1,3).select();
				hold on
				surf(obj.ramp,obj.wavelengths,spectrum);
				title('Original Spectrum')
				xlabel('Indexed Values')
				ylabel('Wavelengths');
				axis tight; grid on; box on; grid minor; 
			end
			if obj.useI1Pro && ~isempty(spectrumTest) && max(obj.spectrumTest(1).in)>0
				obj.p(2,3).select();
				surf(obj.ramp,obj.wavelengths,spectrumTest);
				title('Corrected Spectrum')
				xlabel('Indexed Values')
				ylabel('Wavelengths');
				axis tight; grid on; box on; grid minor;
			end
				
		
			obj.p.title(t);
			obj.p.refresh();
			
		end
		
		% ===================================================================
		%> @brief getCCalxyY
		%>	Uses the ColorCalII to return the current xyY values
		%>
		% ===================================================================
		function set.choice(obj,in)
			
			if in > length(obj.analysisMethods)+1
				warning('Choice greater than model options, setting to 2')
				obj.choice = 2;
			else
				obj.choice = in;
			end
			
			if obj.isAnalyzed %#ok<*MCSUP>
				makeFinalCLUT(obj);
			end
			
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

	end
	
	%=======================================================================
	methods ( Access = private ) % PRIVATE METHODS
		%=======================================================================
		
		%===============reset======================%
		function resetTested(obj)
			obj.isTested = false;
			obj.inputValuesTest = [];
			obj.inputValuesI1Test = [];
			obj.spectrumTest = [];
		end
		
		%===============reset======================%
		function resetAll(obj)
			obj.isTested = false;
			obj.isAnalyzed = false;
			obj.canAnalyze = false;
			obj.modelFit = [];
			obj.inputValues = [];
			obj.inputValuesI1 = [];
			obj.inputValuesTest = [];
			obj.inputValuesI1Test = [];
			obj.spectrum = [];
			obj.spectrumTest = [];
			obj.rampNorm = [];
			obj.inputValuesNorm = [];
			obj.ramp = [];
			obj.displayRange = [];
			obj.displayBaseline = [];
		end
		
		% ===================================================================
		%> @brief makeFinalCLUT
		%> make the CLUT from the gammaTable model fits
		%>
		% ===================================================================
		function makeFinalCLUT(obj)
			if obj.isAnalyzed == true	
				if obj.correctColour
					obj.finalCLUT = [obj.gammaTable{obj.choice,2:4}];
				else
					obj.finalCLUT = repmat(obj.gammaTable{obj.choice,1},1,3);
				end
				disp('--->>> calibrateLumiance: finalCLUT generated...')	
			end
		end
		
		% ===================================================================
		%> @brief zeroCalibration
		%> This performs a zero calibration and only needs doing the first
		%> time the ColorCalII is plugged in
		%>
		% ===================================================================
		function zeroCalibration(obj)
			reply = input('*ZERO CALIBRATION* -- please cover the ColorCalII then press enter...','s');
			if isempty(reply)
				ColorCal2('ZeroCalibration');
				fprintf('\n-- Dark Calibration Done! --\n');
			end
		end
		
		%===============Destructor======================%
		function delete(obj)
			obj.salutation('DELETE Method','Closing calibrateLuminance')
			obj.plotHandle = [];
			obj.p = [];
		end
		
		% ===================================================================
		%> @brief custom save method
		%> 
		%>
		% ===================================================================
		function obj = saveobj(obj)
			obj.salutation('SAVE Method','Saving calibrateLuminance object')
			obj.plotHandle = [];
			obj.p = []; %remove the panel object, useless on reload
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
		
		% ===================================================================
		%> @brief Converts properties to a structure
		%>
		%> @return out the structure
		% ===================================================================
		function out = normalize(obj,in)
			if min(in) < 0
				in(in<0) = 0;
			end
			if max(in) > 1
				in(in>1) = 1;
			end
		end
		
		%===========Salutation==========%
		function salutation(obj,in,message)
			if obj.verbose > 0
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