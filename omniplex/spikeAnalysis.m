classdef spikeAnalysis < optickaCore
%spikeAnalysis Wraps the native and fieldtrip analysis around our PLX/PL2 reading.
	
%------------------PUBLIC PROPERTIES----------%
	properties
		%> plexon file containing the spike data
		file@char
		%> data directory
		dir@char
		%> ± time window around the trigger, if empty use event off
		spikeWindow@double = 0.6
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
		%> saccadeFilter
		filterFirstSaccades@double = [-800 800];
		%> default behavioural type
		selectedBehaviour@char = 'correct';
		%> region of interest for eye location [x y radius]
		ROI@double = [];
		%> include (false) or exclude (true) the ROI entered trials?
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
		%> selectedTrials
		selectedTrials@cell
		%> variable selection map for 3 analysis groups
		map@cell
		%> UI panels
		panels@struct = struct()
		%> use ROI for trial selection
		useROI@logical = false
	end
	
	%------------------DEPENDENT PROPERTIES--------%
	properties (SetAccess = private, Dependent = true)
		%> number of LFP channels
		nUnits@double = 0
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
		function ego = spikeAnalysis(varargin)
			if nargin == 0; varargin.name = 'spikeAnalysis';end
			if nargin>0; ego.parseArgs(varargin, ego.allowedProperties); end
			if isempty(ego.name);ego.name = 'spikeAnalysis'; end
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
			if force == true || isempty(ego.file)
				[f,p] = uigetfile({'*.plx;*.pl2';'Plexon Files'},'Load Spike File');
				if ischar(f) && ~isempty(f)
					ego.file = f;
					ego.dir = p;
					ego.paths.oldDir = pwd;
					cd(ego.dir);
					ego.p = plxReader('file', ego.file, 'dir', ego.dir);
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
			select(ego);
			ego.p.eA.ROI = ego.ROI;
			parseROI(ego.p.eA);
			showInfo(ego);
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
			ego.p.eA.ROI = ego.ROI;
			parseROI(ego.p.eA);
			showInfo(ego);
		end
		
		% ===================================================================
		%> @brief 
		%>
		%> @param
		%> @return
		% ===================================================================
		function select(ego)
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
			prompt = {'Choose PLX variables to merge A:','Choose PLX variables to merge B:',...
				'Choose PLX variables to merge C:','Enter Trials to exclude',...
				'Choose which Spike channel to select',...
				'Behavioural type ''correct'' ''breakFix'' ''incorrect'' ''all''',...
				'Plot Range (s)','Measure Range (s)','Bin Width (s)',...
				'Region of Interest [X Y RADIUS]',...
				'Include (1) or Exclude (0) the ROI trials?',...
				'Saccade Filter'};
			dlg_title = ['REPARSE ' num2str(ego.event.nVars) ' DATA VARIABLES'];
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
				if ~isempty(ego.ROI)
					ego.useROI = true;
				end
				ego.includeROI = logical(str2num(answer{11}));
				ego.filterFirstSaccades = str2num(answer{12});
			end
			selectTrials(ego);
		end
		
		% ===================================================================
		%> @brief selectTrials selects trials based on many filters
		%>
		%> @param
		%> @return
		% ===================================================================
		function selectTrials(ego)
			
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
			
			idx = find([ego.trial.firstSaccade] >= ego.filterFirstSaccades(1));
			idx2 = find([ego.trial.firstSaccade] <= ego.filterFirstSaccades(2));
			saccidx = intersect(idx,idx2);
			
			if ego.useROI == true
				idx = [ego.p.eA.ROIInfo.enteredROI] == obj.includeROI;
				rois = ego.p.eA.ROIInfo(idx);
				roiidx = [rois.correctedIndex];
			end
			
			ego.selectedTrials = {};
			if isempty(ego.map{1})
				a = 1;
				for i = 1:ego.event.nVars
					vidx = find([ego.trial.name]==ego.event.unique(i));
					idx = intersect(vidx, behaviouridx);
					if ~isempty(saccidx); idx = intersect(idx, saccidx); end
					if ego.useROI == true; idx = intersect(idx, roiidx); end
					if ~isempty(idx)
						ego.selectedTrials{a}.idx = idx;
						ego.selectedTrials{a}.behaviour = ego.selectedBehaviour;
						ego.selectedTrials{a}.sel = ego.event.unique(i);						
						a = a + 1;
					end
				end
			else
				idx = [];
				for i = 1:length(ego.map{1})
					idx = [idx find([ego.trial.name]==ego.map{1}(i))];
				end
				idx = intersect(idx, behaviouridx);
				if ~isempty(saccidx); idx = intersect(idx, saccidx); end
				if ego.useROI == true; idx = intersect(idx, roiidx); end
				if ~isempty(idx)
					ego.selectedTrials{1}.idx = idx;
					ego.selectedTrials{1}.behaviour = ego.selectedBehaviour;
					ego.selectedTrials{1}.sel = ego.map{1};
				end
				
				if ~isempty(ego.map{2})
					idx = [];
					for i = 1:length(ego.map{2})
						idx = [idx find([ego.trial.name]==ego.map{2}(i))];
					end
					idx = intersect(idx, behaviouridx);
					if ~isempty(saccidx); idx = intersect(idx, saccidx); end
					if ego.useROI == true; idx = intersect(idx, roiidx); end
					if ~isempty(idx)
						ego.selectedTrials{2}.idx = idx;
						ego.selectedTrials{2}.behaviour = ego.selectedBehaviour;
						ego.selectedTrials{2}.sel = ego.map{2};
					end
				end
				
				if ~isempty(ego.map{3})
					idx = [];
					for i = 1:length(ego.map{3})
						idx = [idx find([ego.trial.name]==ego.map{3}(i))];
					end
					idx = intersect(idx, behaviouridx);
					if ~isempty(saccidx); idx = intersect(idx, saccidx); end
					if ego.useROI == true; idx = intersect(idx, roiidx); end
					if ~isempty(idx)
						ego.selectedTrials{3}.idx = idx;
						ego.selectedTrials{3}.behaviour = ego.selectedBehaviour;
						ego.selectedTrials{3}.sel = ego.map{3};
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
		function showEyePlots(ego)
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
		function doPSTH(ego)
			ft_defaults
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
				%cfg.spikelength		= 0.8;
				%cfg.topplotfunc		= 'line'; % plot as a line
				cfg.errorbars		= 'sem'; % plot with the standard deviation
				cfg.interactive		= 'no'; % toggle off interactive mode
				h=figure;figpos(1,[1920 1080]);set(h,'Color',[1 1 1]);
				ft_spike_plot_raster(cfg, ego.ft, psth{j})
				title([upper(ego.selectedTrials{j}.behaviour) ' ' num2str(ego.selectedTrials{j}.sel) ' ' ego.file]);
				
				cfg            = [];
				cfg.trials			= ego.selectedTrials{j}.idx;
				cfg.spikechannel	= ego.names{ego.selectedUnit};
				cfg.latency    = [ego.rateRange(1) ego.rateRange(2)]; % sustained response period
				cfg.keeptrials = 'yes';
				rate{j} = ft_spike_rate(cfg,ego.ft);
			end
			ego.ft.psth = psth;
			ego.ft.rate = rate;
			h=figure;figpos(1,[1920 1080]);set(h,'Color',[1 1 1]);
			box on
			grid on
			hold on
			if length(psth)<4;
				c = [0 0 0;1 0 0;0 1 0;0 0 1];
			else
				c = rand(length(psth),3)/2;
			end
			t = [ego.file ' '];
			for j = 1:length(psth)
				e = sqrt(psth{j}.var ./ psth{j}.dof);
				e(isnan(e)) = 0;
				areabar(psth{j}.time, psth{j}.avg, e, c(j,:),'k-o','Color',c(j,:),'MarkerFaceColor',c(j,:),'LineWidth',1);
				leg{j,1} = num2str(ego.selectedTrials{j}.sel);
				t = [t 'Rate=' num2str(rate{j}.avg) ' '];
			end
			title(t);
			xlabel('Time (s)')
			ylabel('Firing Rate (Hz)')
			set(gcf,'Renderer','OpenGL');
			legend(leg);
			axis([ego.plotRange(1) ego.plotRange(2) -inf inf]);
			
		end
		
		% ===================================================================
		%> @brief doDensity plots spike density for the selected trial groups
		%>
		%> @param
		%> @return
		% ===================================================================
		function doDensity(ego)
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
				cfg.topplotfunc	= 'line'; % plot as a line
				cfg.errorbars		= 'sem'; % plot with the standard deviation
				cfg.interactive		= 'no'; % toggle off interactive mode
				h=figure;figpos(1,[1920 1080]);set(h,'Color',[1 1 1]);
				ft_spike_plot_raster(cfg, ego.ft, sd{j})
				title([upper(ego.selectedTrials{j}.behaviour) ' ' num2str(ego.selectedTrials{j}.sel) ' ' ego.file])
				
				cfg            = [];
				cfg.trials			= ego.selectedTrials{j}.idx;
				cfg.spikechannel	= ego.names{ego.selectedUnit};
				cfg.latency    = [ego.rateRange(1) ego.rateRange(2)]; % sustained response period
				cfg.keeptrials = 'yes';
				rate{j} = ft_spike_rate(cfg,ego.ft);
			end
			ego.ft.sd = sd;
			ego.ft.rate = rate;
			h=figure;figpos(1,[1920 1080]);set(h,'Color',[1 1 1]);
			box on
			grid on
			hold on
			if length(sd)<4;
				c = [0 0 0;1 0 0;0 1 0;0 0 1];
			else
				c = rand(length(sd),3)/2;
			end
			t = [ego.file ' '];
			for j = 1:length(sd)
				e = sqrt(sd{j}.var ./ sd{j}.dof);
				e(isnan(e)) = 0;
				areabar(sd{j}.time, sd{j}.avg, e, c(j,:),'k-o','Color',c(j,:),'MarkerFaceColor',c(j,:),'LineWidth',1);
				leg{j,1} = num2str(ego.selectedTrials{j}.sel);
				t = [t 'Rate=' num2str(rate{j}.avg) ' '];
			end
			title(t);
			xlabel('Time (s)')
			ylabel('Firing Rate (Hz)')
			set(gcf,'Renderer','OpenGL');
			legend(leg);
			axis([ego.plotRange(1) ego.plotRange(2) -inf inf]);
			
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
		%>
		%> @param
		%> @return
		% ===================================================================
		function plot(ego, varargin)
			if isempty(ego.LFPs);
				return
			end
			if isempty(varargin) || ~ischar(varargin{1})
				sel = 'psth';
			else
				sel = varargin{1};
			end
			
			if length(varargin) > 1
				args = varargin(2:end);
			else
				args = {};
			end
			
			switch sel
				case 'psth'
					ego.drawAllLFPs(); drawnow;			
					ego.drawRawLFPs(); drawnow;		
					ego.drawAverageLFPs(); drawnow;
				case 'all'
					ego.drawAllLFPs(true);			
					ego.drawRawLFPs();		
					ego.drawAverageLFPs();
				case 'continuous'
					ego.drawAllLFPs(true); drawnow;
				case {'trials','raw'}
					ego.drawRawLFPs(); drawnow;
				case 'average'
					ego.drawAverageLFPs(); drawnow;
				case 'frequency'
					ego.drawLFPFrequencies(args); drawnow;
				case 'bandpass'
					ego.drawBandPass(); drawnow;
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
		function h=drawRawLFPs(ego, h, sel)
			
		end

		% ===================================================================
		%> @brief
		%>
		%> @param
		%> @return
		% ===================================================================
		function [idx,val,delta]=findNearest(obj,in,value)
			tmp = abs(in-value);
			[~,idx] = min(tmp);
			val = in(idx);
			delta = abs(value - val);
		end
		
	end
end