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
		%> default behavioural type
		selectedBehaviour@char = 'correct';
		%> plot verbosity
		verbose	= true
	end
	
	%------------------VISIBLE PROPERTIES----------%
	properties (SetAccess = private, GetAccess = public)
		%> LFP plxReader object
		p@plxReader
		%> spike analysis object
		sp@spikeAnalysis
		%> parsed LFPs
		LFPs@struct
		%> fieldtrip parsed data
		ft@struct
		%> selectedTrials: each cell is a trial list grouping
		selectedTrials@cell
		%> trials to remove in reparsing
		cutTrials@double
		%> trials selected to remove via UI
		clickedTrials@double
		%> variable selection map for 3 analysis groups
		map@cell
		%> bandpass frequencies
		bpfreq@cell = {[1 4], [5 8], [9 14], [15 30], [30 50], [50 100], [1 250]}
		%> bandpass frequency names
		bpnames@cell = {'\delta','\theta','\alpha','\beta','\gamma low','\gamma high','all'}
	end
	
	%------------------TRANSIENT PROPERTIES----------%
	properties (SetAccess = private, GetAccess = public, Transient = true)
		%> UI panels
		panels@struct = struct()
	end
	
	%------------------DEPENDENT PROPERTIES--------%
	properties (SetAccess = private, Dependent = true)
		%> number of LFP channels
		nLFPs@double = 0
		%> number of LFP channels
		nSelection@double = 0
	end
	
	%------------------PRIVATE PROPERTIES----------%
	properties (SetAccess = private, GetAccess = private)
		%> allowed properties passed to object upon construction
		allowedProperties@char = 'lfpfile|spikefile|dir|plotRange|demeanLFP|selectedLFP|LFPWindow|verbose'
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
			getFiles(ego, true);
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
					setFiles(ego.sp, in);
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
			ego.mversion = str2double(regexp(version,'(?<ver>^\d\.\d[\d]?)','match','once'));
			if ego.mversion < 8.2
				error('LFP Analysis requires Matlab >= 2013b!!!')
			end
			ego.paths.oldDir = pwd;
			cd(ego.dir);
			ego.LFPs = struct();
			ego.LFPs = readLFPs(ego.p);
			ego.ft = struct();
			parseLFPs(ego);
			select(ego);
			selectTrials(ego);
			getFTLFPs(ego);
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
			getFTLFPs(ego);
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
		function ft = getFTLFPs(ego)
			ft_defaults;
			LFPs = ego.LFPs;
			tic
			ft = struct();
			ft(1).hdr = ft_read_plxheader(ego.lfpfile);
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
					%LFPs(1).sample-1 is the offset in samples due to a
					%non-zero start time, fieldtrip is incredibly annoying
					%limited to using samples to store timestamps, far from
					%ideal!!!
					ft.sampleinfo(a,1)= LFPs(1).trials(k).startIndex + LFPs(1).sample-1; 
					ft.sampleinfo(a,2)= LFPs(1).trials(k).endIndex + LFPs(1).sample-1;
					ft.cfg.trl(a,:) = [ft.sampleinfo(a,:) -window LFPs(1).trials(k).t1];
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
			if isempty(ego.ft); getFTLFPs(ego); end
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
		function cfg=ftTimeLockAnalysis(ego, cfg)
			ft = ego.ft;
			if ~exist('cfg','var')
				cfg = [];
				cfg.keeptrials = 'yes';
				cfg.removemean = 'yes';
				cfg.covariance = 'yes';
				cfg.covariancewindow = [0.075 0.2];
				cfg.channel = ft.label{ego.selectedLFP};
			end
			for i = 1:ego.nSelection
				cfg.trials = ego.selectedTrials{i}.idx;
				av{i} = ft_timelockanalysis(cfg, ft);
				av{i}.cfgUsed = cfg;
				if strcmpi(cfg.covariance, 'yes')					
					disp(['-->> Covariance for Var:' num2str(i) ' = ' num2str(mean(av{i}.cov))]);
				end
			end		
			ego.ft.av = av;
			if ego.doPlots; drawAverageLFPs(ego); end
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
			ft.bp = [];
			
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
			ego.ft.bp = bp;
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
			ft.bp = [];
			
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
			if ~isfield(ego.ft,'label'); getFTLFPs(ego); end
			ft = ego.ft;
			cfgUsed = {};
			if ~exist('cfg','var') || isempty(cfg)
				cfg				= [];
				cfg.keeptrials	= 'no';
				cfg.output		= 'pow';
				cfg.channel		= ft.label{ego.selectedLFP};
				cfg.toi         = -0.3:0.01:0.3;                  % time window "slides"
				cfg.tw			= tw;
				cfg.cycles		= cycles;
				cfg.width		= width;
				cfg.smooth		= smth;
				switch preset
					case 'fix1'
						cfg.method      = 'mtmconvol';
						cfg.taper		= 'hanning';
						lf				= round(1 / cfg.tw);
						cfg.foi         = lf:2:80;						  % analysis frequencies 
						cfg.t_ftimwin	= ones(length(cfg.foi),1).*tw;   % length of fixed time window
					case 'fix2'
						cfg.method      = 'mtmconvol';
						cfg.taper       = 'hanning';
						cfg.foi         = 2:2:80;						  % analysis frequencies 
						cfg.t_ftimwin	= cycles./cfg.foi;					  % x cycles per time window
					case 'mtm1'
						cfg.method      = 'mtmconvol';
						cfg.taper       = 'dpss';
						cfg.foi         = 2:2:80;						  % analysis frequencies 
						cfg.tapsmofrq	= cfg.foi * cfg.smooth;
						cfg.t_ftimwin	= cycles./cfg.foi;					  % x cycles per time window
					case 'mtm2'
						cfg.method      = 'mtmconvol';
						cfg.taper       = 'dpss';
						cfg.foi         = 2:2:80;						  % analysis frequencies 
					case 'morlet'
						cfg.method		= 'wavelet';
						cfg.taper		= '';
						cfg.width		= width;
						cfg.foi         = 2:2:80;						  % analysis frequencies 
				end
			elseif ~isempty(cfg)
				preset = 'custom';
			end
			for i = 1:ego.nSelection
				cfg.trials = ego.selectedTrials{i}.idx;
				fq{i} = ft_freqanalysis(cfg,ft);
				fq{i}.cfgUsed=cfg;
				cfgUsed{i} = cfg;
			end
			ego.ft.(['fq' preset]) = fq;
			if ego.doPlots; plot(ego,'freq',['fq' preset]); end
		end
		
		% ===================================================================
		%> @brief
		%>
		%> @param
		%> @return
		% ===================================================================
		function cfgUsed=ftSpikeLFP(ego, unit)
			if ~exist('unit','var'); unit = ego.sp.selectedUnit;
			else ego.sp.selectedUnit = unit; end
			plotTogether(ego)
			ft = ego.ft;
			spike = ego.sp.ft;
			dat = ft_appendspike([],ft, spike);
			
			try
				cfg					= [];
				cfg.method			= 'nan'; % remove the replaced segment with interpolation
				cfg.timwin			= [-0.001 0.001]; % remove 4 ms around every spike
				cfg.spikechannel	= spike.label{unit};
				cfg.channel			= ft.label;
				dati				= ft_spiketriggeredinterpolation(cfg, dat);
			catch
				warning('interpolation of spikes failed, using raw data');
				dati=dat;
			end
			
			for j = 1:length(ego.selectedTrials)
				name				= ['SPIKE:' spike.label{unit} ' | SEL: ' ego.selectedTrials{j}.name];
				tempft				= selectFTTrials(ego,ft,ego.selectedTrials{j}.idx);
				tempspike			= selectFTTrials(ego,spike,ego.selectedTrials{j}.idx);
				tempdat				= selectFTTrials(ego,dati,ego.selectedTrials{j}.idx);
				
				cfg					= [];

				cfg.timwin			= [-0.15 0.15]; 
				cfg.spikechannel	= spike.label{unit}; 
				cfg.channel			= ft.label;
				cfg.latency			= [-0.4 0];
				staPre				= ft_spiketriggeredaverage(cfg, tempdat);
				ego.ft.staPre{j}	= staPre;
				ego.ft.staPre{j}.name = name;

				cfg.latency			= [0 0.4];
				staPost				= ft_spiketriggeredaverage(cfg, tempdat);
				ego.ft.staPost{j}	= staPost;
				ego.ft.staPost{j}.name = name;

				cfg					= [];

				cfg.method			= 'mtmfft';
				cfg.foilim			= [10 100]; % cfg.timwin determines spacing
				cfg.timwin			= [-0.05 0.05]; % time window of 100 msec
				cfg.taper			= 'hanning';
				cfg.spikechannel	= spike.label{unit};
				cfg.channel			= ft.label{ego.selectedLFP};
				stsFFT				= ft_spiketriggeredspectrum(cfg, tempft, tempspike);

				ang = squeeze(angle(stsFFT.fourierspctrm{1}));
				mag = squeeze(abs(stsFFT.fourierspctrm{1}));
				ego.ft.stsFFT{j} = stsFFT;
				ego.ft.stsFFT{j}.name = name;
				ego.ft.stsFFT{j}.ang=ang;
				ego.ft.stsFFT{j}.mag=mag;
				
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
			
			if isempty(ego.sp.ft)
				parseSpikes(ego);
			end
			
			ego.sp.density;
			
			h=figure;figpos(1,[1000 1500]);set(h,'Color',[1 1 1],'Name','Density LFP Co-Plot');
			p=panel(h);
			p.margin = [20 20 20 25]; %left bottom right top
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
			if isempty(ego.LFPs);
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
			
			switch sel
				case 'normal'	
					ego.drawRawLFPs(); drawnow;		
					ego.drawAverageLFPs(); drawnow;
				case 'all'
					ego.drawAllLFPs();			
					ego.drawRawLFPs();		
					ego.drawAverageLFPs();
				case 'continuous'
					ego.drawAllLFPs(); drawnow;
				case {'trials','raw'}
					ego.drawRawLFPs(); drawnow;
				case {'av','average'}
					ego.drawAverageLFPs(); drawnow;
				case {'freq','frequency'}
					ego.drawLFPFrequencies(args(:)); drawnow;
				case {'bp','bandpass'}
					ego.drawBandPass(); drawnow;
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
		%> @brief selectFTTrials cut out trials where the ft function fails
		%> to use cfg.trials
		%>
		%> @param
		%> @return
		% ===================================================================
		function ftout=selectFTTrials(ego,ft,idx)
			ftout = ft;
			if isfield(ft,'nUnits') %assume a spike structure
				ftout.trialtime = ft.trialtime(idx,:);
				ftout.cfg.trl = ft.cfg.trl(idx,:);
				for j = 1:ft.nUnits
					sel					= ismember(ft.trial{j},idx);
					ftout.timestamp{j}	= ft.timestamp{j}(sel);
					ftout.time{j}		= ft.time{j}(sel);
					ftout.trial{j}		= ft.trial{j}(sel);
				end
			else %assume continuous
				ftout.sampleinfo = ft.sampleinfo(idx,:);
				ftout.trialinfo = ft.trialinfo(idx,:);
				if isfield(ft.cfg,'trl'); ftout.cfg.trl = ft.cfg.trl(idx,:); end
				ftout.time = ft.time(idx);
				ftout.trial = ft.trial(idx);
			end
			
		end
		
		% ===================================================================
		%> @brief selectTrials selects trials based on many filters
		%>
		%> @param
		%> @return
		% ===================================================================
		function select(ego)	
			cuttrials = '[ ';
			if ~isempty(ego.cutTrials)
				cuttrials = [cuttrials num2str(ego.cutTrials)];
			elseif ~isempty(ego.clickedTrials)
				cuttrials = [cuttrials num2str(ego.clickedTrials)];
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

			sel = num2str(ego.selectedLFP);
			beh = ego.selectedBehaviour;

			options.Resize='on';
			options.WindowStyle='normal';
			options.Interpreter='tex';
			prompt = {'Choose PLX variables to merge (A, if empty parse all variables independantly):',...
				'Choose PLX variables to merge (B):',...
				'Choose PLX variables to merge (C):',...
				'Enter Trials to exclude:',...
				'Choose which LFP channel to select:',...
				'Behavioural type (''correct'', ''breakFix'', ''incorrect'' | ''all''):'};
			dlg_title = ['REPARSE ' num2str(ego.LFPs(1).nVars) ' DATA VARIABLES'];
			num_lines = [1 120];
			def = {map{1}, map{2}, map{3}, cuttrials,sel,beh};
			answer = inputdlg(prompt,dlg_title,num_lines,def,options);
			drawnow;
			if ~isempty(answer)
				map{1} = str2num(answer{1}); map{2} = str2num(answer{2}); map{3} = str2num(answer{3}); 
				if ~isempty(answer{4}) 
					ego.cutTrials = str2num(answer{4});
				end
				ego.map = map;
				ego.selectedLFP = str2num(answer{5});
				if ego.selectedLFP < 1 || ego.selectedLFP > ego.nLFPs
					ego.selectedLFP = 1;
				end
				ego.selectedBehaviour = answer{6};
			end
			selectTrials(ego);
		end
		
	end

	%=======================================================================
	methods ( Access = private ) %-------PRIVATE METHODS-----%
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
				time = LFPs(j).time;
				data = LFPs(j).data;
				minL = Inf;
				maxL = 0;
				trials = ego.p.eventList.trials;
				for k = 1:ego.p.eventList.nTrials
					[idx1, val1, dlta1] = ego.findNearest(time, trials(k).t1);
					trials(k).zeroTime = val1;
					trials(k).zeroIndex = idx1; trials(k).startIndex = idx1 - winsteps; trials(k).endIndex = idx1 + winsteps;
					trials(k).zeroDelta = dlta1;
					trials(k).data = data( trials(k).startIndex : trials(k).endIndex );
					trials(k).otime = time( trials(k).startIndex : trials(k).endIndex );
					trials(k).time = [ -window : 1e-3 : window ]';
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
				idx = intersect(idx, behaviouridx);
				if ~isempty(cutidx);	idx = setdiff(idx, cutidx);		end %remove the cut trials
				if ~isempty(idx)
					ego.selectedTrials{a}.idx			= idx;
					ego.selectedTrials{a}.cutidx		= cutidx;
					ego.selectedTrials{a}.roiidx		= roiidx;
					ego.selectedTrials{a}.toiidx		= toiidx;
					ego.selectedTrials{a}.saccidx		= saccidx;
					ego.selectedTrials{a}.behaviour		= ego.selectedBehaviour;
					ego.selectedTrials{a}.sel			= map{i};
					ego.selectedTrials{a}.name			= ['[' num2str(ego.selectedTrials{a}.sel) ']' ' #' num2str(length(idx))];
					a = a + 1;
				end
			end
			if ego.nSelection == 0; warndlg('The selection results in no valid trials to process!'); end
		end
		
		% ===================================================================
		%> @brief
		%>
		%> @param
		%> @return
		% ===================================================================
		function h=drawRawLFPs(ego, h, sel)
			disp('Drawing RAW LFP Trials...')
			if ~exist('h','var')
				h=figure;figpos(1,[1920 1080]);set(h,'Color',[1 1 1]);
				ego.clickedTrials = ego.cutTrials;
			end
			clf(h,'reset')
			if ~exist('sel','var')
				sel = ego.selectedLFP;
			end

			LFP = ego.LFPs(sel);

			p=panel(h);
			[row,col]=ego.optimalLayout(ego.nSelection);
			p.pack(row,col);
			for j = 1:length(ego.selectedTrials)
				[i1,i2] = ind2sub([row,col], j);
				p(i1,i2).select();
				p(i1,i2).title(['LFP & EVENT PLOT: File:' ego.lfpfile ' | Channel:' LFP.name ' | Group:' num2str(j)]);
				p(i1,i2).xlabel('Time (s)');
 				p(i1,i2).ylabel('LFP Raw Amplitude (mV)');
				p(i1,i2).hold('on');
				for k = 1:length(ego.selectedTrials{j}.idx)
					trial = LFP.trials(ego.selectedTrials{j}.idx(k));
					dat = [trial.variable,trial.index,trial.t1];
					cut = ego.cutTrials;
					if ~isempty(intersect(trial.index,cut));
						ls = ':';
					else
						ls = '-';
					end
					tag=['VAR:' num2str(dat(1)) '  TRL:' num2str(dat(2)) '  T1:' num2str(dat(3))];
					if strcmpi(class(gcf),'double')
						c=rand(1,3);
						plot(trial.time, trial.data, 'LineStyle', ls, 'Color', c, 'Tag', tag, 'ButtonDownFcn', @clickMe, 'UserData', dat);
					else
						plot(trial.time, trial.data,'LineStyle', ls, 'Tag',tag,'ButtonDownFcn', @clickMe,'UserData',dat);
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
				drawRawLFPs(ego,gcf,ego.selectedLFP);
			end
			function previousChannel(src,~)
				ego.selectedLFP = ego.selectedLFP - 1;
				if ego.selectedLFP < 1
					ego.selectedLFP = length(ego.LFPs);
				end
				drawRawLFPs(ego,gcf,ego.selectedLFP);
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
					
					if intersect(trl, ego.clickedTrials);
						ego.clickedTrials(ego.clickedTrials == trl) = [];
						set(src,'LineStyle','-','LineWidth',0.5);
					else
						ego.clickedTrials = [ego.clickedTrials trl];
						set(src,'LineStyle',':','LineWidth',2);
					end
					disp(['Current Selected trials : ' num2str(ego.clickedTrials)]);
				end
				ego.cutTrials = ego.clickedTrials;
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
				for j = 1:length(LFPs)
					figure;figpos(1,[1000 1000]);set(gcf,'Color',[1 1 1]);
					title(['TIMELOCK AVERAGES: File:' ego.lfpfile ' | Channel:' LFPs(j).name]);
					xlabel('Time (s)');
					ylabel('LFP Raw Amplitude (mV)');
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
					hold off
					axis([ego.plotRange(1) ego.plotRange(2) -inf inf]);
				end
				if isfield(ego.ft,'av')
					av = ego.ft.av;
					figure;figpos(1,[1000 1000]);set(gcf,'Color',[1 1 1]);
					hold on
					areabar(av{1}.time,av{1}.avg(1,:),av{1}.var(1,:),[.5 .5 .5],0.3,'k-','LineWidth',1);
					areabar(av{2}.time,av{2}.avg(1,:),av{2}.var(1,:),[.5 .3 .3],0.3,'r-','LineWidth',1);
					if length(av) > 2
						areabar(av{3}.time,av{3}.avg(1,:),av{3}.var(1,:),[.3 .3 .5],0.3,'b-','LineWidth',1);
					end
					hold off
					axis([ego.plotRange(1) ego.plotRange(2) -inf inf]);
					xlabel('Time (s)');
					ylabel('LFP Raw Amplitude (mV)');
					title(['FIELDTRIP TIMELOCK ANALYSIS: File:' ego.lfpfile ' | Channel:' av{1}.label{:} ' | LFP: ']);
				end
			end				
		end
		
		% ===================================================================
		%> @brief 
		%>
		%> @param
		%> @return
		% ===================================================================
		function drawAllLFPs(ego)
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
			if ~isfield(ego.ft,'staPre'); warning('No parsed spike-LFP available.'); return; end
			disp('Drawing Spike LFP correlations...')
			ft = ego.ft;
			for j = 1:length(ego.selectedTrials)
				h=figure;figpos(1,[1000 1000]);set(h,'Color',[1 1 1],'NumberTitle','off','Name',num2str(ego.selectedTrials{j}.sel));
				p=panel(h);
				p.margin = [20 20 10 15]; %left bottom right top
				p.fontsize = 10;
				p.pack(2,2);
				
				p(1,1).select();
				plot(ft.staPre{j}.time, ft.staPre{j}.avg(:,:)')
				box on
				grid on
				legend(ft.staPre{j}.cfg.channel)
				xlabel('Time (s)')
				xlim(ft.staPre{j}.cfg.timwin)
				title([ft.staPre{j}.name ' PRE STA \newlineFile:' ego.lfpfile])
				
				p(1,2).select();
				plot(ft.staPost{j}.time, ft.staPost{j}.avg(:,:)')
				box on
				grid on
				legend(ft.staPost{j}.cfg.channel)
				xlabel('Time (s)')
				xlim(ft.staPost{j}.cfg.timwin)
				title([ft.staPost{j}.name ' POST STA \newlineFile:' ego.lfpfile])
				
				p(2,1).select();
				[av,ae] = stderr(ft.stsFFT{j}.ang);
				areabar(ft.stsFFT{j}.freq,rad2ang(av),rad2ang(ae));
				legend(ft.stsFFT{j}.cfg.channel)
				title([ft.stsFFT{j}.name ' Spike Triggered Phase \newlineFile:' ego.lfpfile]);
				xlabel('Frequency (Hz)')
				ylabel('Angle (deg)');
				
				p(2,2).select();
				[mv,me] = stderr(ft.stsFFT{j}.mag);
				areabar(ft.stsFFT{j}.freq, mv, me);
				legend(ft.stsFFT{j}.cfg.channel)
				title([ft.stsFFT{j}.name ' Spike Triggered Amplitude \newlineFile:' ego.lfpfile]);
				xlabel('Frequency (Hz)')
			end
		end
		
		% ===================================================================
		%> @brief 
		%>
		%> @param
		%> @return
		% ===================================================================
		function drawBandPass(ego)
				if ~isfield(ego.ft,'bp') || isempty(ego.ft.bp);	return;	end
				disp('Drawing Frequency Bandpass...')
				bp = ego.ft.bp;
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
						areabar(bp{j}.av{1}.time,bp{j}.av{1}.avg(1,:),bp{j}.av{1}.var(1,:),[.5 .5 .5],'k');
						areabar(bp{j}.av{2}.time,bp{j}.av{2}.avg(1,:),bp{j}.av{2}.var(1,:),[.7 .5 .5],'r');
						if length(bp{j}.av) > 2
							areabar(bp{j}.av{3}.time,bp{j}.av{3}.avg(1,:),bp{j}.av{3}.var(1,:),[.5 .5 .7],'b');
						end
						pp(1,1).hold('off');
						set(gca,'XTickLabel','')
						box on; grid off
						axis([ego.plotRange(1) ego.plotRange(2) -inf inf]);
						pp(1,1).ylabel(['BP ' ego.bpnames{j} '=' num2str(bp{j}.freq)]);
						pp(1,1).title(['FIELDTRIP ' ego.bpnames{j} ' BANDPASS ANALYSIS: File:' ego.lfpfile ' | Channel:' bp{j}.av{1}.label{:}]);
						pp(1,1).margin = [1 1 1 1];

						time = bp{j}.av{1}.time;
						fig = bp{j}.av{2}.avg(1,:);
						grnd = bp{j}.av{1}.avg(1,:);
						idx1 = ego.findNearest(time, -0.2);
						idx2 = ego.findNearest(time, 0);
						idx3 = ego.findNearest(time, 0.05);
						idx4 = ego.findNearest(time, 0.2);
						pre = mean([mean(grnd(idx1:idx2)), mean(fig(idx1:idx2))]); 
						res = (fig - grnd) ./ pre;
						freqdiffs(j) = mean(fig(idx3:idx4)) / mean(grnd(idx3:idx4));
						pp(2,1).select();
						plot(time,res,'k.-','MarkerSize',8);
						box on; grid on
						axis([ego.plotRange(1) ego.plotRange(2) -inf inf]);
						pp(2,1).ylabel('Residuals (norm)')
						pp(2,1).margin = [1 1 1 1];
				end
				p(row,col).select();
				bar(freqdiffs,'FaceColor',[0.4 0.4 0.4]);
				set(gca,'XTick',1:length(bp),'XTickLabel',ego.bpnames);
				p(row,col).xlabel('Frequency Band')
				p(row,col).ylabel('Normalised Residuals')
				p(row,col).title('Normalised Difference at 0.05 - 0.2sec')
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
			if isempty(varargin); 
				name = 'fqfix1';
			elseif length(varargin)==1 && length(varargin{1}) > 1
				varargin = varargin{1};
			end
				if length(varargin)>0
				name = varargin{1};
				while iscell(name);name=name{1};end
			end
			if length(varargin)>1
				zlim = varargin{2};
				while iscell(zlim);zlim=zlim{1};end
			end
			if ~isfield(ego.ft,name)
				return;
			end
			fq = ego.ft.(name);
			h=figure;figpos(1,[2000 2000]);set(h,'Color',[1 1 1]);
			p=panel(h);
			p.margin = [15 15 30 20];
			p.fontsize = 12;
			len=length(fq);
			[row,col]=ego.optimalLayout(len);
			p.pack(row,col);
			bl = {'relative','absolute'};
			hmin = cell(size(bl));
			hmax = hmin;
			h = hmin;
			for jj = 1:length(bl)
				for i = 1:len
					p(i,jj).select();
					cfg					= [];
					cfg.fontsize		= 14;
					cfg.baseline		= ego.baselineWindow;
					cfg.baselinetype	= bl{jj};
					if strcmpi(bl{jj},'relative') && exist('zlim','var')
						cfg.zlim		= zlim;
					end
					cfg.interactive		= 'no';
					cfg.channel			= ego.ft.label{ego.selectedLFP};
					cfgOut=ft_singleplotTFR(cfg, fq{i});
					h{jj}{i} = gca;
					cfgUsed{i}.plotcfg = cfgOut;
					clim = get(gca,'clim');
					hmin{jj} = min([hmin{jj} min(clim)]);
					hmax{jj} = max([hmax{jj} max(clim)]);
					xlabel('Time (s)');
					ylabel('Frequency (Hz)');
					t = [bl{jj} '#' num2str(i) 'Preset: ' name ' | Method: ' fq{i}.cfgUsed.method ' | Taper: ' fq{i}.cfgUsed.taper];
					t = [t ' | Window: ' num2str(fq{i}.cfgUsed.tw) ' | Cycles: ' num2str(fq{i}.cfgUsed.cycles)];
					t = [t ' | Width: ' num2str(fq{i}.cfgUsed.width) ' | Smooth: ' num2str(fq{i}.cfgUsed.smooth)];
					title(t,'FontSize',cfg.fontsize);
				end
				for i = 1:length(h{jj});
					set(h{jj}{i},'clim', [hmin{jj} hmax{jj}]);
					box on; grid on;
				end
			end
			ego.panels.fq = p;
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
			[avg,err] = stderr(data);
		end
		
	end
end