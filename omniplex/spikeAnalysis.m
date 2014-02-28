classdef spikeAnalysis < optickaCore
%spikeAnalysis Wraps the native and fieldtrip analysis around our PLX/PL2 reading.
	
%------------------PUBLIC PROPERTIES----------%
	properties
		%> plexon file containing the spike data
		file@char
		%> data directory
		dir@char
		%> ± time window around the trigger
		spikeWindow@double = []
		%> default range to plot
		plotRange@double = [-0.2 0.4]
		%> plot verbosity
		verbose	= true
	end
	
	%------------------VISIBLE PROPERTIES----------%
	properties (SetAccess = private, GetAccess = public)
		%> spike plxReader object; can be the same or different due to spike resorting
		p@plxReader
		%> fieldtrip reparse
		ft@struct
		%> trials to remove in reparsing
		cutTrials@cell
		%> trials selected to remove via UI
		clickedTrials@cell
		%> variable selection map for 3 analysis groups
		map@cell
		%> UI panels
		panels@struct = struct()
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
		function ego = LFPAnalysis(varargin)
			if nargin == 0; varargin.name = 'spikeAnalysis';end
			if nargin>0; ego.parseArgs(varargin, ego.allowedProperties); end
			if isempty(ego.name);ego.name = 'spikeAnalysis'; end
			getFiles(ego, true);
		end
		
		% ===================================================================
		%> @brief
		%>
		%> @param
		%> @return
		% ===================================================================
		function loadLFPs(ego)
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
			ego.LFPs = readLFPs(ego.p, ego.LFPWindow, ego.demeanLFP);
			ego.ft = struct();
			parseLFPs(ego);
			ft_parseLFPs(ego);
			plotLFPs(ego);
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
		function ft = ftParseSpikes(ego)
			ft_defaults;
			tic
			ft = struct();
			ft(1).hdr = ft_read_plxheader(ego.lfpfile);
			ft.label = {ego.LFPs(:).name};
			ft.time = cell(1);
			ft.trial = cell(1);
			ft.fsample = 1000;
			ft.sampleinfo = [];
			ft.trialinfo = [];
			ft.cfg = struct;
			ft.cfg.dataset = ego.lfpfile;
			ft.cfg.headerformat = 'plexon_plx_v2';
			ft.cfg.dataformat = ft.cfg.headerformat;
			ft.cfg.eventformat = ft.cfg.headerformat;
			ft.cfg.trl = [];
			a=1;
			for j = 1:length(ego.LFPs(1).vars)
				for k = 1:ego.LFPs(1).vars(j).nTrials
					ft.time{a} = ego.LFPs(1).vars(j).trial(k).time';
					for i = 1:length(ego.LFPs)
						dat(i,:) = ego.LFPs(i).vars(j).trial(k).data';
					end
					ft.trial{a} = dat;
					window = ego.LFPs(1).vars(j).trial(k).winsteps;
					ft.sampleinfo(a,1)= ego.LFPs(1).vars(j).trial(k).startIndex-window;
					ft.sampleinfo(a,2)= ego.LFPs(1).vars(j).trial(k).startIndex+window;
					ft.cfg.trl(a,:) = [ft.sampleinfo(a,:) -window];
					ft.trialinfo(a,1) = j;
					a = a+1;
				end
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
		function plotSpikess(ego, varargin)
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
		function nLFPs = get.nUnits(ego)
			nUnits = 0;
			if ~isempty(ego.units)
				nUnits = length(ego.units);
			end	
		end
		
		% ===================================================================
		%> @brief
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
		function LFPs = parseSpikes(ego)
			
		end
		
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