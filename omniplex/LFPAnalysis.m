classdef LFPAnalysis < analysisCore
	%LFPAnalysis Wraps the native and fieldtrip analysis around our PLX/PL2 reading.
	
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
		%> ± time window for demeaning
		baselineWindow@double = [-0.2 0]
		%> default LFP channel
		selectedLFP@double = 1
		%> time window around the trigger
		LFPWindow@double = 0.8
		%> default ± range to plot
		plotRange@double = [-0.2 0.4]
		%> default range to measure for differences
		measureRange@double = [0.1 0.2]
		%> default behavioural type
		selectedBehaviour@char = 'correct';
		%> plot verbosity
		verbose	= true
	end
	
	%------------------VISIBLE PROPERTIES----------%
	properties (SetAccess = {?analysisCore}, GetAccess = public)
		%> LFP plxReader object
		p@plxReader
		%> spike analysis object
		sp@spikeAnalysis
		%> parsed LFPs
		LFPs@struct
		%> fieldtrip parsed data
		ft@struct
		%> fieldtrip parsed results
		results@struct
		%> selectedTrials: each cell is a trial list grouping
		selectedTrials@cell
		%> trials to remove in reparsing
		cutTrials@double
		%> variable selection map for 3 analysis groups
		map@cell
	end
	
	%------------------HIDDEN PROPERTIES----------%
	properties (SetAccess = protected, GetAccess = public, Hidden = true)
		%> bandpass frequencies
		bpfreq@cell = {[1 4], [5 8], [9 14], [15 30], [30 50], [50 100], [1 250]}
		%> bandpass frequency names
		bpnames@cell = {'\delta','\theta','\alpha','\beta','\gamma low','\gamma high','all'}
	end

	%------------------DEPENDENT PROPERTIES--------%
	properties (SetAccess = protected, Dependent = true)
		%> number of LFP channels
		nLFPs@double = 0
		%> number of LFP channels
		nSelection@double = 0
	end
	
	%------------------PRIVATE PROPERTIES----------%
	properties (SetAccess = private, GetAccess = private)
		%> allowed properties passed to object upon construction
		allowedProperties@char = 'lfpfile|spikefile|dir|demeanLFP|baselineWindow|selectedLFP|LFPWindow|plotRange|selectedBehaviour|verbose'
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
		function ego = LFPAnalysis(varargin)
			if nargin == 0; varargin.name = 'LFPAnalysis';end
			ego=ego@analysisCore(varargin); %superclass constructor
			if nargin>0; ego.parseArgs(varargin, ego.allowedProperties); end
			if isempty(ego.name);ego.name = 'LFPAnalysis'; end
			if isempty(ego.lfpfile);getFiles(ego, true);end
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
			if force == true || isempty(ego.lfpfile)
				[f,p] = uigetfile({'*.plx;*.pl2';'Plexon Files'},'Load Continuous LFP File');
				if ischar(f) && ~isempty(f)
					ego.lfpfile = f;
					ego.dir = p;
					ego.paths.oldDir = pwd;
					cd(ego.dir);
					ego.p = plxReader('file', ego.lfpfile, 'dir', ego.dir);
					ego.p.name = ['^' ego.fullName '^'];
					getFiles(ego.p);
				else
					return
				end
			end
			if force == true || isempty(ego.spikefile)
				[f,p] = uigetfile({'*.plx;*.pl2';'Plexon Files'},['Load Spike LFP File to match ' ego.lfpfile]);
				if ischar(f) && ~isempty(f)
					ego.spikefile = f;
					in = struct('file', ego.spikefile, 'dir', ego.dir);
					ego.sp = spikeAnalysis(in);
					ego.sp.name = ['^' ego.fullName '^'];
					in = struct('matfile', ego.p.matfile, 'matdir', ego.p.matdir,'edffile',ego.p.edffile);
					if strcmpi(ego.lfpfile, ego.spikefile)
						inheritPlxReader(ego.sp, ego.p);
					else
						setFiles(ego.sp, in);
					end
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
			if isempty(ego.lfpfile)
				getFiles(ego,true);
				if isempty(ego.lfpfile);return;end
			end
			ego.yokedSelection = false;
			ego.mversion = str2double(regexp(version,'(?<ver>^\d\.\d[\d]?)','match','once'));
			if ego.mversion < 8.2
				error('LFP Analysis requires Matlab >= 2013b!!!')
			end
			ego.paths.oldDir = pwd;
			cd(ego.dir);
			ego.LFPs = struct();
			ego.LFPs = readLFPs(ego.p);
			ego.ft = struct();
			ego.results = struct();
			parseLFPs(ego);
			select(ego);
			getFieldTripLFPs(ego);
			plot(ego,'all');
		end
		
		
		% ===================================================================
		%> @brief
		%>
		%> @param
		%> @return
		% ===================================================================
		function reparse(ego)
			parseLFPs(ego);
			select(ego);
			selectTrials(ego);
			getFieldTripLFPs(ego);
			plot(ego,'normal');
		end
		
		% ===================================================================
		%> @brief
		%>
		%> @param
		%> @return
		% ===================================================================
		function parseSpikes(ego)
			in.cutTrials = ego.cutTrials;
			in.selectedTrials = ego.selectedTrials;
			in.map = ego.map;
			in.plotRange = ego.plotRange;
			in.selectedBehaviour = ego.selectedBehaviour;
			setSelection(ego.sp, in); %set spike anal to same trials etc.
			syncData(ego.sp.p, ego.p); %copy any parsed data
			lazyParse(ego.sp); %lazy parse the spikes
			syncData(ego.p, ego.sp.p); %copy any new parsed data back
			showInfo(ego.sp);
		end
		
		% ===================================================================
		%> @brief
		%>
		%> @param
		%> @return
		% ===================================================================
		function useSpikeSelect(ego)
			
		end
		
		% ===================================================================
		%> @brief
		%>
		%> @param
		%> @return
		% ===================================================================
		function ft = getFieldTripLFPs(ego)
			ft_defaults;
			LFPs = ego.LFPs;
			tic
			ft = struct();
			olddir=pwd; cd(ego.dir);
			ft(1).hdr = ft_read_plxheader(ego.lfpfile);
			cd(olddir);
			ft.hdr.FirstTimeStamp = 0; %we use LFPs(1).sample-1 below to fake 0 start time
			ft.label = {LFPs(:).name};
			ft.time = cell(1);
			ft.trial = cell(1);
			ft.fsample = LFPs(1).recordingFrequency;
			ft.sampleinfo = [];
			ft.trialinfo = [];
			ft.cfg = struct;
			ft.cfg.dataset = ego.lfpfile;
			ft.cfg.headerformat = 'plexon_plx_v2';
			ft.cfg.dataformat = ft.cfg.headerformat;
			ft.cfg.eventformat = ft.cfg.headerformat;
			ft.cfg.trl = [];
			a=1;
			for k = 1:LFPs(1).nTrials
				ft.time{a} = LFPs(1).trials(k).time';
				for i = 1:ego.nLFPs
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
			
			fprintf('Parsing into fieldtrip format took %g ms\n',round(toc*1000));
			
			if ~isempty(ft)
				ego.ft = ft;
			end
		end
		
		% ===================================================================
		%> @brief
		%>
		%> @param
		%> @return
		% ===================================================================
		function ftPreProcess(ego, cfg, removeLineNoise)
			if isempty(ego.ft); getFieldTripLFPs(ego); end
			if ~exist('removeLineNoise','var');removeLineNoise = false;end
			if ~exist('cfg','var');cfg = [];end
			if isfield(ego.ft,'ftOld')
				ft = ego.ft.ftOld;
			else
				ft = ego.ft;
			end
			if removeLineNoise == true;
				cfg.dftfilter = 'yes';
				cfg.dftfreq = [50 100 150];
				disp('---> Will remove 50 100 150Hz line noise!!!')
			end
			if ~isempty(cfg)
				ftp = ft_preprocessing(cfg, ft);
				ftp.uniquetrials = unique(ftp.trialinfo);
			end
			cfg = [];
			cfg.method   = 'trial';
			ftNew = ft_rejectvisual(cfg, ft);
			ftNew.uniquetrials = unique(ftNew.trialinfo);
			ftNew.ftOld = ft;
			ego.ft = ftNew;
		end
		
		% ===================================================================
		%> @brief
		%>
		%> @param
		%> @return
		% ===================================================================
		function cfg=ftTimeLockAnalysis(ego, cfg, statcfg)
			ego.results(1).av = [];
			ego.results(1).avstat = [];
			ft = ego.ft;			
			if ~exist('cfg','var') || isempty(cfg); cfg = []; end
			if isnumeric(cfg) && length(cfg) == 2; w=cfg;cfg=[];cfg.covariancewindow=w; end
			if ~isfield(cfg,'covariancewindow');cfg.covariancewindow = ego.measureRange;end
			cfg.keeptrials					= 'yes';
			cfg.removemean					= 'no';
			cfg.covariance					= 'yes';
			cfg.channel						= ft.label{ego.selectedLFP};
			for i = 1:ego.nSelection
				cfg.trials					= ego.selectedTrials{i}.idx;
				av{i}							= ft_timelockanalysis(cfg, ft);
				av{i}.cfgUsed				= cfg;
				av{i}.name					= ego.selectedTrials{i}.name;
				idx1							= ego.findNearest(av{i}.time, ego.baselineWindow(1));
				idx2							= ego.findNearest(av{i}.time, ego.baselineWindow(2));
				av{i}.baselineWindow		= ego.baselineWindow;
				%tr = squeeze(av{i}.trial(:,:,idx1:idx2)); tr=mean(tr');
				tr = av{i}.avg(idx1:idx2);
				[av{i}.baseline, err]	= stderr(tr(:),'2SD');
				if length(err) == 1
					av{i}.baselineCI			= [av{i}.baseline - err, av{i}.baseline + err];
				else
					av{i}.baselineCI			= [err(1), err(2)];
				end
			end
			
			ego.results(1).av = av;
			
			if exist('statcfg','var');	cfg					= statcfg;
			else cfg													= []; end
			cfg.channel												= ft.label{ego.selectedLFP};
			if ~isfield(cfg,'latency'); cfg.latency		= ego.measureRange; end
			cfg.avgovertime										= 'no'; 
			cfg.parameter											= 'trial';
			if ~isfield(cfg,'method');cfg.method			= 'analytic'; end %'analytic'; % 'montecarlo'
			if ~isfield(cfg,'statistic'); cfg.statistic	= 'indepsamplesT'; end %'indepsamplesT'
			if ~isfield(cfg,'alpha'); cfg.alpha				= ego.alpha; end
			cfg.numrandomization									= 5000;
			cfg.resampling											= 'permutation'; %bootstrap
			cfg.tail													= 0; %two tail
			cfg.correcttail										= 'prob';
			cfg.correctm											= 'bonferroni'; %holm fdr hochberg bonferroni
			cfg.design												= [ones(size(av{1}.trial,1),1); 2*ones(size(av{2}.trial,1),1)]';
			cfg.ivar													= 1;
			stat														= ft_timelockstatistics(cfg, av{1}, av{2});
			ego.results.avstat									= stat;
			cfg.avgovertime										= 'yes'; 
			stat														= ft_timelockstatistics(cfg, av{1}, av{2});
			ego.results.avstatavg								= stat;
			if ego.doPlots; drawTimelockLFPs(ego); end
		end
		
		% ===================================================================
		%> @brief ftBandPass performs Leopold et al., 2003 type BLP
		%>
		%> @param order of BP filter to use
		%> @param downsample whether to down/resample after filtering
		%> @param rectify whether to rectify the responses
		%> @return
		% ===================================================================
		function ftBandPass(ego,order,downsample,rectify)
			if ~exist('order','var') || isempty(order); order = 4; end
			if ~exist('downsample','var') || isempty(downsample); downsample = true; end
			if ~exist('rectify','var') || isempty(rectify); rectify = 'yes'; end
			if rectify == true; rectify = 'yes'; end
			
			ft = ego.ft;
			results.bp = [];
			
			for j = 1:length(ego.bpfreq)
				cfg						= [];
				cfg.channel				= ft.label{ego.selectedLFP};
				cfg.padding				= 0;
				cfg.bpfilter			= 'yes';
				cfg.bpfilttype			= 'but';
				cfg.bpfreq				= ego.bpfreq{j};
				cfg.bpfiltdir			= 'twopass'; %filter direction, 'twopass', 'onepass' or 'onepass-reverse' (default = 'twopass')
				cfg.bpfiltord			= order;
				cfg.bpinstabilityfix	= 'reduce';
				cfg.rectify				= rectify;
				cfg.demean				= 'yes'; %'no' or 'yes', whether to apply baseline correction (default = 'no')
				cfg.baselinewindow		= ego.baselineWindow; %[begin end] in seconds, the default is the complete trial (default = 'all')
				cfg.detrend				= 'no'; %'no' or 'yes', remove linear trend from the data (done per trial) (default = 'no')
				cfg.derivative			= 'no'; %'no' or 'yes', computes the first order derivative of the data (default = 'no')
				disp(['===> FILTER BP = ' ego.bpnames{j} ' --> ' num2str(cfg.bpfreq)]);
				disp('')
				bp{j} = ft_preprocessing(cfg,ft);
				bp{j}.freq = ego.bpfreq{j};
				bp{j}.uniquetrials = unique(bp{j}.trialinfo);
				bp{j}.downsample = downsample;
				if downsample == true
					cfg						= [];
					cfg.channel				= ft.label{ego.selectedLFP};
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
					disp(['===> DOWNSAMPLE = ' ego.bpnames{j}]);
					bp{j} = ft_resampledata(cfg,bp{j});
					
					bp{j}.freq = ego.bpfreq{j};
					bp{j}.uniquetrials = unique(bp{j}.trialinfo);
					bp{j}.downsample = downsample;
				end
				for i = 1:ego.nSelection
					cfg						= [];
					cfg.keeptrials			= 'no';
					cfg.removemean			= 'no';
					cfg.covariance			= 'yes';
					cfg.covariancewindow	= [0.05 0.2];
					cfg.channel				= ft.label{ego.selectedLFP};
					cfg.trials				= ego.selectedTrials{i}.idx;
					bp{j}.av{i} = ft_timelockanalysis(cfg,bp{j});
					bp{j}.av{i}.cfgUsed = cfg;
					if strcmpi(cfg.covariance,'yes')
						disp(['-->> Covariance for ' ego.selectedTrials{i}.name ' = ' num2str(mean(bp{j}.av{i}.cov))]);
					end
				end
			end
			ego.results(1).bp = bp;
			if ego.doPlots; drawBandPass(ego); end
		end
		
		% ===================================================================
		%> @brief ftBandPass performs Leopold et al., 2003 type BLP
		%>
		%> @param order of BP filter to use
		%> @param downsample whether to down/resample after filtering
		%> @param rectify whether to rectify the responses
		%> @return
		% ===================================================================
		function ftHilbert(ego,order,downsample,rectify)
			if ~exist('order','var'); order = 2; end
			if ~exist('downsample','var'); downsample = true; end
			if ~exist('rectify','var'); rectify = 'yes'; end
			if rectify == true; rectify = 'yes'; end
			
			ft = ego.ft;
			results.bp = [];
			
		end
		
		% ===================================================================
		%> @brief
		%>
		%> @param
		%> @return
		% ===================================================================
		function cfgUsed=ftFrequencyAnalysis(ego, cfg, preset, tw, cycles, smth, width)
			if ~exist('preset','var') || isempty(preset); preset='fix1'; end
			if ~exist('tw','var') || isempty(tw); tw=0.2; end
			if ~exist('cycles','var') || isempty(cycles); cycles = 5; end
			if ~exist('smth','var') || isempty(smth); smth = 0.4; end
			if ~exist('width','var') || isempty(width); width = 10; end
			if ~isfield(ego.ft,'label'); getFieldTripLFPs(ego); end
			if isfield(ego.results(1),['fq' preset]);ego.results(1).(['fq' preset]) = [];end
			if isempty(ego.ft);disp('No parsed data yet...');return;end
			ft = ego.ft;
			cfgUsed = {};
			if ~exist('cfg','var') || isempty(cfg)
				cfg				= [];
				cfg.keeptrials	= 'yes';
				cfg.output		= 'pow';
				cfg.channel		= ft.label{ego.selectedLFP};
				cfg.toi         = -0.3:0.01:0.3;                  % time window "slides"
				cfg.tw			= tw;
				cfg.cycles		= cycles;
				cfg.width		= width;
				cfg.smooth		= smth;
				switch preset
					case 'fix1'
						cfg.method			= 'mtmconvol';
						cfg.taper			= 'hanning';
						lf						= round(1 / cfg.tw);
						cfg.foi				= lf:2:80;						  % analysis frequencies
						cfg.t_ftimwin		= ones(length(cfg.foi),1).*tw;   % length of fixed time window
					case 'fix2'
						cfg.method			= 'mtmconvol';
						cfg.taper			= 'hanning';
						cfg.foi				= 2:2:80;						 % analysis frequencies
						cfg.t_ftimwin		= cycles./cfg.foi;			 % x cycles per time window
					case 'mtm1'
						cfg.method			= 'mtmconvol';
						cfg.taper			= 'dpss';
						cfg.foi				= 2:2:80;						 % analysis frequencies
						cfg.tapsmofrq		= cfg.foi * cfg.smooth;
						cfg.t_ftimwin		= cycles./cfg.foi;			 % x cycles per time window
					case 'mtm2'
						cfg.method			= 'mtmconvol';
						cfg.taper			= 'dpss';
						cfg.foi				= 2:2:80;						 % analysis frequencies
					case 'morlet'
						cfg.method			= 'wavelet';
						cfg.taper			= '';
						cfg.width			= width;
						cfg.foi				= 2:2:80;						 % analysis frequencies
				end
			elseif ~isempty(cfg)
				preset = 'custom';
			end
			for i = 1:ego.nSelection
				cfg.trials = ego.selectedTrials{i}.idx;
				fq{i} = ft_freqanalysis(cfg,ft);
				fq{i}.cfgUsed=cfg;
				fq{i}.name = ego.selectedTrials{i}.name;
				cfgUsed{i} = cfg;
			end
			ego.results(1).(['fq' preset]) = fq;
			if ego.doPlots
				plot(ego,'freq',['fq' preset]);
			end
			ftFrequencyStats(ego, ['fq' preset],{'no','relative','absolute'});
		end
		
		% ===================================================================
		%> @brief
		%>
		%> @param
		%> @return
		% ===================================================================
		function ftFrequencyStats(ego,name,bline,range)
			if ~exist('name','var') || isempty('name');name='fqfix1';end
			if ~exist('bline','var') || isempty(bline);bline='no';end
			if ~exist('range','var') || isempty(range);range=ego.measureRange;end
			if ~isfield(ego.results,name); disp('No frequency data parsed...'); return; end
			ft = ego.ft;
			fq = ego.results.(name);

			if ~iscell(bline)
				bline = cellstr(bline);
			end
			
			for jj = 1:length(bline)
				thisbline = bline{jj};
				if ~strcmpi(thisbline,'no')
					cfg.baseline		= ego.baselineWindow;
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
				cfgd.channel			= ft.label{ego.selectedLFP};
				cfgd.foilim				= 'all';
				cfgd.toilim				= ego.baselineWindow;
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
				ego.results.([name 'bline']) = stat;

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
				ego.results.([name 'response']) = stat;
				ego.drawLFPFrequencyStats(name);
			end
		end
		
		% ===================================================================
		%> @brief
		%>
		%> @param
		%> @return
		% ===================================================================
		function cfgUsed=ftSpikeLFP(ego, unit, interpolate)
			if ~exist('unit','var') || isempty(unit); unit = ego.sp.selectedUnit;
			else ego.sp.selectedUnit = unit; end
			if ~exist('interpolate','var'); 
				interpolate = true; iVal = 0.0025;
			elseif isnumeric(interpolate)
				iVal = interpolate; interpolate = true; 
			else
				iVal = 0.0025;
			end
			if isempty(ego.sp.ft)
				plotTogether(ego); drawnow;
			end
			
			in.yokedSelection = true;
			in.cutTrials = ego.cutTrials;
			in.selectedTrials = ego.selectedTrials;
			in.map = ego.map;
			in.plotRange = ego.plotRange;
			in.selectedBehaviour = ego.selectedBehaviour;
			setSelection(ego.sp, in); %set spike anal to same trials etc
			
			ft = ego.ft;
			spike = ego.sp.ft;
			dat = ft_appendspike([],ft, spike);
			
			if interpolate
				try
					cfg					= [];
					cfg.method			= 'pchip'; % remove the replaced segment with interpolation
					cfg.timwin			= [-0.001 0.003]; % remove 3 ms around every spike
					%cfg.interptoi		= iVal*4; %value, time in seconds used for interpolation
					cfg.spikechannel	= spike.label{unit};
					cfg.channel			= ft.label;
					dati					= ft_spiketriggeredinterpolation(cfg, dat);
				catch ME
					dati=dat;
					warning('Spike Interpolation of LFP failed, using raw data');
					disp(getReport(ME,'extended'));
					pause(1);
				end
			end
			
			for j = 1:length(ego.selectedTrials)
				name				= ['SPIKE:' spike.label{unit} ' | SEL: ' ego.selectedTrials{j}.name];
				tempft			= ego.subselectFieldTripTrials(ft,ego.selectedTrials{j}.idx);
				tempspike		= ego.subselectFieldTripTrials(spike,ego.selectedTrials{j}.idx);
				tempdat			= ego.subselectFieldTripTrials(dati,ego.selectedTrials{j}.idx);
				
				cfg							= [];
				cfg.timwin					= [-0.1 0.1]; 
				cfg.spikechannel			= spike.label{unit};
				cfg.channel					= ft.label;
				cfg.latency					= [-0.25 0.05];
				staPre						= ft_spiketriggeredaverage(cfg, tempdat);
				ego.ft.staPre{j}			= staPre;
				ego.ft.staPre{j}.name	= name;
				
				cfg.latency					= [0.05 0.18];
				staPost						= ft_spiketriggeredaverage(cfg, tempdat);
				ego.ft.staPost{j}			= staPost;
				ego.ft.staPost{j}.name	= name;
				
				cfg							= [];
				cfg.method					= 'mtmfft';
				cfg.latency					= [0 0.25];
				cfg.foilim					= [0 80]; % cfg.timwin determines spacing [begin end], time around each spike (default = [-0.1 0.1])
				cfg.timwin					= [-0.02 0.02]; %[begin end], time around each spike (default = [-0.1 0.1])
				%cfg.tapsmofrq = number, the amount of spectral smoothing through multi-tapering. Note that 4 Hz smoothing means plus-minus 4 Hz,i.e. a 8 Hz smoothing box. Note: multitapering rotates phases (no problem for consistency)
				cfg.taper					= 'hanning';
				cfg.spikechannel			= spike.label{unit};
				cfg.channel					= ft.label{ego.selectedLFP};
				stsFFT						= ft_spiketriggeredspectrum(cfg, tempdat, tempspike);
				
				ang = squeeze(angle(stsFFT.fourierspctrm{1}));
				mag = squeeze(abs(stsFFT.fourierspctrm{1}));
				ego.ft.stsFFT{j} = stsFFT;
				ego.ft.stsFFT{j}.name = name;
				ego.ft.stsFFT{j}.ang=ang;
				ego.ft.stsFFT{j}.mag=mag;
				
				cfg							= [];
				cfg.method					= 'mtmconvol';
				cfg.latency					= [0 0.25];
				%cfg.tapsmofrq	= vector 1 x numfoi, the amount of spectral smoothing through multi-tapering. Note that 4 Hz smoothing means plus-minus 4 Hz, i.e. a 8 Hz smoothing box.
				cfg.foi						= 5:5:80; %vector 1 x numfoi, frequencies of interest
				cfg.t_ftimwin				= 5./cfg.foi; % vector 1 x numfoi, length of time window (in seconds)
				cfg.taper					= 'hanning';
				cfg.spikechannel			= spike.label{unit};
				cfg.channel					= ft.label{ego.selectedLFP};
				stsConvol					= ft_spiketriggeredspectrum(cfg, tempdat, tempspike);
				
				ang = squeeze(angle(stsConvol.fourierspctrm{1}));
				mag = squeeze(abs(stsConvol.fourierspctrm{1}));
				ego.ft.stsConvol{j} = stsConvol;
				ego.ft.stsConvol{j}.name = name;
				ego.ft.stsConvol{j}.ang=ang;
				ego.ft.stsConvol{j}.mag=mag;
				
				cfg.latency					= []; %we now reset just in case stat is affected by this
				stsConvol					= ft_spiketriggeredspectrum(cfg, tempdat, tempspike);
				
				cfg               = [];
				cfg.method        = 'ppc0'; % compute the Pairwise Phase Consistency
				cfg.spikechannel	= spike.label{unit};
				cfg.channel			= ft.label{ego.selectedLFP};
				cfg.avgoverchan   = 'unweighted'; % weight spike-LFP phases irrespective of LFP power
				cfg.timwin        = 'all'; % compute over all available spikes in the window
				cfg.latency       = [0.05 0.2]; % sustained visual stimulation period
				statSts           = ft_spiketriggeredspectrum_stat(cfg,stsConvol);
				ego.ft.statSts0{j} = statSts;
				ego.ft.statSts0{j}.name = name;
				
				cfg               = [];
				cfg.method        = 'ppc1'; % compute the Pairwise Phase Consistency
				cfg.spikechannel	= spike.label{unit};
				cfg.channel			= ft.label{ego.selectedLFP};
				cfg.avgoverchan   = 'unweighted'; % weight spike-LFP phases irrespective of LFP power
				cfg.timwin        = 'all'; % compute over all available spikes in the window
				cfg.latency       = [0.05 0.2]; % sustained visual stimulation period
				statSts           = ft_spiketriggeredspectrum_stat(cfg,stsConvol);
				ego.ft.statSts1{j} = statSts;
				ego.ft.statSts1{j}.name = name;
				
				cfg               = [];
				cfg.method        = 'ppc2'; % compute the Pairwise Phase Consistency
				cfg.spikechannel	= spike.label{unit};
				cfg.channel			= ft.label{ego.selectedLFP};
				cfg.avgoverchan   = 'unweighted'; % weight spike-LFP phases irrespective of LFP power
				cfg.timwin        = 'all'; % compute over all available spikes in the window
				cfg.latency       = [0.05 0.2]; % sustained visual stimulation period
				statSts           = ft_spiketriggeredspectrum_stat(cfg,stsConvol);
				ego.ft.statSts2{j} = statSts;
				ego.ft.statSts2{j}.name = name;

			end
			if ego.doPlots; drawSpikeLFP(ego); end
		end
		
		% ===================================================================
		%> @brief
		%>
		%> @param
		%> @return
		% ===================================================================
		function plotTogether(ego,unit)
			if ~exist('unit','var'); unit = ego.sp.selectedUnit;
			else ego.sp.selectedUnit = unit; end
			
			if isempty(ego.ft)
				dp = ego.doPlots; ego.doPlots = false;
				parse(ego);
				ego.doPlots = dp;
			end
			if isempty(ego.sp.ft)
				parseSpikes(ego);
			end
			
			in.yokedSelection = true;
			in.cutTrials = ego.cutTrials;
			in.selectedTrials = ego.selectedTrials;
			in.map = ego.map;
			in.plotRange = ego.plotRange;
			in.selectedBehaviour = ego.selectedBehaviour;
			setSelection(ego.sp, in); %set spike anal to same trials etc
			
			ft_defaults
			ego.sp.density;
			
			h=figure;figpos(1,[1000 1500]);set(h,'Color',[1 1 1],'Name','Density LFP Co-Plot');
			p=panel(h);
			p.margin = [20 20 20 20]; %left bottom right top
			[row,col]=ego.optimalLayout(ego.nSelection);
			p.pack(row,col);
			for j = 1:length(ego.selectedTrials)
				[i1,i2] = ind2sub([row,col], j);
				p(i1,i2).select();
				t = ['LFP: ' ego.LFPs(ego.selectedLFP).name ' | Unit: ' ego.sp.names{ego.sp.selectedUnit} ' | Sel:' ego.selectedTrials{j}.name];
				[time,av,er]=getAverageTuningCurve(ego,ego.selectedTrials{j}.idx, ego.selectedLFP);
				h1 = areabar(time,av,er,[],[],'k.-');
				axis(h1.axis,[ego.plotRange(1) ego.plotRange(2) -inf inf]);
				ylabel(h1.axis,'Voltage (mV)');
				xlabel(h1.axis,'Time (s)');
				box(h1.axis,'off');
				set(h1.axis,'XColor','k','YColor','k','XGrid','on','XMinorGrid','on','Layer','bottom');
				h1_pos = get(h1.axis,'Position'); % store position of first axes
				h2.axis = axes('Position',h1_pos,...
					'XAxisLocation','top',...
					'YAxisLocation','right',...
					'Color','none');
				set(h2.axis,'XColor','k','YColor','k','XTickLabel',{});
				axis(h2.axis);
				hold(h2.axis,'on');
				
				time2 = ego.sp.ft.sd{j}.time;
				av2 = ego.sp.ft.sd{j}.avg;
				er2 = ego.var2SE(ego.sp.ft.sd{j}.var,ego.sp.ft.sd{j}.dof);
				h=areabar(time2,av2,er2,[0.7 0.5 0.5],[],'r.-');
				h2.axish = h;
				axis(h2.axis,[ego.plotRange(1) ego.plotRange(2) -inf inf]);
				ylabel(h2.axis,'Firing Rate (Hz)');
				box(h2.axis,'off')
				p(i1,i2).title(t);
			end
			
		end
		
		% ===================================================================
		%> @brief
		%>
		%> @param
		%> @return
		% ===================================================================
		function plot(ego, varargin)
			if isempty(ego.LFPs) || ego.doPlots == false;
				disp('Nothing parsed or doPlots is false, no plotting performed...')
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
				case 'normal'
					ego.drawTrialLFPs();
					ego.drawAverageLFPs();
				case 'all'
					ego.drawContinuousLFPs();
					ego.drawTrialLFPs();
					ego.drawAverageLFPs();
					ego.drawTimelockLFPs();
				case 'continuous'
					ego.drawContinuousLFPs();
				case {'trials','raw'}
					ego.drawTrialLFPs();
				case {'av','average'}
					ego.drawAverageLFPs();
				case {'timelock','tlock','tl'}
					ego.drawTimelockLFPs();
				case {'freq','frequency','f'}
					ego.drawLFPFrequencies(args(:));
				case {'bp','bandpass'}
					ego.drawBandPass();
				case {'slfp','spikelfp'}
					ego.drawSpikeLFP();
				case {'both','together'}
					ego.plotTogether();
				case {'freqstats','fstats','fstat'}
					ego.drawLFPFrequencyStats();
			end
			
			
		end
		
		% ===================================================================
		%> @brief
		%> @param
		%> @return
		% ===================================================================
		function nLFPs = get.nLFPs(ego)
			nLFPs = 0;
			if ~isempty(ego.LFPs)
				nLFPs = length(ego.LFPs);
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
		%> @brief
		%> @param
		%> @return
		% ===================================================================
		function save(ego)
			[~,f,~] = fileparts(ego.lfpfile);
			name = ['LFP' f];
			if ~isempty(ego.ft)
				name = [name '-ft'];
			end
			if isfield(ego.ft,'bp')
				name = [name '-BP'];
			end
			if isfield(ego.ft,'av')
				name = [name '-TL'];
			end
			name = [name '.mat'];
			[f,p] = uiputfile(name,'SAVE LFP Analysis File');
			if ischar(f) && ~isempty(f)
				od = pwd;
				cd(p);
				lfp = ego;
				save(f,'lfp');
				cd(od);
			end
		end
		
		% ===================================================================
		%> @brief selectTrials selects trials based on many filters
		%>
		%> @param
		%> @return
		% ===================================================================
		function select(ego)
			if ego.nLFPs<1; warningdlg('Data not parsed yet...');return;end
			cuttrials = '[ ';
			if ~isempty(ego.cutTrials)
				cuttrials = [cuttrials num2str(ego.cutTrials)];
			elseif ~isempty(ego.cutTrials)
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
			
			lfp = 'p';
			for i = 1:ego.nLFPs
				if i == ego.selectedLFP
					lfp = [lfp '|¤' num2str(i)];
				else
					lfp = [lfp '|' num2str(i)];
				end
			end
			
			inbeh = {'correct','breakFix','incorrect','all'};
			beh = 'r';
			for i = 1:length(inbeh)
				if strcmpi(inbeh{i}, ego.selectedBehaviour)
					beh = [beh '|¤' inbeh{i}];
				else
					beh = [beh '|' inbeh{i}];
				end
			end
			
			mrange = ego.measureRange;
			
			mtitle   = ['REPARSE ' num2str(ego.LFPs(1).nVars) ' DATA VARIABLES'];
			options  = {['t|' map{1}],'Choose PLX variables to merge (A, if empty parse all variables independantly):';   ...
				['t|' map{2}],'Choose PLX variables to merge (B):';   ...
				['t|' map{3}],'Choose PLX variables to merge (C):';   ...
				['t|' cuttrials],'Enter Trials to exclude:';   ...
				[lfp],'Choose Default LFP Channel to View:';...
				[beh],'Behavioural type (''correct'', ''breakFix'', ''incorrect'' | ''all''):';...
				['t|' num2str(mrange)],'Measurement Range (s) for Statistical Comparisons:';...
				};
			
			answer = menuN(mtitle,options);
			drawnow;
			if iscell(answer) && ~isempty(answer)
				map{1} = str2num(answer{1}); map{2} = str2num(answer{2}); map{3} = str2num(answer{3});
				ego.cutTrials = str2num(answer{4});
				ego.map = map;
				ego.selectedLFP = answer{5};
				ego.selectedBehaviour = inbeh{answer{6}};
				ego.measureRange = str2num(answer{7});
				selectTrials(ego);
			end
		end
		
		% ===================================================================
		%> @brief
		%>
		%> @param
		%> @return
		% ===================================================================
		function set.demeanLFP(ego,in)
			if ~isequal(ego.demeanLFP,logical(in))
				ego.demeanLFP = logical(in);
				disp('You should REPARSE the LFP data to enable this change')
			end
		end
		
		% ===================================================================
		%> @brief
		%>
		%> @param
		%> @return
		% ===================================================================
		function set.baselineWindow(ego,in)
			if isnumeric(in) && length(in)==2 && ~isequal(ego.baselineWindow, in)
				ego.demeanLFP = in;
				disp('You should REPARSE the LFP data to enable this change')
			end
		end
		
		% ===================================================================
		%> @brief
		%>
		%> @param
		%> @return
		% ===================================================================
		function set.LFPWindow(ego,in)
			if isnumeric(in) && length(in)==1 && ~isequal(ego.LFPWindow, in)
				ego.LFPWindow = in;
				disp('You should PARSE the LFP data to enable this change')
			end
		end

	end
	
	%=======================================================================
	methods ( Access = protected ) %-------PRIVATE METHODS-----%
	%=======================================================================
		
		% ===================================================================
		%> @brief
		%>
		%> @param
		%> @return
		% ===================================================================
		function LFPs = parseLFPs(ego)
			if ego.nLFPs == 0
				LFPs = readLFPs(ego.p);
			else
				LFPs = ego.LFPs;
			end
			tic
			window = ego.LFPWindow; winsteps = round(window/1e-3);
			demeanW = round(ego.baselineWindow/1e-3) - 1;
			for j = 1:length(LFPs)
				time		= LFPs(j).time;
				sample	= LFPs(j).sample;
				data		= LFPs(j).data;
				minL		= Inf;
				maxL		= 0;
				trials	= ego.p.eventList.trials;
				for k = 1:ego.p.eventList.nTrials
					[idx1, val1, dlta1] = ego.findNearest(time, trials(k).t1);
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
					if ego.demeanLFP == true
						trials(k).data = trials(k).data - trials(k).prestimMean;
					end
					trials(k).demean = ego.demeanLFP;
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
			
			fprintf('Parsing LFPs into trials with event markers took %g ms\n',round(toc*1000));
			
			if ~isempty(LFPs(1).trials)
				ego.LFPs = LFPs;
			end
		end
		
		% ===================================================================
		%> @brief selectTrials selects trials based on several filters
		%>
		%> @param
		%> @return
		% ===================================================================
		function selectTrials(ego)
			LFPs = ego.LFPs; %#ok<*PROP>
			
			switch lower(ego.selectedBehaviour)
				case 'correct'
					behaviouridx = find([LFPs(1).trials.isCorrect]==true);
				case 'breakfix'
					behaviouridx = find([LFPs(1).trials.isBreak]==true);
				case 'incorrect'
					behaviouridx = find([LFPs(1).trials.isIncorrect]==true);
				otherwise
					behaviouridx = find([LFPs(1).trials.isCorrect]==true);
			end
			
			cutidx = ego.cutTrials;
			saccidx = [];
			roiidx = [];
			toiidx = [];
			
			if isempty(ego.map{1})
				for i = 1:LFPs(1).nVars; map{i} = ego.p.eventList.unique(i); end
			else
				map = ego.map; %#ok<*PROP>
			end
			
			ego.selectedTrials = {};
			a = 1;
			
			for i = 1:length(map)
				idx = []; if isempty(map{i}); continue; end
				for j = 1:length(map{i})
					idx = [ idx find( [LFPs(1).trials.variable] == map{i}(j) ) ];
				end
				idx = intersect(idx, behaviouridx); %this has a positive side effect of also sorting the trials
				if ~isempty(cutidx);	idx = setdiff(idx, cutidx);		end %remove the cut trials
				if ~isempty(idx)
					ego.selectedTrials{a}.idx			= idx;
					ego.selectedTrials{a}.cutidx		= cutidx;
					ego.selectedTrials{a}.roiidx		= roiidx;
					ego.selectedTrials{a}.toiidx		= toiidx;
					ego.selectedTrials{a}.saccidx		= saccidx;
					ego.selectedTrials{a}.behaviour	= ego.selectedBehaviour;
					ego.selectedTrials{a}.sel			= map{i};
					ego.selectedTrials{a}.name			= ['[' num2str(ego.selectedTrials{a}.sel) ']' ' #' num2str(length(idx)) '|' ego.selectedTrials{a}.behaviour];
					a = a + 1;
				end
			end
			if ego.nSelection == 0; warndlg('The selection results in no valid trials to process!'); end
			for j = 1:ego.nSelection
				fprintf(' SELECT TRIALS GROUP %g\n=======================\nInfo: %s\nTrial Index: %s\n-Cut Index: %s\nBehaviour: %s\n',...
					j,ego.selectedTrials{j}.name,num2str(ego.selectedTrials{j}.idx),num2str(ego.selectedTrials{j}.cutidx),...
					ego.selectedBehaviour);
			end
		end
		
		% ===================================================================
		%> @brief
		%>
		%> @param
		%> @return
		% ===================================================================
		function h=drawTrialLFPs(ego, h, sel)
			disp('Drawing RAW LFP Trials...')
			if ~exist('h','var')
				h=figure;figpos(1,[1920 1080]);set(h,'Color',[1 1 1]);
			end
			clf(h,'reset')
			if ~exist('sel','var')
				sel = ego.selectedLFP;
			end
			
			LFP = ego.LFPs(sel);
			cut = ego.cutTrials;
			p=panel(h);
			p.margin = [20 20 10 15]; %left bottom right top
			[row,col]=ego.optimalLayout(ego.nSelection);
			p.pack(row,col);
			for j = 1:length(ego.selectedTrials)
				[i1,i2] = ind2sub([row,col], j);
				p(i1,i2).select();
				p(i1,i2).title(['LFP & EVENT PLOT: File:' ego.lfpfile ' | Channel:' LFP.name ' | Group:' num2str(j) ' | Name:' ego.selectedTrials{j}.name]);
				p(i1,i2).xlabel('Time (s)');
				p(i1,i2).ylabel('LFP Raw Amplitude (mV)');
				p(i1,i2).hold('on');
				c = ego.optimalColours(length(ego.selectedTrials{j}.idx));
				for k = 1:length(ego.selectedTrials{j}.idx)
					trial = LFP.trials(ego.selectedTrials{j}.idx(k));
					dat = [trial.variable,trial.index,trial.t1,trial.isCorrect,trial.isBreak];
					if ismember(trial.index,cut);
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
				[time,avg,err]=getAverageTuningCurve(ego, ego.selectedTrials{j}.idx, ego.selectedLFP);
				areabar(time, avg, err,[0.5 0.5 0.5],0.6,'k-','MarkerFaceColor',[0 0 0],'LineWidth',1);
				p(i1,i2).hold('off');
				axis([ego.plotRange(1) ego.plotRange(2) -inf inf]);
			end
			%dc = datacursormode(gcf);
			%set(dc,'UpdateFcn', @lfpCursor, 'Enable', 'on', 'DisplayStyle','window');
			
			uicontrol('Style', 'pushbutton', 'String', '<<',...
				'Position',[1 1 50 20],'Callback',@previousChannel);
			uicontrol('Style', 'pushbutton', 'String', '>>',...
				'Position',[52 1 50 20],'Callback',@nextChannel);
			
			ego.panels.raw = p;
			
			function nextChannel(src,~)
				ego.selectedLFP = ego.selectedLFP + 1;
				if ego.selectedLFP > length(ego.LFPs)
					ego.selectedLFP = 1;
				end
				drawTrialLFPs(ego,gcf,ego.selectedLFP);
			end
			function previousChannel(src,~)
				ego.selectedLFP = ego.selectedLFP - 1;
				if ego.selectedLFP < 1
					ego.selectedLFP = length(ego.LFPs);
				end
				drawTrialLFPs(ego,gcf,ego.selectedLFP);
			end
			
			function clickMe(src, ~)
				if ~exist('src','var')
					return
				end
				ud = get(src,'UserData');
				tg = get(src,'Tag');
				disp(['Clicked on: ' tg]);
				if ~isempty(ud) && length(ud) > 1
					var = ud(1);
					trl = ud(2);
					t1 = ud(3);
					
					if intersect(trl, ego.cutTrials);
						ego.cutTrials(ego.cutTrials == trl) = [];
						set(src,'LineStyle','-','LineWidth',0.5);
					else
						ego.cutTrials = [ego.cutTrials trl];
						set(src,'LineStyle',':','LineWidth',2);
					end
					disp(['Current Selected trials : ' num2str(ego.cutTrials)]);
				end
			end
			
		end
		
		% ===================================================================
		%> @brief
		%>
		%> @param
		%> @return
		% ===================================================================
		function drawAverageLFPs(ego)
			disp('Drawing Averaged (Reparsed) Timelocked LFPs...')
			LFPs = ego.LFPs;
			if LFPs(1).reparse == true;
				h=figure;figpos(1,[1800 1800]);set(gcf,'Color',[1 1 1]);
				p=panel(h);
				p.margin = [20 20 10 15]; %left bottom right top
				[row,col]=ego.optimalLayout(ego.nLFPs);
				p.pack(row,col);
				for j = 1:length(LFPs)
					[i1,i2] = ind2sub([row,col], j);
					p(i1,i2).select();
					p(i1,i2).title(['TIMELOCK AVERAGES: File:' ego.lfpfile ' | Channel:' LFPs(j).name]);
					p(i1,i2).xlabel('Time (s)');
					p(i1,i2).ylabel('LFP Raw Amplitude (mV)');
					grid on; box on
					set(gca,'Layer','bottom')
					hold on
					c = ego.optimalColours(length(ego.selectedTrials));
					for k = 1:length(ego.selectedTrials)
						leg{k,1} = ego.selectedTrials{k}.name;
						[time,avg,err]=getAverageTuningCurve(ego, ego.selectedTrials{k}.idx, j);
						areabar(time, avg, err, c(k,:)/2, 0.3, 'k.-', 'Color', c(k,:), 'MarkerFaceColor', c(k,:), 'LineWidth', 2);
					end
					legend(leg);
					p(i1,i2).hold('off');
					axis([ego.plotRange(1) ego.plotRange(2) -inf inf]);
				end
			end
		end
		
		% ===================================================================
		%> @brief
		%>
		%> @param
		%> @return
		% ===================================================================
		function drawTimelockLFPs(ego)
			disp('Drawing Averaged (Reparsed) Timelocked LFPs...')
			if isfield(ego.results,'av')
					av = ego.results.av;
					avstat = ego.results.avstat;
					avstatavg = ego.results.avstatavg;
					h=figure;figpos(1,[1700 1000]);set(gcf,'Color',[1 1 1]);
					p=panel(h);
					p.margin = [20 20 10 15]; %left bottom right top
					p.pack('v', {5/6 []})
					p(1).select();
					p(1).hold('on');
					
					xp = [avstat.cfg.latency(1) avstat.cfg.latency(2) avstat.cfg.latency(2) avstat.cfg.latency(1)];
					ym=mean(av{1}.avg(1,:));
					yp = [ym ym ym ym];
					mh = patch(xp,yp,[0.8 0.8 0.8],'FaceAlpha',0.5,'EdgeColor','none');
					set(get(get(mh,'Annotation'),'LegendInformation'),'IconDisplayStyle','off'); % Exclude line from legend
					
					xp = [ego.plotRange(1) ego.plotRange(2) ego.plotRange(2) ego.plotRange(1)];
					yp = [av{1}.baselineCI(1) av{1}.baselineCI(1) av{1}.baselineCI(2) av{1}.baselineCI(2)];
					me1 = patch(xp,yp,[0.8 0.8 1],'FaceAlpha',0.5,'EdgeColor','none');
					set(get(get(me1,'Annotation'),'LegendInformation'),'IconDisplayStyle','off'); % Exclude line from legend
					
					yp = [av{2}.baselineCI(1) av{2}.baselineCI(1) av{2}.baselineCI(2) av{2}.baselineCI(2)];
					me2 = patch(xp,yp,[1 0.8 0.8],'FaceAlpha',0.5,'EdgeColor','none');
					set(get(get(me2,'Annotation'),'LegendInformation'),'IconDisplayStyle','off'); % Exclude line from legend

					e = ego.var2SE(av{1}.var(1,:),av{1}.dof(1,:));
					areabar(av{1}.time, av{1}.avg(1,:), e,[.5 .5 .5],0.3,'b.-','LineWidth',1);
					e = ego.var2SE(av{2}.var(1,:),av{2}.dof(1,:));
					areabar(av{2}.time, av{2}.avg(1,:), e,[.5 .3 .3],0.3,'r.-','LineWidth',1);
					if length(av) == 2
						legend(av{1}.name,av{2}.name)
					elseif length(av) > 2
						e = ego.var2SE(av{3}.var(1,:),av{3}.dof(1,:));
						areabar(av{3}.time, av{3}.avg(1,:), e,[.3 .3 .5],0.3,'g.-','LineWidth',1);
						legend(av{1}.name,av{2}.name,av{3}.name);
					end
					
					ax=axis;
					set(mh,'YData',[ax(3) ax(3) ax(4) ax(4)]);
					
					pos = ax(4)-((ax(4)-ax(3))/20);
					times = avstat.time(logical(avstat.mask));
					pos = repmat(pos, size(times));
					text(times,pos,'*','FontSize',10);
					
					hold off
					grid on; box on
					axis([ego.plotRange(1) ego.plotRange(2) ax(3) ax(4)]);
					ax=axis;
					[c1,c1e]=stderr(av{1}.cov);
					[c2,c2e]=stderr(av{2}.cov);
					[pval]=ranksum(av{1}.cov,av{2}.cov,'alpha',ego.alpha);
					covt = num2str(av{1}.cfgUsed.covariancewindow);
					covt = regexprep(covt,' +',' ');
					xlabel('Time (s)');
					ylabel('LFP Raw Amplitude (mV) ±SEM');
					t=sprintf('COV = %.2g±%.2g <-> %.2g±%.2g [p = %.3g]',c1,c1e,c2,c2e,pval);
					tt=sprintf('%s | Ch: %s | p-val: %.3g [@%.2g]\n%s', ego.lfpfile, av{1}.label{:}, avstatavg.prob, ego.alpha, t);
					title(tt,'FontSize',14);
					
					p(2).select();
					p(2).hold('on');
					res1 = av{2}.avg(1,:) - av{1}.avg(1,:);
					plot(av{1}.time, res1,'b.-')
					if length(av) == 2
						legend('Group B-A')
					elseif length(av) > 2
						res2 = av{3}.avg(1,:) - av{1}.avg(1,:);
						res3 = av{3}.avg(1,:) - av{2}.avg(1,:);
						plot(av{1}.time, res2,'r.-')
						plot(av{1}.time, res3,'g.-')
						legend('Group B-A','Group C-A','Group C-B')
					end
					grid on; box on
					title('Residuals')
					xlim([ego.plotRange(1) ego.plotRange(2)]);
					xlabel('Time (s)');
					ylabel('Residuals (mV)');
				end
		end
		
		% ===================================================================
		%> @brief
		%>
		%> @param
		%> @return
		% ===================================================================
		function drawContinuousLFPs(ego)
			disp('Drawing Continuous LFP data...')
			%first plot is the whole raw LFP with event markers
			LFPs = ego.LFPs;
			figure;figpos(1,[2500 800]);set(gcf,'Color',[1 1 1]);
			title(['RAW LFP & EVENT PLOT: File:' ego.lfpfile ' | Channel: All | LFP: All']);
			xlabel('Time (s)');
			ylabel('LFP Raw Amplitude (mV)');
			hold on
			c = ego.optimalColours(length(LFPs));
			for j = 1:length(LFPs)
				h(j)=plot(LFPs(j).time, LFPs(j).data,'Color',c(j,:));
				name{j} = ['LFP ' num2str(j)];
				[av,sd] = stderr(LFPs(j).data,'SD');
				hl=line([LFPs(j).time(1) LFPs(j).time(end)],[av-(2*sd) av-(2*sd)],'Color',get(h(j),'Color'),'LineWidth',2, 'LineStyle','--');
				set(get(get(hl,'Annotation'),'LegendInformation'),'IconDisplayStyle','off'); % Exclude line from legend
				hl=line([LFPs(j).time(1) LFPs(j).time(end)],[av+(2*sd) av+(2*sd)],'Color',get(h(j),'Color'),'LineWidth',2, 'LineStyle','--');
				set(get(get(hl,'Annotation'),'LegendInformation'),'IconDisplayStyle','off'); % Exclude line from legend
			end
			axis([0 40 -.5 .5])
			disp('Drawing Event markers...')
			c = ego.optimalColours(ego.p.eventList.nVars);
			for j = 1:ego.p.eventList.nTrials
				trl = ego.p.eventList.trials(j);
				var = trl.variable;
				hl=line([trl.t1 trl.t1],[-.4 .4],'Color',c(var,:),'LineWidth',2);
				set(get(get(hl,'Annotation'),'LegendInformation'),'IconDisplayStyle','off'); % Exclude line from legend
				hl=line([trl.t2 trl.t2],[-.4 .4],'Color',c(var,:),'LineWidth',2);
				set(get(get(hl,'Annotation'),'LegendInformation'),'IconDisplayStyle','off'); % Exclude line from legend
				text(trl.t1,.41,['VAR: ' num2str(var) '\newlineTRL: ' num2str(j)],'FontSize',10);
				text(trl.t1,-.41,['COR: ' num2str(trl.isCorrect)],'FontSize',10);
			end
			plot(ego.p.eventList.startFix,zeros(size(ego.p.eventList.startFix))-0.35,'c.','MarkerSize',15);
			plot(ego.p.eventList.correct,zeros(size(ego.p.eventList.correct))-0.35,'g.','MarkerSize',15);
			plot(ego.p.eventList.breakFix,zeros(size(ego.p.eventList.breakFix))-0.35,'b.','MarkerSize',15);
			plot(ego.p.eventList.incorrect,zeros(size(ego.p.eventList.incorrect))-0.35,'r.','MarkerSize',15);
			name{end+1} = 'start fixation';
			name{end+1} = 'correct';
			name{end+1} = 'break fix';
			name{end+1} = 'incorrect';
			legend(name,'Location','NorthWest')
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
		function drawSpikeLFP(ego)
			if ~isfield(ego.results,'staPre'); warning('No parsed spike-LFP available.'); return; end
			disp('Drawing Spike LFP correlations...')
			ft = ego.ft;
			h=figure;figpos(1,[1200 1200]);set(h,'Color',[1 1 1],'NumberTitle','off','Name',...
				[ego.lfpfile]);
			p=panel(h);
			p.margin = [20 20 10 15]; %left bottom right top
			p.fontsize = 10;
			p.pack(2,2);

			p(1,1).select();
			plot(ft.staPre{1}.time, ft.staPre{1}.avg(:,:)')
			maxPre(1) = max(max(ft.staPre{1}.avg(:,:)));
			minPre(1) = min(min(ft.staPre{1}.avg(:,:)));
			box on
			grid on
			legend(ft.staPre{1}.cfg.channel)
			xlabel('Time (s)')
			xlim(ft.staPre{1}.cfg.timwin)
			title(['PRE ' ft.staPre{1}.name])

			p(1,2).select();
			plot(ft.staPost{1}.time, ft.staPost{1}.avg(:,:)')
			maxPost(1) = max(max(ft.staPost{1}.avg(:,:)));
			minPost(1) = min(min(ft.staPost{1}.avg(:,:)));
			box on
			grid on
			legend(ft.staPost{1}.cfg.channel)
			xlabel('Time (s)')
			xlim(ft.staPost{1}.cfg.timwin)
			title(['POST ' ft.staPost{1}.name])

			p(2,1).select();
			plot(ft.staPre{2}.time, ft.staPre{2}.avg(:,:)')
			maxPre(2) = max(max(ft.staPre{2}.avg(:,:)));
			minPre(2) = min(min(ft.staPre{2}.avg(:,:)));
			box on
			grid on
			legend(ft.staPre{2}.cfg.channel)
			xlabel('Time (s)')
			xlim(ft.staPre{2}.cfg.timwin)
			title(['PRE ' ft.staPre{2}.name])

			p(2,2).select();
			plot(ft.staPost{2}.time, ft.staPost{2}.avg(:,:)')
			maxPost(2) = max(max(ft.staPost{2}.avg(:,:)));
			minPost(2) = min(min(ft.staPost{2}.avg(:,:)));
			box on
			grid on
			legend(ft.staPost{2}.cfg.channel)
			xlabel('Time (s)')
			xlim(ft.staPost{2}.cfg.timwin)
			title(['POST ' ft.staPost{2}.name])
			
			miny = min([minPre minPost]);
			maxy = max([maxPre maxPost]);
			if isnan(miny) || isnan(maxy); miny = -0.5; maxy = 0.5; end
			if miny >= maxy; maxy = miny + 1; end
			p(1,1).select();
			axis([-inf inf miny maxy]);
			p(1,2).select();
			axis([-inf inf miny maxy]);
			p(2,1).select();
			axis([-inf inf miny maxy]);
			p(2,2).select();
			axis([-inf inf miny maxy]);
				
			h=figure;figpos(1,[1000 1000]);set(h,'Color',[1 1 1],'NumberTitle','off','Name',...
				[ego.lfpfile ' ' ft.stsFFT{1}.name]);
			p=panel(h);
			p.margin = [20 20 10 15]; %left bottom right top
			p.fontsize = 10;
			p.pack(2,2);
			
			p(1,1).select();
			p(1,1).hold('on');
			[av,ae] = stderr(ft.stsFFT{1}.ang);
			areabar(ft.stsFFT{1}.freq,rad2ang(av),rad2ang(ae),[],[],'k-o');
			[av,ae] = stderr(ft.stsFFT{2}.ang);
			areabar(ft.stsFFT{2}.freq,rad2ang(av),rad2ang(ae),[],[],'r-o');
			legend('Group A','Group B');
			title(['Spike Triggered Phase FFT']);
			xlabel('Frequency (Hz)');
			ylabel('Angle (deg)');

			p(1,2).select();
			p(1,2).hold('on');
			[mv,me] = stderr(ft.stsFFT{1}.mag);
			areabar(ft.stsFFT{1}.freq, mv, me,[],[],'k-o');
			[mv,me] = stderr(ft.stsFFT{2}.mag);
			areabar(ft.stsFFT{2}.freq, mv, me,[],[],'r-o');
			legend('Group A','Group B');
			title(['Spike Triggered Amplitude FFT']);
			xlabel('Frequency (Hz)');
			
			p(2,1).select();
			p(2,1).hold('on');
			[av,ae] = stderr(ft.stsConvol{1}.ang);
			areabar(ft.stsConvol{1}.freq,rad2ang(av),rad2ang(ae),[],[],'k-o');
			[av,ae] = stderr(ft.stsConvol{2}.ang);
			areabar(ft.stsConvol{2}.freq,rad2ang(av),rad2ang(ae),[],[],'r-o');
			legend('Group A','Group B');
			title(['Spike Triggered Phase CONVOL']);
			xlabel('Frequency (Hz)');
			ylabel('Angle (deg)');

			p(2,2).select();
			p(2,2).hold('on');
			[mv,me] = stderr(ft.stsConvol{1}.mag);
			areabar(ft.stsConvol{1}.freq, mv, me,[],[],'k-o');
			[mv,me] = stderr(ft.stsConvol{2}.mag);
			areabar(ft.stsConvol{2}.freq, mv, me,[],[],'r-o');
			legend('Group A','Group B');
			title(['Spike Triggered Amplitude CONVOL']);
			xlabel('Frequency (Hz)');
			
			h=figure;figpos(1,[2000 1000]);set(h,'Color',[1 1 1],'NumberTitle','off','Name',...
				['PPC for ' ego.lfpfile]);
			p=panel(h);
			p.margin = [20 20 10 15]; %left bottom right top
			p.fontsize = 10;
			p.pack(1,3);
			p(1,1).select();
			hold on
			plot(ft.statSts0{1}.freq,ft.statSts0{1}.ppc0','k-o')
			plot(ft.statSts0{2}.freq,ft.statSts0{2}.ppc0','r-o')
			legend(ft.statSts0{1}.name,ft.statSts0{2}.name);
			box on; grid on;
			xlabel('frequency')
			ylabel('PPC')
			title('PPC0 Measure');
			p(1,2).select();
			hold on
			plot(ft.statSts1{1}.freq,ft.statSts1{1}.ppc1','k-o')
			plot(ft.statSts1{2}.freq,ft.statSts1{2}.ppc1','r-o')
			legend(ft.statSts1{1}.name,ft.statSts1{2}.name);
			box on; grid on;
			xlabel('frequency')
			ylabel('PPC')
			title('PPC1 Measure');
			p(1,3).select();
			hold on
			plot(ft.statSts2{1}.freq,ft.statSts2{1}.ppc2','k-o')
			plot(ft.statSts2{2}.freq,ft.statSts2{2}.ppc2','r-o')
			legend(ft.statSts2{1}.name,ft.statSts2{2}.name);
			box on; grid on;
			xlabel('frequency')
			ylabel('PPC')
			title('PPC2 Measure');
			
		end
		
		% ===================================================================
		%> @brief
		%>
		%> @param
		%> @return
		% ===================================================================
		function drawBandPass(ego)
			if ~isfield(ego.results,'bp') || isempty(ego.results.bp); disp('No bandpass data available...'); return; end
			disp('Drawing Frequency Bandpass...')
			bp = ego.results.bp;
			h=figure;figpos(1,[1500 1500]);set(h,'Color',[1 1 1]);
			p=panel(h);
			p.margin = [20 20 10 15]; %left bottom right top
			p.fontsize = 10;
			len=length(bp)+1;
			[row,col]=ego.optimalLayout(len);
			p.pack(row,col);
			for j = 1:length(bp)
				[i1,i2] = ind2sub([row,col], j);
				pp=p(i1,i2);
				pp.margin = [0 0 15 0];
				pp.pack(2,1);
				pp(1,1).select();
				pp(1,1).hold('on');
				time = bp{j}.av{1}.time;
				fig = bp{j}.av{2}.avg(1,:);
				fige = bp{j}.av{2}.var(1,:);
				grnd = bp{j}.av{1}.avg(1,:);
				grnde = bp{j}.av{1}.var(1,:);
				idxa = ego.findNearest(time, ego.plotRange(1));
				idxb = ego.findNearest(time, ego.plotRange(2));
				minv = min([min(fig(idxa:idxb)) min(grnd(idxa:idxb))]);
				maxv = max([max(fig(idxa:idxb)) max(grnd(idxa:idxb))]);
				minv = minv - (abs(minv)/15);
				maxv = maxv + (abs(maxv)/15);
				if minv >= maxv;minv = -inf; end
				areabar(time, grnd, grnde,[.5 .5 .5],'b');
				areabar(time, fig, fige,[.5 .7 .5],'g');
				if length(bp{j}.av) > 2
					areabar(bp{j}.av{3}.time,bp{j}.av{3}.avg(1,:),bp{j}.av{3}.var(1,:),[.7 .5 .5],'r');
				end
				pp(1,1).hold('off');
				set(gca,'XTickLabel','')
				box on; grid off
				axis([ego.plotRange(1) ego.plotRange(2) minv maxv]);
				pp(1,1).ylabel(['BP ' ego.bpnames{j} '=' num2str(bp{j}.freq)]);
				pp(1,1).title(['FIELDTRIP ' ego.bpnames{j} ' BANDPASS ANALYSIS: File:' ego.lfpfile ' | Channel:' bp{j}.av{1}.label{:}]);
				pp(1,1).margin = [1 1 1 1];
				
				idx1 = ego.findNearest(time, -0.2);
				idx2 = ego.findNearest(time, 0);
				idx3 = ego.findNearest(time, 0.075);
				idx4 = ego.findNearest(time, 0.2);
				pre = mean([mean(grnd(idx1:idx2)), mean(fig(idx1:idx2))]);
				res = (fig - grnd) ./ pre;
				freqdiffs(j) = mean(fig(idx3:idx4)) / mean(grnd(idx3:idx4));
				pp(2,1).select();
				plot(time,res,'k.-','MarkerSize',8);
				box on; grid on
				axis([ego.plotRange(1) ego.plotRange(2) -inf inf]);
				pp(2,1).ylabel('Residuals')
				pp(2,1).margin = [1 1 1 1];
			end
			p(row,col).select();
			bar(freqdiffs,'FaceColor',[0.4 0.4 0.4]);
			box on; grid on;
			set(gca,'XTick',1:length(bp),'XTickLabel',ego.bpnames);
			p(row,col).xlabel('Frequency Band')
			p(row,col).ylabel('Group 2 / Group 1')
			p(row,col).title('Normalised Difference at 0.075 - 0.2sec')
			disp('Plotting Bandpass Analysis Finished...')
			ego.panels.bp = p;
		end
		
		% ===================================================================
		%> @brief
		%>
		%> @param
		%> @return
		% ===================================================================
		function drawLFPFrequencies(ego,varargin)
			if isempty(varargin) || isempty(varargin{1})
				name = 'fqfix1';
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
			if ~isfield(ego.results,name)
				disp('The Frequency field is not present in fieldtrip structure...');
				return;
			end
			fq = ego.results.(name);
			h=figure;figpos(1,[2500 2000]);set(h,'Color',[1 1 1],'Name',[ego.lfpfile ' ' fq{1}.cfgUsed.channel]);
			p=panel(h);
			p.margin = [15 15 30 20];
			if isnumeric(gcf);	p.fontsize = 12; end
			bl = {'relative','relative2','absolute','no'};
			row = length(fq); col = length(bl);
			p.pack(row,col);
			hmin = cell(size(bl));
			hmax = hmin;
			h = hmin;
			for jj = 1:length(bl)
				for i = 1:length(fq)
					p(i,jj).select();
					cfg							= [];
					cfg.fontsize				= 13;
					if strcmpi(bl{jj},'no');
						cfg.baseline			= 'no';
					else
						cfg.baseline			= ego.baselineWindow;
						cfg.baselinetype		= bl{jj};
					end
					if strcmpi(bl{jj},'relative') && exist('zlimi','var')
						cfg.zlim					= zlimi;
					end
					if strcmpi(bl{jj},'relative2')
						cfg.baselinetype		= 'relative';
						cfg.zlim					= [0 2];
					end
					cfg.interactive			= 'no';
					cfg.channel					= ego.ft.label{ego.selectedLFP};
					cfgOut						= ft_singleplotTFR(cfg, fq{i});
					grid on; box on;
					set(gca,'Layer','top','TickDir','out')
					h{jj}{i} = gca;
					clim = get(gca,'clim');
					hmin{jj} = min([hmin{jj} min(clim)]);
					hmax{jj} = max([hmax{jj} max(clim)]);
					xlabel('Time (s)');
					ylabel('Frequency (Hz)');
					t = [bl{jj} '#' num2str(i) ' ' name ' | Mth:' fq{i}.cfgUsed.method ' | Tp:' fq{i}.cfgUsed.taper];
					t = [t '\newlineWin:' num2str(fq{i}.cfgUsed.tw) ' | Cyc:' num2str(fq{i}.cfgUsed.cycles)];
					t = [t ' | Wdth:' num2str(fq{i}.cfgUsed.width) ' | Smth:' num2str(fq{i}.cfgUsed.smooth)];
					title(t,'FontSize',cfg.fontsize);
				end
				for i = 1:length(h{jj});
					set(h{jj}{i},'clim', [hmin{jj} hmax{jj}]);
					box on; grid on;
				end
			end
			ego.panels.(name) = p;
		end
		
		% ===================================================================
		%> @brief
		%>
		%> @param
		%> @return
		% ===================================================================
		function drawLFPFrequencyStats(ego,name)
			if ~exist('name','var');name='fqfix1';end
			if ~isfield(ego.results,name);return; end
			fq = ego.results.(name);
			fqbline = ego.results.([name 'bline']);
			fqresponse = ego.results.([name 'response']);
			h=figure;figpos(1,[1000 1000]);set(h,'Color',[1 1 1],'Name',[ego.lfpfile ' ' fq{1}.cfgUsed.channel]);
			p=panel(h);
			p.margin = [15 15 5 20];
			p.pack('v', {7/8 []})
			p(1).select();
			hold on
			plotpowline(fqbline{1}.freq,fqbline{1}.powspctrm,fqbline{1}.powspctrmsem,'b:o');
			plotpowline(fqbline{2}.freq,fqbline{2}.powspctrm,fqbline{2}.powspctrmsem,'r:o');
			plotpowline(fqresponse{1}.freq,fqresponse{1}.powspctrm,fqresponse{1}.powspctrmsem,'b-o');
			plotpowline(fqresponse{2}.freq,fqresponse{2}.powspctrm,fqresponse{2}.powspctrmsem,'r-o');
			grid on; box on
			t=''; if isfield(fqresponse{1},'blname'); t = fqresponse{1}.blname; end
			title(['Baseline: ' t ' | Measurement Window: ' num2str(fqresponse{1}.toilim)])
			ylabel('Power');
			xlabel('Frequency (Hz)');
			legend(['BL' fqbline{1}.name],['BL' fqbline{2}.name],...
				['M' fqresponse{1}.name],['M' fqresponse{2}.name]);
			
			p1 = squeeze(fqresponse{1}.powspctrm);
			p2 = squeeze(fqresponse{2}.powspctrm);
			p1 = nanmean(p1,2);
			p2 = nanmean(p2,2);
			p(2).select();
			p(2).margintop = 0;
			plot(fqresponse{1}.freq,(p2-p1));
			xlabel('Frequency (Hz)');
			ylabel('Residuals')
			grid on;box on
			function plotpowline(f,p,e,lc)
				p = squeeze(p);
				e = squeeze(e);
				p = p';
				e = e';
				p = nanmean(p);
				e = max(e);
				areabar(f, p, e,[0.5 0.5 0.5],0.5,lc);
			end
		end
		
		% ===================================================================
		%> @brief
		%>
		%> @param
		%> @return
		% ===================================================================
		function [time,avg,err,data]=getAverageTuningCurve(ego,idx,sel)
			time = ego.LFPs(sel).trials(1).time';
			data = [ego.LFPs(sel).trials(idx).data];
			data = rot90(fliplr(data)); %get it into trial x data = row x column
			[avg,err] = stderr(data,'SE');
		end
		
	end
end