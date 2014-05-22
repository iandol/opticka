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
		%> fieldtrip reparse
		ft@struct
		%> fieldtrip parsed results
		results@struct
		%> the events as trials structure
		trial@struct
		%> events structure
		event@struct
		%> spike trial structure
		spike@cell
		%> names of spike channels
		names@cell
		%> trials to remove in reparsing
		cutTrials@double
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
		function ego = spikeAnalysis(varargin)
			if nargin == 0; varargin.name = 'spikeAnalysis'; end
			ego=ego@analysisCore(varargin); %superclass constructor
			if nargin>0; ego.parseArgs(varargin, ego.allowedProperties); end
			if isempty(ego.name);ego.name = 'spikeAnalysis'; end
			if isempty(ego.file);
				getFiles(ego,false);
			end
		end
		
		% ===================================================================
		%> @brief Constructor
		%>
		%> @param varargin
		%> @return
		% ===================================================================
		function getFiles(ego, force)
			if ~exist('force','var')
				force = false;
			end
			if force == true || isempty(ego.file)
				[f,p] = uigetfile({'*.plx;*.pl2';'Plexon Files'},'Load Spike PLX/PL2 File');
				if ischar(f) && ~isempty(f)
					ego.file = f;
					ego.dir = p;
					ego.paths.oldDir = pwd;
					cd(ego.dir);
					ego.p = plxReader('file', ego.file, 'dir', ego.dir);
					ego.p.name = ['^' ego.fullName '^'];
					getFiles(ego.p);
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
		function parse(ego)
			ft_defaults
			ego.yokedSelection = false;
			if isempty(ego.file)
				getFiles(ego, true);
				if isempty(ego.file); warning('No plexon file selected'); return; end
			end
			
			ego.paths.oldDir = pwd;
			cd(ego.dir);
			ego.p.eventWindow = ego.spikeWindow;
			parse(ego.p);
			ego.trial = ego.p.eventList.trials;
			ego.event = ego.p.eventList;
			for i = 1:ego.nUnits
				ego.spike{i}.trials = ego.p.tsList.tsParse{i}.trials;
			end
			ego.ft = struct(); ego.results = struct();
			ego.ft = getFieldTripSpikes(ego.p);
			ego.names = ego.ft.label;
			showInfo(ego);
			select(ego);
		end
		
		% ===================================================================
		%> @brief
		%>
		%> @param
		%> @return
		% ===================================================================
		function lazyParse(ego)
			ft_defaults
			if isempty(ego.file)
				getFiles(ego, true);
				if isempty(ego.file); warning('No plexon file selected'); return; end
			end
			ego.paths.oldDir = pwd;
			cd(ego.dir);
			ego.p.eventWindow = ego.spikeWindow;
			lazyParse(ego.p);
			ego.trial = ego.p.eventList.trials;
			ego.event = ego.p.eventList;
			for i = 1:ego.nUnits
				ego.spike{i}.trials = ego.p.tsList.tsParse{i}.trials;
			end
			ego.ft = struct(); ego.results = struct();
			ego.ft = getFieldTripSpikes(ego.p);
			ego.names = ego.ft.label;
			if isempty(ego.selectedTrials)
				select(ego);
			elseif ego.yokedSelection == false
				selectTrials(ego)
			end
			if ~isempty(ego.p.eA.ROIInfo)
				ego.p.eA.ROI = ego.ROI;
				parseROI(ego.p.eA);
			end
			if ~isempty(ego.p.eA.TOIInfo)
				ego.p.eA.TOI = ego.TOI;
				parseTOI(ego.p.eA);
			end
			disp('Lazy spike parsing finished...')
		end
		
		% ===================================================================
		%> @brief 
		%>
		%> @param
		%> @return
		% ===================================================================
		function reparse(ego)
			ego.p.eventWindow = ego.spikeWindow;
			parse(ego.p);
			ego.trial = ego.p.eventList.trials;
			ego.event = ego.p.eventList;
			for i = 1:ego.nUnits
				ego.spike{i}.trials = ego.p.tsList.tsParse{i}.trials;
			end
			ego.ft = struct(); ego.results = struct();
			ego.ft = getFieldTripSpikes(ego.p);
			ego.names = ego.ft.label;
			select(ego);
			if ~isempty(ego.ROI)
				ego.p.eA.ROI = ego.ROI;
				parseROI(ego.p.eA);
			end
			if ~isempty(ego.TOI)
				ego.p.eA.TOI = ego.TOI;
				parseTOI(ego.p.eA);
			end
		end
		
		% ===================================================================
		%> @brief 
		%>
		%> @param
		%> @return
		% ===================================================================
		function select(ego,force)
			if ~exist('force','var'); force = false; end
			if isempty(ego.trial); warndlg('Data not parsed yet...');return;end
			if force == true; ego.yokedSelection = false; end
			if ego.yokedSelection == true;
				disp('This spikeanalysis object is currently locked, run select(true) to override lock...'); return
			end
			cuttrials = '[ ';
			if ~isempty(ego.cutTrials) 
				cuttrials = [cuttrials num2str(ego.cutTrials)];
			end
			cuttrials = [cuttrials ' ]'];
			
			map = cell(1,3);
			if isempty(ego.map) || length(ego.map)~=3 || ~iscell(ego.map)
				map{1} = '1 2 3 4 5 6';
				map{2} = '7 8';
				map{3} = '';
			else
				map{1} = num2str(ego.map{1});
				map{2} = num2str(ego.map{2});
				map{3} = num2str(ego.map{3});
			end
			
			unit = 'p';
			for i = 1:ego.nUnits
				if i == ego.selectedUnit
					unit = [unit '|¤' ego.names{i}];
				else
					unit = [unit '|'  ego.names{i}];
				end
			end
			
			inbeh = {'correct','breakFix','incorrect','all'};
			beh = 'r';
			if ischar(ego.selectedBehaviour);
				t = ego.selectedBehaviour;
				ego.selectedBehaviour = cell(1);
				ego.selectedBehaviour{1} = t;
			end
			for i = 1:length(inbeh)
				if strcmpi(inbeh{i}, ego.selectedBehaviour{1})
					beh = [beh '|¤' inbeh{i}];
				else
					beh = [beh '|' inbeh{i}];
				end
			end
			
			indenf = {'gauss','alphawin'};
			denf = 'r';
			for i = 1:length(indenf)
				if strcmpi(indenf{i}, ego.densityFunction)
					denf = [denf '|¤' indenf{i}];
				else
					denf = [denf '|' indenf{i}];
				end
			end

			pr = num2str(ego.plotRange);
			rr = num2str(ego.measureRange);
			bw = [num2str(ego.binSize) '       ' num2str(ego.densityWindow)];
			roi = num2str(ego.ROI);
			saccfilt = num2str(ego.filterFirstSaccades);
			toifilt = num2str(ego.TOI);
			ego.selectedBehaviour = {};
			
			mtitle   = [ego.file ': REPARSE ' num2str(ego.event.nVars) ' DATA VARIABLES'];
			options  = {['t|' map{1}],'Choose PLX variables to merge (A, if empty parse all variables independantly):';   ...
				['t|' map{2}],'Choose PLX variables to merge (B):';   ...
				['t|' map{3}],'Choose PLX variables to merge (C):';   ...
				['t|' cuttrials],'Enter Trials to exclude:';   ...
				[unit],'Choose Default Spike Channel to View:';...
				[beh],'Behavioural response type:';...
				['t|' pr],'Plot Range (±seconds):';   ...
				['t|' rr],'Measure Firing Rate Range (±seconds):';   ...
				['t|' bw],'Binwidth (PSTH) & Smooth Window (Density) [BINWIDTH -WINDOW +WINDOW] (seconds):';   ...
				[denf],'Smoothing function for Density Plots:';...
				['t|' roi],'Stimulus Region of Interest [X Y RADIUS INCLUDE[0|1]] (blank = ignore):';   ...
				['t|' toifilt],'Fixation Time/Region Of Interest [STARTTIME ENDTIME  X Y RADIUS] (blank = ignore):';   ...
				['t|' saccfilt],'Saccade Filter in seconds [TIME1 TIME2], e.g. [-0.8 0.8] (blank = ignore):';   ...
				};
			answer = menuN(mtitle,options);
			drawnow;
			if iscell(answer) && ~isempty(answer)
				re = regexpi(answer{1},'^[CBI]','once');
				if ~isempty(re)
					ego.selectedBehaviour{1} = answer{1}(1);
					answer{1} = answer{1}(2:end);
				else
					ego.selectedBehaviour{1} = inbeh{answer{6}};
				end
				ego.map{1} = str2num(answer{1});
				
				re = regexpi(answer{2},'^[CBI]','once');
				if ~isempty(re)
					ego.selectedBehaviour{2} = answer{2}(1);
					answer{2} = answer{2}(2:end);
				else
					ego.selectedBehaviour{2} = inbeh{answer{6}};
				end
				ego.map{2} = str2num(answer{2});
				
				re = regexpi(answer{3},'^[CBI]','once');
				if ~isempty(re)
					ego.selectedBehaviour{3} = answer{3}(1);
					answer{3} = answer{3}(2:end);
				else
					ego.selectedBehaviour{3} = inbeh{answer{6}};
				end
				ego.map{3} = str2num(answer{3}); 

				ego.cutTrials = str2num(answer{4});
				ego.selectedUnit = answer{5};
				ego.plotRange = str2num(answer{7});
				ego.measureRange = str2num(answer{8});

				bw = str2num(answer{9});
				
				ego.densityFunction = indenf{answer{10}};
				
				if length(bw) == 1
					ego.binSize = bw(1);
				elseif length(bw)==2
					ego.binSize = bw(1);
					ego.densityWindow = [-abs(bw(2)) abs(bw(2))];
				elseif length(bw)==3
					ego.binSize = bw(1);
					ego.densityWindow = [bw(2) bw(3)];
				end
				
				roi = str2num(answer{11});
				if isnumeric(roi) && length(roi) == 4
					ego.ROI = roi;
				else
					ego.ROI = [];
				end
				ego.TOI = str2num(answer{12});
				ego.filterFirstSaccades = str2num(answer{13});
				
				if ~isempty(ego.ROI)
					ego.p.eA.ROI = ego.ROI;
					parseROI(ego.p.eA);
					plotROI(ego.p.eA);
				end
				if ~isempty(ego.TOI)
					ego.p.eA.TOI = ego.TOI;
					parseTOI(ego.p.eA);
					plotTOI(ego.p.eA);
				end
				selectTrials(ego);
			end
		end
			
		% ===================================================================
		%> @brief doPSTH plots spike density for the selected trial groups
		%>
		%> @param
		%> @return
		% ===================================================================
		function PSTH(ego)
			if ego.nSelection == 0; error('The selection results in no valid trials to process!'); end
			ft_defaults;
			psth = cell(1,length(ego.selectedTrials));
			for j = 1:length(ego.selectedTrials)
				cfg					= [];
				cfg.trials			= ego.selectedTrials{j}.idx;
				cfg.binsize			= ego.binSize;
				cfg.outputunit		= 'rate';
				cfg.latency			= ego.plotRange;
				cfg.spikechannel	= ego.names{ego.selectedUnit};
				psth{j}				= ft_spike_psth(cfg, ego.ft);
			end
			ego.results(1).psth = psth;
			getRates(ego);
			
			if ego.doPlots; plot(ego,'psth'); end
		end
		
		% ===================================================================
		%> @brief doDensity plots spike density for the selected trial groups
		%>
		%> @param
		%> @return
		% ===================================================================
		function density(ego)
			if ego.nSelection == 0; error('The selection results in no valid trials to process!'); end
			ft_defaults;
			sd = cell(1,length(ego.selectedTrials));
			for j = 1:length(ego.selectedTrials)
				cfg					= [];
				cfg.trials			= ego.selectedTrials{j}.idx;
				cfg.winfunc			= ego.densityFunction;
				cfg.timwin			= ego.densityWindow;
				cfg.fsample			= 1000; % sample at 1000 hz
				cfg.outputunit		= 'rate';
				cfg.latency			= ego.plotRange;
				cfg.spikechannel	= ego.names{ego.selectedUnit};
				sd{j}					= ft_spikedensity(cfg, ego.ft);
			end
			ego.results(1).sd = sd;
			getRates(ego);
			
			if ego.doPlots; plot(ego,'density'); end
		end
		
		% ===================================================================
		%> @brief doPSTH plots spike density for the selected trial groups
		%>
		%> @param
		%> @return
		% ===================================================================
		function ISI(ego)
			if ego.nSelection == 0; error('The selection results in no valid trials to process!'); end
			ft_defaults;
			for j = 1:length(ego.selectedTrials)
				cfg					= [];
				cfg.trials			= ego.selectedTrials{j}.idx;
				cfg.bins				= [0:0.0005:0.1]; % use bins of 0.5 milliseconds;
				cfg.param			= 'coeffvar'; % compute the coefficient of variation (sd/mn of isis)
				cfg.spikechannel	= ego.names{ego.selectedUnit};
				isi{j}				= ft_spike_isi(cfg, ego.ft);
			end
			ego.results.isi = isi;
			if ego.doPlots; plot(ego,'isi'); end
		end
		
		% ===================================================================
		%> @brief doPSTH plots spike density for the selected trial groups
		%>
		%> @param
		%> @return
		% ===================================================================
		function getRates(ego)
			if isempty(ego.stats); ego.initialiseStats(); end
			rate = cell(1,length(ego.selectedTrials));
			baseline = rate;
			for j = 1:length(ego.selectedTrials)
				cfg					= [];
				cfg.trials			= ego.selectedTrials{j}.idx;
				cfg.spikechannel	= ego.names{ego.selectedUnit};
				cfg.latency			= [ego.measureRange(1) ego.measureRange(2)]; % sustained response period
				cfg.keeptrials		= 'yes';
				cfg.outputunit		= 'rate';
				rate{j}				= ft_spike_rate(cfg,ego.ft);
				rate{j}.CI			= bootci(ego.stats.nrand, {@mean, rate{j}.trial},'alpha',ego.stats.alpha);
				rate{j}.alpha		= ego.stats.alpha;
					
				cfg.latency			= ego.baselineWindow;
				baseline{j}			= ft_spike_rate(cfg,ego.ft);
				baseline{j}.CI		= bootci(ego.stats.nrand, {@mean, baseline{j}.trial},'alpha',ego.stats.alpha);
				baseline{j}.alpha		= ego.stats.alpha;
			end
			ego.results.rate = rate;
			ego.results.baseline = baseline;
		end
		
		% ===================================================================
		%> @brief
		%> @param
		%> @return
		% ===================================================================
		function nUnits = get.nUnits(ego)
			nUnits = 0;
			if isfield(ego.p.tsList,'nUnits')
				nUnits = ego.p.tsList.nUnits;
			end	
		end
		
		% ===================================================================
		%> @brief
		%> @param
		%> @return
		% ===================================================================
		function nSelection = get.nSelection(ego)
			nSelection = 0;
			if ~isempty(ego.selectedTrials)
				nSelection = length(ego.selectedTrials);
			end	
		end		
		
		% ===================================================================
		%> @brief save saves the object with a pregenerated name
		%> @param
		%> @return
		% ===================================================================
		function save(ego)
			[~,f,~] = fileparts(ego.file);
			name = ['SPIKE' f];
			if ~isempty(ego.ft)
				name = [name '-ft'];
			end
			name = [name '.mat'];
			[f,p] = uiputfile(name,'SAVE Spike Analysis File');
			if ischar(f) && ~isempty(f)
				od = pwd;
				cd(p);
				spike = ego;
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
		function setFiles(ego, in)
			if isstruct(in)
				f=fieldnames(in);
				for i=1:length(f)
					if isprop(ego,f{i})
						try ego.(f{i}) = in.(f{i}); end
					end
				end
				if isempty(ego.p)
					ego.paths.oldDir = pwd;
					cd(ego.dir);
					ego.p = plxReader('file', ego.file, 'dir', ego.dir);
					ego.p.name = ['^' ego.fullName '^'];
				end
				for i=1:length(f)
					if isprop(ego.p,f{i})
						try ego.p.(f{i}) = in.(f{i}); end
					end
				end
				
			end
		end
		
		% ===================================================================
		%> @brief 
		%>
		%> @param
		%> @return
		% ===================================================================
		function findRepeats(ego)
			
		end
		
		% ===================================================================
		%> @brief 
		%>
		%> @param
		%> @return
		% ===================================================================
		function saccadeTimeVsResponse(ego)
			if isempty(ego.gd)
				ego.gd = getDensity();
			end
			usez = false;
			ego.gd.alpha = ego.stats.alpha;
			if usez
				ego.gd.normaliseScatter = false;
			else
				ego.gd.normaliseScatter = true;
			end
			getRates(ego);
			for j = 1:ego.nSelection
				st=[ego.trial(ego.selectedTrials{j}.idx).firstSaccade]';
				nanidx = isnan(st);
				st(nanidx)=[];
				if usez; st = zscore(st); end
				rate = ego.results.rate{j}.trial;
				rate(nanidx) = [];
				%rate = rate/max(rate);
				if usez; rate = zscore(rate); end
				t = ['SaccadeVsResponse ' num2str(ego.selectedTrials{j}.sel)];
				t = regexprep(t,'\s+','_');
				ego.gd.columnlabels = {t};
				ego.gd.legendtxt = {'Saccades','Spikes'};
				ego.gd.x = st;
				ego.gd.y = rate;
				run(ego.gd);
			end
		end
		
		% ===================================================================
		%> @brief 
		%>
		%> @param
		%> @return
		% ===================================================================
		function compareBaseline(ego)
			
		end
		
		% ===================================================================
		%> @brief 
		%>
		%> @param
		%> @return
		% ===================================================================
		function plot(ego, varargin)
			if isempty(ego.results);
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
					plotPSTH(ego); drawnow;
				case {'d','density'}
					plotDensity(ego); drawnow;
				case {'ds','densitysummary'}
					plotDensitySummary(ego); drawnow;
				case {'i','isi'}
					plotISI(ego); drawnow;
			end
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
		function selectTrials(ego)	
			if ego.yokedSelection == true %if we are yoked to another object, don't run this method
				return
			end
			
			cutidx = ego.cutTrials; %cut trials index
			
			saccidx = [];
			if ~isempty(ego.filterFirstSaccades)
				idx = find([ego.trial.firstSaccade] >= ego.filterFirstSaccades(1));
				idx2 = find([ego.trial.firstSaccade] <= ego.filterFirstSaccades(2));
				saccidx = intersect(idx,idx2);
			end
			
			roiidx = [];
			if ~isempty(ego.ROI)
				idx = [ego.p.eA.ROIInfo.enteredROI] == logical(ego.ROI(4));
				rois = ego.p.eA.ROIInfo(idx);
				roiidx = [rois.correctedIndex];
			end	

			toiidx = [];
			if ~isempty(ego.TOI)
				idx = [ego.p.eA.TOIInfo.isTOI] == true;
				tois = ego.p.eA.TOIInfo(idx);
				toiidx = [tois.correctedIndex];
			end
			
			if length(ego.selectedBehaviour) ~= length(ego.map)
				error('Index error for behaviours');
			end
			
			for i = 1:length(ego.selectedBehaviour) %generate our selected behaviour indexes
				switch lower(ego.selectedBehaviour{i})
					case {'c', 'correct'}
						behaviouridx{i} = find([ego.trial.isCorrect]==true); %#ok<*AGROW>
						selectedBehaviour{i} = 'correct';
					case {'b', 'breakfix'}
						behaviouridx{i} = find([ego.trial.isBreak]==true);
						selectedBehaviour{i} = 'breakfix';
					case {'i', 'incorrect'}
						behaviouridx{i} = find([ego.trial.isIncorrect]==true);
						selectedBehaviour{i} = 'incorrect';						
					otherwise
						behaviouridx{i} = [ego.trial.index];
						selectedBehaviour{i} = 'all';
				end
			end
			
			if isempty(ego.map{1}) %if our map is empty, generate groups for each variable
				bidx = behaviouridx{1};
				sb = selectedBehaviour{1};
				for i = 1:ego.event.nVars; 
					map{i} = ego.event.unique(i); 
					behaviouridx{i} = bidx;
					selectedBehaviour{i} = sb;
				end
			else
				map = ego.map; %#ok<*PROP>
			end
	
			ego.selectedTrials = {};
			varList = [ego.trial.variable];
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
					ego.selectedTrials{a}.idx			= idx;
					ego.selectedTrials{a}.cutidx		= cutidx;
					ego.selectedTrials{a}.roiidx		= roiidx; 
					ego.selectedTrials{a}.toiidx		= toiidx;
					ego.selectedTrials{a}.saccidx		= saccidx;
					ego.selectedTrials{a}.bidx			= bidx;
					ego.selectedTrials{a}.behaviour	= selectedBehaviour{i};
					ego.selectedTrials{a}.sel			= map{i};
					ego.selectedTrials{a}.name			= ['[' num2str(ego.selectedTrials{a}.sel) ']' ' #' num2str(length(idx))];
					if isfield(ego.stats,'sort') && ~isempty(ego.stats.sort)
						switch ego.stats.sort
							case 'saccades'
								st = [ego.trial(idx).firstSaccade];
								mn = nanmean(st);
								st(isnan(st)) = mn;
								[~,stidx] = sort(st);
								ego.selectedTrials{a}.idx = idx(stidx);
								ego.selectedTrials{a}.sort = 'saccades';
							case 'variable'

						end					
					end
					a = a + 1;
				end
			end
			
			if ego.nSelection == 0; warndlg('The selection results in no valid trials to process!'); return; end
			for j = 1:ego.nSelection
				fprintf(' SELECT TRIALS GROUP %g\n=======================\nInfo: %s\nTrial Index: %s\n-Cut Index: %s\nBehaviour: %s\n',...
					j,ego.selectedTrials{j}.name,num2str(ego.selectedTrials{j}.idx),num2str(ego.selectedTrials{j}.cutidx),...
					ego.selectedTrials{j}.behaviour);
			end
		end
		
		% ===================================================================
		%> @brief
		%> @param
		%> @return
		% ===================================================================
		function plotDensity(ego)
			if ~isfield(ego.results,'sd'); warning('No Density parsed yet.'); return; end
			disp('Plotting Density Data...')
			sd = ego.results.sd;
			rate = ego.results.rate;
			baseline = ego.results.baseline;
			if ego.nSelection == 0; error('The selection results in no valid trials to process!'); end
			h=figure;set(h,'Color',[1 1 1],'Name',[ego.file ' ' ego.names{ego.selectedUnit}]);
			if length(sd) <4; figpos(1,[1000 1500]); else figpos(1,[2000 2000]); end
			p=panel(h);
			p.margin = [15 20 10 10]; %left bottom right top
			p.pack('v', {3/4 []})
			q = p(1);
			len = ego.nSelection;
			[row,col]=ego.optimalLayout(len);
			q.pack(row,col);
			for j = 1:length(ego.selectedTrials)
				[i1,i2] = ind2sub([row,col], j);
				q(i1,i2).select();
				cfg					= [];
				cfg.trials			= ego.selectedTrials{j}.idx;
				cfg.spikechannel	= ego.names{ego.selectedUnit};
				if length(cfg.trials) < 50; cfg.spikelength = 0.7; else cfg.spikelength = 1; end
				cfg.latency			= ego.plotRange;
				cfg.trialborders	= 'no';
				cfg.linewidth		= 1;
				cfg.plotselection	= 'yes';
				cfg.topplotfunc	= 'line'; % plot as a line
				cfg.errorbars		= 'conf95%'; % plot with the standard deviation
				cfg.interactive	= 'no'; % toggle off interactive mode
				if ego.insetRasterPlot
					cfgUsed{j}		= ft_spike_plot_raster(cfg, ego.ft, sd{j});
				else
					cfgUsed{j}		= ft_spike_plot_raster(cfg, ego.ft);
				end
				q(i1,i2).title([ego.names{ego.selectedUnit} ' VAR: ' num2str(j)])
				if isfield(cfgUsed{j}.hdl,'axTopPlot'); set(cfgUsed{j}.hdl.axTopPlot,'Color','none'); end
				ego.appendTrialNames(cfgUsed{j}.hdl.axRaster,cfgUsed{j}.trials);
			end
			
			p(2).select();
			p(2).marginbottom = 2; %left bottom right top
			box on;grid on
			p(2).hold('on');
			c = ego.optimalColours(length(sd));
			
			xp = [rate{1}.cfg.latency(1) rate{1}.cfg.latency(2) rate{1}.cfg.latency(2) rate{1}.cfg.latency(1)];
			yp = [nanmean(sd{1}.avg) nanmean(sd{1}.avg) nanmean(sd{1}.avg) nanmean(sd{1}.avg)];
			mh = patch(xp,yp,[0.9 0.9 0.9],'FaceAlpha',0.6,'EdgeColor','none');
			set(get(get(mh,'Annotation'),'LegendInformation'),'IconDisplayStyle','off'); % Exclude line from legend
			
			blineText = sprintf('BASELINE (p=%.4g):',baseline{1}.alpha);
			for j = 1:length(baseline)
				xp = [ego.plotRange(1) ego.plotRange(2) ego.plotRange(2) ego.plotRange(1)];
				yp = [baseline{j}.CI(1) baseline{j}.CI(1) baseline{j}.CI(2) baseline{j}.CI(2)];
				me1 = patch(xp,yp,c(j,:),'FaceAlpha',0.1,'EdgeColor','none');
				set(get(get(me1,'Annotation'),'LegendInformation'),'IconDisplayStyle','off'); % Exclude line from legend
				blineText = sprintf('%s  Group:%i %.4g ± %.3g<>%.3g',blineText,j,baseline{j}.avg,baseline{j}.CI(1),baseline{j}.CI(2));
			end
			disp(blineText);
			
			t = [ego.file];
			for j = 1:length(sd)
				e = ego.var2SE(sd{j}.var,sd{j}.dof);
				areabar(sd{j}.time, sd{j}.avg, e, c(j,:)/2, 0.2, 'k.-','Color',c(j,:),'MarkerFaceColor',c(j,:),'LineWidth',1);
				leg{j,1} = ego.selectedTrials{j}.name;
				e = ego.var2SE(rate{j}.var,rate{j}.dof);
				t = [t sprintf(' R%i: %.4g ± %.3g %.3g<>%.3g', j, rate{j}.avg, e, rate{j}.CI(1), rate{j}.CI(2))];
			end
			disp([t sprintf(' | measureRange: %s', num2str(rate{1}.cfg.latency))]);
			title(t,'FontSize',13);
			xlabel(['Time (s) [window = ' sd{1}.cfg.winfunc ' ' num2str(sd{1}.cfg.timwin) '] ']);
			ylabel(['Firing Rate (s/s) \pm S.E.M.'])
			set(gcf,'Renderer','OpenGL');
			legend(leg);
			ax=axis;
			axis([ego.plotRange(1) ego.plotRange(2) ax(3) ax(4)]);
			text(ego.plotRange(1),ax(3),blineText,'FontSize',10,'VerticalAlignment','baseline');
			set(mh,'yData',[ax(3) ax(3) ax(4) ax(4)]);
			set(gca,'Layer','top');
		end
		
		% ===================================================================
		%> @brief
		%> @param
		%> @return
		% ===================================================================
		function plotDensitySummary(ego)
			if ~isfield(ego.results,'sd'); warning('No Density parsed yet.'); return; end
			disp('Plotting Density Data...')
			sd = ego.results.sd;
			rate = ego.results.rate;
			baseline = ego.results.baseline;
			if ego.nSelection == 0; error('The selection results in no valid trials to process!'); end
			h=figure;figpos(1,[1000 1000]);set(h,'Color',[1 1 1],'Name',[ego.file ' ' ego.names{ego.selectedUnit}]);
			box on
			grid on
			hold on
			
			xp = [rate{1}.cfg.latency(1) rate{1}.cfg.latency(2) rate{1}.cfg.latency(2) rate{1}.cfg.latency(1)];
			yp = [nanmean(sd{1}.avg) nanmean(sd{1}.avg) nanmean(sd{1}.avg) nanmean(sd{1}.avg)];
			mh = patch(xp,yp,[0.9 0.9 0.9],'FaceAlpha',0.6,'EdgeColor','none');
			set(get(get(mh,'Annotation'),'LegendInformation'),'IconDisplayStyle','off'); % Exclude line from legend
			
			c = ego.optimalColours(length(sd));
			
			blineText = sprintf('BASELINE (p=%.4g):',baseline{1}.alpha);
			for j = 1:length(baseline)
				xp = [ego.plotRange(1) ego.plotRange(2) ego.plotRange(2) ego.plotRange(1)];
				yp = [baseline{j}.CI(1) baseline{j}.CI(1) baseline{j}.CI(2) baseline{j}.CI(2)];
				me1 = patch(xp,yp,c(j,:),'FaceAlpha',0.1,'EdgeColor','none');
				set(get(get(me1,'Annotation'),'LegendInformation'),'IconDisplayStyle','off'); % Exclude line from legend
				blineText = sprintf('%s  Group:%i %.4g ± %.3g<>%.3g',blineText,j,baseline{j}.avg,baseline{j}.CI(1),baseline{j}.CI(2));
			end
			disp(blineText);
			
			t = [ego.file];
			for j = 1:length(sd)
				e = ego.var2SE(sd{j}.var,sd{j}.dof);
				areabar(sd{j}.time, sd{j}.avg, e, c(j,:)/2, 0.2, 'k.-','Color',c(j,:),'MarkerFaceColor',c(j,:),'LineWidth',1);
				leg{j,1} = ego.selectedTrials{j}.name;
				e = ego.var2SE(rate{j}.var,rate{j}.dof);
				t = [t sprintf(' R%i: %.4g ± %.3g %.3g<>%.3g', j, rate{j}.avg, e, rate{j}.CI(1), rate{j}.CI(2))];
			end
			disp([t sprintf(' | measureRange: %s', num2str(rate{1}.cfg.latency))]);
			title(t,'FontSize',14);
			xlabel(['Time (s) [window = ' sd{1}.cfg.winfunc ' ' num2str(sd{1}.cfg.timwin) '] ']);
			ylabel(['Firing Rate (s/s) \pm S.E.M.'])
			set(gcf,'Renderer','OpenGL');
			legend(leg);
			ax=axis;
			axis([ego.plotRange(1) ego.plotRange(2) ax(3) ax(4)]);
			text(ego.plotRange(1),ax(3),blineText,'FontSize',11,'VerticalAlignment','baseline');
			set(mh,'yData',[ax(3) ax(3) ax(4) ax(4)]);
			set(gca,'Layer','top');
		end
		
		% ===================================================================
		%> @brief
		%> @param
		%> @return
		% ===================================================================
		function plotPSTH(ego)
			if ~isfield(ego.results,'psth'); warning('No PSTH parsed yet.'); return; end
			psth = ego.results.psth;
			rate = ego.results.rate;
			baseline = ego.results.baseline;
			if ego.nSelection == 0; error('The selection results in no valid trials to process!'); end

			h=figure;set(h,'Color',[1 1 1],'Name',[ego.file ' ' ego.names{ego.selectedUnit}]);
			if length(psth) <4; figpos(1,[1000 1500]); else figpos(1,[2000 2000]); end
			p=panel(h);
			p.margin = [20 20 20 10]; %left bottom right top
			p.pack('v', {3/4 []})
			q = p(1);
			len = ego.nSelection;
			[row,col]=ego.optimalLayout(len);
			q.pack(row,col);
			for j = 1:length(ego.selectedTrials)
				%ft = ego.subselectFieldTripTrials(ego.ft,ego.selectedTrials{j}.idx);
				[i1,i2] = ind2sub([row,col], j);
				q(i1,i2).select();
				cfg						= [];
				cfg.trials				= ego.selectedTrials{j}.idx;
				cfg.spikechannel		= ego.names{ego.selectedUnit};
				if length(cfg.trials) < 50; cfg.spikelength = 0.7; else cfg.spikelength = 1; end
				cfg.latency				= ego.plotRange;
				cfg.linewidth			= 1;
				cfg.trialborders		= 'no';
				cfg.plotselection		= 'yes';
				%cfg.topplotfunc		= 'line'; % plot as a line
				cfg.errorbars			= 'conf95%'; % plot with the standard deviation
				cfg.interactive		= 'no'; % toggle off interactive mode
				if ego.insetRasterPlot
					cfgUsed{j}			= ft_spike_plot_raster(cfg, ego.ft, psth{j});
				else
					cfgUsed{j}			= ft_spike_plot_raster(cfg, ego.ft);
				end
				if isfield(cfgUsed{j}.hdl,'axTopPlot'); set(cfgUsed{j}.hdl.axTopPlot,'Color','none'); end
				ego.appendTrialNames(cfgUsed{j}.hdl.axRaster,cfgUsed{j}.trials);
			end
			p(2).select();
			box on; grid on
			p(2).hold('on');
			c = ego.optimalColours(length(psth));
			
			xp = [rate{1}.cfg.latency(1) rate{1}.cfg.latency(2) rate{1}.cfg.latency(2) rate{1}.cfg.latency(1)];
			yp = [nanmean(psth{1}.avg) nanmean(psth{1}.avg) nanmean(psth{1}.avg) nanmean(psth{1}.avg)];
			mh = patch(xp,yp,[0.9 0.9 0.9],'FaceAlpha',0.6,'EdgeColor','none');
			set(get(get(mh,'Annotation'),'LegendInformation'),'IconDisplayStyle','off'); % Exclude line from legend
			
			for j = 1:length(baseline)
				xp = [ego.plotRange(1) ego.plotRange(2) ego.plotRange(2) ego.plotRange(1)];
				yp = [baseline{j}.CI(1) baseline{j}.CI(1) baseline{j}.CI(2) baseline{j}.CI(2)];
				me1 = patch(xp,yp,c(j,:),'FaceAlpha',0.1,'EdgeColor','none');
				set(get(get(me1,'Annotation'),'LegendInformation'),'IconDisplayStyle','off'); % Exclude line from legend
			end
			
			t = [ego.file];
			for j = 1:length(psth)
				e = ego.var2SE(psth{j}.var,psth{j}.dof);
				areabar(psth{j}.time, psth{j}.avg, e, c(j,:)/2, 0.2, 'k.-','Color',c(j,:),'MarkerFaceColor',c(j,:),'LineWidth',1);
				leg{j,1} = ego.selectedTrials{j}.name;
				e = ego.var2SE(rate{j}.var,rate{j}.dof);
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
			axis([ego.plotRange(1) ego.plotRange(2) ax(3) ax(4)]);
			set(mh,'yData',[ax(3) ax(3) ax(4) ax(4)]);
			set(gca,'Layer','top');
		end
		
		% ===================================================================
		%> @brief
		%> @param
		%> @return
		% ===================================================================
		function plotISI(ego)
			if ~isfield(ego.results,'isi'); warning('No ISI parsed yet.'); return; end
			if ego.nSelection == 0; error('The selection results in no valid trials to process!'); end
			isi = ego.results.isi;
			len = ego.nSelection;
			h=figure;figpos(1,[1000 2000]);set(h,'Color',[1 1 1],'Name',[ego.file ' ' ego.names{ego.selectedUnit}]);
			p=panel(h);
			p.margin = [20 20 20 20]; %left bottom right top
			[row,col]=ego.optimalLayout(len);
			p.pack(row,col);
			for j = 1:length(ego.selectedTrials)
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
				p(i1,i2).title([ego.selectedTrials{j}.name ' ' ego.file]);
			end
		end
		
		% ===================================================================
		%> @brief
		%> @param
		%> @return
		% ===================================================================
		function appendTrialNames(ego,hdl,idx)
			
			axis(hdl);
			xpos = xlim;
			
			if isfield(ego.trial(idx(1)),'firstSaccade')
				st = [ego.trial(idx).firstSaccade];
				yt = 1:length(st);
				plot(st,yt,'go','MarkerFaceColor',[0 1 0],'MarkerSize',4);
			end
			
			for j = 1:length(idx)
				cs{j} = num2str(idx(j));
				y(j) = j;
				x(j) = xpos(2) + abs(((xpos(2)-xpos(1))/100));
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
		end
		
	end
end