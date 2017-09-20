classdef LFPAnalysis < analysisCore
	%> LFPAnalysis Wraps native and fieldtrip analysis around our 
	%> PLX/PL2 reading, taking our trial selection and behavioural 
	%> selection into account. As we can do spike-LFP anaysis this asks for a
	%> spike data file, it can be the same as the LFP file or different if we resorted
	%> the data.
	
	%------------------PUBLIC PROPERTIES----------%
	properties
		%> plexon file containing the LFP data
		lfpfile@char
		%> plexon file containing the spike data
		spikefile@char
		%> data directory
		dir@char
		%> remove the mean voltage offset from the individual trials?
		demeanLFP@logical = true
		%> default LFP channel
		selectedLFP@double
		%> time window around the trigger we wish to load
		LFPWindow@double = 0.8
		%> default behavioural type
		selectedBehaviour@cell = {'correct'}
		%> plot verbosity
		verbose = true
	end
	
	%------------------DEPENDENT PROPERTIES--------%
	properties (SetAccess = protected, Dependent = true)
		%> number of LFP channels
		nLFPs@double = 0
		%> selected LFP channel
		nSelection@double = 0
	end
	
	%------------------VISIBLE PROPERTIES----------%
	properties (SetAccess = {?analysisCore}, GetAccess = public)
		%> LFP plxReader object
		p@plxReader
		%> spike analysis object
		sp@spikeAnalysis
		%> trial parsed LFPs
		LFPs@struct
		%> fieldtrip structure parsed from .LFPs
		ft@struct
		%> fieldtrip parsed results
		results@struct
		%> selectedTrials: each cell is a trial list grouping
		selectedTrials@cell
		%> trials to remove in reparsing. Our raw data plot allows us to visually remove
		%> trials, we can also call fieldtrip preprocessing code too.
		cutTrials@int32
		%> variable selection map for the analysis groups
		map@cell
	end
	
	%------------------CLASS PROPERTIES----------%
	properties (SetAccess = {?analysisCore}, GetAccess = {?analysisCore})
		%> external plot destination handle (see LFPMeta for an example)
		plotDestination = [];
		%> last freq method used
		lastFrequencyMethod@char
	end
	
	%------------------HIDDEN PROPERTIES----------%
	properties (SetAccess = protected, GetAccess = public, Hidden = true)
		%> bandpass frequencies
		bpfreq@cell = {[1 4], [4 7], [7 14], [15 30], [30 50], [50 100], [1 250]}
		%> bandpass frequency names
		bpnames@cell = {'\delta','\theta','\alpha','\beta','\gamma low','\gamma high','all'}
	end
	
	%------------------PRIVATE PROPERTIES----------%
	properties (SetAccess = private, GetAccess = private)
		%> allowed properties passed to object upon construction, see parseArgs
		allowedProperties@char = 'lfpfile|spikefile|dir|demeanLFP|selectedLFP|LFPWindow|selectedBehaviour|verbose'
	end
	
	%=======================================================================
	methods %------------------PUBLIC METHODS
	%=======================================================================
		
		% ===================================================================
		%> @brief Constructor
		%>
		%> @param varargin see parseArgs for more details
		%> @return constructors return the object
		% ===================================================================
		function me = LFPAnalysis(varargin)
			if nargin == 0; varargin.name = 'LFPAnalysis';end
			me=me@analysisCore(varargin); %superclass constructor
			if nargin>0; me.parseArgs(varargin, me.allowedProperties); end
			if isempty(me.name);me.name = 'LFPAnalysis'; end
			if isempty(me.lfpfile);getFiles(me, true);end
		end
		
		% ===================================================================
		%> @brief getFiles loads the requisite files before parsing
		%>
		%> @param force force us to ask for new filenames
		%> @return
		% ===================================================================
		function getFiles(me, force)
		%getFiles loads the requisite files before parsing
			if ~exist('force','var')
				force = false;
			end
			if force == true || isempty(me.lfpfile)
				[f,p] = uigetfile({'*.plx;*.pl2';'Plexon Files'},'Load Continuous LFP File');
				if ischar(f) && ~isempty(f)
					me.lfpfile = f;
					me.name = f;
					me.dir = p;
					me.paths.oldDir = pwd;
					cd(me.dir);
					me.p = plxReader('file', me.lfpfile, 'dir', me.dir);
					me.p.name = ['PARENT:' me.uuid ' ' ];
					getFiles(me.p);
				else
					return
				end
			end
			if force == true || isempty(me.spikefile)
				f = uigetfile({'*.plx;*.pl2';'Plexon Files'},['Load Spike LFP File to match ' me.lfpfile]);
				if ischar(f) && ~isempty(f)
					me.spikefile = f;
					in = struct('file', me.spikefile, 'dir', me.dir);
					me.sp = spikeAnalysis(in);
					me.sp.name = [f ' PARENT:' me.uuid];
					in = struct('matfile', me.p.matfile, 'matdir', me.p.matdir,'edffile',me.p.edffile);
					if strcmpi(me.lfpfile, me.spikefile)
						inheritPlxReader(me.sp, me.p);
					else
						setFiles(me.sp, in);
					end
				else
					return
				end
			end
			checkPaths(me);
		end
		
		% ===================================================================
		%> @brief parse is the major first data parsing step. This performs *all* the steps
		%> from checking paths are still correct, parsing the Plexon events (our trial and
		%> behavioural data), parsing raw LFPs into the trial structures, and finally
		%> converting into a .ft fieldtrip structure.
		%>
		%> @param
		%> @return
		% ===================================================================
		function parse(me, varargin)
		%parse is the major first data parsing step
			if isempty(me.lfpfile)
				getFiles(me,true);
				if isempty(me.lfpfile);return;end
			end
			fprintf('\n<strong>:#:</strong> Parsing all LFP data from raw plexon files denovo...\n')
			checkPaths(me);
			me.yokedSelection = false;
			me.paths.oldDir = pwd;
			cd(me.dir);
			%clear our data structures
			me.LFPs = struct(); me.ft = struct(); me.results = struct(); me.panels = struct();
			me.p.eventWindow = me.LFPWindow;
			parseEvents(me.p);
			me.LFPs = readLFPs(me.p);
			parseLFPs(me);
			if ~me.openUI && me.doPlots; showInfo(me); end
			select(me);
			getFieldTripLFPs(me);
			if me.openUI
				updateUI(me);
				set(me.handles.list,'String',{['=== Data Parsed @ ' datestr(now) '===']});
			else
				plot(me,'normal');
			end
		end
		
		% ===================================================================
		%> @brief reparse data after an initial parse, takes less time.
		%>
		%> @param
		%> @return
		% ===================================================================
		function reparse(me,varargin)
			if isempty(me.lfpfile) %we obviously haven't done an initial parse
				parse(me); 
				return
			end
			checkPaths(me);
			fprintf('\n<strong>:#:</strong> Reparsing LFP data...\n')
			me.ft = struct();
			me.results = struct();
			parseEvents(me.p);
			parseLFPs(me);
			if me.doPlots; select(me); end
			getFieldTripLFPs(me);
			if me.openUI; updateUI(me); end
		end
		
		% ===================================================================
		%> @brief This only parses some data if there is no equivalent structure yet.
		%>
		%> @param
		%> @return
		% ===================================================================
		function lazyParse(me, varargin)
			if isempty(me.file)
				getFiles(me, true);
				if isempty(me.file); warning('No plexon file selected'); return; end
			end
			fprintf('\n<strong>:#:</strong> Lazy parsing LFP data (i.e. only structures that haven''t been parsed yet)...\n')
			checkPaths(me);
			me.paths.oldDir = pwd;
			cd(me.dir);
			me.p.eventWindow = me.spikeWindow;
			lazyParse(me.p);
			for i = 1:me.nUnits
				me.spike{i}.trials = me.p.tsList.tsParse{i}.trials;
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
			if me.openUI; updateUI(me); end
			fprintf('Lazy spike parsing finished...\n')
		end
		
		% ===================================================================
		%> @brief toggle between stimulus=0 and post-stimulus sccade=0 so we can align spikes
		%> and LFPs to either event
		%>
		%> @param
		%> @return
		% ===================================================================
		function toggleSaccadeRealign(me, varargin)
			if me.p.saccadeRealign == true; t = 'ENABLED';else t = 'DISABLED'; end
			fprintf(['\n<strong>:#:</strong> Saccade align state, was: ' t '\n'])
			me.p.saccadeRealign = ~me.p.saccadeRealign;
			me.sp.p.saccadeRealign = me.p.saccadeRealign;
			doPlots = me.doPlots;
			me.doPlots = false;
			me.reparse;
			me.parseSpikes;
			me.doPlots = doPlots;
			if me.p.saccadeRealign == true
				t = ['Saccade Realign ENABLED @ ' datestr(now)];
				fprintf(['\n<strong>:#:</strong> ' t '\n']);
				if me.openUI; 
					t = {' '; t; ' '};
					s=get(me.handles.list,'String');
					s = [s; t];
					set(me.handles.list,'String',s,'Value',length(s));
				end
			else
				t = ['Saccade Realign DISABLED @ ' datestr(now)];
				fprintf(['\n<strong>:#:</strong> ' t '\n']);
				if me.openUI; 
					t = {' '; t; ' '};
					s=get(me.handles.list,'String');
					s = [s; t];
					set(me.handles.list,'String',s,'Value',length(s));
				end
			end
		end
		
		% ===================================================================
		%> @brief This LFP object has a spikeAnalysis object as a property so we can use a
		%> different spike sort to the parent LFP plexon file. But we have to ensure that the
		%> spikeAnalysis is 'locked' or 'yoked' to the LFPAnalysis object settings and
		%> selection. This function makes surethis locking occurs...
		%>
		%> @param
		%> @return
		% ===================================================================
		function parseSpikes(me, varargin)
			checkPaths(me);
			fprintf('\n<strong>:#:</strong> Syncing settings and reparsing Spike data...\n')
			me.sp.p.saccadeRealign = me.p.saccadeRealign;
			in.cutTrials = me.cutTrials;
			in.selectedTrials = me.selectedTrials;
			in.map = me.map;
			in.plotRange = me.plotRange;
			in.measureRange = me.measureRange;
			in.baselineWindow = me.baselineWindow;
			in.selectedBehaviour = me.selectedBehaviour; 
			in.yokedSelection = true;
			setSelection(me.sp, in); %set spike anal to same trials etc.
			syncData(me.sp.p, me.p, 'tsList'); %copy any parsed data, exclude tsList
			lazyParse(me.sp); %lazy parse the spikes
			syncData(me.p, me.sp.p, 'tsList'); %copy any new parsed data back, exclude tsList
			if me.openUI; 
				updateUI(me.sp)
				updateUI(me);
			elseif me.doPlots
				showInfo(me.sp);
			end
		end
		
		% ===================================================================
		%> @brief As we can also select trials from the spikeanalysis object, this function
		%> allows us to let the LFPAnalysis use the spikeanalysis selection.
		%>
		%> @param
		%> @return
		% ===================================================================
		function useSpikeSelect(me,val)
			if ~exist('val','var'); val = false; end
			in = struct();
			if val == true
				in.yokedSelection = false;
				setSelection(me.sp,in);
				select(me.sp);
				in.yokedSelection = true;
				in.cutTrials = me.sp.cutTrials;
				in.selectedTrials = me.sp.selectedTrials;
				in.map = me.sp.map;
				in.plotRange = me.sp.plotRange;
				in.measureRange = me.sp.measureRange;
				in.baselineWindow = me.sp.baselineWindow;
				in.selectedBehaviour = me.sp.selectedBehaviour;
				disp('Now setting the LFP object to the spike selection...')
				setSelection(me,in);
			else
				in.yokedSelection = false;
				setSelection(me,in);
				select(me)
				in.cutTrials = me.cutTrials;
				in.selectedTrials = me.selectedTrials;
				in.map = me.map;
				in.plotRange = me.plotRange;
				in.measureRange = me.measureRange;
				in.baselineWindow = me.baselineWindow;
				in.selectedBehaviour = me.selectedBehaviour;
				in.yokedSelection = true;
				disp('Now setting the spike object to the LFP selection...')
				setSelection(me.sp, in); %set spike anal to same trials etc.
			end
		end
		
		% ===================================================================
		%> @brief Parse the Plexon plxReader LFP data (itself parsed into trials) into a fieldtrip structure, stored in
		%> the .ft property and also returned to the commandline if needed.
		%>
		%> @param
		%> @return ft fieldtrip structure
		% ===================================================================
		function ft = getFieldTripLFPs(me, varargin)
			ft_defaults;
			LFPs = me.LFPs;
			getft = tic;
			ft = struct();
			olddir=pwd; cd(me.dir);
			ft(1).hdr = ft_read_header(me.lfpfile,'headerformat','plexon_plx_v2');
			cd(olddir);
			ft.hdr.FirstTimeStamp = 0; %we use LFPs(1).sample-1 below to fake 0 start time
			ft.label = {LFPs(:).name};
			ft.time = cell(1);
			ft.trial = cell(1);
			ft.fsample = LFPs(1).recordingFrequency;
			ft.sampleinfo = [];
			ft.trialinfo = [];
			ft.cfg = struct;
			ft.cfg.dataset = me.lfpfile;
			ft.cfg.headerformat = 'plexon_plx_v2';
			ft.cfg.dataformat = ft.cfg.headerformat;
			ft.cfg.eventformat = ft.cfg.headerformat;
			ft.cfg.trl = [];
			a=1;
			if ~isfield(LFPs,'nTrials'); 
				for jj = 1:length(LFPs); LFPs(jj).nTrials = me.p.eventList.nTrials; end
			end
			for k = 1:LFPs(1).nTrials
				ft.time{a} = LFPs(1).trials(k).time';
				for i = 1:me.nLFPs
					dat(i,:) = LFPs(i).trials(k).data';
				end
				ft.trial{a} = dat;
				window = LFPs(1).trials(k).winsteps;
				ft.sampleinfo(a,1)= LFPs(1).trials(k).rawSampleStart; %faked sample numbers
				ft.sampleinfo(a,2)= LFPs(1).trials(k).rawSampleEnd;
				ft.cfg.trl(a,:) = [ft.sampleinfo(a,:) -window LFPs(1).trials(k).variable LFPs(1).trials(k).index LFPs(1).trials(k).t1];
				ft.trialinfo(a,1) = LFPs(1).trials(k).variable;
				a = a + 1;
			end
			ft.uniquetrials = unique(ft.trialinfo);
			
			fprintf('<strong>:#:</strong> Parsing into fieldtrip format took <strong>%g ms</strong>\n',round(toc(getft)*1000));
			
			if ~isempty(ft)
				me.ft = ft;
			end
		end
		
		% ===================================================================
		%> @brief Uses the Fieldtrip preprocessing functions if need be. This modifies the
		%> .ft property structure but not the raw .LFP property. To undo these changes you must
		%> use the getFieldTripLFPs() method to regenerate .ft
		%>
		%> @param cfg a fieldtrip cfg structure
		%> @param removeLineNoise a boolean to remove line noise
		%> @return
		% ===================================================================
		function ftPreProcess(me, cfg, removeLineNoise)
			if isempty(me.ft); getFieldTripLFPs(me); end
			if ~exist('removeLineNoise','var');removeLineNoise = false;end
			if ~exist('cfg','var');cfg = [];end
			if isfield(me.ft,'ftOld')
				ft = me.ft.ftOld;
			else
				ft = me.ft;
			end
			if removeLineNoise == true;
				cfg.padding = 0.2;
				cfg.dftfilter = 'yes';
				cfg.dftfreq = [80 160 240];
				disp('---> Will remove 50 100 150Hz line noise!!!')
			end
			if ~isempty(cfg)
				ftp = ft_preprocessing(cfg, ft);
				ftp.uniquetrials = unique(ftp.trialinfo);
				ftp.removeLineNoise = removeLineNoise;
			end
			cfg = [];
			cfg.method   = 'trial';
			if exist('ftp','var')
				ftNew = ft_rejectvisual(cfg, ftp);
			else
				ftNew = ft_rejectvisual(cfg, ft);
			end
			ftNew.uniquetrials = unique(ftNew.trialinfo);
			ftNew.ftOld = ft;
			me.ft = ftNew;
		end
		
		% ===================================================================
		%> @brief Performs a FieldTrip timelock analysis on our parsed data.
		%>
		%> @param
		%> @return
		% ===================================================================
		function cfg=ftTimeLockAnalysis(me, cfg, statcfg)
			if isempty(fieldnames(me.ft)); warning('Fieldtrip structure is empty, regenerating...');me.getFieldTripLFPs;end
			ft = me.ft;	
			if isfield(ft,'uniquetrials');
				ft = rmfield(ft,'uniquetrials'); %ft_timelockanalysis > ft_selectdata generates a warning as this is an unofficial field, so remove it here
			end
			if ~exist('cfg','var') || isempty(cfg); cfg = []; end
			if isnumeric(cfg) && length(cfg) == 2; w=cfg;cfg=[];cfg.covariancewindow=w; end
			if ~isfield(cfg,'covariancewindow');cfg.covariancewindow = me.measureRange;end
			if ~isfield(cfg,'keeptrials'); cfg.keeptrials = 'yes'; end
			if ~isfield(cfg,'removemean'); cfg.removemean	= 'yes'; end
			if ~isfield(cfg,'covariance'); cfg.covariance	= 'yes'; end
			cfg.channel						= ft.label{me.selectedLFP};
			me.results(1).av = [];
			if strcmp(cfg.keeptrials, 'yes')
				me.results(1).avstat = [];
				me.results(1).avstatavg = [];
			end 
			for i = 1:me.nSelection
				cfg.trials					= me.selectedTrials{i}.idx;
				av{i}							= ft_timelockanalysis(cfg, ft);
				av{i}.cfgUsed				= cfg;
				av{i}.name					= me.selectedTrials{i}.name;
				idx1							= me.findNearest(av{i}.time, me.baselineWindow(1));
				idx2							= me.findNearest(av{i}.time, me.baselineWindow(2));
				av{i}.baselineWindow		= me.baselineWindow;
				%tr = squeeze(av{i}.trial(:,:,idx1:idx2)); tr=mean(tr');
				tr = av{i}.avg(idx1:idx2);
				[av{i}.baseline, err]	= me.stderr(tr(:),'2SD');
				if length(err) == 1
					av{i}.baselineCI			= [av{i}.baseline - err, av{i}.baseline + err];
				else
					av{i}.baselineCI			= [err(1), err(2)];
				end
			end
			
			me.results(1).av = av;
			if isempty(me.options.stats); me.setStats(); end
			sv = me.options.stats;
			
			if strcmp(cfg.keeptrials, 'yes') %keeptrials was ON
				if exist('statcfg','var');	cfg					= statcfg;
				else cfg													= []; end
				cfg.channel												= ft.label{me.selectedLFP};
				if ~isfield(cfg,'latency'); cfg.latency		= me.measureRange; end
				cfg.avgovertime										= 'no'; 
				cfg.parameter											= 'trial';
				if ~isfield(cfg,'method');cfg.method			= sv.method; end %'analytic'; % 'montecarlo'
				if ~isfield(cfg,'statistic'); cfg.statistic	= sv.statistic; end %'indepsamplesT'
				if ~isfield(cfg,'alpha'); cfg.alpha				= sv.alpha; end
				cfg.numrandomization									= sv.nrand;
				cfg.resampling											= sv.resampling; %bootstrap
				cfg.tail													= sv.tail; %two tail
				cfg.correcttail										= 'prob';
				cfg.correctm											= sv.correctm; %holm fdr hochberg bonferroni
				if strcmpi(cfg.correctm,'cluster')
					if strcmpi(cfg.method,'montecarlo') %cluster only valid with monte carlo
						cfg.neighbours										= [];
						cfg.clustertail									= cfg.tail;
						cfg.clusteralpha									= 0.05;
						cfg.clusterstatistic								= 'maxsum';
					else
						warning('Switched to Bonferroni correction cluster requires monte carlo method.');
						cfg.correctm = 'bonferroni';
					end
				end
				cfg.ivar													= 1;
				cfg.design												= [ones(size(av{1}.trial,1),1); 2*ones(size(av{2}.trial,1),1)]';
				stat														= ft_timelockstatistics(cfg, av{1}, av{2});
				me.results.avstat									= stat;
				cfg.avgovertime										= 'yes'; 
				stat														= ft_timelockstatistics(cfg, av{1}, av{2});
				me.results.avstatavg								= stat;
			end
			if me.doPlots; drawTimelockLFPs(me); end
		end
		
		% ===================================================================
		%> @brief ftBandPass performs Leopold et al., 2003 type BLP
		%>
		%> @param order of BP filter to use
		%> @param downsample whether to down/resample after filtering
		%> @param rectify whether to rectify the responses
		%> @return
		% ===================================================================
		function ftBandPass(me,order,downsample,rectify)
			if ~exist('order','var') || isempty(order); order = 4; end
			if ~exist('downsample','var') || isempty(downsample); downsample = false; end
			if ~exist('rectify','var') || isempty(rectify); rectify = 'yes'; end
			if rectify == true; rectify = 'yes'; end
			
			ft = me.ft;
			results.bp = [];
			
			for j = 1:length(me.bpfreq)
				cfg						= [];
				cfg.channel				= ft.label{me.selectedLFP};
				cfg.padding				= 0;
				cfg.bpfilter			= 'yes';
				cfg.bpfilttype			= 'but';
				cfg.bpfreq				= me.bpfreq{j};
				cfg.bpfiltdir			= 'twopass'; %filter direction, 'twopass', 'onepass' or 'onepass-reverse' (default = 'twopass')
				cfg.bpfiltord			= order;
				cfg.bpinstabilityfix	= 'reduce';
				cfg.rectify				= rectify;
				cfg.demean				= 'yes'; %'no' or 'yes', whether to apply baseline correction (default = 'no')
				cfg.baselinewindow		= me.baselineWindow; %[begin end] in seconds, the default is the complete trial (default = 'all')
				cfg.detrend				= 'no'; %'no' or 'yes', remove linear trend from the data (done per trial) (default = 'no')
				cfg.derivative			= 'no'; %'no' or 'yes', computes the first order derivative of the data (default = 'no')
				disp(['===> FILTER BP = ' me.bpnames{j} ' --> ' num2str(cfg.bpfreq)]);
				disp('')
				bp{j} = ft_preprocessing(cfg,ft);
				bp{j}.freq = me.bpfreq{j};
				bp{j}.uniquetrials = unique(bp{j}.trialinfo);
				bp{j}.downsample = downsample;
				if downsample == true
					cfg						= [];
					cfg.channel				= ft.label{me.selectedLFP};
					cfg.padding				= 0;
					cfg.lpfilter			= 'yes';
					cfg.lpfreq				= 8;
					cfg.lpfilttype			= 'but';
					cfg.lpfiltdir			= 'twopass'; %filter direction, 'twopass', 'onepass' or 'onepass-reverse' (default = 'twopass')
					cfg.lpfiltord			= 8;
					cfg.lpinstabilityfix	= 'reduce';
					bp{j} = ft_preprocessing(cfg,bp{j});
					cfg						= [];
					cfg.resample			= 'yes';
					cfg.resamplefs			= 20;
					cfg.detrend				= 'no';
					disp(['===> DOWNSAMPLE = ' me.bpnames{j}]);
					bp{j} = ft_resampledata(cfg,bp{j});
					
					bp{j}.freq = me.bpfreq{j};
					bp{j}.uniquetrials = unique(bp{j}.trialinfo);
					bp{j}.downsample = downsample;
				end
				for i = 1:me.nSelection
					cfg						= [];
					cfg.keeptrials			= 'no';
					cfg.removemean			= 'no';
					cfg.covariance			= 'yes';
					cfg.covariancewindow	= [0.05 0.2];
					cfg.channel				= ft.label{me.selectedLFP};
					cfg.trials				= me.selectedTrials{i}.idx;
					bp{j}.av{i} = ft_timelockanalysis(cfg,bp{j});
					bp{j}.av{i}.cfgUsed = cfg;
					if strcmpi(cfg.covariance,'yes')
						disp(['-->> Covariance for ' me.selectedTrials{i}.name ' = ' num2str(mean(bp{j}.av{i}.cov))]);
					end
				end
			end
			me.results(1).bp = bp;
			if me.doPlots; drawBandPass(me); end
		end
		
		% ===================================================================
		%> @brief ftHilbert 
		%>
		%> @param order of BP filter to use
		%> @param downsample whether to down/resample after filtering
		%> @param rectify whether to rectify the responses
		%> @return
		% ===================================================================
		function ftHilbert(me)
			if ~exist('order','var'); order = 2; end
			if ~exist('downsample','var'); downsample = true; end
			if ~exist('rectify','var'); rectify = 'yes'; end
			if rectify == true; rectify = 'yes'; end
			
			ft = me.ft;
			results.bp = [];
			
		end
		
		% ===================================================================
		%> @brief ftBandPass performs Leopold et al., 2003 type BLP
		%>
		%> @param order of BP filter to use
		%> @param downsample whether to down/resample after filtering
		%> @param rectify whether to rectify the responses
		%> @return
		% ===================================================================
		function ftAlphaPhase(me)
			if ~exist('order','var'); order = 2; end
			if ~exist('downsample','var'); downsample = true; end
			if ~exist('rectify','var'); rectify = 'yes'; end
			if rectify == true; rectify = 'yes'; end
			
			ft = me.ft;
			results.bp = [];
			
		end
		
		% ===================================================================
		%> @brief
		%>
		%> @param
		%> @return
		% ===================================================================
		function ftFrequencyAnalysis(me, cfg, preset, tw, cycles, smth, width,toi,foi)
			if ~isfield(me.ft,'label'); getFieldTripLFPs(me); end
			if me.openUI; setTimeFreqOptions(me); end
			if ~exist('cfg','var') || isempty(cfg); cfg=[]; end
			if ~exist('preset','var') || isempty(preset); preset=me.options.method; end
			if ~exist('tw','var') || isempty(tw); tw=me.options.tw; end
			if ~exist('cycles','var') || isempty(cycles); cycles = me.options.cycles; end
			if ~exist('smth','var') || isempty(smth); smth = me.options.smth; end
			if ~exist('width','var') || isempty(width); width = me.options.width; end
			if ~exist('toi','var') || isempty(toi); toi = me.options.toi; end
			if ~exist('foi','var') || isempty(foi); foi = me.options.foi; end
			
			if isempty(me.results);me.results=struct();end
			if isfield(me.results(1),['fq' preset]);me.results(1).(['fq' preset]) = [];end
			
			ft = me.ft;
			cfgUsed = {};
			if isempty(cfg) || (length(fieldnames(cfg))==1 && isfield(cfg,'keeptrials'))
				if ~isfield(cfg,'keeptrials'); cfg.keeptrials	= 'no'; end
				cfg.output		= 'pow';
				cfg.channel		= ft.label{me.selectedLFP};
				if ischar(toi); cfg.toi=str2num(toi); else cfg.toi=toi; end % time window "slides"
				if ischar(foi); cfg.foi=str2num(foi); else cfg.foi=foi; end % analysis frequencies
				cfg.tw			= tw;
				cfg.pad			= 2;
				cfg.cycles		= cycles;
				cfg.width		= width; %'width', or number of cycles, of the wavelet (default = 7)
				cfg.smooth		= smth;
				switch preset
					case 'fix1'
						cfg.method			= 'mtmconvol';
						cfg.taper			= 'hanning';
						lf						= round(1 / cfg.tw);
						cfg.foi				= lf:min(diff(cfg.foi)):max(cfg.foi); % analysis frequencies
						fprintf('\n:#:--->>>Fixed window of %g means the minimum frequency of interest is: %g\n', cfg.tw, lf);
						cfg.t_ftimwin		= ones(length(cfg.foi),1).*tw;   % length of fixed time window
					case 'fix2'
						cfg.method			= 'mtmconvol';
						cfg.taper			= 'hanning';
						cfg.t_ftimwin		= cfg.cycles./cfg.foi;			 % x cycles per time window
					case 'mtm1'
						cfg.method			= 'mtmconvol';
						cfg.taper			= 'dpss';
						cfg.tapsmofrq		= cfg.foi .* cfg.smooth;
						cfg.t_ftimwin		= cfg.cycles./cfg.foi;			 % x cycles per time window
					case 'mtm2'
						cfg.method			= 'mtmconvol';
						cfg.taper			= 'dpss';
						cfg.tapsmofrq		= ones(size(cfg.foi)) .* cfg.smooth;
						cfg.t_ftimwin		= cfg.cycles./cfg.foi;			 % x cycles per time window
					case 'morlet'
						cfg.method			= 'wavelet';
						cfg.taper			= '';
						cfg.width			= cfg.width; %'width', or number of cycles, of the wavelet (default = 7)
					case 'tfr'
						cfg.foilim			= [min(cfg.foi) max(cfg.foi)];
						cfg = rmfield(cfg,'foi');
						cfg.method			= 'tfr';
						cfg.taper			= '';
						cfg.width			= cfg.width; %'width', or number of cycles, of the wavelet (default = 7)
				end
			elseif ~isempty(cfg)
				preset = 'custom';
			end
			for i = 1:me.nSelection
				cfg.trials = me.selectedTrials{i}.idx;
				if isfield(ft,'uniquetrials')
					ut = ft.uniquetrials;
					ft = rmfield(ft,'uniquetrials');
				end
				fq{i} = ft_freqanalysis(cfg,ft);
				fq{i}.cfgUsed=cfg;
				fq{i}.name = me.selectedTrials{i}.name;
				if exist('ut','var'); fq{i}.uniquetrials = ut; end
			end
			me.lastFrequencyMethod = ['fq' preset];
			me.results(1).(me.lastFrequencyMethod) = fq;
			if me.doPlots
				plot(me,'freq',me.lastFrequencyMethod);
			end
			clear fq ut ft;
			%ftFrequencyStats(me, ['fq' preset],{'no','relative','absolute','db'});
		end
		
		% ===================================================================
		%> @brief
		%>
		%> @param
		%> @return
		% ===================================================================
		function ftFrequencyStats(me,name,bline,range)
			if ~exist('name','var') || isempty('name');
				if ~isempty(me.lastFrequencyMethod)
					name = me.lastFrequencyMethod;
				else
					name='fqfix1'; %default method
				end
			end
			if me.openUI; setTimeFreqOptions(me); end
			if ~exist('bline','var') || isempty(bline);bline=me.options.bline;end
			if ~exist('range','var') || isempty(range);range=me.measureRange;end
			if ~isfield(me.results,name)
				fprintf('\nCan''t find %s results; ',name)
				if isfield(me.results,'fqfix1'); name = 'fqfix1';
				elseif isfield(me.results,'fqmtm1'); name = 'fqmtm1';
				elseif isfield(me.results,'fqmorlet'); name = 'fqmorlet';
				else return;
				end
				fprintf('using %s frequency analysis instead.\n',name)
			end
			ft = me.ft;
			fq = me.results.(name);

			if ~iscell(bline)
				bline = cellstr(bline);
			end
			
			for jj = 1:length(bline)
				thisbline = bline{jj};
				if ~strcmpi(thisbline,'no')
					cfg.baseline		= me.baselineWindow;
					cfg.baselinetype	= thisbline;
					for i=1:length(fq)
						if isfield(fq{i},'name')
							tname			= fq{i}.name;
						else
							tname			= num2str(i);
						end
						fqb{i}			= ft_freqbaseline(cfg,fq{i});
						fqb{i}.name		= tname;
						fqb{i}.blname	= [cfg.baselinetype ':' num2str(cfg.baseline)];
						fqb{i}.blname	= regexprep(fqb{i}.blname,' +',' ');
					end
				else
					for i=1:length(fq)
						fqb{i} = fq{i};
						fqb{i}.blname = 'no';
					end
				end

				cfgd						= [];
				cfgd.variance			= 'yes';
				cfgd.jackknife			= 'yes';
				cfgd.channel			= ft.label{me.selectedLFP};
				cfgd.foilim				= 'all';
				cfgd.toilim				= me.baselineWindow;
				stat = cell(size(fqb));
				for i = 1:length(fqb)
					stat{i}				= ft_freqdescriptives(cfgd,fqb{i});
					if isfield(fqb{i},'name')
						stat{i}.name		= fqb{i}.name;
					else
						stat{i}.name	= num2str(i);
					end
					stat{i}.blname		= fqb{i}.blname;
					stat{i}.toilim		= cfgd.toilim;
				end
				me.results.([name 'bline']) = stat;

				cfgd.toilim				= range;
				stat = cell(size(fqb));
				for i = 1:length(fqb)
					stat{i}				= ft_freqdescriptives(cfgd,fqb{i});
					if isfield(fqb{i},'name')
						stat{i}.name		= fqb{i}.name;
					else
						stat{i}.name	= num2str(i);
					end
					stat{i}.blname		= fqb{i}.blname;
					stat{i}.toilim		= cfgd.toilim;
				end
				me.results.([name 'response']) = stat;
				if isempty(me.options.stats); me.setStats(); end
				sv								= me.options.stats;
				cfg							= [];
				cfg.channel					= fq{1}.cfgUsed.channel;
				cfg.latency					= range;
				cfg.frequency				= 'all';
				cfg.avgoverchan			= 'no';
				cfg.avgovertime			= 'no';
				cfg.avgoverfreq			= 'no';
				cfg.parameter				= 'powspctrm';
				cfg.method					= sv.method;
				cfg.statistic				= sv.statistic;
				cfg.alpha					= sv.alpha; 
				cfg.numrandomization		= sv.nrand;
				cfg.resampling				= sv.resampling; %bootstrap
				cfg.tail						= sv.tail; %two tail
				cfg.correcttail			= 'prob';
				cfg.correctm				= sv.correctm; %holm fdr hochberg bonferroni
				if strcmpi(cfg.correctm,'cluster')
					cfg.neighbours			= [];
					cfg.clustertail		= 0;
					cfg.clusteralpha		= 0.05;
					cfg.clusterstatistic = 'maxsum';
				end
				cfg.design					= [ones(size(fq{1}.trialinfo,1),1); 2*ones(size(fq{2}.trialinfo,1),1)]';
				cfg.ivar = 1;
				
				stat							= ft_freqstatistics(cfg,fqb{1},fqb{2});
				stat.blname					= fqb{1}.blname;
				me.results.([name 'statall']) = stat;
				
				clear stat statl
				
				freq							= me.bpfreq(1:end-1);
				fnames						= me.bpnames(1:end-1);
				if isfield(me.options.stats,'customFreq')
					freq{end+1}				= me.options.stats.customFreq;
					fnames{end+1}			= 'custom';
				end
				a = 1;
				for k = 1:length(freq)
					cfg.frequency			= freq{k};
					cfg.correctm			= sv.correctm; %holm fdr hochberg bonferroni
					cfg.avgovertime		= 'yes';
					cfg.avgoverfreq		= 'yes';
					try
						stat(a)					= ft_freqstatistics(cfg,fqb{1},fqb{2});
						statl(a).blname		= fqb{1}.blname;
						statl(a).freq			= cfg.frequency;
						t							= num2str(statl(a).freq); t = regexprep(t,'\s+',' ');
						statl(a).name			= [fnames{k} ':' t];
						statl(a).alpha			= cfg.alpha;
						a = a + 1;
					catch
						disp(['Stats failed for ' fnames{k}]);
					end
				end
				fn=fieldnames(statl);
				for k = 1:length(stat)
					for l=1:length(fn)
						stat(k).(fn{l}) = statl(k).(fn{l});
					end
				end
				
				me.results.([name 'statf']) = stat;
				
				me.drawLFPFrequencyStats(name);
			end
		end
		
		% ===================================================================
		%> @brief
		%>
		%> @param
		%> @return
		% ===================================================================
		function cfgUsed=ftSpikeLFP(me, unit, interpolate)
			sv = me.options.stats;
			if ~exist('unit','var') || isempty(unit); unit = me.sp.selectedUnit;
			else me.sp.selectedUnit = unit; end
			if ~exist('interpolate','var'); 
				interpolate = true; iMethod = sv.interp;
			elseif ischar(interpolate)
				iMethod = interpolate; interpolate = true;
			end
			if isempty(me.sp.ft)
				plotTogether(me); drawnow;
			end
			if strcmpi(iMethod,'no');interpolate = false;end
			
			in.yokedSelection				= true;
			in.cutTrials					= me.cutTrials;
			in.selectedTrials				= me.selectedTrials;
			in.map							= me.map;
			in.plotRange					= me.plotRange;
			in.selectedBehaviour			= me.selectedBehaviour;
			setSelection(me.sp, in); %set spike analysis object to use same trials and settings as the LFP analysis
			
			ft									= me.ft; %fieldtrip structure for LFP
			spike								= me.sp.ft; %fieldtrip structure for spikes
			dat								= ft_appendspike([],ft, spike); %append the data together
			
			if ~strcmpi(iMethod,'no') || interpolate
				try
					cfg					= [];
					cfg.method			= iMethod; % remove the replaced segment with interpolation
					cfg.timwin			= sv.interpw; % remove X ms around every spike
					cfg.interptoi		= 0.1;
					cfg.spikechannel	= spike.label{unit};
					cfg.channel			= ft.label;
					dati					= ft_spiketriggeredinterpolation(cfg, dat);
				catch ME
					dati=dat;
					warndlg('Spike Interpolation of LFP failed, using raw data');
					disp(getReport(ME,'extended'));
					pause(1);
				end
			else
				dati=dat;
			end
			
			me.results.staPre			= cell(1,me.nSelection);
			me.results.staPost		= cell(1,me.nSelection);
			me.results.stsFFT			= cell(1,me.nSelection);
			me.results.stsConvol		= cell(1,me.nSelection);
			me.results.statSts0		= cell(1,me.nSelection);
			me.results.statSts1		= cell(1,me.nSelection);
			me.results.statSts2		= cell(1,me.nSelection);
			me.results.statSts3		= cell(1,me.nSelection);
			me.results.statSts4		= cell(1,me.nSelection);
			me.results.statSts5		= cell(1,me.nSelection);
			me.results.statStsW		= cell(1,me.nSelection);
			
			cycles						= me.options.stats.spikelfptaperopt(1);
			smooth						= me.options.stats.spikelfptaperopt(2);
			taper							= me.options.stats.spikelfptaper;
			for j = 1:length(me.selectedTrials)
				name				= [spike.label{unit} ' | ' me.selectedTrials{j}.name];
				tempspike		= me.subselectFieldTripTrials(spike,me.selectedTrials{j}.idx);
				tempdat			= me.subselectFieldTripTrials(dati,me.selectedTrials{j}.idx);
				
				%-------------------------STA-----------------------
				cfg									= [];
				cfg.timwin							= [-0.1 0.1]; 
				cfg.spikechannel					= spike.label{unit};
				cfg.channel							= ft.label;
				cfg.latency							= [-0.25 -0.05];
				cfg.keeptrials						= 'yes';
				staPre								= ft_spiketriggeredaverage(cfg, tempdat);
				me.results(1).staPre{j}			= staPre;
				me.results.staPre{j}.name		= [name ':' num2str(cfg.latency)];
				cfg.latency							= me.measureRange;
				staPost								= ft_spiketriggeredaverage(cfg, tempdat);
				me.results.staPost{j}			= staPost;
				me.results.staPost{j}.name		= [name ':' num2str(cfg.latency)];
				
				%--------------------------FFT METHOD-----------------------
				cfg									= [];
				cfg.method							= 'mtmfft';
				cfg.latency							= me.measureRange;
				cfg.foilim							= [6 100]; % cfg.timwin determines spacing [begin end], time around each spike (default = [-0.1 0.1])
				cfg.timwin							= [-0.1 0.1]; %[begin end], time around each spike (default = [-0.1 0.1])
				cfg.tapsmofrq						= 3; %the amount of spectral smoothing through multi-tapering. Note that 4 Hz smoothing means plus-minus 4 Hz,i.e. a 8 Hz smoothing box. Note: multitapering rotates phases (no problem for consistency)
				cfg.rejectsaturation				= 'no';
				cfg.taper							= taper;
				cfg.spikechannel					= spike.label{unit};
				cfg.channel							= ft.label{me.selectedLFP};
				stsFFT								= ft_spiketriggeredspectrum(cfg, tempdat, tempspike);
				ang									= squeeze(angle(stsFFT.fourierspctrm{1}));
				mag									= squeeze(abs(stsFFT.fourierspctrm{1}));
				me.results.stsFFT{j}				= stsFFT;
				me.results.stsFFT{j}.name		= name;
				me.results.stsFFT{j}.ang		= ang;
				me.results.stsFFT{j}.mag		= mag;
				clear stsFFT ang mag
				
				%--------------------------CONVOL METHOD-----------------------
				cfg									= [];
				cfg.method							= 'mtmconvol';
				%cfg.latency							= me.measureRange;
				cfg.foi								= 6:4:100; %vector 1 x numfoi, frequencies of interest
				cfg.tapsmofrq						= cfg.foi * smooth; %the amount of spectral smoothing through multi-tapering. Note that 4 Hz smoothing means plus-minus 4 Hz,i.e. a 8 Hz smoothing box. Note: multitapering rotates phases (no problem for consistency)
				cfg.t_ftimwin						= cycles ./ cfg.foi; % vector 1 x numfoi, length of time window (in seconds)
				cfg.rejectsaturation				= 'no';
				cfg.borderspikes					= 'yes';
				cfg.taper							= taper;
				cfg.spikechannel					= spike.label{unit};
				cfg.channel							= ft.label{me.selectedLFP};
				stsConvol							= ft_spiketriggeredspectrum(cfg, tempdat, tempspike);
				
				ang									= squeeze(angle(stsConvol.fourierspctrm{1}));
				mag									= squeeze(abs(stsConvol.fourierspctrm{1}));
				me.results.stsConvol{j}			= stsConvol;
				me.results.stsConvol{j}.name	= name;
				me.results.stsConvol{j}.ang	= ang;
				me.results.stsConvol{j}.mag	= mag;
				clear stsConvol ang mag
				
				cfg.latency							= []; %we now reset just in case stat is affected by this
				stsConvol							= ft_spiketriggeredspectrum(cfg, tempdat, tempspike);
				
				%--------------------------STATISTICS-----------------------
				cfg									= [];
				cfg.method							= 'ppc0'; % compute the Pairwise Phase Consistency
				cfg.spikechannel					= spike.label{unit};
				cfg.channel							= ft.label{me.selectedLFP};
				cfg.spikesel						= 'all';
				cfg.avgoverchan					= 'unweighted';
				cfg.timwin							= 'all'; % compute over all available spikes in the window
				cfg.latency							= me.measureRange; % sustained visual stimulation period
				statSts								= ft_spiketriggeredspectrum_stat(cfg,stsConvol);
				me.results.statSts0{j}			= statSts;
				me.results.statSts0{j}.name	= name;
				
				cfg									= [];
				cfg.method							= 'ppc1'; % compute the Pairwise Phase Consistency
				cfg.spikechannel					= spike.label{unit};
				cfg.channel							= ft.label{me.selectedLFP};
				cfg.spikesel						= 'all';
				cfg.avgoverchan					= 'unweighted'; % weight spike-LFP phases irrespective of LFP power
				cfg.timwin							= 'all'; % compute over all available spikes in the window
				cfg.latency							= me.measureRange; % sustained visual stimulation period
				statSts								= ft_spiketriggeredspectrum_stat(cfg,stsConvol);
				me.results.statSts1{j}			= statSts;
				me.results.statSts1{j}.name	= name;
				
				cfg									= [];
				cfg.method							= 'ppc2'; % compute the Pairwise Phase Consistency
				cfg.spikechannel					= spike.label{unit};
				cfg.spikesel						= 'all';
				cfg.channel							= ft.label{me.selectedLFP};
				cfg.avgoverchan					= 'unweighted'; % weight spike-LFP phases irrespective of LFP power
				cfg.timwin							= 'all'; % compute over all available spikes in the window
				cfg.latency							= me.measureRange; % sustained visual stimulation period
				statSts								= ft_spiketriggeredspectrum_stat(cfg,stsConvol);
				me.results.statSts2{j}			= statSts;
				me.results.statSts2{j}.name	= name;
				
				cfg									= [];
				cfg.method							= 'plv'; % compute the Pairwise Phase Consistency
				cfg.spikechannel					= spike.label{unit};
				cfg.spikesel						= 'all';
				cfg.channel							= ft.label{me.selectedLFP};
				cfg.avgoverchan					= 'unweighted'; % weight spike-LFP phases irrespective of LFP power
				cfg.timwin							= 'all'; % compute over all available spikes in the window
				cfg.latency							= me.measureRange; % sustained visual stimulation period
				statSts								= ft_spiketriggeredspectrum_stat(cfg,stsConvol);
				me.results.statSts3{j}			= statSts;
				me.results.statSts3{j}.name	= name;
				
				cfg									= [];
				cfg.method							= 'ral'; % compute the Pairwise Phase Consistency
				cfg.spikechannel					= spike.label{unit};
				cfg.spikesel						= 'all';
				cfg.channel							= ft.label{me.selectedLFP};
				cfg.avgoverchan					= 'unweighted'; % weight spike-LFP phases irrespective of LFP power
				cfg.timwin							= 'all'; % compute over all available spikes in the window
				cfg.latency							= me.measureRange; % sustained visual stimulation period
				statSts								= ft_spiketriggeredspectrum_stat(cfg,stsConvol);
				me.results.statSts4{j}			= statSts;
				me.results.statSts4{j}.name	= name;
				
				cfg									= [];
				cfg.method							= 'ang'; % compute the Pairwise Phase Consistency
				cfg.spikechannel					= spike.label{unit};
				cfg.spikesel						= 'all';
				cfg.channel							= ft.label{me.selectedLFP};
				cfg.avgoverchan					= 'unweighted'; % weight spike-LFP phases irrespective of LFP power
				cfg.timwin							= 'all'; % compute over all available spikes in the window
				cfg.latency							= me.measureRange; % sustained visual stimulation period
				statSts								= ft_spiketriggeredspectrum_stat(cfg,stsConvol);
				me.results.statSts5{j}			= statSts;
				me.results.statSts5{j}.name	= name;
				
				cfg									= [];
				cfg.method							= 'ppc0'; % compute the Pairwise Phase Consistency
				cfg.spikechannel					= spike.label{unit};
				cfg.channel							= ft.label{me.selectedLFP};
				cfg.spikesel						= 'all';
				cfg.avgoverchan					= 'unweighted';
				cfg.timwin							= me.options.stats.spikelfppcw(1); 
				cfg. winstepsize					= me.options.stats.spikelfppcw(2);
				cfg.latency							= [-0.3 0.3];
				statSts								= ft_spiketriggeredspectrum_stat(cfg,stsConvol);
				me.results.statStsW{j}			= statSts;
				me.results.statStsW{j}.name	= name;
				me.results.statStsW{j}.times	= [cfg.latency(1):cfg. winstepsize:cfg.latency(2)-cfg. winstepsize];
				clear statSts
			end
			if me.doPlots; drawSpikeLFP(me); end
		end
		
		% ===================================================================
		%> @brief
		%>
		%> @param
		%> @return
		% ===================================================================
		function plotTogether(me,varargin)
			if ~exist('varargin','var') || isempty(varargin) || ~isnumeric(varargin); unit = me.sp.selectedUnit; end
			me.sp.selectedUnit = unit;
			
			if isempty(me.ft)
				dp = me.doPlots; me.doPlots = false;
				parse(me);
				me.doPlots = dp;
			end
			if isempty(me.sp.ft)
				parseSpikes(me);
			end
			
			in.yokedSelection			= true;
			in.cutTrials				= me.cutTrials;
			in.selectedTrials			= me.selectedTrials;
			in.map						= me.map;
			in.plotRange				= me.plotRange;
			in.measureRange			= me.measureRange;
			in.baselineWindow			= me.baselineWindow;
			in.selectedBehaviour		= me.selectedBehaviour;
			setSelection(me.sp, in); %set spike anal to same trials etc
			
			ft_defaults
			me.sp.density;
			
			h=figure;figpos(1,[1000 1500]);set(h,'Color',[1 1 1],'NumberTitle','off',...
				'Name',['Co-Plot ' me.lfpfile '+' me.spikefile ' > LFP: ' me.LFPs(me.selectedLFP).name ' | Unit: ' me.sp.names{me.sp.selectedUnit}]);
			p=panel(h);
			p.margin = [25 20 20 20]; %left bottom right top
			[row,col]=me.optimalLayout(me.nSelection);
			p.pack(row,col);
			mxF = 1;
			for j = 1:length(me.selectedTrials)
				[i1,i2] = ind2sub([row,col], j);
				p(i1,i2).select();
				t = ['LFP: ' me.LFPs(me.selectedLFP).name ' | Unit: ' me.sp.names{me.sp.selectedUnit} ' | Sel:' me.selectedTrials{j}.name];
				[time,av,er]=getAverageTuningCurve(me,me.selectedTrials{j}.idx, me.selectedLFP);
				h1 = me.areabar(time,av,er,[],[],'k-');
				axis(h1.axis,[me.plotRange(1) me.plotRange(2) -inf inf]);
				ylabel(h1.axis,'Voltage (mV)');
				xlabel(h1.axis,'Time (s)');
				box(h1.axis,'off');
				set(h1.axis,'XColor','k','YColor','k','XGrid','on','XMinorGrid','on','Layer','bottom');
				h1_pos = get(h1.axis,'Position'); % store position of first axes
				h2.axis = axes('Position',h1_pos,...
					'XAxisLocation','top',...
					'YAxisLocation','right',...
					'Color','none');
				fax(j) = h2.axis;
				set(h2.axis,'XColor','k','YColor','k','XTickLabel',{});
				axis(h2.axis);
				hold(h2.axis,'on');
				
				time2 = me.sp.results.sd{j}.time;
				av2 = me.sp.results.sd{j}.avg;
				mxF = max([mxF (max(av2))]);
				er2 = me.var2SE(me.sp.results.sd{j}.var,me.sp.results.sd{j}.dof);
				h=me.areabar(time2,av2,er2,[0.7 0.5 0.5],[],'r.-');
				h2.axish = h;
				axis(h2.axis,[me.plotRange(1) me.plotRange(2) -inf inf]);
				ylabel(h2.axis,'Firing Rate (Hz)');
				box(h2.axis,'off')
				p(i1,i2).title(t);
			end
			for j = 1:length(me.selectedTrials)
				fax(j).YLim = [0 ceil(mxF+(mxF/10))];
			end
			
		end
		
		% ===================================================================
		%> @brief
		%>
		%> @param
		%> @return
		% ===================================================================
		function plot(me, varargin)
			if isempty(me.LFPs) || (me.doPlots == false && isempty(me.plotDestination))
				disp('Nothing parsed or doPlots is false, no plotting performed...')
				return
			end
			if isempty(varargin)
				sel = 'normal';
			elseif isa(varargin{1},'matlab.ui.control.UIControl') %callback from the GUI
				if length(varargin)==3 %with an additional callback item
					sel = varargin{3};
				else
					sel = 'normal';
				end
			elseif ischar(varargin{1})
				sel = varargin{1};
			else
				sel = 'normal';
			end
			
			if length(varargin) > 1
				args = varargin(2:end);
			else
				args = {};
			end
			
			switch lower(sel)
				case {'n', 'normal'}
					me.drawTrialLFPs();
					me.drawAverageLFPs();
				case 'all'
					me.drawContinuousLFPs();
					me.drawTrialLFPs();
					me.drawAverageLFPs();
				case {'cont','continuous'}
					me.drawContinuousLFPs();
				case {'trials','raw'}
					me.drawTrialLFPs();
				case {'av','average'}
					me.drawAverageLFPs();
				case {'timelock','tlock','tl'}
					me.drawTimelockLFPs();
				case {'freq','frequency','f','power'}
					me.drawLFPFrequencies(args(:));
				case {'bp','bandpass'}
					me.drawBandPass();
				case {'s', 'slfp', 'spikelfp'}
					me.drawSpikeLFP();
				case {'pt', 'both', 'together'}
					me.plotTogether();
				case {'freqstats','fstats','fstat','fs'}
					me.drawLFPFrequencyStats();
				otherwise
					disp('Didn''t recognise draw method, try: normal, all, continuous, raw, average, timelock, freq, bandpass, spikelfp, fstats etc...')
			end
		end
		
		% ===================================================================
		%> @brief
		%> @param
		%> @return
		% ===================================================================
		function nLFPs = get.nLFPs(me)
			nLFPs = 0;
			if ~isempty(me.LFPs)
				nLFPs = length(me.LFPs);
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
			else
				me.selectTrials();
				nSelection = length(me.selectedTrials);
			end
		end
		
		% ===================================================================
		%> @brief saves this object as a MAT file, object renamed to 'lfp'
		%> @param
		%> @return
		% ===================================================================
		function save(me, varargin)
			fprintf('<strong>:#:</strong> Saving LFPAnalysis object: ...\t');
			[~,f,~] = fileparts(me.lfpfile);
			name = ['LFP' f];
			if ~isempty(me.ft)
				name = [name '-ft'];
			end
			if isfield(me.results,'bp')
				name = [name '-BP'];
			end
			if isfield(me.results,'av')
				name = [name '-TL'];
			end
			if isfield(me.results,'staPre')
				name = [name '-SP'];
			end
				name = [name '.mat'];
			[f,p] = uiputfile(name,'SAVE LFP Analysis File');
			stic = tic;
			if ischar(f) && ~isempty(f)
				od = pwd;
				cd(p);
				lfp = me;
				optimiseSize(lfp.p);
				optimiseSize(lfp.sp.p);
				save(f,'lfp');
				cd(od);
			end
			fprintf('... took <strong>%g ms</strong>\n',round(toc(stic)*1000));
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
			if force == true; me.yokedSelection = false; end
			if me.yokedSelection == true;
				if me.openUI
					warndlg('This LFPAnalysis object is currently locked, force parse or run select(true) to override lock...'); return
				else
					warning('This LFPAnalysis object is currently locked, force parse or run select(true) to override lock...'); return
				end
			end
			if me.nLFPs<1; warningdlg('Data not parsed yet...');return;end
			cuttrials = '[ ';
			if ~isempty(me.cutTrials)
				if iscellstr(me.cutTrials)
					me.cutTrials = int32(me.cellArray2Num(me.cutTrials));
				end
				cuttrials = [cuttrials num2str(me.cutTrials)];
			elseif ~isempty(me.cutTrials)
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
			
			lfp = 'p';
			for i = 1:me.nLFPs
				if i == me.selectedLFP
					lfp = [lfp '|�' me.LFPs(i).name];
				else
					lfp = [lfp '|' me.LFPs(i).name];
				end
			end
			
			spk = 'p';
			if isempty(me.sp) || me.sp.nUnits == 0
				spk = [spk '|No units'];
			else
				for i = 1:me.sp.nUnits
					if i == me.sp.selectedUnit
						spk = [spk '|�' me.sp.names{i}];
					else
						spk = [spk '|'  me.sp.names{i}];
					end
				end
			end
			
			inbeh = {'correct','breakFix','incorrect','all'};
			beh = 'r';
			if ischar(me.selectedBehaviour)
				t = me.selectedBehaviour;
				me.selectedBehaviour = cell(1);
				me.selectedBehaviour{1} = t;
			end
			for i = 1:length(inbeh)
				if strcmpi(inbeh{i}, me.selectedBehaviour{1})
					beh = [beh '|�' inbeh{i}];
				else
					beh = [beh '|' inbeh{i}];
				end
			end
			
			mrange = me.measureRange;
			pr = num2str(me.plotRange);
			bl = num2str(me.baselineWindow);
			comment = me.comment;
			me.selectedBehaviour = {};
			
			mtitle   = [me.lfpfile ': REPARSE ' num2str(me.LFPs(1).nVars) ' VARS'];
			options  = {['t|' map{1}],'Choose PLX variables to merge (A, if empty parse all variables independantly):';   ...
				['t|' map{2}],'Choose PLX variables to merge (B):';   ...
				['t|' map{3}],'Choose PLX variables to merge (C):';   ...
				['t|' cuttrials],'Enter Trials to exclude:';   ...
				[lfp],'Choose LFP Channel to View:';...
				[spk],'Choose Spike Unit:';...
				[beh],'Behavioural type (''correct'', ''breakFix'', ''incorrect'' | ''all''):';...
				['t|' num2str(mrange)],'Measurement Range (s) for Statistical Comparisons:';...
				['t|' num2str(pr)],'Plot Range (s):';...
				['t|' num2str(bl)],'Baseline Window (s; default [-0.2 0]):';...
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
					me.selectedBehaviour{1} = inbeh{answer{7}};
				end
				me.map{1} = str2num(answer{1});
				
				re = regexpi(answer{2},'^[CBI]','once');
				if ~isempty(re)
					me.selectedBehaviour{2} = answer{2}(1);
					answer{2} = answer{2}(2:end);
				else
					me.selectedBehaviour{2} = inbeh{answer{7}};
				end
				me.map{2} = str2num(answer{2});
				
				re = regexpi(answer{3},'^[CBI]','once');
				if ~isempty(re)
					me.selectedBehaviour{3} = answer{3}(1);
					answer{3} = answer{3}(2:end);
				else
					me.selectedBehaviour{3} = inbeh{answer{7}};
				end
				me.map{3} = str2num(answer{3}); 
				
				me.cutTrials = int32(str2num(answer{4}));
				me.cutTrials = sort(unique(me.cutTrials));
				me.selectedLFP = answer{5};
				if ~isempty(me.sp) 
					if me.sp.nUnits > 0
						me.sp.selectedUnit = answer{6};
					end
				end
				me.measureRange = str2num(answer{8});
				me.plotRange = str2num(answer{9});
				me.baselineWindow = str2num(answer{10});
				me.comment = answer{11};
				selectTrials(me);
			end
		end
		
		
		% ===================================================================
		%> @brief replaces the LFP signals with a noisy surrogate to test, you can change the
		%> surrogate parameters in the code, including randomising phase and having a
		%> timelocked burst of a particular frequency to test time frequency algorithms etc.
		%>
		%> @param
		%> @return
		% ===================================================================
		function createSurrogate(me, varargin)
			me.getFieldTripLFPs(); %reset ft to real data
			ft = me.ft;
			f = ft.fsample; %f is the frequency, normally 1000 for LFPs
			nCh = length(ft.label); %number of channels
			
			tmult = (length(ft.time{1})-1) / f; 

			randPhaseRange			= 2*pi; %how much to randomise phase?
			rphase					= 0; %default phase
			basef						= 5; % base frequency
			onsetf					= 10; %an onset at 0 frequency
			onsetDivisor			= 0.5; %scale the onset frequency
			burstf					= 30; %small burst frequency
			burstOnset				= 0.1; %time of onset of burst freq
			burstLength				= 0.2; %length of burst
			powerDivisor			= 2; %how much to attenuate the secondary frequencies
			group2Divisor			= 1; %do we use a diff divisor for group 2?
			noiseDivisor			= 0.4; %scale noise to signal
			
			options = {['t|' num2str(randPhaseRange)], 'Random phase range in radians?';...
				['t|' num2str(rphase)], 'Default phase?';...
				['t|' num2str(basef)], 'Base Frequency (Hz)';...
				['t|' num2str(onsetf)], 'Onset (time=0) Frequency (Hz)';...
				['t|' num2str(onsetDivisor)], 'Onset F Power Divisor';...
				['t|' num2str(burstf)], 'Burst Frequency (Hz)';...
				['t|' num2str(burstOnset)], 'Burst Onset Time (s)';...
				['t|' num2str(burstLength)], 'Burst Length (s)';...
				['t|' num2str(powerDivisor)], 'Burst Power Divisor';...
				['t|' num2str(group2Divisor)], 'Burst Power Divisor for Group 2';...
				['t|' num2str(noiseDivisor)], 'Noise Divisor';...
				};
			answer = menuN('Select Surrogate options:',options);
			drawnow;
			if iscell(answer) && ~isempty(answer)
				randPhaseRange = eval(answer{1});
				rphase = str2num(answer{2});
				basef = str2num(answer{3});
				onsetf = str2num(answer{4});
				onsetDivisor = str2num(answer{5});
				burstf = str2num(answer{6});
				burstOnset = str2num(answer{7});
				burstLength = str2num(answer{8});
				powerDivisor = str2num(answer{9});
				group2Divisor = str2num(answer{10});
				noiseDivisor = str2num(answer{11});
			end
			
			piMult					= basef * 2; %resultant pi multiplier
			burstMult				= burstf * 2; %resultant pi multiplier
			onsetMult				= onsetf * 2; %onset multiplier
			
			fprintf('\n\nSurrogate Data:\nRandom Phase Range (pi=%.3g) = %.3g\nBase F \t\t\t\t= %i\nBurst F (starts at %.2g secs) \t= %i\nOnset F (starts at 0 time) \t= %i\nGeneral Divisor \t\t= %i\nGroup 2 Burst F Divisor \t= %i\nNoise Divisor \t\t= %.3g\n\n',...
				pi,randPhaseRange,basef,burstOnset,burstf,onsetf,powerDivisor,group2Divisor,noiseDivisor);
			
			
			for j = 1:length(ft.trial)
				time = ft.time{j};
				for k = 1:nCh
					mx = max(ft.trial{j}(k,:));
					mn = min(ft.trial{j}(k,:));
					rn = mx - mn;
					y = makeSurrogate();
					y = y * rn; % scale to the voltage range of the original trial
					y = y + mn;
					ft.trial{j}(k,:) = y;
				end
			end
			
			plotSurrogates();
			
			me.ft = ft;
			
			function y = makeSurrogate()
				rphase = rand * randPhaseRange;
				%base frequency
				y = sin((0 : (pi*piMult)/f : (pi*piMult) * tmult)+rphase)';
				y = y(1:length(time));
				%burst frequency with different power in group 2 if present
				rphase = rand * randPhaseRange;
				yy = sin((0 : (pi*burstMult)/f : (pi*burstMult) * burstLength)+rphase)';
				if me.nSelection > 1 && ismember(j,me.selectedTrials{2}.idx)
					yy = yy ./ group2Divisor;
				else
					yy = yy ./ powerDivisor;
				end
				%intermediate onset frequency
				rphase = rand * randPhaseRange;
				yyy = sin((0 : (pi*onsetMult)/f : (pi*onsetMult) * 0.4)+rphase)';
				yyy = yyy ./ onsetDivisor;
				%find our times to inject yy burst frequency
				st = me.findNearest(time,burstOnset);
				en = me.findNearest(time,burstOnset+burstLength);
				y(st:en) = y(st:en) + yy;
				%add our fixed 0.4s intermediate onset freq
				y(801:1201) = y(801:1201) + yyy;
				%add our noise
				y = y + ((rand(size(y))-0.5)./noiseDivisor);
				%normalise our surrogate to be 0-1 range
				y = y - min(y); y = y / max(y); % 0 - 1 range;
				%make sure we are a column vector
				if size(y,2) < size(y,1); y = y'; end
			end
			
			function plotSurrogates()
				h=figure;figpos(1,[800 1600]);set(gcf,'Color',[1 1 1]);
				p=panel(h);
				p.pack(me.nSelection,1)
				for ii = 1:me.nSelection
					p(ii,1).select();
					hold on
					for jj = me.selectedTrials{ii}.idx
						plot(ft.time{jj},ft.trial{jj}(1,:));
					end
					title(['Surrogate Data: ' me.selectedTrials{ii}.name]);
					grid on; box on
					xlabel('Time');
					ylabel('Voltage');
				end
			end
			
		end
		
		
		% ===================================================================
		%> @brief
		%>
		%> @param
		%> @return
		% ===================================================================
		function chSpectrum(me,tapers)
			if ~exist('mtspectrumc','file'); warning('Chronux Toolbox not installed...');return; end
			if ~exist('tapers','var') || isempty(tapers)
				if me.openUI
					answer=menuN('Chronux Spectrum:',{'t|[10 2]','Set Tapers [TW K] TW=time-bandwidth-product, K=#tapers:'});
					if iscell(answer) && ~isempty(answer); tapers = str2num(answer{1}); 
					elseif ischar(answer); tapers = str2num(answer);end
				else
					tapers = [10 2]; 
				end
			end
			me.runChronuxAnalysis(tapers)
		end
		
		% ===================================================================
		%> @brief
		%>
		%> @param
		%> @return
		% ===================================================================
		function set.demeanLFP(me,in)
			if ~isequal(me.demeanLFP,logical(in))
				me.demeanLFP = logical(in);
				disp('You should REPARSE the LFP data to enable this change')
			end
		end
		
		% ===================================================================
		%> @brief
		%>
		%> @param
		%> @return
		% ===================================================================
		function set.LFPWindow(me,in)
			if isnumeric(in) && length(in)==1 && ~isequal(me.LFPWindow, in)
				me.LFPWindow = in;
				disp('You should PARSE the LFP data to enable this change')
			end
		end

	end
	
	%=======================================================================
	methods ( Access = protected ) %-------PRIVATE METHODS-----%
	%=======================================================================
		
		% ===================================================================
		%> @brief Parse the LFP signals into trial structures
		%>
		%> @param
		%> @return
		% ===================================================================
		function LFPs = parseLFPs(me)
			if me.nLFPs == 0 || isempty(me.LFPs(1).time);
				LFPs = readLFPs(me.p);
			else
				LFPs = me.LFPs;
			end
			plfp = tic;
			window = me.LFPWindow; winsteps = round(window/1e-3);
			demeanW = round(me.baselineWindow/1e-3) - 1;
			for j = 1:length(LFPs)
				time		= LFPs(j).time;
				sample	= LFPs(j).sample;
				data		= LFPs(j).data;
				minL		= Inf;
				maxL		= 0;
				trials	= me.p.eventList.trials;
				for k = 1:me.p.eventList.nTrials
					if me.p.saccadeRealign == true
						t1 = trials(k).t1; 
						if ~isnan(trials(k).firstSaccade); t1 = t1+trials(k).firstSaccade; end
					else
						t1 = trials(k).t1;
					end
					[idx1, val1, dlta1] = me.findNearest(time, t1);
					trials(k).zeroTime = val1;
					trials(k).zeroIndex = idx1; 
					trials(k).zeroDelta = dlta1;
					trials(k).startIndex = idx1 - winsteps; 
					trials(k).endIndex = idx1 + winsteps;
					trials(k).otime = time( trials(k).startIndex : trials(k).endIndex );
					trials(k).time = [ -window : 1e-3 : window ]';
					trials(k).sample = sample( trials(k).startIndex : trials(k).endIndex );
					trials(k).data = data( trials(k).startIndex : trials(k).endIndex );
					trials(k).rawSampleStart = sample(trials(k).startIndex);
					trials(k).rawSampleEnd = sample(trials(k).endIndex);
					trials(k).prestimMean = mean(trials(k).data(winsteps + demeanW(1) : winsteps + demeanW(2)));
					if me.demeanLFP == true
						trials(k).data = trials(k).data - trials(k).prestimMean;
					end
					trials(k).demean = me.demeanLFP;
					trials(k).window = window;
					trials(k).winsteps = winsteps;
					minL = min([length(trials(k).data) minL]);
					maxL = max([length(trials(k).data) maxL]);
				end
				LFPs(j).trials = trials;
				LFPs(j).minL = minL;
				LFPs(j).maxL = maxL;
				LFPs(j).reparse = true;
			end
			
			fprintf('<strong>:#:</strong> Parsing LFPs into trials with event markers took <strong>%g ms</strong>\n',round(toc(plfp)*1000));
			
			if ~isempty(LFPs(1).trials)
				me.LFPs = LFPs;
			end
		end
		
		% ===================================================================
		%> @brief selectTrials selects trials based on several filters
		%>
		%> @param
		%> @return
		% ===================================================================
		function selectTrials(me)
			%if we are yoked to another object, don't run this method
			if me.yokedSelection == true; fprintf('Object is yoked, cannot run selectTrials...\n');return; end
			if isempty(me.options); initialise(me); end%initialise the various analysisCore options fields
			LFPs = me.LFPs; %#ok<*PROP>
			if ~isfield(LFPs,'trials')
				LFPs = readLFPs(me.p); parseLFPs(me);
				me.LFPs = LFPs;
			end
			if length(me.selectedBehaviour) ~= length(me.map)
				for i = 1:length(me.map);me.selectedBehaviour{i} = 'correct';end
				fprintf('\n---> LFPAnalysis: Reset selectedBehaviours to match map length...\n');
			end
			
			for i = 1:length(me.selectedBehaviour) %generate our selected behaviour indexes
				switch lower(me.selectedBehaviour{i})
					case {'c', 'correct'}
						behaviouridx{i} = find([LFPs(1).trials.isCorrect]==true); %#ok<*AGROW>
						selectedBehaviour{i} = 'correct';
					case {'b', 'breakfix'}
						behaviouridx{i} = find([LFPs(1).trials.isBreak]==true);
						selectedBehaviour{i} = 'breakfix';
					case {'i', 'incorrect'}
						behaviouridx{i} = find([LFPs(1).trials.isIncorrect]==true);
						selectedBehaviour{i} = 'incorrect';						
					otherwise
						behaviouridx{i} = [LFPs(1).trials.index];
						selectedBehaviour{i} = 'all';
				end
			end
			
			cutidx = me.cutTrials;
			saccidx = [];
			roiidx = [];
			toiidx = [];
			
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
			varList = [LFPs(1).trials.variable];
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
				if ~isempty(cutidx);	idx = setdiff(idx, cutidx); end%remove the cut trials
				if ~isempty(saccidx);	idx = intersect(idx, saccidx);	end %remove saccade filtered trials
				if ~isempty(roiidx);		idx = intersect(idx, roiidx);		end %remove roi filtered trials
				if ~isempty(toiidx);		idx = intersect(idx, toiidx);		end %remove roi filtered trialsend 
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
			if me.nSelection == 0; warning('The selection results in no valid trials to process!'); end
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
		%>
		%> @param
		%> @return
		% ===================================================================
		function h=drawTrialLFPs(me, h, sel)
			disp('Drawing RAW LFP Trials...')
			if ~exist('h','var')
				h=figure;figpos(1,[1920 1080]);set(h,'Color',[1 1 1]);
			end
			clf(h,'reset')
			if ~exist('sel','var')
				sel = me.selectedLFP;
			end
			
			LFP = me.LFPs(sel);
			cut = me.cutTrials;
			p=panel(h);
			p.margin = [20 20 10 15]; %left bottom right top
			[row,col]=me.optimalLayout(me.nSelection);
			p.pack(row,col);
			for j = 1:length(me.selectedTrials)
				[i1,i2] = ind2sub([row,col], j);
				p(i1,i2).select();
				p(i1,i2).title(['LFP & EVENT PLOT: File:' me.lfpfile ' | Channel:' LFP.name ' | Group:' num2str(j) ' | Name:' me.selectedTrials{j}.name]);
				p(i1,i2).xlabel('Time (s)');
				p(i1,i2).ylabel('LFP Raw Amplitude (mV) �2SD');
				p(i1,i2).hold('on');
				c = me.optimalColours(length(me.selectedTrials{j}.idx));
				[time,avg,err]=getAverageTuningCurve(me, me.selectedTrials{j}.idx, me.selectedLFP,'2SD');
				me.areabar(time, avg, err,[0.5 0.5 0.5],0.4,'k-','MarkerFaceColor',[0 0 0],'LineWidth',2);
				for k = 1:length(me.selectedTrials{j}.idx)
					trial = LFP.trials(me.selectedTrials{j}.idx(k));
					dat = [trial.variable,trial.index,trial.t1,trial.isCorrect,trial.isBreak];
					if ismember(trial.index,cut)
						ls = ':';cc=[0.5 0.5 0.5];
					else
						ls = '-';cc=c(k,:);
					end
					tag=['VAR:' num2str(dat(1)) '  TRL:' num2str(dat(2)) '  T1:' num2str(dat(3)) '  CORR:' num2str(dat(4)) '  BREAK:' num2str(dat(5))];
					if strcmpi(class(gcf),'double')
						plot(trial.time, trial.data, 'LineStyle', ls, 'Color', cc, 'Tag', tag, 'ButtonDownFcn', @clickMe, 'UserData', dat);
					else
						plot(trial.time, trial.data, 'LineStyle', ls, 'Tag',tag,'ButtonDownFcn', @clickMe,'UserData',dat);
					end
				end
				p(i1,i2).hold('off');
				axis([me.plotRange(1) me.plotRange(2) -inf inf]);
			end
			%dc = datacursormode(gcf);
			%set(dc,'UpdateFcn', @lfpCursor, 'Enable', 'on', 'DisplayStyle','window');
			
			uicontrol('Style', 'pushbutton', 'String', '<<',...
				'Position',[1 1 50 20],'Callback',@previousChannel);
			uicontrol('Style', 'pushbutton', 'String', '>>',...
				'Position',[52 1 50 20],'Callback',@nextChannel);
			
			me.panels.raw = p;
			
			function nextChannel(src,~)
				me.selectedLFP = me.selectedLFP + 1;
				if me.selectedLFP > length(me.LFPs)
					me.selectedLFP = 1;
				end
				drawTrialLFPs(me,gcf,me.selectedLFP);
			end
			function previousChannel(src,~)
				me.selectedLFP = me.selectedLFP - 1;
				if me.selectedLFP < 1
					me.selectedLFP = length(me.LFPs);
				end
				drawTrialLFPs(me,gcf,me.selectedLFP);
			end
			
			function clickMe(src, ~)
				if ~exist('src','var')
					return
				end
				ud = get(src,'UserData');
				tg = get(src,'Tag');
				disp(['Clicked on: ' tg]);
				if ~isempty(ud) && length(ud) > 1
					%var = ud(1);
					trl = ud(2);
					%t1 = ud(3);
					
					if intersect(trl, me.cutTrials)
						me.cutTrials(me.cutTrials == trl) = [];
						set(src,'LineStyle','-','LineWidth',0.5);
					else
						me.cutTrials = [me.cutTrials int32(trl)];
						set(src,'LineStyle',':','LineWidth',2);
					end
					disp(['Current Selected trials : ' num2str(me.cutTrials)]);
				end
			end
			
		end
		
		% ===================================================================
		%> @brief
		%>
		%> @param
		%> @return
		% ===================================================================
		function drawAverageLFPs(me)
			disp('Drawing Averaged (Reparsed) Timelocked LFPs...')
			LFPs = me.LFPs;
			if LFPs(1).reparse == true
				if isgraphics(me.plotDestination)
					h = me.plotDestination;
				else
					h=figure;figpos(1,[1700 1000]);set(gcf,'Name',[me.lfpfile],'Color',[1 1 1]);
				end
				p=panel(h);
				p.margin = [20 20 10 15]; %left bottom right top
				[row,col]=me.optimalLayout(me.nLFPs);
				p.pack(row,col);
				for j = 1:length(LFPs)
					[i1,i2] = ind2sub([row,col], j);
					p(i1,i2).select();
					p(i1,i2).title(['TIMELOCK AVERAGES: File:' me.lfpfile ' | Channel:' LFPs(j).name]);
					p(i1,i2).xlabel('Time (s)');
					p(i1,i2).ylabel('LFP Raw Amplitude (mV) �1SE');
					grid on; box on
					set(gca,'Layer','bottom')
					hold on
					c = me.optimalColours(length(me.selectedTrials));
					for k = 1:length(me.selectedTrials)
						leg{k,1} = me.selectedTrials{k}.name;
						[time,avg,err]=getAverageTuningCurve(me, me.selectedTrials{k}.idx, j);
						me.areabar(time, avg, err, c(k,:)/2, 0.3, 'k.-', 'Color', c(k,:), 'MarkerFaceColor', c(k,:), 'LineWidth', 2);
					end
					legend(leg);
					p(i1,i2).hold('off');
					axis([me.plotRange(1) me.plotRange(2) -inf inf]);
				end
			end
		end
		
		% ===================================================================
		%> @brief
		%>
		%> @param
		%> @return
		% ===================================================================
		function drawTimelockLFPs(me)
			disp('Drawing Averaged (Reparsed) Timelocked LFPs...');
			if isfield(me.results,'av')
				av = me.results.av;
				avstat = me.results.avstat;
				avstatavg = me.results.avstatavg;
				if isgraphics(me.plotDestination)
					h = me.plotDestination;
				else
					h=figure;figpos(1,[1700 1000]);set(gcf,'Name',[me.lfpfile ' ' av{1}.label{:}],'Color',[1 1 1]);
				end
				p=panel(h);
				p.margin = [20 20 10 15]; %left bottom right top
				p.pack('v', {5/6 []})
				p(1).select();
				p(1).hold('on');
				
				cl = me.optimalColours(length(av));
				
				xp = [avstat.cfg.latency(1) avstat.cfg.latency(2) avstat.cfg.latency(2) avstat.cfg.latency(1)];
				ym=mean(av{1}.avg(1,:));
				yp = [ym ym ym ym];
				mh = patch(xp,yp,[0 0 0],'FaceAlpha',0.1,'EdgeColor','none');
				set(get(get(mh,'Annotation'),'LegendInformation'),'IconDisplayStyle','off'); % Exclude line from legend
				%we draw baseline patches first
				for i = 1:length(av)
					xp = [me.plotRange(1) me.plotRange(2) me.plotRange(2) me.plotRange(1)];
					yp = [av{i}.baselineCI(1) av{i}.baselineCI(1) av{i}.baselineCI(2) av{i}.baselineCI(2)];
					me1 = patch(xp,yp,cl(i,:),'FaceAlpha',0.1,'EdgeColor','none');
					set(get(get(me1,'Annotation'),'LegendInformation'),'IconDisplayStyle','off'); % Exclude line from legend
				end
				
				tlout = struct();
				for i = 1:length(av)
					tlout(i).e = me.var2SE(av{i}.var(1,:),av{i}.dof(1,:))';
					tlout(i).t=av{i}.time';
					tlout(i).d=av{i}.avg(1,:)';
					namestr{i} = av{i}.name;

					if me.options.stats.smoothing > 0
						prm = me.options.stats.smoothing;
						tlout(i).f = fit(tlout(i).t,tlout(i).d,'smoothingspline','SmoothingParam', prm); %data
						tlout(i).fe = fit(tlout(i).t,tlout(i).e,'smoothingspline','SmoothingParam', prm); %error
						tlout(i).s = feval(tlout(i).f,tlout(i).t);
						tlout(i).se = feval(tlout(i).fe,tlout(i).t);
						me.areabar(tlout(i).t, tlout(i).s, tlout(i).se, [.5 .5 .5],0.3,'LineWidth',1);
					else
						me.areabar(tlout(i).t, tlout(i).d, tlout(i).e, [.5 .5 .5],0.3,'b-','LineWidth',1,'Color',cl(i,:));
					end
				end
				legend(namestr,'Location','southwest');

				assignin('base','timelockOut',tlout);

				ax=axis;
				set(mh,'YData',[ax(3) ax(3) ax(4) ax(4)]);
				
				pos = ax(4)-((ax(4)-ax(3))/20);
				times = avstat.time(logical(avstat.mask));
				pos = repmat(pos, size(times));
				hp=plot(times,pos,'o');
				set(get(get(hp,'Annotation'),'LegendInformation'),'IconDisplayStyle','off'); % Exclude line from legend
				
				hold off
				grid on; box on
				axis([me.plotRange(1) me.plotRange(2) ax(3) ax(4)]);
				ax=axis;
				c1 = NaN; c1e=c1; c2=c1; c2e=c1; pval=c1;
				for ii = 1:length(av)
					if size(av{ii}.cov,3)>1;
						av{ii}.cov = av{ii}.cov(:,:,1);
					end
				end
				[c1,c1e]=me.stderr(av{1}.cov);
				[c2,c2e]=me.stderr(av{2}.cov);
				try
					[pval]=ranksum(av{1}.cov,av{2}.cov,'alpha',me.options.stats.alpha);
				end
				xlabel('Time (s)');
				ylabel('LFP Raw Amplitude (mV) �SE');
				t=sprintf('COV = %.2g�%.2g <-> %.2g�%.2g [p = %.3g]',c1,c1e,c2,c2e,pval);
				tt=sprintf('%s | Ch: %s | %s p = %.3g [%s : %s (alpha=%.2g)]\n%s', me.lfpfile, av{1}.label{:}, avstat.cfg.statistic, avstatavg.prob, avstat.cfg.method, avstat.cfg.correctm, me.options.stats.alpha, t);
				title(tt,'FontSize',12);
				
				p(2).select();
				p(2).hold('on');
				
				idx1 = me.findNearest(av{1}.time, avstat.cfg.latency(1));
				idx2 = me.findNearest(av{1}.time, avstat.cfg.latency(2));
				
				res1 = av{2}.avg(1,:) - av{1}.avg(1,:);
				t = sprintf('Residuals (Sums: %.2g',sum(res1(idx1:idx2)));
				plot(av{1}.time, res1,'k.-')
				if length(av) == 2
					legend('Group B-A')
				elseif length(av) > 2
					res2 = av{3}.avg(1,:) - av{1}.avg(1,:);
					res3 = av{3}.avg(1,:) - av{2}.avg(1,:);
					plot(av{1}.time, res2,'r.-')
					plot(av{1}.time, res3,'g.-')
					legend('Group B-A','Group C-A','Group C-B')
					t = sprintf('%s %.2g %.2g',t,sum(res2(idx1:idx2)),sum(res3(idx1:idx2)));
				end
				grid on; box on
				t = [t ')'];
				title(t)
				xlim([me.plotRange(1) me.plotRange(2)]);
				xlabel('Time (s)');
				ylabel('Residuals (mV)');
			else
				disp('No Timelock analysis performed, so no data can be plotted...');
			end
		end
		
		% ===================================================================
		%> @brief
		%>
		%> @param
		%> @return
		% ===================================================================
		function drawContinuousLFPs(me)
			disp('Drawing Continuous LFP data...')
			%first plot is the whole raw LFP with event markers
			LFPs = me.LFPs;
			figure;figpos(1,[2500 800]);set(gcf,'Color',[1 1 1]);
			title(['RAW LFP & EVENT PLOT: File:' me.lfpfile ' | Channel: All | LFP: All']);
			xlabel('Time (s)');
			ylabel('LFP Raw Amplitude (mV)');
			hold on
			c = me.optimalColours(length(LFPs));
			for j = 1:length(LFPs)
				h(j)=plot(LFPs(j).time, LFPs(j).data,'Color',c(j,:));
				name{j} = ['LFP ' num2str(j)];
				[av,sd] = me.stderr(LFPs(j).data,'SD');
				hl=line([LFPs(j).time(1) LFPs(j).time(end)],[av-(2*sd) av-(2*sd)],'Color',get(h(j),'Color'),'LineWidth',2, 'LineStyle','--');
				set(get(get(hl,'Annotation'),'LegendInformation'),'IconDisplayStyle','off'); % Exclude line from legend
				hl=line([LFPs(j).time(1) LFPs(j).time(end)],[av+(2*sd) av+(2*sd)],'Color',get(h(j),'Color'),'LineWidth',2, 'LineStyle','--');
				set(get(get(hl,'Annotation'),'LegendInformation'),'IconDisplayStyle','off'); % Exclude line from legend
			end
			axis([0 40 -.5 .5])
			disp('Drawing Event markers...')
			c = me.optimalColours(me.p.eventList.nVars);
			for j = 1:me.p.eventList.nTrials
				trl = me.p.eventList.trials(j);
				var = trl.variable;
				hl=line([trl.t1 trl.t1],[-.4 .4],'Color',c(var,:),'LineWidth',2);
				set(get(get(hl,'Annotation'),'LegendInformation'),'IconDisplayStyle','off'); % Exclude line from legend
				hl=line([trl.t2 trl.t2],[-.4 .4],'Color',c(var,:),'LineWidth',2);
				set(get(get(hl,'Annotation'),'LegendInformation'),'IconDisplayStyle','off'); % Exclude line from legend
				text(double(trl.t1),.41,['VAR: ' num2str(var) '\newlineTRL: ' num2str(j)],'FontSize',10);
				text(double(trl.t1),-.41,['COR: ' num2str(trl.isCorrect)],'FontSize',10);
			end
			plot(me.p.eventList.startFix,zeros(size(me.p.eventList.startFix))-0.35,'c.','MarkerSize',15);
			plot(me.p.eventList.correct,zeros(size(me.p.eventList.correct))-0.35,'g.','MarkerSize',15);
			plot(me.p.eventList.breakFix,zeros(size(me.p.eventList.breakFix))-0.35,'b.','MarkerSize',15);
			plot(me.p.eventList.incorrect,zeros(size(me.p.eventList.incorrect))-0.35,'r.','MarkerSize',15);
			name{end+1} = 'start fixation';
			name{end+1} = 'correct';
			name{end+1} = 'break fix';
			name{end+1} = 'incorrect';
			legend(name,'Location','southwest')
			hold off;
			box on;
			pan xon;
			uicontrol('Style', 'pushbutton', 'String', '<<',...
				'Position',[1 1 50 20],'Callback',@backPlot);
			uicontrol('Style', 'pushbutton', 'String', '>>',...
				'Position',[52 1 50 20],'Callback',@forwardPlot);
			
			function forwardPlot(src, ~)
				if ~exist('src','var')
					return
				end
				ax = axis(gca);
				ax(1) = ax(1) + 40;
				ax(2) = ax(1) + 40;
				axis(ax);
			end
			function backPlot(src, ~)
				if ~exist('src','var')
					return
				end
				ax = axis(gca);
				ax(1) = ax(1) - 40;
				ax(2) = ax(1) + 40;
				axis(ax);
			end
		end
		
		% ===================================================================
		%> @brief
		%>
		%> @param
		%> @return
		% ===================================================================
		function drawSpikeLFP(me)
			if ~isfield(me.results,'staPre'); warning('No parsed spike-LFP available.'); return; end
			disp('Drawing Spike LFP correlations...')
			res = me.results;
			h=figure;figpos(1,[1200 1200]);set(h,'Color',[1 1 1],'NumberTitle','off','Name',...
				[me.lfpfile ' | ' me.spikefile ' | ' res.staPre{1}.cfg.spikechannel{1}]);
			p=panel(h);
			p.margin = [20 20 10 15]; %left bottom right top
			p.fontsize = 12;
			p.pack(length(res.staPre),2);
			
			for i = 1:length(res.staPre)
				p(i,1).select();
				hold on;
				e = me.var2SE(res.staPre{i}.var,res.staPre{i}.dof);
				for j = 1:size(res.staPre{i}.avg,1)
					me.areabar(res.staPre{i}.time, res.staPre{i}.avg(j,:), e(j,:),[0.5 0.5 0.5],0.2);
				end
				maxPre(i) = max(max(res.staPre{i}.avg(:,:)));
				minPre(i) = min(min(res.staPre{i}.avg(:,:)));
				box on
				grid on
				legend(res.staPre{i}.cfg.channel)
				xlabel('Time (s)')
				xlim(res.staPre{i}.cfg.timwin)
				t = ['PRE:' num2str(res.staPre{i}.cfg.latency) ' ' res.staPre{i}.name];
				t = regexprep(t,' +',' ');
				title(t)

				p(i,2).select();
				hold on;
				e = me.var2SE(res.staPost{i}.var,res.staPost{i}.dof);
				for j = 1:size(res.staPost{i}.avg,1)
					me.areabar(res.staPost{i}.time, res.staPost{i}.avg(j,:), e(j,:),[0.5 0.5 0.5],0.2);
				end
				maxPost(i) = max(max(res.staPost{i}.avg(:,:)));
				minPost(i) = min(min(res.staPost{i}.avg(:,:)));
				box on
				grid on
				legend(res.staPost{i}.cfg.channel)
				xlabel('Time (s)')
				xlim(res.staPost{i}.cfg.timwin)
				t=['POST:' num2str(res.staPost{i}.cfg.latency) ' ' res.staPost{i}.name];
				t = regexprep(t,' +',' ');
				title(t)
			end
			
			miny = min([minPre minPost]);
			maxy = max([maxPre maxPost]);
			if isnan(miny) || isnan(maxy); miny = -0.5; maxy = 0.5; end
			if miny >= maxy; maxy = miny + 1; end
			for i = 1:length(res.staPre)
				p(i,1).select();
				axis([-inf inf miny maxy]);
				p(i,2).select();
				axis([-inf inf miny maxy]);
			end
				
			h=figure;figpos(1,[1200 1200]);set(h,'Color',[1 1 1],'NumberTitle','off','Name',...
				[me.lfpfile '|' res.stsFFT{1}.lfplabel{1} '|' res.stsFFT{1}.label{1}]);
			p=panel(h);
			p.margin = [20 20 10 15]; %left bottom right top
			p.fontsize = 12;
			p.pack(2,2);
			
			lo = {'b-o','r-o','g-o','k-o','y-o','b:o','r:o'};
			leg = {''};
			
			for i = 1 : length(res.stsFFT)
				if ~isempty(res.stsFFT{i}.ang)
					p(1,1).select();
					p(1,1).hold('on');
					[av,ae] = me.stderr(res.stsFFT{i}.ang);
					me.areabar(res.stsFFT{i}.freq,rad2ang(av),rad2ang(ae),[],0.2,lo{i});
					leg{i} = res.stsFFT{i}.name;

					p(1,2).select();
					p(1,2).hold('on');
					[mv,merr] = me.stderr(res.stsFFT{i}.mag);
					me.areabar(res.stsFFT{i}.freq, mv, merr,[],0.2,lo{i});
					
					p(2,1).select();
					p(2,1).hold('on');
					[av,ae] = me.stderr(res.stsConvol{i}.ang);
					me.areabar(res.stsConvol{i}.freq,rad2ang(av),rad2ang(ae),[],0.2,lo{i});

					p(2,2).select();
					p(2,2).hold('on');
					[mv,merr] = me.stderr(res.stsConvol{i}.mag);
					me.areabar(res.stsConvol{i}.freq, mv, merr,[],0.2,lo{i});
				end
			end
			p(1,1).select();
			legend(leg);
			title(['Spike Triggered Phase FFT: ' num2str(res.stsFFT{1}.cfg.latency)]);
			xlabel('Frequency (Hz)');
			ylabel('Angle (deg)');
			grid on; box on;
			p(1,2).select();
			title(['Spike Triggered Amplitude FFT: ' num2str(res.stsFFT{1}.cfg.latency)]);
			xlabel('Frequency (Hz)');
			grid on; box on;
			p(2,1).select();
			title(['Spike Triggered Phase CONVOL: ' num2str(res.stsConvol{1}.cfg.latency)]);
			xlabel('Frequency (Hz)');
			ylabel('Angle (deg)');
			grid on; box on;
			p(2,2).select();
			title(['Spike Triggered Amplitude CONVOL: ' num2str(res.stsConvol{1}.cfg.latency)]);
			xlabel('Frequency (Hz)');
			grid on; box on;
			
			h=figure;figpos(1,[1920 1080]);set(h,'Color',[1 1 1],'NumberTitle','off','Name',...
				['PPC for ' me.lfpfile ' ' me.spikefile]);
			p=panel(h);
			p.margin = [20 20 10 15]; %leres bottom right top
			p.fontsize = 12;
			p.pack(2,3);
			
			for i = 1:length(res.statSts0)
				p(1,1).select();
				hold on
				plot(res.statSts0{i}.freq,res.statSts0{i}.ppc0',lo{i})
				leg{i}=[res.statSts0{i}.name ' | ' num2str(min(res.statSts0{i}.nspikes)) ' spks'];
				box on; grid on;
				xlabel('frequency')
				ylabel('PPC')
				title([res.statSts0{i}.cfg.method ' Measure for ' num2str(res.statSts0{i}.cfg.latency)]);
				
				p(1,2).select();
				hold on
				plot(res.statSts1{i}.freq,res.statSts1{i}.ppc1',lo{i})
				box on; grid on;
				xlabel('frequency')
				ylabel('PPC')
				title([res.statSts1{i}.cfg.method ' Measure for ' num2str(res.statSts1{i}.cfg.latency)]);
				
				p(1,3).select();
				hold on
				plot(res.statSts2{i}.freq,res.statSts2{i}.ppc2',lo{i})
				box on; grid on;
				xlabel('frequency')
				ylabel('PPC')
				title([res.statSts2{i}.cfg.method ' Measure for ' num2str(res.statSts2{i}.cfg.latency)]);
				
				p(2,1).select();
				hold on
				plot(res.statSts3{i}.freq,res.statSts3{i}.plv',lo{i})
				box on; grid on;
				xlabel('frequency')
				ylabel('PLV')
				title([res.statSts3{i}.cfg.method ' Measure for ' num2str(res.statSts3{i}.cfg.latency)]);
				
				p(2,2).select();
				hold on
				plot(res.statSts4{i}.freq,res.statSts4{i}.ral',lo{i})
				box on; grid on;
				xlabel('frequency')
				ylabel('RAL')
				title([res.statSts4{i}.cfg.method ' Measure for ' num2str(res.statSts4{i}.cfg.latency)]);
				
				p(2,3).select();
				hold on
				plot(res.statSts5{i}.freq,res.statSts5{i}.ang',lo{i})
				box on; grid on;
				xlabel('frequency')
				ylabel('ANG')
				title([res.statSts5{i}.cfg.method ' Measure for ' num2str(res.statSts5{i}.cfg.latency)]);
			end
			p(1,1).select();
			legend(leg);
			
			w = me.results.statStsW;
			h=figure;figpos(2,[500 1000]);set(h,'Color',[1 1 1],'NumberTitle','off','Name',...
				[me.lfpfile '|' res.stsFFT{1}.lfplabel{1} '|' res.stsFFT{1}.label{1}]);
			p=panel(h);
			p.margin = [20 20 10 15]; %leres bottom right top
			p.fontsize = 12;
			p.pack(length(w),1);
			colormap(jet)
			for i = 1:length(w)
				p(i,1).select();
				imagesc(w{i}.times, w{i}.freq, squeeze(w{i}.ppc0));
				box on; grid on; axis tight; axis xy
				xlabel('Time')
				ylabel('Frequency');
				title(['Timwin: ' num2str(w{i}.cfg.timwin) ' | ' w{i}.name])
				colorbar
			end
			
		end
		
		% ===================================================================
		%> @brief
		%>
		%> @param
		%> @return
		% ===================================================================
		function drawBandPass(me)
			if ~isfield(me.results,'bp') || isempty(me.results.bp); disp('No bandpass data available...'); return; end
			disp('Drawing Frequency Bandpass...')
			bp = me.results.bp;
			h=figure;figpos(1,[1500 1500]);set(h,'Color',[1 1 1]);
			p=panel(h);
			p.margin = [20 20 10 15]; %left bottom right top
			p.fontsize = 10;
			len=length(bp)+1;
			[row,col]=me.optimalLayout(len);
			p.pack(row,col);
			for j = 1:length(bp)
				[i1,i2] = ind2sub([row,col], j);
				pp=p(i1,i2);
				pp.margin = [0 0 15 0];
				pp.pack(2,1);
				pp(1,1).select();
				pp(1,1).hold('on');
				time = bp{j}.av{1}.time;
				grnd = bp{j}.av{1}.avg(1,:);
				grnde = me.var2SE(bp{j}.av{1}.var(1,:),bp{j}.av{1}.dof(1,:));
				fig = bp{j}.av{2}.avg(1,:);
				fige = me.var2SE(bp{j}.av{2}.var(1,:),bp{j}.av{2}.dof(1,:));
				if length(bp{j}.av) > 2
					bord = bp{j}.av{3}.avg(1,:);
					borde = me.var2SE(bp{j}.av{3}.var(1,:),bp{j}.av{3}.dof(1,:));
				end
				idxa = me.findNearest(time, me.plotRange(1));
				idxb = me.findNearest(time, me.plotRange(2));
				minv = min([min(fig(idxa:idxb)) min(grnd(idxa:idxb))]);
				maxv = max([max(fig(idxa:idxb)) max(grnd(idxa:idxb))]);
				minv = minv - (abs(minv)/15);
				maxv = maxv + (abs(maxv)/15);
				if minv >= maxv;minv = -inf; end
				me.areabar(time, grnd, grnde,[.5 .5 .5],'b');
				me.areabar(time, fig, fige,[.7 .5 .5],'r');
				if length(bp{j}.av) > 2
					me.areabar(time,bord,borde,[.7 .5 .5],'g');
				end
				pp(1,1).hold('off');
				set(gca,'XTickLabel','')
				box on; grid off
				axis([me.plotRange(1) me.plotRange(2) minv maxv]);
				pp(1,1).ylabel(['BP ' me.bpnames{j} '=' num2str(bp{j}.freq)]);
				pp(1,1).title([me.bpnames{j} ' BP: File:' me.lfpfile ' | Channel:' bp{j}.av{1}.label{:}]);
				pp(1,1).margin = [1 1 1 1];
				
				idx1 = me.findNearest(time, -0.2);
				idx2 = me.findNearest(time, 0);
				idx3 = me.findNearest(time, 0.075);
				idx4 = me.findNearest(time, 0.2);
				pre = mean([mean(grnd(idx1:idx2)), mean(fig(idx1:idx2))]);
				res = (fig - grnd) ./ pre;
				if length(bp{j}.av) > 2
					res2 = (bord - grnd) ./ pre;
				end
				freqdiffs(j) = mean(fig(idx3:idx4)) / mean(grnd(idx3:idx4));
				pp(2,1).select();
				plot(time,res,'m.-','MarkerSize',6);
				if length(bp{j}.av) > 2
					hold on
					plot(time,res2,'c.-','MarkerSize',6);
				end
				box on; grid on; hold off
				axis([me.plotRange(1) me.plotRange(2) -inf inf]);
				pp(2,1).ylabel('Residuals')
				pp(2,1).margin = [1 1 1 1];
			end
			p(row,col).select();
			bar(freqdiffs,'FaceColor',[0.4 0.4 0.4]);
			box on; grid on;
			set(gca,'XTick',1:length(bp),'XTickLabel',me.bpnames);
			p(row,col).xlabel('Frequency Band')
			p(row,col).ylabel('Group 2 / Group 1')
			p(row,col).title('Normalised Difference at 0.075 - 0.2sec')
			disp('Plotting Bandpass Analysis Finished...')
			me.panels.bp = p;
		end
		
		% ===================================================================
		%> @brief
		%>
		%> @param
		%> @return
		% ===================================================================
		function drawLFPFrequencies(me,varargin)
			if isempty(varargin) || isempty(varargin{1})
				name = ['fq' me.options.method];
				if isempty(varargin)
					varargin = {};
				end
			end
			while iscell(varargin) && length(varargin)==1 
				varargin = varargin{1};
			end
			if (~isempty(varargin) && ischar(varargin)) ||  (~isempty(varargin) && ischar(varargin{1}))
				if ischar(varargin);	name = varargin;
				else name = varargin{1}; end
				while iscell(name);name=name{1};end
			end
			if iscell(varargin) && length(varargin) > 1
				zlimi = varargin{2};
				while iscell(zlimi);zlimi=zlimi{1};end
				if ~isnumeric(zlimi); clear zlimi; end
			end
			if iscell(varargin) && length(varargin) > 2
				bl = varargin{2};
				while iscell(bl);bl=bl{1};end
				if ~ischar(bl); clear bl; end
			end
			if ~isfield(me.results,name)
				disp('The Frequency field is not present in fieldtrip structure...');
				return;
			end
			fq = me.results.(name);
			if isgraphics(me.plotDestination)
				h = me.plotDestination;
			else
				ho = figure;figpos(1,[1000 2000]);set(ho,'Color',[1 1 1],'Name',[me.lfpfile ' ' fq{1}.cfgUsed.channel]);
				%h = uipanel('Parent',ho,'units', 'normalized', 'position', [0 0 1 1],'BackgroundColor',[1 1 1],'BorderType','none');
			end
			p=panel(ho);
			p.margin = [20 15 30 10];%left bottom right top
			if isnumeric(gcf);	p.fontsize = 12; end
			if ~exist('bl','var')
				bl = {me.options.bline};
			end
			if length(bl) == 1
				[row,col] = me.optimalLayout(length(fq));
			else
				row = length(fq); col = length(bl);
			end
			p.pack(row,col); %#ok<*PROPLC>
			hmin = cell(size(bl));
			hmax = hmin;
			h = hmin;
			for jj = 1:length(bl)
				for i = 1:length(fq)
					if length(bl) == 1
						[aa,bb] = ind2sub([row, col],i);
						p(aa,bb).select();
					else
						p(i,jj).select();
					end
					cfg									= [];
					cfg.fontsize				= 13;
					if strcmpi(bl{jj},'no')
						cfg.baseline			= 'no';
					else
						cfg.baseline			= me.baselineWindow;
						cfg.baselinetype	= bl{jj};
						if strcmpi(bl{jj},'relative') && exist('zlimi','var')
							cfg.zlim				= zlimi;
						else
							
						end
						if strcmpi(bl{jj},'relative2')
							cfg.baselinetype		= 'relative';
							cfg.zlim					= [0 2];
						end
					end
					if isfield(fq{i},'uniquetrials'); fq{i} = rmfield(fq{i},'uniquetrials'); end
					cfg.interactive			= 'no';
					cfg.channel					= me.ft.label{me.selectedLFP};
					cfgOut						= ft_singleplotTFR(cfg, fq{i});
					grid on; box on;
					set(gca,'Layer','top','TickDir','out')
					h{jj}{i} = gca;
					clim = get(gca,'clim');
					hmin{jj} = min([hmin{jj} min(clim)]);
					hmax{jj} = max([hmax{jj} max(clim)]);
					xlabel('Time (s)');
					ylabel('Frequency (Hz)');
					t = [bl{jj} '#' num2str(i) ' ' name ' |Mth:' fq{i}.cfgUsed.method ' |Tp:' fq{i}.cfgUsed.taper];
					t = [t ' |Win:' num2str(fq{i}.cfgUsed.tw) ' |Cyc:' num2str(fq{i}.cfgUsed.cycles)];
					t = [t ' |Smth:' num2str(fq{i}.cfgUsed.smooth) ' | Wdth:' num2str(fq{i}.cfgUsed.width) ];
					title(t,'FontSize',cfg.fontsize);
				end
				for i = 1:length(h{jj})
					set(h{jj}{i},'clim', [hmin{jj} hmax{jj}]);
					box on; grid on;
				end
				colormap('jet');
			end
			me.panels.(name) = p;
			clear fq p
		end
		
		% ===================================================================
		%> @brief
		%>
		%> @param
		%> @return
		% ===================================================================
		function drawLFPFrequencyStats(me,name)
			if ~exist('name','var');name='fqfix1';end
			if ~isfield(me.results,name)
				fprintf('\nCan''t find %s frequency analysis; ',name)
				if isfield(me.results,'fqfix1'); name = 'fqfix1';
				elseif isfield(me.results,'fqmtm1'); name = 'fqmtm1';
				elseif isfield(me.results,'fqmorlet'); name = 'fqmorlet';
				else return;
				end
				fprintf('plotting %s frequency analysis instead.\n',name)
			end
			lo = {'b-o','r-o','g-o','k-o','y-o','b:o','r:o'};
			
			fq = me.results.(name);
			fqbline = me.results.([name 'bline']);
			fqresponse = me.results.([name 'response']);
			fqstatall = me.results.([name 'statall']);
			fqstatf = me.results.([name 'statf']);
			
			h=figure;figpos(1,[1500 1500]);set(h,'Color',[1 1 1],'Name',[me.lfpfile ' | ' fq{1}.cfgUsed.channel ' | ' name ' | CorrectM:' fqstatall.cfg.correctm]);
			p=panel(h);
			p.margin = [15 15 15 15];%left bottom right top
			p.pack('h', {1/2 []})
			q=p(1);
			q.pack('v',{7/8 []});
			q(1).select();
			hold on
			plotpowline(fqbline{1}.freq,fqbline{1}.powspctrm,fqbline{1}.powspctrmsem,'b:x',[0.6 0.6 0.6]);
			plotpowline(fqbline{2}.freq,fqbline{2}.powspctrm,fqbline{2}.powspctrmsem,'r:x',[0.6 0.6 0.6]);
			if length(fqbline)>2
				plotpowline(fqbline{3}.freq,fqbline{3}.powspctrm,fqbline{3}.powspctrmsem,'g:x',[0.6 0.6 0.6]);
			end
			
			plotpowline(fqresponse{1}.freq,fqresponse{1}.powspctrm,fqresponse{1}.powspctrmsem,'b-o',[0.4 0.4 0.5]);
			plotpowline(fqresponse{2}.freq,fqresponse{2}.powspctrm,fqresponse{2}.powspctrmsem,'r-o',[0.5 0.4 0.4]);
			if length(fqbline)>2
				plotpowline(fqresponse{3}.freq,fqresponse{3}.powspctrm,fqresponse{3}.powspctrmsem,'g-o',[0.4 0.5 0.4]);	
				leg = {['BL' fqbline{1}.name],['BL' fqbline{2}.name],['BL' fqbline{3}.name],...
				['M' fqresponse{1}.name],['M' fqresponse{2}.name],['M' fqresponse{3}.name]};
			else
				leg = {['BL' fqbline{1}.name],['BL' fqbline{2}.name],...
				['M' fqresponse{1}.name],['M' fqresponse{2}.name]};
			end
			grid on; box on
			t=''; if isfield(fqresponse{1},'blname'); t = [' | BL:' fqresponse{1}.blname]; end
			title([name t ' | TWin: ' num2str(fqresponse{1}.toilim)])
			ylabel('Power');
			xlabel('Frequency (Hz)');
			legend(leg);
			if strcmpi(fqresponse{1}.blname,'no')
				set(gca,'YScale','log');
			end
			axis tight
			
			q(2).select();
			q(2).margintop = 0;
			p1 = squeeze(fqresponse{1}.powspctrm);
			p2 = squeeze(fqresponse{2}.powspctrm);
			p1 = nanmean(p1,2);
			p2 = nanmean(p2,2);
			plot(fqresponse{1}.freq,(p2-p1));
			xlabel('Frequency (Hz)');
			ylabel('Residuals')
			axis tight
			grid on;box on
			
			t=''; if isfield(fqstatall,'blname'); t = fqstatall.blname; end
			
			r=p(2);
			r.pack('v',{1/2 []});
			r(1).select();
			surf(fqstatall.freq,fqstatall.time,double(squeeze(fqstatall.mask))');
			xlabel('Frequency (Hz)');
			ylabel('Time (s)');
			view([90 270]);
			axis tight
			grid on; box on;
			set(gca,'TickDir','out');
			title(['Baseline: ' t ' Significance']);
			
			r(2).select();
			f=[fqstatf(:).prob];
			x=1:length(f);
			plot(x,f,'k.:','MarkerSize',18);	
			hold on
			line([min(x) max(x)],[fqstatf(1).alpha fqstatf(1).alpha],...
				'LineStyle',':','LineWidth',3);
			set(gca,'XTick',1:length(f),'XTickLabel',{fqstatf(:).name});
			ylabel('p-value (log axis)');
			xlabel('Frequency Bands');
			%ylim([0 fqstatf(1).alpha*2])
			axis tight
			grid on; box on;
			set(gca,'TickDir','out');
			set(gca,'YScale','log');
			title(['Baseline: ' t 'Frequency Band p-values']);
			function plotpowline(f,p,e,lc,ec)
				p = squeeze(p);
				e = squeeze(e);
				p = p';
				e = e';
				p = nanmean(p);
				e = max(e);
				me.areabar(f, p, e, ec,0.2,lc);
			end
		end
		
		% ===================================================================
		%> @brief chSpectrum chronux spectrum equivalent
		%>
		% ===================================================================
		function runChronuxAnalysis(me,tapers)
			params.tapers = tapers;
			params.Fs = 1000;
			%params.pad = 0;
			params.err = [1 me.options.stats.alpha];
			params.fpass = [0 100];
			params.trialave = 1;
			uselog = 'l';
			
			h=figure;
			figpos(1,[1800 1200]);
			set(h,'Color',[1 1 1],'NumberTitle','off','Name',[me.lfpfile ' | ' me.spikefile]);
			o=panel(h);
			o.margin = [25 10 10 10];%left bottom right top
			o.pack('h', {2/3 []});
			o(2).pack('v', {1/2 []});
			p = o(1);
			p.margin = [15 15 15 15];%left bottom right top
			p.pack('v', {1/3 []});
			q=p(2);
			q.margin = [30 15 20 10];%left bottom right top
			q.pack(2,me.nSelection);
			lo = {'k-o','r-o','b-o','g.-','y.-','c.-','k.:','r.:','b.:','g.:','y.:','c.:'};
			
			ft = me.ft;
			lfp = me.LFPs(me.selectedLFP);
			names = lfp.name;
			sp = me.sp.spike{me.sp.selectedUnit};
			names = [names '<>' me.sp.names{me.sp.selectedUnit}];
			time = ft.time{1};
			b1 = me.findNearest(time,me.baselineWindow(1));
			b2 = me.findNearest(time,me.baselineWindow(2));
			s1 = me.findNearest(time,me.measureRange(1));
			s2 = me.findNearest(time,me.measureRange(2));
			tit = sprintf('%s TAPER: %i & %i | Baseline T: %.2g : %.2g secs | Stimulus T: %.2g : %.2g secs',lfp.name,tapers(1), tapers(2),...
				me.baselineWindow(1), me.baselineWindow(2), me.measureRange(1), me.measureRange(2));
			cmin = Inf; cmax = -Inf;
			
			name={};
			for i=1:me.nSelection
				%d = [lfp.trials(me.selectedTrials{i}.idx).data];
				idx = me.selectedTrials{i}.idx;
				d = zeros(length(ft.trial{1}(1,:)),length(idx));
				spk = [];
				for j = 1:length(idx)
					d(:,j) = ft.trial{idx(j)}(me.selectedLFP,:)';
					spk(j).times = sp.trials{idx(j)}.spikes - sp.trials{idx(j)}.base;
				end
				
				p(1).select();
				p(1).hold('on');
				[s,f,e] = mtspectrumc(d(b1:b2,:),params);
				plot_vector(s,f,uselog,e,lo{i+6},0.5);%me.areabar(f,s,e,[],0.2,lo{i+5})
				name{end+1} = ['BASELINE ' me.selectedTrials{i}.name];
				grid on; box on;
				
				[s,f,e] = mtspectrumc(d(s1:s2,:),params);
				plot_vector(s,f,uselog,e,lo{i},2);
				name{end+1} = ['DATA ' me.selectedTrials{i}.name];
				
				q(1,i).select();
				[s,t,f,e] = mtspecgramc(d(300:1300,:), [0.3,0.05], params );
				t = t - 0.5;
				plot_matrix(s,t,f,uselog);
				title(['Group ' num2str(i)])
				cl = get(gca,'CLim'); cmin = min(cmin, cl(1)); cmax = max(cmax, cl(2));
				box on; axis tight
				
				q(2,i).select();
				bt1 = me.findNearest(t,me.baselineWindow(1));
				bt2 = me.findNearest(t,me.baselineWindow(2));
				sB=mean(s(bt1:bt2,:)); % spectrum in the first movingwindow taken to be baseline
				plot_matrix(s./repmat(sB,[size(s,1) 1]), t,f,uselog);
				title(['Group ' num2str(i) ' - baseline']);
				box on; axis tight
				
				datasp=extractdatapt(spk, me.measureRange,1);
				datalfp=extractdatac(d, params.Fs, me.measureRange+0.8);
				[C,phi,S12,S1,S2,f,zerosp,confC,phistd]=coherencycpt(datalfp,datasp,params);
				o(2,1).select();
				hold on; grid on; box on;
				plot(f,C,lo{i}); line(get(gca,'xlim'),[confC confC],'Color',lo{i}(1));ylim([0 1]);
				title(names); xlabel(''); ylabel('Coherence');
				o(2,2).select();
				hold on; grid on; box on;
				me.areabar(f,phi,phistd,[0.5 0.5 0.5],0.3,lo{i});
				xlabel('Frequency'); ylabel('Phase');
				
			end
			p(1).select();
			p(1).title(tit);
			legend(name);
			for i=1:me.nSelection
				q(1,i).select();
				set(gca,'CLim',[cmin cmax]);
			end	
			
			function plot_matrix(X,t,f,plt,Xerr,zlims)
				if nargin < 1; error('Need data'); end;
				[NT,NF]=size(X);
				if nargin < 2;	 t=1:NT;		end;
				if nargin < 3;	 f=1:NF;		end;
				if length(f)~=NF || length(t)~=NT; error('axes grid and data have incompatible lengths'); end;
				if nargin < 4 || isempty(plt); plt='l'; end;
				if strcmp(plt,'l');
					 X=10*log10(X);
					 if nargin ==5; Xerr=10*log10(Xerr); end;
				end;
				if nargin < 5 || isempty(Xerr)
					imagesc(t,f,X');
					if exist('zlims','var'); zlim(zlims); end
					axis xy; 
					colorbar; 
				else
					subplot(311); imagesc(t,f,squeeze(Xerr(1,:,:))'); axis xy; colorbar; title('Lower confidence');
					subplot(312); imagesc(t,f,X'); title('X');axis xy; colorbar;
					subplot(313); imagesc(t,f,squeeze(Xerr(2,:,:))'); axis xy; colorbar; title('Upper confidence');
				end;
				xlabel('Time (s)');ylabel('Frequency');
			end
			
			function plot_vector(X,f,plt,Xerr,c,w) 
				if nargin < 1; error('Need data'); end;
				N=length(X); 
				if nargin < 2 || isempty(f);	 f=1:N;	end;
				if length(f)~=N; error('frequencies and data have incompatible lengths'); end;
				if nargin < 3 || isempty(plt) ;	 plt='l';	end;
				if nargin < 4 || isempty(Xerr);	 Xerr=[];	end;				
				if nargin < 5 || isempty(c); c='k.-';end;
				if nargin < 6 || isempty(w);	 w=1;	end;

				if strcmp(plt,'l');
					 X=10*log10(X);
					 if nargin >=4 & ~isempty(Xerr); Xerr=10*log10(Xerr); end;
				end;

				if nargin < 4 || isempty(Xerr);
					 plot(f,X,c,'Linewidth',w);
				else
					 if length(Xerr)==1;
						 plot(f,X,c); 
						 line(get(gca,'xlim'),[Xerr,Xerr],'Color',c,'LineStyle','--','Linewidth',w);
					 elseif ~isempty(Xerr);
						 plot(f,X,c,'Linewidth',w); 
						 hold on; 
						 he1=plot(f,Xerr(1,:),[c(1) '--'],'Linewidth',w);
						 he2=plot(f,Xerr(2,:),[c(1) '--'],'Linewidth',w);
						 set(get(get(he1,'Annotation'),'LegendInformation'),'IconDisplayStyle','off'); % Exclude line from legend
						 set(get(get(he2,'Annotation'),'LegendInformation'),'IconDisplayStyle','off'); % Exclude line from legend
					 end
				end
				xlabel('f');
				if strcmp(plt,'l'); ylabel('10*log10(X) dB'); else ylabel('X'); end
			end
				
		end
		
		% ===================================================================
		%> @brief
		%>
		%> @param
		%> @return
		% ===================================================================
		function [time,avg,err,data]=getAverageTuningCurve(me,idx,sel,err)
			if ~exist('err','var');err = 'SE'; end
			time = me.LFPs(sel).trials(1).time';
			data = [me.LFPs(sel).trials(idx).data];
			data = rot90(fliplr(data)); %get it into trial x data = row x column
			[avg,err] = me.stderr(data,err);
		end
		
		% ===================================================================
		%> @brief
		%>
		%> @param
		%> @return
		% ===================================================================
		function makeUI(me, varargin)
			if ~isempty(me.handles) && isfield(me.handles,'hbox') && isa(me.handles.hbox,'uix.HBoxFlex')
				fprintf('--->>> UI already open!\n');
				me.openUI = true;
				return
			end
			embedMode = false;
			if isa(varargin{1},'uix.BoxPanel')
				parent = varargin{1};
				embedMode = true;
			end
			if ~exist('parent','var')
				parent = figure('Tag','LFP Analysis',...
					'Name', ['LFP Analysis: ' me.fullName], ...
					'MenuBar', 'none', ...
					'CloseRequestFcn', @me.closeUI,...
					'NumberTitle', 'off');
				figpos(1,[1200 600])
			end
			me.handles(1).parent = parent;
			
			fs = 10;
			if ismac
				SansFont = 'Avenir Next';
			else
				SansFont = 'DejaVu Sans';
			end
			MonoFont = 'Fira Code';
			bgcolor = [0.89 0.89 0.89];
			bgcoloredit = [0.9 0.9 0.9];
			
			%make context menu
			hcmenu = uicontextmenu;
			uimenu(hcmenu,'Label','Select','Callback',@me.select,'Accelerator','e');
			uimenu(hcmenu,'Label','Plot','Callback',@me.plot,'Accelerator','p');

			handles.parent = me.handles.parent; %#ok<*PROP>
			if embedMode == true
				handles.root = handles.parent;
			else
				handles.root = uix.BoxPanel('Parent',parent,...
					'Title','LFP Analysis UI',...
					'FontName',SansFont,...
					'FontSize',fs+2,...
					'FontWeight','bold',...
					'Padding',0,...
					'TitleColor',[0.7 0.68 0.66],...
					'BackgroundColor',bgcolor);
			end
			handles.tabs = uix.TabPanel('Parent', handles.root,'Padding',0,...
				'BackgroundColor',bgcolor,'TabWidth',120,'FontSize', fs+1,'FontName',SansFont);
			handles.lfppanel = uix.Panel('Parent', handles.tabs,'Padding',0,...
				'BackgroundColor',bgcolor);
			handles.spikepanel = uix.Panel('Parent', handles.tabs,'Padding',0,...
				'BackgroundColor',bgcolor);
			handles.tabs.TabTitles = {'LFP Data','Spike Data'};
			handles.hbox = uix.HBoxFlex('Parent', handles.lfppanel,'Padding',0,...
				'Spacing', 5, 'BackgroundColor', bgcolor);
			handles.lfpinfo = uicontrol('Parent', handles.hbox,'Style','edit','Units','normalized',...
				'BackgroundColor',[0.3 0.3 0.3],'ForegroundColor',[1 1 0],'Max',500,...
				'FontSize',fs+1,'FontWeight','bold','FontName',SansFont,'HorizontalAlignment','left');
			handles.controls = uix.VBoxFlex('Parent', handles.hbox,'Padding',0,'Spacing',0,'BackgroundColor',bgcolor);
			handles.controls1 = uix.Grid('Parent', handles.controls,'Padding',4,'Spacing',2,'BackgroundColor',bgcolor);
			handles.controls3 = uix.Grid('Parent', handles.controls,'Padding',4,'Spacing',2,'BackgroundColor',bgcolor);
			handles.controls2 = uix.Grid('Parent', handles.controls,'Padding',4,'Spacing',0,'BackgroundColor',bgcolor);
			
			handles.parsebutton = uicontrol('Style','pushbutton',...
				'Parent',handles.controls1,...
				'Tag','LFPAParse',...
				'Tooltip','Parse All data',...
				'FontName',SansFont,...
				'FontSize', fs,...
				'Callback',@me.parse,...
				'String','Parse LFPs');
			handles.reparsebutton = uicontrol('Style','pushbutton',...
				'Parent',handles.controls1,...
				'Tag','LFPAReparse',...
				'FontName',SansFont,...
				'FontSize', fs,...
				'Tooltip','Reparse should be a bit quicker',...
				'Callback',@me.reparse,...
				'String','Reparse LFPs');
			handles.reparsebutton = uicontrol('Style','pushbutton',...
				'Parent',handles.controls1,...
				'Tag','LFPAparses',...
				'FontName',SansFont,...
				'FontSize', fs,...
				'Tooltip','Parse the spikes using the LFP trial selection, useful for plotTogether and ftSpikeLFP',...
				'Callback',@me.parseSpikes,...
				'String','Parse Spikes');
			handles.selectbutton = uicontrol('Style','pushbutton',...
				'Parent',handles.controls1,...
				'Tag','LFPAselect',...
				'FontName',SansFont,...
				'FontSize', fs,...
				'Tooltip','Select trials',...
				'Callback',@me.select,...
				'String','Select Trials');
			handles.plotbutton = uicontrol('Style','pushbutton',...
				'Parent',handles.controls1,...
				'Tag','LFPAplotbutton',...
				'FontName',SansFont,...
				'FontSize', fs,...
				'Tooltip','Plot',...
				'Callback',{@me.plot, 'all'},...
				'String','Examine Raw LFPs');
			handles.statbutton = uicontrol('Style','pushbutton',...
				'Parent',handles.controls1,...
				'Tag','LFPAstatbutton',...
				'FontName',SansFont,...
				'FontSize', fs,...
				'Tooltip','Plot',...
				'Callback',@me.setStats,...
				'String','Analysis Stats Options');
			handles.savebutton = uicontrol('Style','pushbutton',...
				'Parent',handles.controls1,...
				'Tag','LFPAsave',...
				'FontName',SansFont,...
				'FontSize', fs,...
				'Tooltip','Save this LFP Analysis object',...
				'Callback',@me.save,...
				'String','Save Analysis Object');
			handles.saccbutton = uicontrol('Style','pushbutton',...
				'Parent',handles.controls1,...
				'Tag','LMAsaccbutton',...
				'FontName',SansFont,...
				'FontSize', fs,...
				'Tooltip','Toggle Saccade Realign',...
				'Callback',@me.toggleSaccadeRealign,...
				'String','Toggle Saccade Align');
			handles.surrbutton = uicontrol('Style','pushbutton',...
				'Parent',handles.controls1,...
				'Tag','LMAsurrbutton',...
				'FontName',SansFont,...
				'FontSize', fs,...
				'Tooltip','Create surrogate Data, with known parameters so you can test if analysis is working, reparse to recover original data',...
				'Callback',@me.createSurrogate,...
				'String','Create Surrogate Data!');
			handles.plotsbutton = uicontrol('Style','togglebutton',...
				'Parent',handles.controls1,...
				'Tag','LMAplotsbutton',...
				'FontName',SansFont,...
				'FontSize', fs,...
				'Min',0,...
				'Max',1,...
				'Value',double(me.doPlots),...
				'Tooltip','Plot analysis results each time or not',...
				'Callback',@togglePlots,...
				'String','Plot Results?');
			handles.analmethod = uicontrol('Style','popupmenu',...
				'Parent',handles.controls3,...
				'FontName',SansFont,...
				'FontSize', fs,...
				'Tooltip','Select a method to run',...
				'Callback',@runAnal,...
				'Tag','LFPAanalmethod',...
				'String',{'plotTogether','ftTimeLockAnalysis','ftFrequencyAnalysis','ftFrequencyStats','ftBandPass','ftSpikeLFP','chSpectrum','showEyePlots'});
			handles.list = uicontrol('Style','edit',...
				'Parent',handles.controls2,...
				'Tag','LMAlistbox',...
				'Min',1,...
				'Max',100,...
				'FontSize',fs,...
				'FontName',MonoFont,...
				'String',{''},...
				'uicontextmenu',hcmenu);
			
			set(handles.hbox,'Widths', [-1 -1]);
			set(handles.controls,'Heights', [75 30 -1]);
			set(handles.controls1,'Heights', [-1 -1]);
			set(handles.controls3,'Widths', [-1], 'Heights', [-1])

			me.sp.GUI(handles.spikepanel);
			
			me.handles = handles;
			me.openUI = true;
			
			updateUI(me);
			
			function runAnal(src, ~)
				if ~exist('src','var');	return; end
				s = get(src,'String'); v = get(src,'Value'); s = s{v};
				if me.nLFPs > 0
					eval(['me.' s])
				end
			end
			
			function togglePlots(src, ~)
				if ~exist('src','var');	return; end
				v = get(src,'Value');
				me.doPlots = logical(v);
				fprintf('doPlots is %i\n',me.doPlots)
			end
		end
		
		% ===================================================================
		%> @brief 
		%>
		%> @param
		%> @return
		% ===================================================================
		function closeUI(me, varargin)
			fprintf('--->>> Close UI for object: %s\n',me.fullName);
			try me.sp.closeUI; end %#ok<TRYNC>
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
			if me.openUI && ~isempty(me.handles)
				if me.nLFPs == 0
					notifyUI(me,'You need to PARSE the data files first');
				else
					notifyUI(me,'LFPs seems to be parsed, run an analysis...');
				end
				fs = 10;
				if isa(me.p,'plxReader')
					me.p.generateInfo;
					set(me.handles.lfpinfo,'String',me.p.info,'FontSize',fs+1)
				end
				if isa(me.sp,'spikeanalysis')
					updateUI(me.sp);
				end
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
				try set(me.handles.root,'Title',info); end %#ok<TRYNC>
			end
		end
	end
end
