classdef spikeAnalysis < analysisCore
%spikeAnalysis Wraps the native and fieldtrip analysis around our PLX/PL2 reading.
	
%------------------PUBLIC PROPERTIES----------%
	properties
		%> plexon file containing the spike data
		file@char
		%> data directory
		dir@char
		%> ± time window around the trigger, if empty use event off
		spikeWindow@double = 0.8
		%> used by legacy spikes to allow negative time offsets
		startOffset@double = 0
		%> default range to plot
		plotRange@double = [-0.2 0.4]
		%> default range to measure an average firing rate
		rateRange@double = [0.05 0.2]
		%> bin size
		binSize@double = 0.01
		%> default Spike channel
		selectedUnit@double = 1
		%> saccadeFilter, if empty ignore
		filterFirstSaccades@double = [ ];
		%> default behavioural type
		selectedBehaviour@char = 'correct';
		%> region of interest for eye location [x y radius], if empty ignore
		ROI@double = [];
		%> include (true) or exclude (false) the ROI entered trials?
		includeROI@logical = false
		%> plot verbosity
		verbose	= true
	end
	
	%------------------VISIBLE PROPERTIES----------%
	properties (SetAccess = private, GetAccess = public)
		%> spike plxReader object; can be the same or different due to spike resorting
		p@plxReader
		%> fieldtrip reparse
		ft@struct
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
	
	%------------------TRANSIENT PROPERTIES----------%
	properties (SetAccess = private, GetAccess = private, Transient = true)
		%> UI panels
		panels@struct = struct()
		%>
		selectOverride@logical = false
	end
		
	%------------------DEPENDENT PROPERTIES--------%
	properties (SetAccess = private, Dependent = true)
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
		%> @brief Set the plxReader files from a structure
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
		%> @brief set trials / var parsing from outside, override dialog
		%>
		%> @param varargin
		%> @return
		% ===================================================================
		function setSelection(ego, in)
			if isfield(in,'cutTrials')
				ego.cutTrials = in.cutTrials;
			end
			if isfield(in,'selectedTrials')
				ego.selectedTrials = in.selectedTrials;
				ego.selectOverride = true;
			end
			if isfield(in,'map')
				ego.map = in.map;
			end
			if isfield(in,'plotRange')
				ego.plotRange = in.plotRange;
			end
			if isfield(in,'selectedBehaviour')
				ego.selectedBehaviour = in.selectedBehaviour;
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
			ego.selectOverride = false;
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
			ego.ft = getFTSpikes(ego.p);
			ego.names = ego.ft.label;
			showInfo(ego);
			select(ego);
			ego.p.eA.ROI = ego.ROI;
			parseROI(ego.p.eA);
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
			ego.ft = getFTSpikes(ego.p);
			ego.names = ego.ft.label;
			if isempty(ego.selectedTrials)
				select(ego);
			elseif ego.selectOverride == false
				selectTrials(ego)
			end
			if ~isempty(ego.ROI)
				ego.p.eA.ROI = ego.ROI;
				parseROI(ego.p.eA);
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
			ego.ft = getFTSpikes(ego.p);
			ego.names = ego.ft.label;
			select(ego);
			if ~isempty(ego.ROI)
				ego.p.eA.ROI = ego.ROI;
				parseROI(ego.p.eA);
			end
		end
		
		% ===================================================================
		%> @brief 
		%>
		%> @param
		%> @return
		% ===================================================================
		function select(ego)
			if isempty(ego.trial); warning('Data not parsed yet...');return;end
			ego.selectOverride = false;
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
			
			sel = num2str(ego.selectedUnit);
			beh = ego.selectedBehaviour;
			pr = num2str(ego.plotRange);
			rr = num2str(ego.rateRange);
			bw = num2str(ego.binSize);
			roi = num2str(ego.ROI);
			includeroi = num2str(ego.includeROI);
			saccfilt = num2str(ego.filterFirstSaccades);

			options.Resize='on';
			options.WindowStyle='normal';
			options.Interpreter='tex';
			prompt = {'Choose PLX variables to merge A (if empty, use all variables as individual groups and ignore B & C):',...
				'Choose PLX variables to merge B:',...
				'Choose PLX variables to merge C:',...
				['Enter Trials (1-' num2str(ego.event.nTrials) ')  to exclude:'],...
				['Choose which Spike channel to select (# units = ' num2str(ego.nUnits) ')'],...
				'Behavioural type ''correct'' ''breakFix'' ''incorrect'' or ''all''',...
				'Plot Range (seconds)',...
				'Measure Range (seconds)',...
				'Bin Width (seconds)',...
				'Region of Interest [X Y RADIUS] (blank = ignore):',...
				'Include (1) or Exclude (0) the ROI trials?',...
				'Saccade Filter in seconds [>Time1 <Time2], e.g. [-0.8 0.8] (blank = ignore):'};
			dlg_title = [ego.file ': REPARSE ' num2str(ego.event.nVars) ' DATA VARIABLES'];
			num_lines = [1 120];
			def = {map{1}, map{2}, map{3}, cuttrials, sel, beh, pr, rr, bw, roi, includeroi,saccfilt};
			answer = inputdlg(prompt,dlg_title,num_lines,def,options);
			drawnow;
			if isempty(answer)
				map{1} = []; map{2}=[]; map{3}=[]; cuttrials = [];
			else
				map{1} = str2num(answer{1}); map{2} = str2num(answer{2}); map{3} = str2num(answer{3}); 
				ego.cutTrials = str2num(answer{4});
				ego.map = map;
				ego.selectedUnit = str2num(answer{5});
				if ego.selectedUnit < 1 || ego.selectedUnit > length(ego.spike)
					ego.selectedUnit = 1;
				end
				ego.selectedBehaviour = answer{6};
				ego.plotRange = str2num(answer{7});
				ego.rateRange = str2num(answer{8});
				ego.binSize = str2num(answer{9});
				roi = str2num(answer{10});
				if isnumeric(roi) && length(roi) == 3
					ego.ROI = roi;
				else
					ego.ROI = [];
				end
				ego.includeROI = logical(str2num(answer{11}));
				ego.filterFirstSaccades = str2num(answer{12});
			end
			if ~isempty(ego.ROI)
				ego.p.eA.ROI = ego.ROI;
				parseROI(ego.p.eA);
				plotROI(ego.p.eA);
			end
			selectTrials(ego);
		end
		
		% ===================================================================
		%> @brief 
		%>
		%> @param
		%> @return
		% ===================================================================
		function showEyePlots(ego)
			if ego.nSelection == 0; error('The selection results in no valid trials to process!'); end
			if ~isempty(ego.selectedTrials)
				for i = 1:length(ego.selectedTrials)
					ego.p.eA.plot(ego.selectedTrials{i}.idx);
				end
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
			
			for j = 1:length(ego.selectedTrials)
				cfg					= [];
				cfg.trials			= ego.selectedTrials{j}.idx;
				cfg.binsize			=  ego.binSize;
				cfg.outputunit		= 'rate';
				cfg.latency			= ego.plotRange;
				cfg.spikechannel	= ego.names{ego.selectedUnit};
				psth{j}				= ft_spike_psth(cfg, ego.ft);
								
				cfg					= [];
				cfg.trials			= ego.selectedTrials{j}.idx;
				cfg.spikechannel	= ego.names{ego.selectedUnit};
				cfg.latency			= [ego.rateRange(1) ego.rateRange(2)]; % sustained response period
				cfg.keeptrials		= 'yes';
				rate{j}				= ft_spike_rate(cfg,ego.ft);
			end
			ego.ft.psth = psth;
			ego.ft.rate = rate;
			
			if ego.doPlots; plotPSTH(ego); end
		end
		
		% ===================================================================
		%> @brief doDensity plots spike density for the selected trial groups
		%>
		%> @param
		%> @return
		% ===================================================================
		function density(ego)
			for j = 1:length(ego.selectedTrials)
				cfg					= [];
				cfg.trials			= ego.selectedTrials{j}.idx;
				cfg.timwin			= [-0.025 0.025];
				cfg.fsample			= 1000; % sample at 1000 hz
				cfg.outputunit		= 'rate';
				cfg.latency			= ego.plotRange;
				cfg.spikechannel	= ego.names{ego.selectedUnit};
				sd{j}				= ft_spikedensity(cfg, ego.ft);
				
				cfg					= [];
				cfg.trials			= ego.selectedTrials{j}.idx;
				cfg.spikechannel	= ego.names{ego.selectedUnit};
				cfg.latency			= [ego.rateRange(1) ego.rateRange(2)]; % sustained response period
				cfg.keeptrials		= 'yes';
				rate{j}				= ft_spike_rate(cfg,ego.ft);
			end
			ego.ft.sd = sd;
			ego.ft.rate = rate;
			
			if ego.doPlots; plotDensity(ego); end
		end
		
		% ===================================================================
		%> @brief showInfo shows the info box for the plexon parsed data
		%>
		%> @param
		%> @return
		% ===================================================================
		function showInfo(ego)
			if ~isempty(ego.p.info)
				infoBox(ego.p);
			end
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
		%> @brief 
		%>
		%> @param
		%> @return
		% ===================================================================
		function plot(ego, varargin)
			if isempty(ego.fp);
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
				case 'psth'	
					plotPSTH(ego); drawnow;
				case 'density'
					plotDensity(ego); drawnow;
			end
		end
		
	end

	%=======================================================================
	methods ( Access = private ) %-------PRIVATE METHODS-----%
	%=======================================================================
	
		% ===================================================================
		%> @brief selectTrials selects trials based on many filters
		%>
		%> @param
		%> @return
		% ===================================================================
		function selectTrials(ego)
			
			if ego.selectOverride == true
				return
			end
			
			switch lower(ego.selectedBehaviour)
				case 'correct'
					behaviouridx = find([ego.trial.isCorrect]==true);
				case 'breakfix'
					behaviouridx = find([ego.trial.isBreak]==true);
				case 'incorrect'
					behaviouridx = find([ego.trial.isIncorrect]==true);
				otherwise
					behaviouridx = [ego.trial.index];
			end
			
			cutidx = ego.cutTrials;
			
			saccidx = [];
			if ~isempty(ego.filterFirstSaccades)
				idx = find([ego.trial.firstSaccade] >= ego.filterFirstSaccades(1));
				idx2 = find([ego.trial.firstSaccade] <= ego.filterFirstSaccades(2));
				saccidx = intersect(idx,idx2);
			end
			
			roiidx = [];
			if ~isempty(ego.ROI)
				idx = [ego.p.eA.ROIInfo.enteredROI] == ego.includeROI;
				rois = ego.p.eA.ROIInfo(idx);
				roiidx = [rois.correctedIndex];
			end	
			
			if isempty(ego.map{1})
				for i = 1:ego.event.nVars; map{i} = ego.event.unique(i); end
			else
				map = ego.map; %#ok<*PROP>
			end
	
			ego.selectedTrials = {};
			a = 1;
			for i = 1:length(map)
				idx = []; if isempty(map{i}); continue; end
				for j = 1:length(map{i})
					idx = [ idx find( [ego.trial.variable] == map{i}(j) ) ];
				end
				idx = intersect(idx, behaviouridx);
				if ~isempty(cutidx);	idx = setdiff(idx, cutidx);		end %remove the cut trials
				if ~isempty(saccidx);	idx = intersect(idx, saccidx);	end %remove saccade filtered trials
				if ~isempty(roiidx);	idx = intersect(idx, roiidx);	end %remove roi filtered trials
				if ~isempty(idx)
					ego.selectedTrials{a}.idx			= idx;
					ego.selectedTrials{a}.cutidx		= cutidx;
					ego.selectedTrials{a}.roiidx		= roiidx;
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
		%> @param
		%> @return
		% ===================================================================
		function plotDensity(ego)
			if ~isfield(ego.ft,'sd'); warning('No Density parsed yet.'); return; end
			sd = ego.ft.sd;
			rate = ego.ft.rate;
			if ego.nSelection == 0; error('The selection results in no valid trials to process!'); end
			h=figure;figpos(1,[2000 2000]);set(h,'Color',[1 1 1],'Name',ego.names{ego.selectedUnit});
			p=panel(h);
			p.margin = [20 20 20 10]; %left bottom right top
			len = ego.nSelection + 1;
			[row,col]=ego.optimalLayout(len);
			p.pack(row,col);
			for j = 1:length(ego.selectedTrials)
				[i1,i2] = ind2sub([row,col], j);
				p(i1,i2).select();
				cfg					= [];
				cfg.trials			= ego.selectedTrials{j}.idx;
				cfg.spikechannel	= ego.names{ego.selectedUnit};
				cfg.spikelength		= 1;
				cfg.topplotfunc		= 'line'; % plot as a line
				cfg.errorbars		= 'conf95%'; % plot with the standard deviation
				cfg.interactive		= 'no'; % toggle off interactive mode
				ft_spike_plot_raster(cfg, ego.ft, sd{j})
				p(i1,i2).title([upper(ego.selectedTrials{j}.behaviour) ' ' ego.selectedTrials{j}.name ' ' ego.file])
			end
			p(row,col).select();
			box on
			grid on
			hold on
			c = ego.optimalColours(length(sd));
			t = [ego.file ' '];
			for j = 1:length(sd)
				e = ego.var2SE(sd{j}.var,sd{j}.dof);
				areabar(sd{j}.time, sd{j}.avg, e, c(j,:)/2, 0.2, 'k.-','Color',c(j,:),'MarkerFaceColor',c(j,:),'LineWidth',1);
				leg{j,1} = ego.selectedTrials{j}.name;
				t = [t 'Rate' num2str(j) '=' num2str(rate{j}.avg) ' '];
			end
			p(row,col).title(t);
			p(row,col).xlabel('Time (s)')
			p(row,col).ylabel(['Firing Rate (Hz) \pm ' cfg.errorbars])
			set(gcf,'Renderer','OpenGL');
			legend(leg);
			axis([ego.plotRange(1) ego.plotRange(2) -inf inf]);
		end
		
		% ===================================================================
		%> @brief
		%> @param
		%> @return
		% ===================================================================
		function plotPSTH(ego)
			if ~isfield(ego.ft,'psth'); warning('No PSTH parsed yet.'); return; end
			psth = ego.ft.psth;
			rate = ego.ft.rate;
			if ego.nSelection == 0; error('The selection results in no valid trials to process!'); end
			h=figure;figpos(1,[2000 2000]);set(h,'Color',[1 1 1],'Name',ego.names{ego.selectedUnit});
			p=panel(h);
			p.margin = [20 20 20 10]; %left bottom right top
			len = ego.nSelection + 1;
			[row,col]=ego.optimalLayout(len);
			p.pack(row,col);
			for j = 1:length(ego.selectedTrials)
				[i1,i2] = ind2sub([row,col], j);
				p(i1,i2).select();
				cfg					= [];
				cfg.trials			= ego.selectedTrials{j}.idx;
				cfg.spikechannel	= ego.names{ego.selectedUnit};
				cfg.spikelength		= 1;
				%cfg.topplotfunc		= 'line'; % plot as a line
				cfg.errorbars		= 'conf95%'; % plot with the standard deviation
				cfg.interactive		= 'no'; % toggle off interactive mode
				ft_spike_plot_raster(cfg, ego.ft, psth{j})
				p(i1,i2).title([upper(ego.selectedTrials{j}.behaviour) ' ' ego.selectedTrials{j}.name ' ' ego.file])
			end
			p(row,col).select();
			box on
			grid on
			hold on
			c = ego.optimalColours(length(psth));
			t = [ego.file ' '];
			for j = 1:length(psth)
				e = sqrt(psth{j}.var ./ psth{j}.dof);
				e(isnan(e)) = 0;
				areabar(psth{j}.time, psth{j}.avg, e, c(j,:)/2, 0.2, 'k.-','Color',c(j,:),'MarkerFaceColor',c(j,:),'LineWidth',1);
				leg{j,1} = ego.selectedTrials{j}.name;
				t = [t 'Rate' num2str(j) '=' num2str(rate{j}.avg) ' '];
			end
			p(row,col).title(t);
			p(row,col).xlabel('Time (s)')
			p(row,col).ylabel(['Firing Rate (Hz) \pm ' cfg.errorbars])
			set(gcf,'Renderer','OpenGL');
			legend(leg);
			axis([ego.plotRange(1) ego.plotRange(2) -inf inf]);
		end
	
	end
end