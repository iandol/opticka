% ========================================================================
%> @brief calibrateLuminance: automatic luminance calibration
%>
%> calibrateLuminance automatic luminance calibration:
%> To enter settings:
%>
%> >> c = calibrateLuminance()
%> >> c.nMeasures = 40
%> >> c.useSpectroCal2 = true
%> >> c.run(); %collect uncalibrated data
%> >> c.analyse(); %fit models to the raw data
%> >> c.test() %test the fitted model for linearity
%> >> c.plot() % plot the final result
%> >> c.save() % save the data
%> >> c.finalCAL % this holds the corrected table you can pass to PTB Screen('LoadNormalizedGammaTable')
%>
%> calibrateLuminance will ask if you need to zero calibrate (e.g. ColorCal2, you only need
%> to do this after first plugging in the ColorCal). Then simply place the
%> meter in front of the monitor and follow instructions. After doing
%> nMeasures of luminance steps, it will fit the raw luminance values using a
%> variety of methods and then plot these out to a figure (it will ask you for
%> comments to enter for the calibration, you should enter monitor type,
%> lighting conditions etc). You can then save mycal to disk for later use by
%> your programs. 
%>
%>
%> Copyright ©2014-2022 Ian Max Andolina — released: LGPL3, see LICENCE.md
% ========================================================================
classdef calibrateLuminance < handle
	
	properties
		%> comments to note about this calibration
		comments cell = {''}
		%> number of measures
		nMeasures double = 30
		%> screen to calibrate
		screen
		%> bitDepth of framebuffer, '8bit' is best for old GPUs, but prefer
		%> 'FloatingPoint32BitIfPossible' for newer GPUS, 'Native10Bit' and can pass 
		%> options to enable Display++ modes 'EnableBits++Bits++Output'
		%> 'EnableBits++Mono++Output' or 'EnableBits++Color++Output'
		bitDepth char = 'FloatingPoint32BitIfPossible'
		%> specify port to connect to
		port char = '/dev/ttyUSB0'
		%> use SpectroCal II automatically
		useSpectroCal2 logical = true
		%> use ColorCalII automatically
		useCCal2 logical = false
		%> use i1Pro?
		useI1Pro logical = false
		%> length of gamma table, 1024 for Linux/macOS, 256 for Windows
		tableLength double = 1024
		%> choose I1Pro over CCal if both connected?
		preferI1Pro logical = false
		%> test Lum, R, G and B as seperate curves?
		testColour logical = true
		%> correct R G B seperately (true) or overall luminance (false) 
		correctColour logical = false
		%> methods list to fit to raw luminance values, first is always
		%> gamma
		analysisMethods cell = {'gamma';'pchipinterp';'cubicspline'}
		%> which model should opticka select: 1 is simple gamma,
		%> 2:n are the analysisMethods chosen; 2=pchipinterp
		choice double = 2
		%> Target (centered square that will be measured) size in pixels
		targetSize = 1000;
		%> background screen colour
		backgroundColour = [ 0.5 0.5 0.5 ];
		%> filename this was saved as
		filename
		%> EXTERNAL data as a N x 2 matrix
		externalInput
		%> wavelengths to test (SpectroCal2 is 380:1:780 | I1Pro is 380:10:730)
		wavelengths = 380:1:780
		%>use monitor sync for SpectroCal2?
		monitorSync logical = true
		%> more logging to the commandline?
		verbose logical = false
		%> allows the constructor to run the open method immediately
		runNow logical = false
	end
	
	properties (Hidden = true)
		%> keep spectrocal open 
		keepOpen logical = false
		%>
		screenVals = []
	end
	
	properties (Dependent = true)
		maxLuminances
		displayRange
		displayBaseline
	end
	
	%--------------------VISIBLE PROPERTIES-----------%
	properties (SetAccess = protected, GetAccess = public)
		info struct
		finalCLUT = []
		displayGamma = []
		gammaTable = []
		modelFit = []
		cMatrix = []
		thisx = []
		thisy = []
		thisY = []
		thisSpectrum = []
		thisWavelengths = []
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
		%> clock() dateStamp set on construction
		dateStamp double
		%> universal ID
		uuid char
        SPD struct
		%spectroCAL serial object
		spCAL
	end
	
	properties (SetAccess = private, GetAccess = private)
		saveName
		savePath
		isRunAll = false
		isTested = false
		isAnalyzed = false
		canAnalyze = false
		win
		p
		plotHandle
		allowedPropertiesBase = '^(bitDepth|useSpectroCal2|port|preferI1Pro|useCCal2|useI1Pro|correctColour|testColour|filename|tableLength|verbose|runNow|screen|nMeasures)$'
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
		function me = calibrateLuminance(args)
			if nargin>0 && isstruct(args)
				if nargin>0 && isstruct(args)
					fnames = fieldnames(args); %find our argument names
					for i=1:length(fnames)
						if regexp(fnames{i},me.allowedPropertiesBase) %only set if allowed property
							me.salutation(fnames{i},'Configuring property constructor');
							me.(fnames{i})=args.(fnames{i}); %we set up the properies from the arguments as a structure
						end
					end
				end
			end
			me.dateStamp = clock();
			me.uuid = num2str(dec2hex(floor((now - floor(now))*1e10))); %me.uuid = char(java.util.UUID.randomUUID)%128bit uuid
			if isempty(me.screen)
				me.screen = max(Screen('Screens'));
			end
			me.screenVals.fps =  Screen('NominalFrameRate',me.screen);
			if ispc
				me.tableLength = 256;
				me.port = 'COM4';
			end
			if me.useI1Pro && I1('IsConnected') == 0
				me.useI1Pro = false;
				fprintf('---> Couldn''t connect to I1Pro!!!\n');
			end
			if me.runNow == true
				me.calibrate();
				me.run();
				me.analyze();
			end
		end
		
		% ===================================================================
		%> @brief calibrate
		%>	run the calibration loop, uses the max # screen by default
		%>
		% ===================================================================
		function calibrate(me)
			me.screenVals.fps =  Screen('NominalFrameRate',me.screen);
			reply = input('Do you need to calibrate sensors (Y/N) = ','s');
			if ~strcmpi(reply,'y')
				return;
			end
			if me.useSpectroCal2 == true
				resetAll(me)
			elseif me.useI1Pro == true
				if I1('IsConnected') == 0
					me.useI1Pro = false;
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
				resetAll(me)
			elseif me.useCCal2 == true
				me.cMatrix = ColorCal2('ReadColorMatrix');
				if isempty(me.cMatrix)
					me.useCCal2 = false;
				else
					me.zeroCalibration;
				end
				resetAll(me)
			else
				input('Please run manual calibration, then press enter to continue');
				resetAll(me)
			end
		end
		
		% ===================================================================
		%> @brief get max luminance values for each channel
		%>	
		% ===================================================================
		function value = get.maxLuminances(me)
			value = [];
			if me.canAnalyze
				if isstruct(me.inputValues)
					for i = 1:length(me.inputValues)
						value(i) = max(me.inputValues(i).in);
					end
				else
					value = max(me.inputValues);
				end
			end
		end
		
		% ===================================================================
		%> @brief get max luminance values for each channel
		%>	
		% ===================================================================
		function value = get.displayBaseline(me)
			value = [];
			if me.canAnalyze
				if isstruct(me.inputValues)
					value = min(me.inputValues(1).in);
				else
					value = min(me.inputValues);
				end
			end
		end
		
		% ===================================================================
		%> @brief get max luminance values for each channel
		%>	
		% ===================================================================
		function value = get.displayRange(me)
			value = [];
			if me.canAnalyze
				if isstruct(me.inputValues)
					value = max(me.inputValues(1).in) - min(me.inputValues(1).in);
				else
					value = max(me.inputValues) - min(me.inputValues);
				end
			end
		end
		
		% ===================================================================
		%> @brief run all options
		%>	runs,  analyzes (fits) and tests the monitor
		%>
		% ===================================================================
		function runAll(me)
			me.isRunAll = true;
			resetAll(me);
			addComments(me);
			[me.saveName, me.savePath] = uiputfile('*.mat');
			calibrate(me);
			run(me);
			analyze(me);
			WaitSecs(2);
			test(me);
			me.save;
			me.isRunAll = false;
		end
		
		% ===================================================================
		%> @brief run
		%>	run the main calibration loop, uses the max # screen by default
		%>
		% ===================================================================
		function run(me)
			resetAll(me)
			openScreen(me);
			try
				me.info(1).version = Screen('Version');
				me.info(1).comp = Screen('Computer');
				if IsLinux
					try me.info(1).display = Screen('ConfigureDisplay','Scanout',me.screen,0); end
				end
			end
			Screen('FillRect',me.win,[0.7 0.7 0.7],me.screenVals.targetRect);
			Screen('Flip',me.win);
			if ~me.useCCal2 && ~me.useI1Pro && ~me.useSpectroCal2
				input(sprintf(['When black screen appears, point photometer, \n' ...
					'get reading in cd/m^2, input reading using numpad and press enter. \n' ...
					'A screen of higher luminance will be shown. Repeat %d times. ' ...
					'Press enter to start'], me.nMeasures));
			elseif me.useI1Pro == true && me.useCCal2 == true
				fprintf('\nPlace i1 and Cal over light source, then press i1 button to measure: ');
				while I1('KeyPressed') == 0
					WaitSecs(0.01);
				end
			elseif me.useSpectroCal2
				me.openSpectroCAL();
				me.spectroCalLaser(true)
				input('Align Laser then press enter to start...')
				me.spectroCalLaser(false)
			end
			
			psychlasterror('reset');
			
			try
				Screen('Flip',me.win);
				[me.oldCLUT, me.dacBits, me.lutSize] = Screen('ReadNormalizedGammaTable', me.win);
				me.tableLength = me.lutSize;
				if ~IsWin; BackupCluts; end
				me.initialCLUT = repmat([0:1/(me.tableLength-1):1]',1,3); %#ok<NBRAK>
				Screen('LoadNormalizedGammaTable', me.win, me.initialCLUT);
				
				me.ramp = [0:1/(me.nMeasures - 1):1]; %#ok<NBRAK>
				
				me.inputValues(1).in = zeros(1,length(me.ramp));
				me.inputValues(2).in = me.inputValues(1).in;
				me.inputValues(3).in = me.inputValues(1).in;
				me.inputValues(4).in = me.inputValues(1).in;
				
				if me.useI1Pro
					me.inputValuesI1(1).in = zeros(1,length(me.ramp));
					me.inputValuesI1(2).in = me.inputValuesI1(1).in;
					me.inputValuesI1(3).in = me.inputValuesI1(1).in;
					me.inputValuesI1(4).in = me.inputValuesI1(1).in;
				end
				
				me.spectrum(1).in = zeros(length(me.wavelengths),length(me.ramp));
				if me.testColour
					me.spectrum(2).in = me.spectrum(1).in; me.spectrum(3).in = me.spectrum(1).in; me.spectrum(4).in = me.spectrum(1).in;
				end
				
				if me.testColour
					loop=1:4;
				else
					loop = 1;
				end
				for col = loop
					vals = me.ramp';
					valsl = length(vals);
					cout = zeros(valsl,3);
					if col == 1
						testname = 'Gray';
						cout(:,1) = vals;
						cout(:,2) = vals;
						cout(:,3) = vals;
					elseif col == 2
						cout(:,1) = vals;testname = 'Red';
					elseif col == 3
						cout(:,2) = vals;testname = 'Green';
					elseif col == 4
						cout(:,3) = vals;testname = 'Blue';
					end
					a=1;
					[~, randomIndex] = sort(rand(valsl, 1));
					for i = 1:valsl
                        testColour = cout(randomIndex(i),:);
						Screen('FillRect',me.win,testColour,me.screenVals.targetRect);
						Screen('Flip',me.win);
						WaitSecs('YieldSecs',1);
						if ~me.useSpectroCal2 && ~me.useCCal2 && ~me.useI1Pro
							me.inputValues(col).in(randomIndex(a)) = input(['Enter luminance for value=' num2str(testColour) ': ']);
							fprintf('\t--->>> Result: %.3g cd/m2\n', me.inputValues(col).in(randomIndex(a)));
						else
							if me.useSpectroCal2 == true
								[me.thisx, me.thisy, me.thisY, lambda, radiance] = me.takeSpectroCALMeasurement();
								me.inputValues(col).in(randomIndex(a)) = me.thisY;
								me.spectrum(col).in(:,randomIndex(a)) = radiance;
							end
							if me.useCCal2 == true
								[me.thisx,me.thisy,me.thisY] = me.getCCalxyY;
								me.inputValues(col).in(randomIndex(a)) = me.thisY;
							end
							if me.useI1Pro == true
								I1('TriggerMeasurement');
								Lxy = I1('GetTriStimulus');
								me.inputValuesI1(col).in(randomIndex(a)) = Lxy(1);
								%me.inputValues(col).in(a) = me.inputValuesI1(col).in(a);
								sp = I1('GetSpectrum')';
								me.spectrum(col).in(:,randomIndex(a)) = sp;
							end
							fprintf('---> Test %s #%i: Fraction %g = %g cd/m2\n\n', testname, i, vals(randomIndex(i)), me.inputValues(col).in(randomIndex(a)));
						end
						a = a + 1;
					end
					if col == 1 % assign the RGB values to each channel by default
						me.inputValues(2).in = me.inputValues(1).in;
						me.inputValues(3).in = me.inputValues(1).in;
						me.inputValues(4).in = me.inputValues(1).in;
					end
				end
				if ~IsWin; RestoreCluts; end
				if me.useSpectroCal2;me.closeSpectroCAL();end
				Screen('LoadNormalizedGammaTable', me.win, me.oldCLUT);
				me.closeScreen();
				me.canAnalyze = true;
			catch %#ok<CTCH>
				resetAll(me);
				if ~IsWin; RestoreCluts; end
				Screen('CloseAll');
				psychrethrow(psychlasterror);
			end
		end
		
		% ===================================================================
		%> @brief test
		%>	once the models are analyzed, lets test the corrected luminance
		%>
		% ===================================================================
		function test(me)
			if me.isAnalyzed == false
				warning('Cannot test until you run analyze() first...')
				return
			end
			try
				resetTested(me)
				if me.isRunAll
					doPipeline = false;
					me.choice = 2;
				else
					reply = input('Set 0 for SimpleGamma or a Model number 2:N for the standard correction: ');
					if reply == 0
						doPipeline = true;
					else
						doPipeline = false;
						me.choice = reply;
					end
				end
				
				openScreen(me);
				
				try
					me.info(1).version = Screen('Version');
					me.info(1).comp = Screen('Computer');
					if IsLinux
						me.info(1).display = Screen('ConfigureDisplay','Scanout',me.screen,0);
					end
				end
				
				if me.useSpectroCal2
					me.openSpectroCAL();
				end
				
				makeFinalCLUT(me);
				if doPipeline == true
					PsychColorCorrection('SetEncodingGamma', me.win, 1/me.displayGamma(1));
					fprintf('LOAD SetEncodingGamma using PsychColorCorrection to: %g\n',1/me.displayGamma(1))
				else
					fprintf('LOAD GammaTable Model: %i = %s\n',me.choice,me.analysisMethods{me.choice})
					if isprop(me,'finalCLUT') && ~isempty(me.finalCLUT)
						gTmp = me.finalCLUT;
					else
						gTmp = repmat(me.gammaTable{me.choice},1,3);
					end
					Screen('LoadNormalizedGammaTable', me.win, gTmp);
				end
				
				me.ramp = [0:1/(me.nMeasures - 1):1]; %#ok<NBRAK>
				
				me.inputValuesTest(1).in = zeros(1,length(me.ramp));
				me.inputValuesTest(2).in = me.inputValuesTest(1).in; me.inputValuesTest(3).in = me.inputValuesTest(1).in; me.inputValuesTest(4).in = me.inputValuesTest(1).in;
				
				me.inputValuesI1Test(1).in = zeros(1,length(me.ramp));
				me.inputValuesI1Test(2).in = me.inputValuesI1Test(1).in; me.inputValuesI1Test(3).in = me.inputValuesI1Test(1).in; me.inputValuesI1Test(4).in = me.inputValuesI1Test(1).in;
				
				me.spectrumTest(1).in = zeros(length(me.wavelengths),length(me.ramp));
				if me.testColour
					me.spectrumTest(2).in = me.spectrumTest(1).in; me.spectrumTest(3).in = me.spectrumTest(1).in; me.spectrumTest(4).in = me.spectrumTest(1).in;
				end
				
				if me.testColour
					loop=1:4;
				else
					loop = 1;
				end
				for col = loop
					vals = me.ramp';
					valsl = length(vals);
					cout = zeros(valsl,3);
					if col == 1
                        testname = 'Gray';
						cout(:,1) = vals;
						cout(:,2) = vals;
						cout(:,3) = vals;
					elseif col == 2
						cout(:,1) = vals;testname = 'Red';
					elseif col == 3
						cout(:,2) = vals;testname = 'Green';
					elseif col == 4
						cout(:,3) = vals;testname = 'Blue';
					end
					a=1;
					[~, randomIndex] = sort(rand(valsl, 1));
					for i = 1:valsl
						Screen('FillRect',me.win,cout(randomIndex(i),:),me.screenVals.targetRect);
						Screen('Flip',me.win);
						WaitSecs('YieldSecs',1);
						if ~me.useSpectroCal2 && ~me.useCCal2 && ~me.useI1Pro
							me.inputValuesTest(col).in(randomIndex(a)) = input(['LUM: ' num2str(cout(i,:)) ' = ']);
							fprintf('\t--->>> Result: %.3g cd/m2\n', me.inputValues(col).in(randomIndex(a)));
						else
							if me.useSpectroCal2 == true
								[me.thisx, me.thisy, me.thisY, lambda, radiance] = me.takeSpectroCALMeasurement();
								me.inputValuesTest(col).in(randomIndex(a)) = me.thisY;
								me.spectrumTest(col).in(:,randomIndex(a)) = radiance;
							end
							if me.useCCal2 == true
								[me.thisx,me.thisy,me.thisY] = me.getCCalxyY;
								me.inputValuesTest(col).in(randomIndex(a)) = me.thisY;
							end
							if me.useI1Pro == true
								I1('TriggerMeasurement');
								Lxy = I1('GetTriStimulus');
								me.inputValuesI1Test(col).in(randomIndex(a)) = Lxy(1);
								%me.inputValuesTest(col).in(a) = me.inputValuesI1Test(col).in(a);
								sp = I1('GetSpectrum')';
								me.spectrumTest(col).in(:,randomIndex(a)) = sp;
							end
							fprintf('---> Tested value %i: %g = %g (was %.2g) cd/m2\n\n', i, vals(randomIndex(i)), me.inputValuesTest(col).in(randomIndex(a)), me.inputValues(col).in(randomIndex(a)));
						end
						a = a + 1;
					end
				end
				if ~IsWin; RestoreCluts; end
				if me.useSpectroCal2;me.closeSpectroCAL();end
				Screen('LoadNormalizedGammaTable', me.win, me.oldCLUT);
				me.closeScreen();
				me.isTested = true;
				plot(me);
			catch ME %#ok<CTCH>
				resetTested(me);
				if ~IsWin; RestoreCluts; end
				Screen('CloseAll');
				psychrethrow(psychlasterror);
			end
			
		end
		
		% ===================================================================
		%> @brief analyze
		%>	once the raw data is collected, this analyzes (fits) the data
		%>
		% ===================================================================
		function analyze(me)
			if ~me.canAnalyze && isempty(me.inputValues)
				disp('You must use the run() method first!')
				return;
			end
			
			me.modelFit = [];
			me.gammaTable = []; me.inputValuesNorm = []; me.rampNorm = [];
			resetTested(me);
			
			me.inputValuesNorm = struct('in',[]);
			me.rampNorm = struct('in',[]);
			
			if isstruct(me.inputValuesI1)
				ii = length(me.inputValuesI1);
			elseif me.correctColour
				ii = length(me.inputValues);
			else
				ii = 1;
			end
			
			for loop = 1:ii
				if me.preferI1Pro == true
					if isstruct(me.inputValuesI1)
						inputValues = me.inputValuesI1(loop).in;
					else
						inputValues = me.inputValuesI1;
					end
				elseif ~me.useCCal2 && ~me.correctColour
					if isstruct(me.inputValues)
						inputValues = me.inputValues(loop).in;
					else
						inputValues = me.inputValues;
					end
				elseif ~me.useCCal2 && me.correctColour
					if isstruct(me.inputValues)
						inputValues = me.inputValues(loop).in;
					else
						inputValues = me.inputValues;
					end
				else
					if isstruct(me.inputValues)
						inputValues = me.inputValues(loop).in;
					else
						inputValues = me.inputValues;
					end
				end
				
				%Normalize values
				me.inputValuesNorm(loop).in = (inputValues - me.displayBaseline)/(max(inputValues) - min(inputValues));
				me.rampNorm(loop).in = me.ramp;
				inputValuesNorm = me.inputValuesNorm(loop).in; %#ok<*NASGU>
				rampNorm = me.rampNorm(loop).in;
				
				if ~exist('fittype') %#ok<EXIST>
					error('This function needs fittype() for automatic fitting. This function is missing on your setup.\n');
				end
				
				%Gamma function fitting
				g = fittype('x^g');
				fo = fitoptions('Method','NonlinearLeastSquares',...
					'Display','iter','MaxIter',1000,...
					'Upper',4,'Lower',0.1,'StartPoint',2);
				[fittedmodel, gof, output] = fit(rampNorm',inputValuesNorm',g,fo);
				me.displayGamma(loop) = fittedmodel.g;
				me.gammaTable{1,loop} = ((([0:1/(me.tableLength-1):1]'))).^(1/fittedmodel.g);
				me.salutation('Analyse','gammaTable 1 = simple fitted gamma');
				
				me.modelFit{1,loop}.method = 'Gamma';
				me.modelFit{1,loop}.model = fittedmodel;
				me.modelFit{1,loop}.g = fittedmodel.g;
				me.modelFit{1,loop}.ci = confint(fittedmodel);
				me.modelFit{1,loop}.table = fittedmodel([0:1/(me.tableLength-1):1]');
				me.modelFit{1,loop}.gof = gof;
				me.modelFit{1,loop}.output = output;
				
				for i = 1:length(me.analysisMethods)-1
					method = me.analysisMethods{i+1};
					%fo = fitoptions('Display','iter','MaxIter',1000);
					[fittedmodel,gof,output] = fit(rampNorm',inputValuesNorm', method);
					me.modelFit{i+1,loop}.method = method;
					me.modelFit{i+1,loop}.model = fittedmodel;
					me.modelFit{i+1,loop}.table = fittedmodel([0:1/(me.tableLength-1):1]');
					me.modelFit{i+1,loop}.gof = gof;
					me.modelFit{i+1,loop}.output = output;
					%Invert interpolation
					x = inputValuesNorm;
					x = me.makeUnique(x);
					[fittedmodel,gof] = fit(x',rampNorm',method);
					g = fittedmodel([0:1/(me.tableLength-1):1]');
					%g = me.normalize(g); %make sure we are from 0 to 1
					me.gammaTable{i+1,loop} = g;
					me.salutation('Analyse',sprintf('gammaTable %i = %s model',i+1,method));
				end
				
			end
			me.choice = 2; %default is pchipinterp
			me.isAnalyzed = true;
			makeFinalCLUT(me);
			plot(me);
		end
		
		% ===================================================================
		%> @brief plot
		%>	This plots the calibration results
		%>
		% ===================================================================
		function plot(me,full)
			if ~me.isAnalyzed
				disp('You must use the run() then analyse() methods first...')
				return;
			end
			
			if ~exist('full','var') || isempty(full); full = false; end
			
			if me.useSpectroCal2;me.closeSpectroCAL();end %just in case not closed yet
			
			me.plotHandle = figure;
			figpos(1,[1200 1200]);
			me.p = panel(me.plotHandle);
			
			if me.useI1Pro || me.useSpectroCal2
				me.p.pack(2,3);
			else
				me.p.pack(2,2);
			end
			me.p.margin = [15 20 10 15];
			me.p.fontsize = 12;
			
			
			me.p(1,1).select();
			
			if  isstruct(me.inputValues) || me.useI1Pro
				if me.useI1Pro == true
					inputValues = me.inputValuesI1; %#ok<*PROP>
					inputTest = me.inputValuesI1Test;
				else
					inputValues = me.inputValues;
					inputTest = me.inputValuesTest;
				end
				if ~me.testColour
					plot(me.ramp, inputValues(1).in, 'k.-');
					leg = {'RAW'};
					if ~isempty(inputTest)
						me.p(1,1).hold('on')
						plot(me.ramp, inputTest(1).in, 'ko-');
						me.p(1,1).hold('off')
						leg = [leg,{'Corrected'}];
					end
				else
					plot(me.ramp, inputValues(1).in, 'k.-',me.ramp, inputValues(2).in, 'r.-',me.ramp, inputValues(3).in, 'g.-',me.ramp, inputValues(4).in, 'b.-');
					leg = {'L','R','G','B'};
					if ~isempty(inputTest)
						me.p(1,1).hold('on')
						plot(me.ramp, inputTest(1).in, 'ko-',me.ramp, inputTest(2).in, 'ro-',me.ramp, inputTest(3).in, 'go-',me.ramp, inputTest(4).in, 'bo-');
						me.p(1,1).hold('off')
						leg = [leg,{'C:L','C:R','C:G','C:B'}];
					end
				end
				
				legend(leg,'Location','northwest')
				axis tight; grid on; grid minor; box on
				
				xlabel('Values (0-1)');
				ylabel('Luminance cd/m^2');
				t=title('Input->Output, Raw/Corrected');
			else %legacy plot
				plot(me.ramp, me.inputValues, 'k.-');
				legend('CCal')
				if max(me.inputValuesI1) > 0
					me.p(1,1).hold('on')
					plot(me.ramp, me.inputValuesI1, 'b.-');
					me.p(1,1).hold('on')
					legend('CCal','I1Pro')
				end
				if max(me.inputValuesTest) > 0
					me.p(1,1).hold('on')
					plot(me.ramp, me.inputValuesTest, 'r.-');
					me.p(1,1).hold('on')
					legend('CCal','CCalCorrected')
				end
				if max(me.inputValuesI1Test) > 0
					me.p(1,1).hold('on')
					plot(me.ramp, me.inputValuesI1Test, 'g.-');
					me.p(1,1).hold('on')
					legend('CCal','I1Pro','CCalCorrected','I1ProCorrected')
				end
				axis tight; grid on; grid minor; box on
				xlabel('Indexed Values');
				ylabel('Luminance cd/m^2');
				t=title('Input -> Output Raw Data');
			end
			t.ButtonDownFcn = @cloneAxes;
			
			colors = {[0 0 0], [0.7 0 0],[0 0.7 0],[0 0 0.7]};
			linestyles = {':','-','-.','--',':.',':c',':y',':m'};
			if isstruct(me.inputValuesI1)
				ii = length(me.inputValuesI1);
			elseif me.correctColour
				ii = length(me.inputValues);
			else
				ii = 1;
			end
			for loop = 1:ii
				if isstruct(me.inputValues)
					rampNorm = me.rampNorm(loop).in;
					inputValuesNorm = me.inputValuesNorm(loop).in;
				else
					rampNorm = me.rampNorm;
					inputValuesNorm = me.inputValuesNorm;
				end
				me.p(1,2).select();
				me.p(1,2).hold('on');
				legendtext = cell(1);
				for i=1:size(me.modelFit,1)
					plot([0:1/(me.tableLength-1):1]', me.modelFit{i,loop}.table,linestyles{i},'Color',colors{loop});
					legendtext{i} = me.modelFit{i,loop}.method;
				end
				plot(rampNorm, inputValuesNorm,'-.o','Color',[0.5 0.5 0.5])
				legendtext{end+1} = 'RAW';
				me.p(1,2).hold('off')
				axis tight; grid on; box on; if loop == 1; grid minor; end
				ylim([0 1])
				xlabel('Normalised Luminance Input');
				ylabel('Normalised Luminance Output');
				legend(legendtext,'Location','SouthEast');
				if length(me.displayGamma) == 1
					t=sprintf('Gamma: L^{%.2f}', me.displayGamma(1));
				else
					t=sprintf('Gamma: L^{%.2f} R^{%.2f} G^{%.2f} B^{%.2f}', me.displayGamma(1),me.displayGamma(2),me.displayGamma(3),me.displayGamma(4));
				end
				t=text(0.01,0.95,t);
				t.ButtonDownFcn = @cloneAxes;
				
				legendtext={};
				me.p(2,1).select();
				me.p(2,1).hold('on');
				for i=1:size(me.gammaTable,1)
					plot(1:length(me.gammaTable{i,loop}),me.gammaTable{i,loop},linestyles{i},'Color',colors{loop});
					legendtext{i} = me.modelFit{i}.method;
				end
				me.p(2,1).hold('off');
				axis tight; grid on; box on; if loop == 1; grid minor; end
				ylim([0 1])
				xlabel('Indexed Values')
				ylabel('Normalised Luminance Output');
				legend(legendtext,'Location','NorthWest');
				t=title('Output Gamma curves');
				t.ButtonDownFcn = @cloneAxes;
				
				me.p(2,2).select();
				me.p(2,2).hold('on');
				for i=1:size(me.gammaTable,1)
					plot(me.modelFit{i,loop}.output.residuals,linestyles{i},'Color',colors{loop});
					legendtext{i} = me.modelFit{i}.method;
				end
				me.p(2,2).hold('off');
				axis tight; grid on; box on; if loop == 1; grid minor; end
				xlabel('Indexed Values')
				ylabel('Residual Values');
				legend(legendtext,'Location','Best');
				t=title('Model Residuals');
				t.ButtonDownFcn = @cloneAxes;
			end
			
			if isempty(me.comments)
				t = me.filename;
			else
				t = [me.filename me.comments];
			end
			
			if (me.useI1Pro || me.useSpectroCal2)
				spectrum = me.spectrum(1).in;
				if ~isempty(me.spectrumTest)
					spectrumTest = me.spectrumTest(1).in;
				else
					spectrumTest = [];
				end
			else
				spectrum = me.spectrum;
				spectrumTest = me.spectrumTest;
			end
			if (me.useI1Pro || me.useSpectroCal2) && ~isempty(spectrum)
				me.p(1,3).select();
				hold on
				surf(me.ramp,me.wavelengths,spectrum,'EdgeAlpha',0.1);
				title('Original Spectrum: L')
				xlabel('Indexed Values')
				ylabel('Wavelengths');
				view([60 10]);
				axis tight; grid on; box on;
			end
			if (me.useI1Pro || me.useSpectroCal2) && ~isempty(spectrumTest)
				me.p(2,3).select();
				surf(me.ramp,me.wavelengths,spectrumTest,'EdgeAlpha',0.1);
				title('Corrected Spectrum: L')
				xlabel('Indexed Values')
				ylabel('Wavelengths');
				view([60 10]);
				axis tight; grid on; box on;
            end
			
			me.p.title(t);
			me.p.refresh();
            cnames = {'Gray';'Red';'Green';'Blue'};
            if full && me.useSpectroCal2 && ~isempty(me.spectrum) && me.testColour
                figure;figpos(1,[900 900])
                for i = 1:length(me.spectrum)
                    subplot(2,2,i);
                    surf(me.ramp,me.wavelengths, me.spectrum(i).in,'EdgeAlpha',0.1);
                    title(['Original Spectrum: ' cnames{i}])
                    xlabel('Indexed Values')
                    ylabel('Wavelengths');
                    view([60 10]);
                    axis tight; grid on; box on;
                end
            end
            if full && me.useSpectroCal2 && ~isempty(me.spectrumTest) && me.testColour
                figure;figpos(1,[900 900]);
                for i = 1:length(me.spectrumTest)
                    subplot(2,2,i);
                    surf(me.ramp,me.wavelengths, me.spectrumTest(i).in,'EdgeAlpha',0.1);
                    title(['Corrected Spectrum: ' cnames{i}])
                    xlabel('Indexed Values')
                    ylabel('Wavelengths');
                    view([60 10]);
                    axis tight; grid on; box on;
                end
			end
			
			function cloneAxes(src,~)
				disp('Cloning axis!')
				if ~isa(src,'matlab.graphics.axis.Axes')
					if isa(src.Parent,'matlab.graphics.axis.Axes')
						src = src.Parent;
					end
				end
				f=figure;
				nsrc = copyobj(src,f);
				nsrc.OuterPosition = [0.05 0.05 0.9 0.9];
			end
		end
		
		% ===================================================================
		%> @brief set the model choice
		%>	
		%>
		% ===================================================================
		function set.choice(me,in)
			
			if in > length(me.analysisMethods)+1
				warning('Choice greater than model options, setting to 2')
				me.choice = 2;
			else
				me.choice = in;
			end
			
			if me.isAnalyzed %#ok<*MCSUP>
				makeFinalCLUT(me);
			end
			
		end
		
		% ===================================================================
		%> @brief getCCalxyY
		%>	Uses the ColorCalII to return the current xyY values
		%>
		% ===================================================================
		function [x,y,Y] = getCCalxyY(me)
			s = ColorCal2('MeasureXYZ');
			correctedValues = me.cMatrix(1:3,:) * [s.x s.y s.z]';
			X = correctedValues(1);
			Y = correctedValues(2);
			Z = correctedValues(3);
			x = X / (X + Y + Z);
			y = Y / (X + Y + Z);
		end
		
		% ===================================================================
		%> @brief getSpectroCALValues
		%>	Uses the SpectroCAL2 to return the current xyY values
		%>
		% ===================================================================
		function [x, y, Y, wavelengths, spectrum] = getSpectroCALValues(me)
			%[CIEXY, ~, Luminance, Lambda, Radiance, errorString] = SpectroCALMakeSPDMeasurement(me.port, ...
			%	me.wavelengths(1), me.wavelengths(end), me.wavelengths(2)-me.wavelengths(1));
			if ~isa(me.spCAL,'serial') || isempty(me.spCAL) || strcmp(me.spCAL.Status,'closed')
				doClose = true;
				me.openSpectroCAL();
			else
				doClose = false;
			end
			[x, y, Y, wavelengths, spectrum] = me.takeSpectroCALMeasurement();
			%[Radiance, WL, XYZ] = SpectroCALtakeMeas(me.spCAL);
			me.thisx = x;
			me.thisy = y;
			me.thisY = Y;
			me.thisWavelengths = wavelengths;
			me.thisSpectrum = spectrum;
			if doClose && ~me.keepOpen; me.closeSpectroCAL(); end
		end
		
		%===============reset======================%
		function spectroCalLaser(me,state)
			if ~exist('state','var') || isempty(state); state = false; end
			if ischar(state) && strcmpi(state,'on')
				state = true;
			else
				state = false;
			end
			if ~isa(me.spCAL,'serial') || isempty(me.spCAL) || strcmp(me.spCAL.Status,'closed')
				doClose = true;
				me.openSpectroCAL();
			else
				doClose = false;
			end
			fprintf(me.spCAL,['*CONTR:LASER ', num2str(state), char(13)]);
			error=fread(me.spCAL,1);
			if doClose && ~me.keepOpen; me.closeSpectroCAL(); end
		end
		
		%===============makeSPD======================%
		function Phosphors = makeSPD(me)
			Phosphors = [];
			if me.isTested && ~isempty(me.spectrumTest)
				spectrum = me.spectrumTest;
			elseif me.canAnalyze && ~isempty(me.spectrum)
				spectrum = me.spectrum;
				warning('The SPD will be generated from the uncorrected values, this shouldn''t be an issue')
			else
				warning('No data is available...');
				return
			end	
			Phosphors.wavelength = me.wavelengths';
			nm = {'Red','Green','Blue'};
			for i = 1:3
				Phosphors.(nm{i}) = spectrum(i+1).in(:,end);
			end
			figure;
			hold on
			plot(Phosphors.wavelength, Phosphors.Red, 'r')
			plot(Phosphors.wavelength, Phosphors.Green, 'g')
			plot(Phosphors.wavelength, Phosphors.Blue, 'b')
			xlabel('Wavelength');box on;grid on;
			title(['SPD for ' me.comments])
			fprintf('Phosphors SPD exported!\n');
		end
		
		%===============reset======================%
		function fullCalibration(me)
			me.close;
			me.nMeasures = 30;
			me.bitDepth = 'EnableBits++Color++Output';
			me.useSpectroCal2 = true;
			me.testColour = true;
			me.correctColour = true;
			me.runAll;
		end
		
		%===============reset======================%
		function save(me)
			c = me;
			if isempty(me.saveName)
				[me.saveName, me.savePath] = uiputfile('*.mat');
			end
			save([me.savePath filesep me.saveName],'c');
			clear c;
		end
		
		%===============reset======================%
		function close(me)
			me.closeSpectroCAL();
			me.resetTested();
			me.resetAll();
		end
		
		%===============init======================%
		function openSpectroCAL(me)
			if ~isa(me.spCAL,'serial')
				me.spCAL = serial(me.port, 'BaudRate', 921600,'DataBits', 8, 'StopBits', 1, 'FlowControl', 'none', 'Parity', 'none', 'Terminator', 'CR','Timeout', 240, 'InputBufferSize', 16000);
			end
			try fopen(me.spCAL);catch;warning('Port Already Open...');end
			me.configureSpectroCAL();
		end
		
		%===============init======================%
		function closeSpectroCAL(me)
			if isa(me.spCAL,'serial') && strcmp(me.spCAL.Status,'open')
				try; fclose(me.spCAL); end
				me.spCAL = [];
			end
		end
	end
	
	%=======================================================================
	methods ( Access = private ) % PRIVATE METHODS
	%=======================================================================
		
		%===============init======================%
		function openScreen(me)
			PsychDefaultSetup(2);
			Screen('Preference', 'SkipSyncTests', 2);
			Screen('Preference', 'VisualDebugLevel', 0);
			PsychImaging('PrepareConfiguration');
			
			if regexpi(me.bitDepth, '^EnableBits')
				PsychImaging('AddTask', 'FinalFormatting', 'DisplayColorCorrection', 'ClampOnly');
				if regexp(me.bitDepth, 'Color')
					PsychImaging('AddTask', 'General', me.bitDepth, 2);
				else
					PsychImaging('AddTask', 'General', me.bitDepth);
				end
				fprintf('\n---> Bit Depth mode set to: %s\n', me.bitDepth);
			else
				switch me.bitDepth
					case {'Native10Bit','Native11Bit','Native16Bit'}
						PsychImaging('AddTask', 'General', 'FloatingPoint32BitIfPossible');
						PsychImaging('AddTask', 'General', ['Enable' me.bitDepth 'Framebuffer']);
						fprintf('\n---> screenManager: 32-bit internal / %s Output bit-depth\n', me.bitDepth);
					case {'Native16BitFloat'}
						PsychImaging('AddTask', 'General', 'FloatingPoint32BitIfPossible');
						PsychImaging('AddTask', 'General', ['Enable' me.bitDepth 'ingPointFramebuffer']);
						fprintf('\n---> screenManager: 32-bit internal / %s Output bit-depth\n', me.bitDepth);
					case {'PseudoGray'}
						PsychImaging('AddTask', 'General', 'FloatingPoint32BitIfPossible');
						PsychImaging('AddTask', 'General', 'EnablePseudoGrayOutput');
						fprintf('\n---> screenManager: Internal processing set to: %s\n', me.bitDepth);
					otherwise
						PsychImaging('AddTask', 'General', me.bitDepth);
						fprintf('\n---> screenManager: Internal processing set to: %s\n', me.bitDepth);
				end
			end
			if me.screen == 0
				rect = [0 0 1000 1000];
			else
				rect = [];
			end
			me.win = PsychImaging('OpenWindow', me.screen, me.backgroundColour, rect);
			me.screenVals.winRect = Screen('Rect',me.win);
			me.screenVals.targetRect = CenterRect([0 0 me.targetSize me.targetSize],me.screenVals.winRect);
			
			me.screenVals.ifi = Screen('GetFlipInterval', me.win);
			me.screenVals.fps=Screen('NominalFramerate', me.win);
			
			me.screenVals.white = WhiteIndex(me.screen);
			me.screenVals.black = BlackIndex(me.screen);
			me.screenVals.gray = GrayIndex(me.screen);
			%find our fps if not defined above
			if me.screenVals.fps==0
				me.screenVals.fps=round(1/me.screenVals.ifi);
				if me.screenVals.fps==0
					me.screenVals.fps=60;
				end
			end
		end
		
		%===============init======================%
		function closeScreen(me)
			if ~isempty(me.win) && me.win > 0
				try
					kind = Screen(me.win, 'WindowKind');
					if kind == 1 
						Screen('Close',me.win);
						if me.verbose; fprintf('!!!>>>Closing Win: %i kind: %i\n',me.win,kind); end
					end
				catch ME
					%Screen('CloseAll');
					if me.verbose 
						getReport(ME);
					end
				end
			end
		end
		
		%===============init======================%
		function [refreshRate] = configureSpectroCAL(me)
			intgrTime = [];
			doSynchonised = me.monitorSync;
			doHorBarPTB = false;
			reps = 1;
			freq = me.screenVals.fps;
			% set the range to be fit the CIE 1931 2-deg CMFs
			start = me.wavelengths(1); stop = me.wavelengths(end); step = me.wavelengths(2) - me.wavelengths(1);
			if isempty(intgrTime)
				% Set automatic adaption to exposure
				fprintf(me.spCAL,['*CONF:EXPO 1', char(13)]); % setting: adaption of tint
				errorString = me.checkACK('setting exposure'); if ~isempty(errorString), fclose(me.spCAL); return; end
				if doSynchonised
					fprintf(me.spCAL,['*CONF:CYCMOD 1', char(13)]); %switching to synchronized measuring mode
					errorString = me.checkACK('setting SYNC'); if ~isempty(errorString), fclose(me.spCAL); return; end
					while reps
						reps=reps-1;
						fprintf(me.spCAL,['*CONTR:CYCTIM 200 4000', char(13)]); %measurement of cycle time
						% read the return
						data = fscanf(me.spCAL);
						disp(data);
						tint = str2double(data(13:end)); % in mS
						refreshRate = 1/tint*1000;
						disp(['Refresh rate is: ',num2str(refreshRate)]);
						if ~isnan(tint)
							fprintf(me.spCAL,['*CONF:CYCTIM ',num2str(tint*1000), char(13)]);  %setting: cycle time to measured value (in us)
							errorString = me.checkACK('setting Cycle Time'); if ~isempty(errorString), fclose(me.spCAL); return; end
						else
							% reset
							fprintf(me.spCAL,['*RST', char(13)]); % software reset
							pause(2);
							if me.spCAL.BytesAvailable>0
								data = fread(me.spCAL,me.spCAL.BytesAvailable)';
								disp(char(data));
							end
							% Set automatic adaption to exposure
							fprintf(me.spCAL,['*CONF:EXPO 1', char(13)]); % setting: adaption of tint
							errorString = me.checkACK('setting exposure'); if ~isempty(errorString), fclose(me.spCAL); return; end
						end
						if ~isempty(freq)
							if abs(refreshRate-freq)<1;reps=0;end
						end
					end
				end
				
			else
				% Set integration time to intgrTime
				fprintf(me.spCAL,['*CONF:TINT ',num2str(intgrTime), char(13)]);
				me.checkACK('set integration time');
				refreshRate = NaN;
				% Set manual adaption to exposure
				fprintf(me.spCAL,['*CONF:EXPO 2', char(13)]);
				me.checkACK('set manual exposure');
			end
			% Radiometric spectra in nm / value
			fprintf(me.spCAL,['*CONF:FUNC 6', char(13)]);
			errorString = me.checkACK('setting spectra'); if ~isempty(errorString), fclose(me.spCAL); return; end
			% Set wavelength range and resolution
			fprintf(me.spCAL,['*CONF:WRAN ',num2str(start),' ',num2str(stop),' ',num2str(step), char(13)]);
			errorString = me.checkACK('setting wavelength'); if ~isempty(errorString), fclose(me.spCAL); return; end
			disp('SpectroCAL initialised.');
		end
		
		%===============init======================%
		function [CIEx, CIEy, Y, Lambda, Radiance] = takeSpectroCALMeasurement(me)
			% request a measurement
			fprintf(me.spCAL,['*INIT', char(13)]);
			errorString = me.checkACK('request measurement'); if ~isempty(errorString), fclose(me.spCAL); return; end
			% wait while measuring
			tic;
			while 1
				if me.spCAL.BytesAvailable>0
					sReturn = fread(me.spCAL,me.spCAL.BytesAvailable)';
					if sReturn(1)~=7 % if the return is not 7
						warning(['SpectroCAL: returned error code ',num2str(sReturn(1))]);
						errorString = {['SpectroCAL: returned error code ',num2str(sReturn(1))],'Check for overexposure.'};
						fclose(me.spCAL);
						return % abort the measurement and exit the function
					else
						break; % measurement succesfully completed
					end
					
				end
				if toc>240
					warning('SpectroCAL: timeout. No response received within 240 seconds.');
					errorString = 'SpectroCAL: timeout. No response received within 240 seconds.';
					fclose(me.spCAL);
					return % abort the measurement and exit the function
				end
				pause(0.01);
			end
			% retrieve the measurement
			fprintf(me.spCAL,['*FETCH:SPRAD 7', char(13)]);
			% the returned data will be a header followed by two consecutive carriage
			% returns and then the data followed by two consecutive carriage returns
			% read head and data
			data = [];
			while 1
				if me.spCAL.BytesAvailable>0
					data =  [data;fread(me.spCAL, me.spCAL.BytesAvailable)]; %#ok<AGROW>
					if length(data)>40 % read until both header and data is retrieved
						if data(end)==13 && data(end-1)==13
							break
						end
					end
				end
			end
			cr = find(data==13);
			mes = data(cr(2)+1:cr(end-1));
			% extract wave length (WL) and radiance from measurement
			tmp = sscanf(char(mes), '%d %g',[2,inf]);
			Lambda = tmp(1,:);
			Radiance = tmp(2,:);
			
			% Get XYZ tristimulus values
			fprintf(me.spCAL,['*FETCH:XYZ', char(13)]);
			data = [];
			while 1
				if me.spCAL.BytesAvailable>0
					data =  [data;fread(me.spCAL, me.spCAL.BytesAvailable)]; %#ok<AGROW>
					if length(find(data==13))>=3 % wait for all three cr
						break
					end
				end
			end
			% extract XYZ
			tmp = sscanf(char(data'), '%s %g',[3,inf]);
			XYZ = tmp(3,:)';
			denom = sum(XYZ,1);
			xy = XYZ(1:2,:)./denom([1 1]',:);
			xyY = [xy ; XYZ(2,:)];
			CIEx = xyY(1);
			CIEy = xyY(2);
			Y = xyY(3);
		end
		
		%===============reset======================%
		function errorString = checkACK(me,string)
			if ~exist('string','var') || isempty(string); string = 'GENERAL';end
			tic;
			while 1
				if me.spCAL.BytesAvailable>0
					sReturn = fread(me.spCAL,1)';
					if sReturn(1)~=6 % if the return is not 6
						warning(['error initialising SpectroCAL: returned error code ',num2str(sReturn(1))]);
						errorString = ['SpectroCAL: ',string];
						return
					else
						errorString = '';
						return; % command acknowledged
					end
					
				end
				if toc>2
					warning('error initialising SpectroCAL: timeout. No response received within 2 seconds.');
					errorString = 'SpectroCAL: timeout. No response received within 2 seconds.';
					return
				end
				pause(0.01);
			end
		end
		
		%===============reset======================%
		function resetTested(me)
			me.isTested = false;
			me.inputValuesTest = [];
			me.inputValuesI1Test = [];
			me.spectrumTest = [];
		end
		
		%===============reset======================%
		function resetAll(me)
			me.isTested = false;
			me.isAnalyzed = false;
			me.canAnalyze = false;
			me.modelFit = [];
			me.inputValues = [];
			me.inputValuesI1 = [];
			me.inputValuesTest = [];
			me.inputValuesI1Test = [];
			me.spectrum = [];
			me.spectrumTest = [];
			me.rampNorm = [];
			me.inputValuesNorm = [];
			me.ramp = [];
		end
		
		% ===================================================================
		%> @brief makeFinalCLUT
		%> make the CLUT from the gammaTable model fits
		%>
		% ===================================================================
		function makeFinalCLUT(me)
			if me.isAnalyzed == true
				if me.choice == 0 
					fprintf('--->>> calibrateLumiance: Making Linear Table...\n')
					me.finalCLUT = repmat(linspace(0,1,me.tableLength)',1,3);
				elseif me.correctColour && size(me.gammaTable,2)>1
					fprintf('--->>> calibrateLumiance: Making Colour-corrected Table from gammaTable: %i...\n',me.choice);
					me.finalCLUT = [me.gammaTable{me.choice,2:4}];
				else
					fprintf('--->>> calibrateLumiance: Making luminance-corrected Table from gammaTable: %i...\n',me.choice);
					me.finalCLUT = repmat(me.gammaTable{me.choice,1},1,3);
				end
				me.finalCLUT(1,:) = 0;
				me.finalCLUT(end,:) = 1;
				disp('--->>> calibrateLumiance: finalCLUT generated...');
			else
				fprintf('--->>> calibrateLumiance: Making Linear Table...\n')
				me.finalCLUT = repmat(linspace(0,1,me.tableLength)',1,3);
			end
		end
		
		% ===================================================================
		%> @brief zeroCalibration
		%> This performs a zero calibration and only needs doing the first
		%> time the ColorCalII is plugged in
		%>
		% ===================================================================
		function zeroCalibration(me)
			reply = input('*ZERO CALIBRATION* -- please cover the ColorCalII then press enter...','s');
			if isempty(reply)
				ColorCal2('ZeroCalibration');
				fprintf('\n-- Dark Calibration Done! --\n');
			end
		end
		
		%===============Destructor======================%
		function delete(me)
			me.verbose=true;
			me.closeSpectroCAL();
			me.closeScreen();
			me.salutation('DELETE Method',['Deleting: ' me.uuid],true);
			me.plotHandle = [];
			me.p = [];
		end
		
		% ===================================================================
		%> @brief custom save method
		%>
		%>
		% ===================================================================
		function me = saveobj(me)
			me.salutation('SAVE Method','Saving calibrateLuminance object')
			me.plotHandle = [];
			me.p = []; %remove the panel object, useless on reload
		end
		
		% ===================================================================
		%> @brief Converts properties to a structure
		%>
		%> @return out the structure
		% ===================================================================
		function out=toStructure(me)
			fn = fieldnames(me);
			for j=1:length(fn)
				out.(fn{j}) = me.(fn{j});
			end
		end
		
		% ===================================================================
		%> @brief make unique
		%>
		%> @return x
		% ===================================================================
		function x = makeUnique(me,x)
			for i = 1:length(x)
				idx = find(x==x(i));
				if length(idx) > 1
					x(i) = x(i) - rand/1e5;
				end
			end
		end
		
		% ===================================================================
		%> @brief normalise values 0 < > 1
		%>
		%> @return out normalised data
		% ===================================================================
		function out = normalize(me,in)
			if min(in) < 0
				in(in<0) = 0;
			end
			if max(in) > 1
				in(in>1) = 1;
			end
			out = in;
		end
		
		% ===================================================================
		%> @brief add a comment
		%>
		%>
		% ===================================================================
		function addComments(me)
			ans = questdlg('Do you want to add comments to this calibration?');
			if strcmpi(ans,'Yes')
				if iscell(me.comments)
					cmts = me.comments;
				else
					cmts = {me.comments};
				end
				cmt = inputdlg('Please enter a description for this calibration run:','Luminance Calibration',10,cmts);
				if ~isempty(cmt)
					me.comments{1} = cmt{1};
				end
			end
		end
		
		%===========Salutation==========%
		function salutation(me,in,message,override)
			if ~exist('override','var') || isempty(override); override = false; end
			if me.verbose > 0 || override
				if ~exist('in','var') || isempty(in); in = 'General Message'; end
				if exist('message','var')
					fprintf(['calibrateLuminance<' me.uuid '> ' message ' | ' in '\n']);
				else
					fprintf(['calibrateLuminance<' me.uuid '> ' in '\n']);
				end
			end
		end
	end
end
