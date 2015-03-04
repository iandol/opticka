classdef spikeAnalysis < analysisCore
%spikeAnalysis Wraps the native and fieldtrip analysis around our PLX/PL2 reading.
	
	%------------------PUBLIC PROPERTIES----------%
	properties
		%> plexon file containing the spike data
		file@char
		%> data directory
		dir@char
		%> ± time window around the trigger, if empty use event off
		spikeWindow@double						= 0.8
		%> used by legacy spikes to allow negative time offsets
		startOffset@double						= 0
		%> bin size
		binSize@double								= 0.01
		%> gaussian/smooth window for density plots
		densityWindow@double						= [-0.015 0.015]
		%> density plots smooth function
		densityFunction@char						= 'gauss'
		%> default Spike channel
		selectedUnit@double						= 1
		%> saccadeFilter, if empty ignore
		filterFirstSaccades@double				= [ ]
		%> default behavioural type
		selectedBehaviour@cell					= {'correct'}
		%> region of interest for eye location [x y radius include], if empty ignore
		ROI@double									= []
		%> time of interest for fixation, if empty ignore
		TOI@double									= []
		%> inset raster plot?
		insetRasterPlot@logical					= false
		%> plot verbosity
		verbose										= true
	end
	
	%------------------VISIBLE PROPERTIES----------%
	properties (SetAccess = {?analysisCore}, GetAccess = public)
		%> spike plxReader object; can be the same or different due to spike resorting
		p@plxReader
		%> spike trial structure
		spike@cell
		%> names of spike channels
		names@cell
		%> fieldtrip reparse
		ft@struct
		%> fieldtrip parsed results
		results@struct
		%> chronux reparse, cell is condition, struct is trials
		chronux@cell
		%> chronux parsed results
		chresults@struct
		%> trials to remove in reparsing
		cutTrials@int32
		%> selectedTrials: each cell is a trial list grouping
		selectedTrials@cell
		%> variable selection map for 3 analysis groups
		map@cell
	end
		
	%------------------DEPENDENT PROPERTIES--------%
	properties (SetAccess = protected, Dependent = true)
		%> number of LFP channels
		nUnits@double = 0
		%> number of selected trial sets
		nSelection@double = 0
	end
	
	%------------------PRIVATE PROPERTIES----------%
	properties (SetAccess = private, GetAccess = private)
		%> allowed properties passed to object upon construction
		allowedProperties@char = 'file|dir|plotRange|demeanLFP|selectedLFP|spikeWindow|verbose'
	end
	
	%=======================================================================
	methods %------------------PUBLIC METHODS
	%=======================================================================

		% ===================================================================
		%> @brief Constructor
		%>
		%> @param varargin
		%> @return
		% ===================================================================
		function me = spikeAnalysis(varargin)
			if nargin == 0; varargin.name = 'spikeAnalysis'; end
			me=me@analysisCore(varargin); %superclass constructor
			if nargin>0; me.parseArgs(varargin, me.allowedProperties); end
			if isempty(me.name);me.name = 'spikeAnalysis'; end
			if isempty(me.file);
				getFiles(me,false);
			end
		end
		
		% ===================================================================
		%> @brief Constructor
		%>
		%> @param varargin
		%> @return
		% ===================================================================
		function getFiles(me, force)
			if ~exist('force','var')
				force = false;
			end
			if force == true || isempty(me.file)
				[f,p] = uigetfile({'*.plx;*.pl2';'Plexon Files'},'Load Spike PLX/PL2 File');
				if ischar(f) && ~isempty(f)
					me.file = f;
					me.dir = p;
					me.paths.oldDir = pwd;
					cd(me.dir);
					me.p = plxReader('file', me.file, 'dir', me.dir);
					me.p.name = ['^' me.fullName '^'];
					getFiles(me.p);
				else
					return
				end
			end
		end
		
		% ===================================================================
		%> @brief 
		%>
		%> @param
		%> @return
		% ===================================================================
		function parse(me, varargin)
			ft_defaults
			me.yokedSelection = false;
			if isempty(me.file)
				getFiles(me, true);
				if isempty(me.file); warning('No plexon file selected'); return; end
			end
			checkPaths(me);
			me.paths.oldDir = pwd;
			cd(me.dir);
			fprintf('\n<strong>§§</strong> Parsing Spike data denovo...\n')
			me.spike = {};
			me.p.eventWindow = me.spikeWindow;
			parse(me.p);
			for i = 1:me.nUnits
				me.spike{i}.trials = me.p.tsList.tsParse{i}.trials;%TODO: inefficient duplication, make into handles
			end
			me.ft = struct(); me.results = struct();
			me.ft = getFieldTripSpikes(me.p);
			me.names = me.ft.label;
			if ~me.openUI; showInfo(me); end
			select(me);
			if ~me.openUI; updateUI(me); end
		end
		
		% ===================================================================
		%> @brief 
		%>
		%> @param
		%> @return
		% ===================================================================
		function reparse(me, varargin)
			fprintf('\n<strong>§§</strong> Reparsing Spike data...\n')
			me.p.eventWindow = me.spikeWindow;
			me.spike = {};
			reparse(me.p);
			for i = 1:me.nUnits
				me.spike{i}.trials = me.p.tsList.tsParse{i}.trials;%TODO: inefficient duplication, make into handles
			end
			me.ft = struct(); me.results = struct();
			me.ft = getFieldTripSpikes(me.p);
			me.names = me.ft.label;
			select(me);
			if ~isempty(me.ROI)
				me.p.eA.ROI = me.ROI;
				parseROI(me.p.eA);
			end
			if ~isempty(me.TOI)
				me.p.eA.TOI = me.TOI;
				parseTOI(me.p.eA);
			end
			if ~me.openUI; updateUI(me); end
		end
		
		% ===================================================================
		%> @brief
		%>
		%> @param
		%> @return
		% ===================================================================
		function lazyParse(me)
			ft_defaults
			if isempty(me.file)
				getFiles(me, true);
				if isempty(me.file); warning('No plexon file selected'); return; end
			end
			checkPaths(me);
			me.paths.oldDir = pwd;
			cd(me.dir);
			fprintf('<strong>§</strong> Lazy parsing spike data...\n')
			me.p.eventWindow = me.spikeWindow;
			lazyParse(me.p);
			for i = 1:me.nUnits
				me.spike{i}.trials = me.p.tsList.tsParse{i}.trials; %TODO: inefficient duplication, make into handles
			end
			me.ft = struct(); me.results = struct();
			me.ft = getFieldTripSpikes(me.p);
			me.names = me.ft.label;
			if isempty(me.selectedTrials)
				select(me);
			elseif me.yokedSelection == false
				selectTrials(me)
			end
			if ~isempty(me.p.eA.ROIInfo)
				me.p.eA.ROI = me.ROI;
				parseROI(me.p.eA);
			end
			if ~isempty(me.p.eA.TOIInfo)
				me.p.eA.TOI = me.TOI;
				parseTOI(me.p.eA);
			end
		end
		
		% ===================================================================
		%> @brief reparse data to saccade onset after an initial parse
		%>
		%> @param
		%> @return
		% ===================================================================
		function toggleSaccadeRealign(me, varargin)
			if me.yokedSelection == true;
				warning('This spikeAnalysis object is currently locked, toggle its parent LFPAnalysis object'); return;
			end
			me.p.saccadeRealign = ~me.p.saccadeRealign;
			doPlots = me.doPlots;
			me.doPlots = false;
			me.reparse;	
			me.doPlots = doPlots;
			if me.p.saccadeRealign == true
				disp('Saccade Realign is now ENABLED, data was reparsed...')
			else
				disp('Saccade Realign is now DISABLED, data was reparsed...')
			end
		end
		
		% ===================================================================
		%> @brief selects trials/options based on many filters
		%>
		%> @param
		%> @return
		% ===================================================================
		function select(me, varargin)
			if ~exist('varargin','var') || ~islogical(varargin)
				force = false; 
			elseif islogical(varargin)
				force = varargin;
			end
			if isempty(me.p.eventList.trials); warndlg('Data not parsed yet...');return;end
			if force == true; me.yokedSelection = false; end
			if me.yokedSelection == true;
				if me.openUI
					warndlg('This spikeAnalysis object is currently locked, force parse or run select(true) to override lock, or use the LFPAnalysis parent select...'); return
				else
					warning('This spikeAnalysis object is currently locked, force parse or run select(true) to override lock, or use the LFPAnalysis parent select...'); return
				end
			end
			cuttrials = '[ ';
			if ~isempty(me.cutTrials) 
				cuttrials = [cuttrials num2str(me.cutTrials)];
			end
			cuttrials = [cuttrials ' ]'];
			
			map = cell(1,3);
			if isempty(me.map) || length(me.map)~=3 || ~iscell(me.map)
				map{1} = '1 2 3 4 5 6';
				map{2} = '7 8';
				map{3} = '';
			else
				map{1} = num2str(me.map{1});
				map{2} = num2str(me.map{2});
				map{3} = num2str(me.map{3});
			end
			
			unit = 'p';
			for i = 1:me.nUnits
				if i == me.selectedUnit
					unit = [unit '|¤' me.names{i}];
				else
					unit = [unit '|'  me.names{i}];
				end
			end
			
			inbeh = {'correct','breakFix','incorrect','all'};
			beh = 'r';
			if ischar(me.selectedBehaviour);
				t = me.selectedBehaviour;
				me.selectedBehaviour = cell(1);
				me.selectedBehaviour{1} = t;
			end
			for i = 1:length(inbeh)
				if strcmpi(inbeh{i}, me.selectedBehaviour{1})
					beh = [beh '|¤' inbeh{i}];
				else
					beh = [beh '|' inbeh{i}];
				end
			end
			
			indenf = {'gauss','alphawin'};
			denf = 'r';
			for i = 1:length(indenf)
				if strcmpi(indenf{i}, me.densityFunction)
					denf = [denf '|¤' indenf{i}];
				else
					denf = [denf '|' indenf{i}];
				end
			end

			pr = num2str(me.plotRange);
			rr = num2str(me.measureRange);
			bw = [num2str(me.binSize) '       ' num2str(me.densityWindow)];
			roi = num2str(me.ROI);
			saccfilt = num2str(me.filterFirstSaccades);
			toifilt = num2str(me.TOI);
			comment = me.comment;
			me.selectedBehaviour = {};
			
			mtitle   = [me.file ': REPARSE ' num2str(me.p.eventList.nVars) ' DATA VARIABLES'];
			options  = {['t|' map{1}],'Choose PLX variables to merge (A, if empty parse all variables independantly):';   ...
				['t|' map{2}],'Choose PLX variables to merge (B):';   ...
				['t|' map{3}],'Choose PLX variables to merge (C):';   ...
				['t|' cuttrials],'Enter Trials to exclude:';   ...
				[unit],'Choose Default Spike Channel to View:';...
				[beh],'Behavioural response type:';...
				['t|' pr],'Plot Range (Â±seconds):';   ...
				['t|' rr],'Measure Firing Rate Range (Â±seconds):';   ...
				['t|' bw],'Binwidth (PSTH) & Smooth Window (Density) [BINWIDTH -WINDOW +WINDOW] (seconds):';   ...
				[denf],'Smoothing function for Density Plots:';...
				['t|' roi],'Stimulus Region of Interest [X Y RADIUS INCLUDE[0|1]] (blank = ignore):';   ...
				['t|' toifilt],'Fixation Time/Region Of Interest [STARTTIME ENDTIME  X Y RADIUS] (blank = ignore):';   ...
				['t|' saccfilt],'Saccade Filter in seconds [TIME1 TIME2], e.g. [-0.8 0.8] (blank = ignore):';   ...
				['t|' comment],'Comment:';...
				};
			answer = menuN(mtitle,options);
			drawnow;
			if iscell(answer) && ~isempty(answer)
				re = regexpi(answer{1},'^[CBI]','once');
				if ~isempty(re)
					me.selectedBehaviour{1} = answer{1}(1);
					answer{1} = answer{1}(2:end);
				else
					me.selectedBehaviour{1} = inbeh{answer{6}};
				end
				me.map{1} = str2num(answer{1});
				
				re = regexpi(answer{2},'^[CBI]','once');
				if ~isempty(re)
					me.selectedBehaviour{2} = answer{2}(1);
					answer{2} = answer{2}(2:end);
				else
					me.selectedBehaviour{2} = inbeh{answer{6}};
				end
				me.map{2} = str2num(answer{2});
				
				re = regexpi(answer{3},'^[CBI]','once');
				if ~isempty(re)
					me.selectedBehaviour{3} = answer{3}(1);
					answer{3} = answer{3}(2:end);
				else
					me.selectedBehaviour{3} = inbeh{answer{6}};
				end
				me.map{3} = str2num(answer{3}); 

				me.cutTrials = int32(str2num(answer{4}));
				me.selectedUnit = answer{5};
				me.plotRange = str2num(answer{7});
				me.measureRange = str2num(answer{8});
				me.comment = answer{14};

				bw = str2num(answer{9});
				
				me.densityFunction = indenf{answer{10}};
				
				if length(bw) == 1
					me.binSize = bw(1);
				elseif length(bw)==2
					me.binSize = bw(1);
					me.densityWindow = [-abs(bw(2)) abs(bw(2))];
				elseif length(bw)==3
					me.binSize = bw(1);
					me.densityWindow = [bw(2) bw(3)];
				end
				
				roi = str2num(answer{11});
				if isnumeric(roi) && length(roi) == 4
					me.ROI = roi;
				else
					me.ROI = [];
				end
				me.TOI = str2num(answer{12});
				me.filterFirstSaccades = str2num(answer{13});
				
				if ~isempty(me.ROI)
					me.p.eA.ROI = me.ROI;
					parseROI(me.p.eA);
					plotROI(me.p.eA);
				end
				if ~isempty(me.TOI)
					me.p.eA.TOI = me.TOI;
					parseTOI(me.p.eA);
					plotTOI(me.p.eA);
				end
				selectTrials(me);
			end
		end
			
		% ===================================================================
		%> @brief doPSTH plots spike density for the selected trial groups
		%>
		%> @param
		%> @return
		% ===================================================================
		function PSTH(me)
			if me.nSelection == 0; error('The selection results in no valid trials to process!'); end
			ft_defaults;
			psth = cell(1,length(me.selectedTrials));
			for j = 1:length(me.selectedTrials)
				cfg					= [];
				cfg.trials			= me.selectedTrials{j}.idx;
				cfg.binsize			= me.binSize;
				cfg.outputunit		= 'rate';
				cfg.latency			= me.plotRange;
				cfg.spikechannel	= me.names{me.selectedUnit};
				psth{j}				= ft_spike_psth(cfg, me.ft);
			end
			me.results(1).psth = psth;
			getRates(me);
			
			if me.doPlots 
				plot(me,'waves',me.measureRange);
				plot(me,'psth'); 
			end
		end
		
		% ===================================================================
		%> @brief doDensity plots spike density for the selected trial groups
		%>
		%> @param
		%> @return
		% ===================================================================
		function density(me)
			if me.nSelection == 0; error('The selection results in no valid trials to process!'); end
			ft_defaults;
			sd = cell(1,length(me.selectedTrials));
			for j = 1:length(me.selectedTrials)
				cfg					= [];
				cfg.trials			= me.selectedTrials{j}.idx;
				cfg.winfunc			= me.densityFunction;
				cfg.timwin			= me.densityWindow;
				cfg.fsample			= 1000; % sample at 1000 hz
				cfg.outputunit		= 'rate';
				cfg.latency			= me.plotRange;
				cfg.spikechannel	= me.names{me.selectedUnit};
				sd{j}					= ft_spikedensity(cfg, me.ft);
				e						= me.var2SE(sd{j}.var,sd{j}.dof);
				sd{j}.stderr		= e;
				tCrit					= tinv( 0.975, sd{j}.dof );
				et						= tCrit.*sqrt( sd{j}.var ./ sd{j}.dof ); 
				sd{j}.stdterr		= et;
			end
			me.results(1).sd = sd;
			getRates(me);
			
			
			if me.doPlots 
				plot(me,'waves',me.measureRange);
				plot(me,'density'); 
			end
		end
		
		% ===================================================================
		%> @brief doPSTH plots spike density for the selected trial groups
		%>
		%> @param
		%> @return
		% ===================================================================
		function ISI(me)
			if me.nSelection == 0; error('The selection results in no valid trials to process!'); end
			ft_defaults;
			for j = 1:length(me.selectedTrials)
				cfg					= [];
				cfg.trials			= me.selectedTrials{j}.idx;
				cfg.bins				= [0:0.0005:0.1]; % use bins of 0.5 milliseconds;
				cfg.param			= 'coeffvar'; % compute the coefficient of variation (sd/mn of isis)
				cfg.spikechannel	= me.names{me.selectedUnit};
				isi{j}				= ft_spike_isi(cfg, me.ft);
			end
			me.results.isi = isi;
			if me.doPlots; plot(me,'isi'); end
		end
		
		% ===================================================================
		%> @brief doPSTH plots spike density for the selected trial groups
		%>
		%> @param
		%> @return
		% ===================================================================
		function getRates(me)
			if isempty(me.options) || isempty(me.options.stats); me.initialise(); end
			rate = cell(1,length(me.selectedTrials));
			baseline = rate;
			for j = 1:length(me.selectedTrials)
				cfg					= [];
				cfg.trials			= me.selectedTrials{j}.idx;
				cfg.spikechannel	= me.names{me.selectedUnit};
				cfg.latency			= [me.measureRange(1) me.measureRange(2)]; % sustained response period
				cfg.keeptrials		= 'yes';
				cfg.outputunit		= 'rate';
				rate{j}				= ft_spike_rate(cfg,me.ft);
				rate{j}.CI			= bootci(me.options.stats.nrand, {@mean, rate{j}.trial},'alpha',me.options.stats.alpha);
				rate{j}.alpha		= me.options.stats.alpha;
					
				cfg.latency			= me.baselineWindow;
				baseline{j}			= ft_spike_rate(cfg,me.ft);
				baseline{j}.CI		= bootci(me.options.stats.nrand, {@mean, baseline{j}.trial},'alpha',me.options.stats.alpha);
				baseline{j}.alpha		= me.options.stats.alpha;
			end
			me.results.rate = rate;
			me.results.baseline = baseline;
		end
		
		% ===================================================================
		%> @brief ROC plots ROC and AUC comparing group 2 and group 1 data
		%>
		%> @param
		%> @return
		% ===================================================================
		function ROC(me)
			getRates(me);
			dp = me.results.rate{2}.trial;
			dn = me.results.rate{1}.trial;
			scores = me.formatByClass(dp,dn);
			[tp,fp] = me.roc(scores);
			[A,Aci] = me.auc(scores,0.05,'boot',1000,'type','bca');
			p = me.aucBootstrap(scores,2000,'both',0.5);
			h=figure;set(h,'Color',[1 1 1],'Name',[me.file ' ' me.names{me.selectedUnit}]);
			figpos(1,[1000 1000]);
			plot(fp,tp); axis square
			grid on; box on;
			line([0 1],[0 1],'LineStyle','--');
			xlabel('False alarm rate');
			ylabel('Hit rate');
			t = sprintf('Time: %.2g - %.2g | AUC: %.2g %.2g<>%.2g | p=%.2g',...
				me.results.rate{2}.cfg.latency(1),...
				me.results.rate{2}.cfg.latency(2),...
				A,Aci(1),Aci(2),p);
			title(t);
			me.results.ROC.tp = tp;
			me.results.ROC.fp = fp;
			me.results.ROC.auc = A;
			me.results.ROC.aucCI = Aci;
			me.results.ROC.p = p;
		end
		
		% ===================================================================
		%> @brief
		%> @param
		%> @return
		% ===================================================================
		function nUnits = get.nUnits(me)
			nUnits = 0;
			if isfield(me.p.tsList,'nUnits')
				nUnits = me.p.tsList.nUnits;
			end	
		end
		
		% ===================================================================
		%> @brief
		%> @param
		%> @return
		% ===================================================================
		function nSelection = get.nSelection(me)
			nSelection = 0;
			if ~isempty(me.selectedTrials)
				nSelection = length(me.selectedTrials);
			end	
		end		
		
		% ===================================================================
		%> @brief save saves the object with a pregenerated name
		%> @param
		%> @return
		% ===================================================================
		function save(me)
			[~,f,~] = fileparts(me.file);
			name = ['SPIKE' f];
			if ~isempty(me.ft)
				name = [name '-ft'];
			end
			name = [name '.mat'];
			[f,p] = uiputfile(name,'SAVE Spike Analysis File');
			if ischar(f) && ~isempty(f)
				od = pwd;
				cd(p);
				spike = me;
				optimiseSize(spike.p);
				save(f,'spike');
				cd(od);
				clear spike;
			end
		end
		
		% ===================================================================
		%> @brief Set the plxReader files from a structure, used when this is yoked to an
		%> LFPAnalysis
		%>
		%> @param varargin
		%> @return
		% ===================================================================
		function setFiles(me, in)
			if isstruct(in)
				f=fieldnames(in);
				for i=1:length(f)
					if isprop(me,f{i})
						try me.(f{i}) = in.(f{i}); end
					end
				end
				if isempty(me.p)
					me.paths.oldDir = pwd;
					cd(me.dir);
					me.p = plxReader('file', me.file, 'dir', me.dir);
					me.p.name = ['PARENT:' me.uuid ' ' ];
				end
				for i=1:length(f)
					if isprop(me.p,f{i})
						try 
							me.p.(f{i}) = in.(f{i}); 
						catch
							fprintf('---> spikeAnalysis setFiles: skipping %s\n',f{i});
						end
					end
				end
			end
		end
		
		
		% ===================================================================
		%> @brief findRepeats looks for repetition priming effects
		%>
		%> @param
		%> @return
		% ===================================================================
		function chSpectrum(me)
			
			
		end
		
		
		
		% ===================================================================
		%> @brief findRepeats looks for repetition priming effects
		%>
		%> @param
		%> @return
		% ===================================================================
		function findRepeats(me)
			
			
		end
		
		% ===================================================================
		%> @brief 
		%>
		%> @param
		%> @return
		% ===================================================================
		function saccadeTimeVsResponse(me)
			if isempty(me.gd)
				me.gd = getDensity();
			end
			usez = false;
			me.gd.alpha = me.options.stats.alpha;
			if usez
				me.gd.normaliseScatter = false;
			else
				me.gd.normaliseScatter = true;
			end
			getRates(me);
			for j = 1:me.nSelection
				st=[me.p.eventList.trials(me.selectedTrials{j}.idx).firstSaccade]';
				nanidx = isnan(st);
				st(nanidx)=[];
				if usez; st = zscore(st); end
				rate = me.results.rate{j}.trial;
				rate(nanidx) = [];
				%rate = rate/max(rate);
				if usez; rate = zscore(rate); end
				t = ['SaccadeVsResponse ' num2str(me.selectedTrials{j}.sel)];
				t = regexprep(t,'\s+','_');
				me.gd.columnlabels = {t};
				me.gd.legendtxt = {'Saccades','Spikes'};
				me.gd.x = st;
				me.gd.y = rate;
				run(me.gd);
			end
		end
		
		% ===================================================================
		%> @brief 
		%>
		%> @param
		%> @return
		% ===================================================================
		function compareBaseline(me)

		end
		
		% ===================================================================
		%> @brief 
		%>
		%> @param
		%> @return
		% ===================================================================
		function plot(me, varargin)
			if isempty(me.results);
				return
			end
			if isempty(varargin) || ~ischar(varargin{1})
				sel = 'normal';
			else
				sel = varargin{1};
			end
			
			if length(varargin) > 1
				args = varargin(2:end);
			else
				args = {};
			end
			
			switch lower(sel)
				case {'p','psth'}
					plotPSTH(me); drawnow;
				case {'d','density'}
					plotDensity(me); drawnow;
				case {'ds','densitysummary'}
					plotDensitySummary(me); drawnow;
				case {'i','isi'}
					plotISI(me); drawnow;
				case {'w','waves','waveforms'}
					plotWaveforms(me,args); drawnow;
			end
		end
		
		% ===================================================================
		%> @brief Get spike structure in chronux format to use with its functions, the
		%>  results are stored in the chronux property, which is a cell array containing
		%>  structures for each data selection.
		%> @param
		%> @return
		% ===================================================================
		function getChronuxSpikes(me)
			tft = tic;
			me.chronux = {};
			for i = 1:me.nSelection
				idx = me.selectedTrials{i}.idx;
				data = []; a = 1;
				for j = idx
					base = me.spike{me.selectedUnit}.trials{j}.base;
					if me.p.saccadeRealign && isfield(me.spike{me.selectedUnit}.trials{j},'firstSaccade')
						fS = me.spike{me.selectedUnit}.trials{j}.firstSaccade;
						data(a).times = me.spike{me.selectedUnit}.trials{j}.spikes' - (base+fS);
					else
						data(a).times = me.spike{me.selectedUnit}.trials{j}.spikes' - base;
					end
					data(a).times = data(a).times + (me.spikeWindow+0.1); %annoyingly chronux doesn't handle negative spike times!!!!
					data(a).base = base;
					data(a).variable = me.spike{me.selectedUnit}.trials{j}.variable;
					data(a).index = me.spike{me.selectedUnit}.trials{j}.index;
					a = a + 1;
				end
				me.chronux{i} = data;
			end
			fprintf('<strong>§</strong> Converting spikes to chronux format took <strong>%g ms</strong>\n',round(toc(tft)*1000));
		end
		
	end

	%=======================================================================
	methods ( Access = protected ) %-------PRIVATE METHODS-----%
	%=======================================================================
	
		% ===================================================================
		%> @brief selectTrials selects trials based on many filters
		%>
		%> @param
		%> @return
		% ===================================================================
		function selectTrials(me)	
			%if we are yoked to another object, don't run this method
			if me.yokedSelection == true; disp('Object is yoked, cannot run selectTrials...');return; end

			if length(me.selectedBehaviour) ~= length(me.map)
				for i = 1:length(me.map);me.selectedBehaviour{i} = 'correct';end
				warning('Had to reset selectedBehaviours, probably due to an old LFPAnalysis object');
			end
			
			for i = 1:length(me.selectedBehaviour) %generate our selected behaviour indexes
				switch lower(me.selectedBehaviour{i})
					case {'c', 'correct'}
						behaviouridx{i} = find([me.p.eventList.trials.isCorrect]==true); %#ok<*AGROW>
						selectedBehaviour{i} = 'correct';
					case {'b', 'breakfix'}
						behaviouridx{i} = find([me.p.eventList.trials.isBreak]==true);
						selectedBehaviour{i} = 'breakfix';
					case {'i', 'incorrect'}
						behaviouridx{i} = find([me.p.eventList.trials.isIncorrect]==true);
						selectedBehaviour{i} = 'incorrect';						
					otherwise
						behaviouridx{i} = [me.p.eventList.trials.index];
						selectedBehaviour{i} = 'all';
				end
			end
			
			cutidx = me.cutTrials; %cut trials index
			
			saccidx = [];
			if ~isempty(me.filterFirstSaccades)
				idx = find([me.p.eventList.trials.firstSaccade] >= me.filterFirstSaccades(1));
				idx2 = find([me.p.eventList.trials.firstSaccade] <= me.filterFirstSaccades(2));
				saccidx = intersect(idx,idx2);
			end
			
			roiidx = [];
			if ~isempty(me.ROI)
				idx = [me.p.eA.ROIInfo.enteredROI] == logical(me.ROI(4));
				rois = me.p.eA.ROIInfo(idx);
				roiidx = [rois.correctedIndex];
			end	

			toiidx = [];
			if ~isempty(me.TOI)
				idx = [me.p.eA.TOIInfo.isTOI] == true;
				tois = me.p.eA.TOIInfo(idx);
				toiidx = [tois.correctedIndex];
			end
			
			if isempty(me.map{1}) %if our map is empty, generate groups for each variable
				bidx = behaviouridx{1};
				sb = selectedBehaviour{1};
				for i = 1:me.p.eventList.nVars; 
					map{i} = me.p.eventList.unique(i); 
					behaviouridx{i} = bidx;
					selectedBehaviour{i} = sb;
				end
			else
				map = me.map; %#ok<*PROP>
			end
	
			me.selectedTrials = {};
			varList = [me.p.eventList.trials.variable];
			a = 1;
			
			for i = 1:length(map)
				if isempty(map{i}); continue; end
				idx = find(ismember(varList,map{i})==true); %selects our trials based on variable
				if length(behaviouridx) >= i
					bidx = behaviouridx{i};
				else
					bidx = behaviouridx{1};
				end
				idx = intersect(idx, bidx); %this has a positive side effect of also sorting the trials
				if ~isempty(cutidx);		idx = setdiff(idx, cutidx);		end %remove the cut trials
				if ~isempty(saccidx);	idx = intersect(idx, saccidx);	end %remove saccade filtered trials
				if ~isempty(roiidx);		idx = intersect(idx, roiidx);		end %remove roi filtered trials
				if ~isempty(toiidx);		idx = intersect(idx, toiidx);		end %remove roi filtered trials
				if ~isempty(idx)
					me.selectedTrials{a}.idx			= idx;
					me.selectedTrials{a}.cutidx		= cutidx;
					me.selectedTrials{a}.roiidx		= roiidx; 
					me.selectedTrials{a}.toiidx		= toiidx;
					me.selectedTrials{a}.saccidx		= saccidx;
					me.selectedTrials{a}.bidx			= bidx;
					me.selectedTrials{a}.behaviour	= selectedBehaviour{i};
					me.selectedTrials{a}.sel			= map{i};
					me.selectedTrials{a}.name			= ['[' num2str(me.selectedTrials{a}.sel) ']' ' #' num2str(length(idx)) '|' me.selectedTrials{a}.behaviour];
					if isfield(me.options.stats,'sort') && ~isempty(me.options.stats.sort)
						switch me.options.stats.sort
							case 'saccades'
								st = [me.p.eventList.trials(idx).firstSaccade];
								mn = nanmean(st);
								st(isnan(st)) = mn;
								[~,stidx] = sort(st);
								me.selectedTrials{a}.idx = idx(stidx);
								me.selectedTrials{a}.sort = 'saccades';
							case 'variable'

						end					
					end
					a = a + 1;
				end
			end
			
			if me.nSelection == 0; warning('The selection results in no valid trials to process!'); return; end
			for j = 1:me.nSelection
				t{j}=sprintf(' SELECT TRIALS GROUP %g\n=======================\nInfo: %s\nTrial Index: %s\n-Cut Index: %s\nBehaviour: %s\n',...
					j,me.selectedTrials{j}.name,num2str(me.selectedTrials{j}.idx),num2str(me.selectedTrials{j}.cutidx),...
					me.selectedTrials{j}.behaviour);
				disp(t{j});
			end
			if size(t,2) > size(t,1); t = t'; end
			if me.openUI
				s=get(me.handles.list,'String');
				s{end+1} = ['Reselected @ ' datestr(now)];
				if size(s,2) > size(s,1); s = s'; end
				if length(s) > 500; s = s(end-500:end); end
				s = [s; t];
				set(me.handles.list,'String',s,'Value',length(s));
			end
		end
		
		% ===================================================================
		%> @brief
		%> @param
		%> @return
		% ===================================================================
		function plotDensity(me)
			if ~isfield(me.results,'sd'); warning('No Density parsed yet.'); return; end
			disp('Plotting Density Data...')
			fs = get(0,'DefaultAxesFontSize');
			sd = me.results.sd;
			rate = me.results.rate;
			baseline = me.results.baseline;
			if me.nSelection == 0; error('The selection results in no valid trials to process!'); end
			h=figure;set(h,'Color',[1 1 1],'Name',[me.file ' ' me.names{me.selectedUnit}]);
			if length(sd) <4; figpos(1,[1000 1500]); else figpos(1,[2000 2000]); end
			p=panel(h);
			p.fontsize = fs;
			p.margin = [12 12 12 6]; %left bottom right top
			p.pack('v', {3/4 []})
			q = p(1);
			len = me.nSelection;
			[row,col]=me.optimalLayout(len);
			q.pack(row,col);
			for j = 1:length(me.selectedTrials)
				[i1,i2] = ind2sub([row,col], j);
				q(i1,i2).select();
				cfg					= [];
				cfg.trials			= me.selectedTrials{j}.idx;
				cfg.spikechannel	= me.names{me.selectedUnit};
				if length(cfg.trials) < 50; cfg.spikelength = 0.7; else cfg.spikelength = 1; end
				cfg.latency			= me.plotRange;
				cfg.trialborders	= 'no';
				cfg.linewidth		= 1;
				cfg.plotselection	= 'yes';
				cfg.topplotfunc	= 'line'; % plot as a line
				cfg.errorbars		= 'conf95%'; % plot with the standard deviation
				cfg.interactive	= 'no'; % toggle off interactive mode
				if me.insetRasterPlot
					cfgUsed{j}		= ft_spike_plot_raster(cfg, me.ft, sd{j});
				else
					cfgUsed{j}		= ft_spike_plot_raster(cfg, me.ft);
				end
				q(i1,i2).title([me.names{me.selectedUnit} ' VAR: ' num2str(j)])
				if isfield(cfgUsed{j}.hdl,'axTopPlot'); set(cfgUsed{j}.hdl.axTopPlot,'Color','none'); end
				me.appendTrialNames(cfgUsed{j}.hdl.axRaster,cfgUsed{j}.trials);
			end
			
			p(2).select();
			p(2).marginbottom = 2; %left bottom right top
			box on;grid on
			p(2).hold('on');
			c = me.optimalColours(length(sd));
			
			xp = [rate{1}.cfg.latency(1) rate{1}.cfg.latency(2) rate{1}.cfg.latency(2) rate{1}.cfg.latency(1)];
			yp = [nanmean(sd{1}.avg) nanmean(sd{1}.avg) nanmean(sd{1}.avg) nanmean(sd{1}.avg)];
			mh = patch(xp,yp,[0.9 0.9 0.9],'FaceAlpha',0.6,'EdgeColor','none');
			set(get(get(mh,'Annotation'),'LegendInformation'),'IconDisplayStyle','off'); % Exclude line from legend
			
			blineText = sprintf('BASELINE (p=%.4g):',baseline{1}.alpha);
			for j = 1:length(baseline)
				xp = [me.plotRange(1) me.plotRange(2) me.plotRange(2) me.plotRange(1)];
				yp = [baseline{j}.CI(1) baseline{j}.CI(1) baseline{j}.CI(2) baseline{j}.CI(2)];
				me1 = patch(xp,yp,c(j,:),'FaceAlpha',0.1,'EdgeColor','none');
				set(get(get(me1,'Annotation'),'LegendInformation'),'IconDisplayStyle','off'); % Exclude line from legend
				blineText = sprintf('%s  Group:%i %.4g ± %.3g<>%.3g',blineText,j,baseline{j}.avg,baseline{j}.CI(1),baseline{j}.CI(2));
			end
			disp(blineText);
			
			t = [me.file];
			for j = 1:length(sd)
				if isfield(me.options.stats,'ploterror') && strcmpi(me.options.stats.ploterror,'SEM')
					e = sd{j}.stderr;
					yt='Firing Rate (s/s) \pm 1 S.E.M.';
				else
					e = sd{j}.stdterr;
					yt='Firing Rate (s/s) \pm 95% CI';
				end
				areabar(sd{j}.time, sd{j}.avg, e, c(j,:)/2, 0.2, 'k.-','Color',c(j,:),'MarkerFaceColor',c(j,:),'LineWidth',1);
				leg{j,1} = me.selectedTrials{j}.name;
				e = me.var2SE(rate{j}.var,rate{j}.dof);
				t = [t sprintf(' R%i: %.4g ± %.3g %.3g<>%.3g', j, rate{j}.avg, e, rate{j}.CI(1), rate{j}.CI(2))];
			end
			disp([t sprintf(' | measureRange: %s', num2str(rate{1}.cfg.latency))]);
			title(t);
			xlabel(['Time (s) [window = ' sd{1}.cfg.winfunc ' ' num2str(sd{1}.cfg.timwin) '] ']);
			ylabel(yt)
			set(gcf,'Renderer','OpenGL');
			legend(leg);
			ax=axis;
			axis([me.plotRange(1) me.plotRange(2) ax(3) ax(4)]);
			text(me.plotRange(1),ax(3),blineText,'FontSize',fs+1,'VerticalAlignment','baseline');
			set(mh,'yData',[ax(3) ax(3) ax(4) ax(4)]);
			set(gca,'Layer','top');
		end
		
		% ===================================================================
		%> @brief
		%> @param
		%> @return
		% ===================================================================
		function plotDensitySummary(me)
			if ~isfield(me.results,'sd'); warning('No Density parsed yet.'); return; end
			disp('Plotting Density Data...')
			sd = me.results.sd;
			rate = me.results.rate;
			baseline = me.results.baseline;
			if me.nSelection == 0; error('The selection results in no valid trials to process!'); end
			h=figure;figpos(1,[1000 1000]);set(h,'Color',[1 1 1],'Name',[me.file ' ' me.names{me.selectedUnit}]);
			box on
			grid on
			hold on
			
			xp = [rate{1}.cfg.latency(1) rate{1}.cfg.latency(2) rate{1}.cfg.latency(2) rate{1}.cfg.latency(1)];
			yp = [nanmean(sd{1}.avg) nanmean(sd{1}.avg) nanmean(sd{1}.avg) nanmean(sd{1}.avg)];
			mh = patch(xp,yp,[0.9 0.9 0.9],'FaceAlpha',0.6,'EdgeColor','none');
			set(get(get(mh,'Annotation'),'LegendInformation'),'IconDisplayStyle','off'); % Exclude line from legend
			
			c = me.optimalColours(length(sd));
			
			blineText = sprintf('BASELINE (p=%.4g):',baseline{1}.alpha);
			for j = 1:length(baseline)
				xp = [me.plotRange(1) me.plotRange(2) me.plotRange(2) me.plotRange(1)];
				yp = [baseline{j}.CI(1) baseline{j}.CI(1) baseline{j}.CI(2) baseline{j}.CI(2)];
				me1 = patch(xp,yp,c(j,:),'FaceAlpha',0.1,'EdgeColor','none');
				set(get(get(me1,'Annotation'),'LegendInformation'),'IconDisplayStyle','off'); % Exclude line from legend
				blineText = sprintf('%s  Group:%i %.4g ± %.3g<>%.3g',blineText,j,baseline{j}.avg,baseline{j}.CI(1),baseline{j}.CI(2));
			end
			disp(blineText);
			
			t = [me.file];
			for j = 1:length(sd)
				e = me.var2SE(sd{j}.var,sd{j}.dof);
				areabar(sd{j}.time, sd{j}.avg, e, c(j,:)/2, 0.2, 'k.-','Color',c(j,:),'MarkerFaceColor',c(j,:),'LineWidth',1);
				leg{j,1} = me.selectedTrials{j}.name;
				e = me.var2SE(rate{j}.var,rate{j}.dof);
				t = [t sprintf(' R%i: %.4g ± %.3g %.3g<>%.3g', j, rate{j}.avg, e, rate{j}.CI(1), rate{j}.CI(2))];
			end
			disp([t sprintf(' | measureRange: %s', num2str(rate{1}.cfg.latency))]);
			title(t,'FontSize',14);
			xlabel(['Time (s) [window = ' sd{1}.cfg.winfunc ' ' num2str(sd{1}.cfg.timwin) '] ']);
			ylabel(['Firing Rate (s/s) \pm S.E.M.'])
			set(gcf,'Renderer','OpenGL');
			legend(leg);
			ax=axis;
			axis([me.plotRange(1) me.plotRange(2) ax(3) ax(4)]);
			text(me.plotRange(1),ax(3),blineText,'FontSize',11,'VerticalAlignment','baseline');
			set(mh,'yData',[ax(3) ax(3) ax(4) ax(4)]);
			set(gca,'Layer','top');
		end
		
		% ===================================================================
		%> @brief
		%> @param
		%> @return
		% ===================================================================
		function plotPSTH(me)
			if ~isfield(me.results,'psth'); warning('No PSTH parsed yet.'); return; end
			psth = me.results.psth;
			rate = me.results.rate;
			baseline = me.results.baseline;
			if me.nSelection == 0; error('The selection results in no valid trials to process!'); end

			h=figure;set(h,'Color',[1 1 1],'Name',[me.file ' ' me.names{me.selectedUnit}]);
			if length(psth) <4; figpos(1,[1000 1500]); else figpos(1,[2000 2000]); end
			p=panel(h);
			p.margin = [20 20 20 10]; %left bottom right top
			p.pack('v', {3/4 []})
			q = p(1);
			len = me.nSelection;
			[row,col]=me.optimalLayout(len);
			q.pack(row,col);
			for j = 1:length(me.selectedTrials)
				%ft = me.subselectFieldTripTrials(me.ft,me.selectedTrials{j}.idx);
				[i1,i2] = ind2sub([row,col], j);
				q(i1,i2).select();
				cfg						= [];
				cfg.trials				= me.selectedTrials{j}.idx;
				cfg.spikechannel		= me.names{me.selectedUnit};
				if length(cfg.trials) < 50; cfg.spikelength = 0.7; else cfg.spikelength = 1; end
				cfg.latency				= me.plotRange;
				cfg.linewidth			= 1;
				cfg.trialborders		= 'no';
				cfg.plotselection		= 'yes';
				%cfg.topplotfunc		= 'line'; % plot as a line
				cfg.errorbars			= 'conf95%'; % plot with the standard deviation
				cfg.interactive		= 'no'; % toggle off interactive mode
				if me.insetRasterPlot
					cfgUsed{j}			= ft_spike_plot_raster(cfg, me.ft, psth{j});
				else
					cfgUsed{j}			= ft_spike_plot_raster(cfg, me.ft);
				end
				if isfield(cfgUsed{j}.hdl,'axTopPlot'); set(cfgUsed{j}.hdl.axTopPlot,'Color','none'); end
				me.appendTrialNames(cfgUsed{j}.hdl.axRaster,cfgUsed{j}.trials);
			end
			p(2).select();
			box on; grid on
			p(2).hold('on');
			c = me.optimalColours(length(psth));
			
			xp = [rate{1}.cfg.latency(1) rate{1}.cfg.latency(2) rate{1}.cfg.latency(2) rate{1}.cfg.latency(1)];
			yp = [nanmean(psth{1}.avg) nanmean(psth{1}.avg) nanmean(psth{1}.avg) nanmean(psth{1}.avg)];
			mh = patch(xp,yp,[0.9 0.9 0.9],'FaceAlpha',0.6,'EdgeColor','none');
			set(get(get(mh,'Annotation'),'LegendInformation'),'IconDisplayStyle','off'); % Exclude line from legend
			
			for j = 1:length(baseline)
				xp = [me.plotRange(1) me.plotRange(2) me.plotRange(2) me.plotRange(1)];
				yp = [baseline{j}.CI(1) baseline{j}.CI(1) baseline{j}.CI(2) baseline{j}.CI(2)];
				me1 = patch(xp,yp,c(j,:),'FaceAlpha',0.1,'EdgeColor','none');
				set(get(get(me1,'Annotation'),'LegendInformation'),'IconDisplayStyle','off'); % Exclude line from legend
			end
			
			t = [me.file];
			for j = 1:length(psth)
				e = me.var2SE(psth{j}.var,psth{j}.dof);
				areabar(psth{j}.time, psth{j}.avg, e, c(j,:)/2, 0.2, 'k.-','Color',c(j,:),'MarkerFaceColor',c(j,:),'LineWidth',1);
				leg{j,1} = me.selectedTrials{j}.name;
				e = me.var2SE(rate{j}.var,rate{j}.dof);
				t = [t sprintf(' R%i: %.4g ± %.3g', j, rate{j}.avg, e)];
			end
			disp([t sprintf(' | measureRange: %s', num2str(rate{1}.cfg.latency))]);
			title(t,'FontSize',13);
			p(2).margintop = 25;
			xlabel(['Time (s) [binsize = ' num2str(psth{1}.cfg.binsize) ' ]']);
			ylabel(['Firing Rate (s/s) \pm S.E.M.'])
			set(gcf,'Renderer','OpenGL');
			legend(leg);
			ax=axis;
			axis([me.plotRange(1) me.plotRange(2) ax(3) ax(4)]);
			set(mh,'yData',[ax(3) ax(3) ax(4) ax(4)]);
			set(gca,'Layer','top');
		end
		
		% ===================================================================
		%> @brief
		%> @param
		%> @return
		% ===================================================================
		function plotISI(me)
			if ~isfield(me.results,'isi'); warning('No ISI parsed yet.'); return; end
			if me.nSelection == 0; error('The selection results in no valid trials to process!'); end
			isi = me.results.isi;
			len = me.nSelection;
			h=figure;figpos(1,[1000 2000]);set(h,'Color',[1 1 1],'Name',[me.file ' ' me.names{me.selectedUnit}]);
			p=panel(h);
			p.margin = [20 20 20 20]; %left bottom right top
			[row,col]=me.optimalLayout(len);
			p.pack(row,col);
			for j = 1:length(me.selectedTrials)
				[i1,i2] = ind2sub([row,col], j);
				p(i1,i2).select();
				cfg					= [];
				cfg.spikechannel	= isi{j}.label{1};
				cfg.interpolate	= 5; % interpolate at 5 times the original density
				cfg.window			= 'gausswin'; % use a gaussian window to smooth
				cfg.winlen			= 0.004; % the window by which we smooth has size 4 by 4 ms
				cfg.colormap		= jet(300); % colormap
				cfg.scatter			= 'no'; % do not plot the individual isis per spike as scatters
				ft_spike_plot_isireturn(cfg,isi{j})
				p(i1,i2).title([me.selectedTrials{j}.name ' ' me.file]);
			end
		end
		
		% ===================================================================
		%> @brief
		%> @param
		%> @return
		% ===================================================================
		function plotWaveforms(me,timeWindow)
			if ~exist('timeWindow','var') || isempty(timeWindow)
				timeWindow = me.plotRange;
			elseif iscell(timeWindow) 
				while iscell(timeWindow);timeWindow=timeWindow{1};end
			end
			if me.nSelection == 0; error('The selection results in no valid trials to process!'); end
			if ~isfield(me.spike{1}.trials{1},'waves')
				warning('No waveform data present, nothing to plot...')
				return
			end
			fs = get(0,'DefaultAxesFontSize');
			h=figure;figpos(2,[1600 600]);set(h,'Color',[1 1 1],'Name',[me.file ' ' me.names{me.selectedUnit}]);
			p=panel(h);
			p.fontsize = fs-1;
			p.margin = [10 8 12 8]; %left bottom right top
			[row,col]=me.optimalLayout(me.nSelection);
			p.pack(col,row);
			for j = 1:length(me.selectedTrials)
				[i1,i2] = ind2sub([col,row], j);
				p(i1,i2).select();
				idx				= me.selectedTrials{j}.idx;
				map				= me.optimalColours(length(idx));
				name				= [me.names{me.selectedUnit} ' ' me.selectedTrials{j}.name '| time:' num2str(timeWindow)];
				s					= me.spike{me.selectedUnit};
				len				= length(s.trials);
				t					= [s.trials{idx}]; %extract our trials
				if ~isfield(t,'waves')
					warning('No waveform data present')
					return
				end
				time				= (0:1/4e4:(1/4e4)*(size(t(1).waves,2)-1)) .*1e3;
				waves = [];
				nwaves = 0;
				hold on
				for k = 1:length(t)
					if isempty(timeWindow)
						w = t(k).waves;
					else
						sp = t(k).spikes - t(k).base;
						idx = find(sp >= timeWindow(1) & sp <= timeWindow(2));
						w = t(k).waves(idx,:);
					end
					if ~isempty(w)
						plot(time,w','k-','Color',map(k,:));
						waves = vertcat(waves,w);
					end
				end
				if ~isempty(waves)
					nwaves = size(waves,1);
					[a,e]=stderr(waves,'SD');
					areabar(time,a,e,[0.7 0.7 0.7],0.75,'r-o','LineWidth',2);
				end
				xlabel('Time(ms)')
				ylabel('Voltage (mV)')
				title([name ' | nwaves: ' num2str(nwaves)]);
			end
		end
		
		% ===================================================================
		%> @brief
		%> @param
		%> @return
		% ===================================================================
		function appendTrialNames(me,hdl,idx)
			
			axis(hdl);
			xpos = xlim;
			hold on
			nMS1 = 0;
			nMS2 = 0;
			for j = 1:length(idx)
				cs{j} = num2str(idx(j));
				y(j) = j;
				x(j) = xpos(2) + abs(((xpos(2)-xpos(1))/100));
				if isfield(me.p.eventList.trials(idx(1)),'microSaccades')
					mS = me.p.eventList.trials(idx(j)).microSaccades;
					if me.p.saccadeRealign == true
						mS = mS - me.p.eventList.trials(idx(j)).firstSaccade;
					end
					mS(isnan(mS))=[];
					if ~isempty(mS)
						mS1 = mS( mS >= me.baselineWindow(1) & mS <= me.baselineWindow(2));
						mS2 = mS( mS >= 0 & mS <= me.measureRange(2));
						nMS1 = nMS1 + length(mS1);
						nMS2 = nMS2 + length(mS2);
						plot(mS, y(j), 'ro', 'MarkerFaceColor', 'none', 'MarkerSize', 4);
					end
				end
			end
			if isfield(me.p.eventList.trials(idx(1)),'firstSaccade')
				st = [me.p.eventList.trials(idx).firstSaccade];
				if me.p.saccadeRealign == true
					st = st - st;
				end
				yt = 1:length(st);
				plot(st, yt, 'go', 'MarkerFaceColor', 'none', 'MarkerSize', 4);
			end
			if length(idx) >= 100
				fs = 9;
			elseif length(idx) >= 40
				fs = 10;
			else
				fs = 11;
			end
			if ~isnumeric(gca)
				fs = fs-3;
			end
			text(x,y,cs,'FontSize',fs,'Color',[0.5 0.5 0.5],'Interpreter','none')
			set(hdl,'YGrid','on','YMinorGrid','on')
			fprintf('\nRatio of baseline microSaccades: %.2g (%i msaccs for %i trials)\n',nMS1/length(idx),nMS1,length(idx));
			fprintf('Ratio of response microSaccades: %.2g (%i msaccs for %i trials)\n\n',nMS2/length(idx),nMS2,length(idx));
		end
		
		% ===================================================================
		%> @brief
		%>
		%> @param
		%> @return
		% ===================================================================
		function makeUI(me, varargin)
			if ~isempty(me.handles) && isfield(me.handles,'hbox') && isa(me.handles.hbox,'uix.HBoxFlex')
				fprintf('---> UI already open!\n');
				me.openUI = true;
				return
			end
			embedMode = false; %check if LFPAnalysis wants us to embed in its figure?
			while iscell(varargin) && ~isempty(varargin); varargin = varargin{1}; end
			if ~isempty(varargin) && isa(varargin,'uix.Panel')
				parent = varargin;
				embedMode = true;
			end
			if ~exist('parent','var')
				parent = figure('Tag','Spike Analysis',...
					'Name', ['Spike Analysis: ' me.fullName], ...
					'MenuBar', 'none', ...
					'CloseRequestFcn', @me.closeUI,...
					'NumberTitle', 'off');
				figpos(1,[1200 600])
			end
			me.handles(1).parent = parent;
			
			%make context menu
			hcmenu = uicontextmenu;
			uimenu(hcmenu,'Label','Select','Callback',@me.select,'Accelerator','e');
			uimenu(hcmenu,'Label','Plot','Callback',@me.plot,'Accelerator','p');
			
			fs = 10;
			SansFont = 'Helvetica';
			MonoFont = 'Consolas';
			bgcolor = [0.89 0.89 0.89];
			bgcoloredit = [0.9 0.9 0.9];

			handles.parent = me.handles.parent; %#ok<*PROP>
			if embedMode == true
				handles.root = handles.parent;
			else
				handles.root = uix.BoxPanel('Parent',parent,...
					'Title','Spike Analysis UI',...
					'FontName',SansFont,...
					'FontSize',fs,...
					'FontWeight','normal',...
					'Padding',0,...
					'TitleColor',[0.8 0.78 0.76],...
					'BackgroundColor',bgcolor);
			end
			
			handles.hbox = uix.HBoxFlex('Parent', handles.root,'Padding',0,...
				'Spacing', 5, 'BackgroundColor', bgcolor);
			handles.spikeinfo = uicontrol('Parent', handles.hbox,'Style','edit','Units','normalized',...
				'BackgroundColor',[0.3 0.3 0.3],'ForegroundColor',[1 1 0],'Max',500,...
				'FontSize',fs+1,'FontWeight','bold','FontName',SansFont,'HorizontalAlignment','left');

			handles.controls = uix.VBoxFlex('Parent', handles.hbox,'Padding',0,'Spacing',0,'BackgroundColor',bgcolor);
			handles.controls1 = uix.Grid('Parent', handles.controls,'Padding',4,'Spacing',2,'BackgroundColor',bgcolor);
			handles.controls2 = uix.Grid('Parent', handles.controls,'Padding',4,'Spacing',0,'BackgroundColor',bgcolor);
			
			handles.parsebutton = uicontrol('Style','pushbutton',...
				'Parent',handles.controls1,...
				'Tag','LFPAParse',...
				'Tooltip','Parse All data',...
				'FontSize', fs,...
				'Callback',@me.parse,...
				'String','Parse Spikes');
			handles.reparsebutton = uicontrol('Style','pushbutton',...
				'Parent',handles.controls1,...
				'Tag','LFPAReparse',...
				'FontSize', fs,...
				'Tooltip','Reparse should be a bit quicker',...
				'Callback',@me.reparse,...
				'String','Reparse Spikes');
			handles.selectbutton = uicontrol('Style','pushbutton',...
				'Parent',handles.controls1,...
				'Tag','LFPAselect',...
				'FontSize', fs,...
				'Tooltip','Select trials',...
				'Callback',@me.select,...
				'String','Select Trials');
			handles.plotbutton = uicontrol('Style','pushbutton',...
				'Parent',handles.controls1,...
				'Tag','LFPAplotbutton',...
				'FontSize', fs,...
				'Tooltip','Plot',...
				'Callback',@me.plot,...
				'String','Plot');
			handles.statbutton = uicontrol('Style','pushbutton',...
				'Parent',handles.controls1,...
				'Tag','LFPAstatbutton',...
				'FontSize', fs,...
				'Tooltip','Plot',...
				'Callback',@me.setStats,...
				'String','Analysis Stats Options');
			handles.savebutton = uicontrol('Style','pushbutton',...
				'Parent',handles.controls1,...
				'Tag','LFPAsave',...
				'FontSize', fs,...
				'Tooltip','Save this LFP Analysis object',...
				'Callback',@me.save,...
				'String','Save Analysis Object');
			handles.saccbutton = uicontrol('Style','pushbutton',...
				'Parent',handles.controls1,...
				'Tag','LMAsaccbutton',...
				'FontSize', fs,...
				'Tooltip','Toggle Saccade Realign',...
				'Callback',@me.toggleSaccadeRealign,...
				'String','Toggle Saccade Align');
			handles.analmethod = uicontrol('Style','popupmenu',...
				'Parent',handles.controls1,...
				'FontSize', fs,...
				'Tooltip','Select a method to run',...
				'Callback',@runAnal,...
				'Tag','LFPAanalmethod',...
				'String',{'density','PSTH','ISI','ROC','showEyePlots'});
			
			handles.list = uicontrol('Style','edit',...
				'Parent',handles.controls2,...
				'Tag','LMAlistbox',...
				'Min',1,...
				'Max',100,...
				'FontSize',fs-1,...
				'FontName',MonoFont,...
				'String',{''},...
				'uicontextmenu',hcmenu);
			
			set(handles.hbox,'Widths', [-1 -1]);
			set(handles.controls,'Heights', [60 -1]);
			set(handles.controls1,'Heights', [-1 -1]);
			
			me.handles = handles;
			me.openUI = true;
			
			updateUI(me);
			
			function runAnal(src, ~)
				if ~exist('src','var');	return; end
				s = get(src,'String'); v = get(src,'Value'); s = s{v};
				if me.nUnits > 0
					eval(['me.' s])
				end
			end
		end
		
		
		% ===================================================================
		%> @brief 
		%>
		%> @param
		%> @return
		% ===================================================================
		function closeUI(me, varargin)
			try delete(me.handles.parent); end %#ok<TRYNC>
			me.handles = struct();
			me.openUI = false;
		end
		
		% ===================================================================
		%> @brief 
		%>
		%> @param
		%> @return
		% ===================================================================
		function updateUI(me, varargin)
			if me.openUI && isa(me.p,'plxReader')
				if me.nUnits == 0
					notifyUI(me,'You need to PARSE the data files first');
				else
					notifyUI(me,'Data seems to be parsed, try running an analysis');
				end
				fs = 10;
				me.p.generateInfo;
				set(me.handles.spikeinfo,'String',me.p.info,'FontSize',fs+1)
			end
		end
		
		% ===================================================================
		%> @brief 
		%>
		%> @param
		%> @return
		% ===================================================================
		function notifyUI(me, varargin)
			if nargin > 2
				info = sprintf(varargin{:});
			elseif nargin == 1 && iscell(varargin)
				info = varargin{1};
			else
				info = varargin;
			end
			if isa(me.handles.root,'uix.BoxPanel')
				try set(me.handles.root,'Title',info); end
			end
		end
	end
end
