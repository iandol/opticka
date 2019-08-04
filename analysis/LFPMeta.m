classdef LFPMeta < analysisCore
	
	properties
		%verbosity
		verbose = true;
	end
	
	properties (SetAccess = protected, GetAccess = public)
		%> LFP sites
		sites@cell
		%> display list
		list@cell
		%> raw LFP objects
		raw@cell
		%> meta result
		results
	end
	
	properties (SetAccess = protected, GetAccess = public, Transient = true)
		%> version
		version@double = 1.11
	end
	
	properties (Dependent = true, SetAccess = private, GetAccess = public)
		%> number of loaded units
		nSites
	end
	
	properties (SetAccess = private, GetAccess = private)
		oldDir@char
		previousSelection@double = 0
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
		function me=LFPMeta(varargin)
			if nargin == 0; varargin.name = 'LFPMeta';end
			me=me@analysisCore(varargin); %superclass constructor
			if nargin>0; me.parseArgs(varargin, me.allowedProperties); end
			if isempty(me.name);me.name = 'LFPMeta'; end
			me.plotRange = [-0.35 0.35];
			makeUI(me);
		end
		
		% ===================================================================
		%> @brief add LFPAnalysis objects to the meta list
		%>
		%> @param
		%> @return
		% ===================================================================
		function add(me, varargin)
			[file,path]=uigetfile('*.mat','Meta-Analysis:Choose LFP source File','Multiselect','on');
			if ~iscell(file) && ~ischar(file)
				warning('Meta-Analysis Error: No File Specified')
				return
			end
	
			cd(path);
			if ischar(file)
				file = {file};
			end
			
			if size(me.list,2) > size(me.list,1)
				me.list = rot90(me.list);
				if size(me.raw,2) > size(me.raw,1)
					me.raw = rot90(me.raw);
				end
			end
			
			addtic = tic;
			l = length(file);
			for ll = 1:length(file)
				notifyUI(me,sprintf('Loading %g of %g Cells...',ll,l));
				load(file{ll});
				if exist('lfp','var') && isa(lfp,'LFPAnalysis')
					optimiseSize(lfp);
					lfp.results = struct();
					idx = me.nSites+1;
					me.raw{idx,1} = lfp;
					%generateSitesInfo(me,idx);
				else
					warndlg('This file wasn''t an LFPAnalysis MAT file...')
					return
				end
				clear lfp
			end
			
			generateSitesList(me);
			tt=toc(addtic);
			fprintf('Cell loading took %.5g seconds\n',tt)
			notifyUI(me,sprintf('Loaded %g Cells in %.5gsecs, you now need to process them...',me.nSites,tt));
			
		end
		
		% ===================================================================
		%> @brief 
		%>
		%> @param
		%> @return
		% ===================================================================
		function process(me, varargin)
			if me.nSites > 0
				me.handles.axistabs.Selection = 1;
				me.previousSelection = -1;
				ho = me.handles.axisind;
				delete(ho.Children);
				ho = me.handles.axisall;
				delete(ho.Children);
				as = get(me.handles.analmethod,'String');
				am = get(me.handles.analmethod,'Value');
				setOptions(me); %initialise the various analysisCore options fields
				ptic = tic;
				for i = 1 : me.nSites
					notifyUI(me,sprintf('Reprocessing Fieldtrip %s analysis for site %i...',as{am},i));
					me.raw{i}.doPlots = false;
					me.raw{i}.options = me.options;
					me.raw{i}.baselineWindow = me.baselineWindow;
					me.raw{i}.measureRange = me.measureRange;
					me.raw{i}.plotRange = me.plotRange;
					if am == 1 %timelock
						cfg = [];cfg.keeptrials = 'yes';
						me.raw{i}.ftTimeLockAnalysis(cfg);
					else
						cfg = [];cfg.keeptrials = 'no';
						me.raw{i}.ftFrequencyAnalysis(cfg);
					end
				end
				notifyUI(me,'Fieldtrip Reprocessing for %s analysis completed for %i sites; took %g s',as{am},i,toc(ptic));
				plotSite(me);
			end
		end
		
		% ===================================================================
		%> @brief run the averaging of the data
		%>
		%> @param
		%> @return
		% ===================================================================
		function run(me,varargin)
			if me.nSites > 0
				me.previousSelection = -1;
				me.handles.axistabs.Selection = 2;
				ho = me.handles.axisall;
				delete(ho.Children);
				as = get(me.handles.analmethod,'String');
				am = get(me.handles.analmethod,'Value');
				notifyUI(me,'Starting computing the Fieldtrip Grand Average for dataset: %s',as{am});
				rtic = tic;
				for i = 1: me.nSites
					me.raw{i}.doPlots = false;
					me.raw{i}.options = me.options;
					me.raw{i}.baselineWindow = me.baselineWindow;
					me.raw{i}.measureRange = me.measureRange;
					me.raw{i}.plotRange = me.plotRange;
					if am == 1 %timelock
						if ~isfield(me.raw{i}.results,'av')
							errordlg('You have''nt Processed the data yet...')
						end
						metaA{i} = me.raw{i}.results.av{1};
						metaB{i} = me.raw{i}.results.av{2};
						metaA{i}.label = {'LFP'}; %force an homogeneous label name
						metaB{i}.label = {'LFP'};
						metaA{i}.dimord = 'chan_time';
						metaB{i}.dimord = 'chan_time';
					else
						metaA{i} = me.raw{i}.results.(['fq' me.options.method]){1};
						metaB{i} = me.raw{i}.results.(['fq' me.options.method]){2};
						metaA{i}.label = {'LFP'}; %force an homogeneous label name
						metaB{i}.label = {'LFP'};
					end
				end
				
				if am == 1 %timelock
					cfg						= [];
					cfg.channel				= 'all';
					cfg.keepindividual	= 'no';
					cfg.parameter			= 'avg';
					cfg.method				= 'across'; %(default) or 'within', see below.
% 					cfg.latency				= me.measureRange;
% 					cfg.normalizevar		= 'N' or 'N-1' (default = 'N-1')
					avgA = ft_timelockgrandaverage(cfg, metaA{:});
					avgB = ft_timelockgrandaverage(cfg, metaB{:});
				else %powerspectrum
					cfg						= [];
					cfg.channel				= 'all';metaA{1}.label;
					cfg.keepindividual	= 'no';
					cfg.parameter			= 'powspctrm';
					cfg.foilim				= 'all';
					cfg.toilim				= 'all';
					avgA = ft_freqgrandaverage([], metaA{:});
					avgB = ft_freqgrandaverage([], metaB{:});
				end
				
				h = uipanel('Parent',ho,'units', 'normalized', 'position', [0 0 1 1],'BackgroundColor',[1 1 1],'BorderType','none');

				if am == 1 %timelock
					axes('Parent',h);
					e = analysisCore.var2SE(avgA.var, avgA.dof);
					me.areabar(avgA.time,avgA.avg, e, [0.5 0.5 0.5],0.5,'k.-');
					hold on
					e = analysisCore.var2SE(avgB.var, avgB.dof);
					me.areabar(avgB.time, avgB.avg, e, [0.5 0.5 0.5],0.5,'r.-');
					hold off
					legend('Group A','Group B')
					grid on
					xlim(me.plotRange)
					title('Population average')
					xlabel('Time (s)');
					ylabel('Voltage (mV) ±1S.E.');
				else
					p=panel(h);
					p.margin = [15 15 30 20];%left bottom right top
					p.pack(2,1);
					p(1,1).select();
					cfg						= [];
					cfg.fontsize			= 13;
					if strcmpi(me.options.bline,'no')
						cfg.baseline = 'no';
					else
						cfg.baselinetype		= me.options.bline;
						cfg.baseline			= me.baselineWindow;
						if strcmpi(cfg.baselinetype,'relative')
							cfg.zlim					= [0 2];
						end
					end
					cfg.interactive		= 'no';
					cfg.channel				= metaA{1}.label;
					cfgOut					= ft_singleplotTFR(cfg, avgA);
					title(['GROUP A Average of ' num2str(me.nSites)])
					grid on; box on;
					set(gca,'Layer','top','TickDir','out')
					ah{1} = gca;
					clim = get(gca,'clim');
					hmin(1) = min(clim);
					hmax(1) = max(clim);
					xlabel('Time (s)');
					ylabel('Frequency (Hz)');
					p(2,1).select();
					cfgOut						= ft_singleplotTFR(cfg, avgB);
					title(['GROUP A Average of ' num2str(me.nSites)])
					grid on; box on;
					set(gca,'Layer','top','TickDir','out')
					ah{2} = gca;
					clim = get(gca,'clim');
					hmin(2) = min(clim);
					hmax(2) = max(clim);
					xlabel('Time (s)');
					ylabel('Frequency (Hz)');
					set(ah{1},'clim', [min(hmin) max(hmax)]);
					set(ah{2},'clim', [min(hmin) max(hmax)]);
					colormap default;
					colormap('jet');
					end
				notifyUI(me,'Finished computing the Grand Average for dataset: %s; took %g s',as{am},toc(rtic));
			end
			
		end
		% ===================================================================
		%> @brief 
		%>
		%> @param
		%> @return
		% ===================================================================
		function load(me, varargin)
			[file,path]=uigetfile('*.mat','Meta-Analysis:Choose MetaAnalysis');
			if ~ischar(file)
				errordlg('No File Specified', 'Meta-Analysis Error');
				return
			end
			notifyUI(me,'Loading MetaAnalysis object, please be patient...');
			cd(path);
			ltic=tic;
			load(file);
			if exist('lfpmet','var') && isa(lfpmet,'LFPMeta')
				reset(me);
				for i = 1:length(lfpmet.raw)
					lfpmet.raw{i}.results = struct();
				end
				me.raw = lfpmet.raw;
			end
			generateSitesList(me);
			clear lfpmet
			notifyUI(me,'Loaded MetaAnalysis object: %i sites took %.3gs; use context menu to reparse and analyse',me.nSites,toc(ltic));
		end
		
		% ===================================================================
		%> @brief 
		%>
		%> @param
		%> @return
		% ===================================================================
		function save(me, varargin)
			[file,path] = uiputfile('*.mat','Save Meta Analysis:');
			if ~ischar(file)
				errordlg('No file selected...')
				return 
			end
			fprintf('<strong>:#:</strong> Saving LFPAnalysis object: ...\t');
			notifyUI(me,'Saving MetaAnalysis object...');
			stic = tic;
			me.oldDir = pwd;
			cd(path);
			lfpmet = me; %#ok<NASGU>
			for i = 1:length(lfpmet.raw)
				lfpmet.raw{i}.results = struct();
			end
			save(file,'lfpmet');
			clear lfpmet;
			cd(me.oldDir);
			to = round(toc(stic)*1000);
			fprintf('... took <strong>%g ms</strong>\n',to);
			notifyUI(me,'MetaAnalysis object saved in %gms, you''ll need to reanalyse now...',to);
		end
		
		% ===================================================================
		%> @brief
		%>
		%> @param
		%> @return
		% ===================================================================
		function spawn(me, varargin)
			tab = me.handles.axistabs.Selection;
			switch tab
				case 1
					gh = me.handles.axisind;
				otherwise
					gh = me.handles.axisall;
			end
			h = figure;
			figpos(1,[1000 800]);
			set(h,'Color',[1 1 1]);
			hh = copyobj(gh,h);
			set(hh,'Units','normalized','Position',[0 0 1 1]); 
			set(hh.Children,'Units','normalized','Position',[0 0 1 1]);
			colormap('jet')
		end
		
		% ===================================================================
		%> @brief
		%>
		%> @param
		%> @return
		% ===================================================================
		function toggleSaccades(me, varargin)
			if me.nSites > 0
				notifyUI(me,'Will start to toggle the saccade align state for all sites...')
				firstState = false;
				for i = 1 : me.nSites
					if i == 1
						me.raw{i}.toggleSaccadeRealign
						firstState = me.raw{i}.p.saccadeRealign; %keep our first state saved
					else
						if firstState ~= me.raw{i}.p.saccadeRealign; %make sure all states will sync to first
							me.raw{i}.toggleSaccadeRealign
						end
					end
					t = sprintf('Saccade align state has been toggled to %i for site %i...',firstState,i);
					notifyUI(me,t)
				end
				t = sprintf('Saccade align state has been toggled to %i for all sites, please reprocess',firstState);
				notifyUI(me,t)
			end
		end
		
		% ===================================================================
		%> @brief get method for nSites
		%>
		%> @param
		%> @return
		% ===================================================================
		function value = get.nSites(me)
			value = length(me.raw);
			if isempty(value)
				value = 0;
				return
			elseif value == 1 && iscell(me.raw) && isempty(me.raw{1})
				value = 0;
			end
		end
		
		% ===================================================================
		%> @brief
		%>
		%> @param
		%> @return
		% ===================================================================
		function quit(me, varargin)
			reset(me);
			closeUI(me);
		end

	end%-------------------------END PUBLIC METHODS--------------------------------%
	
	%=======================================================================
	methods (Hidden = true) %------------------Hidden METHODS
	%=======================================================================
	
		% ===================================================================
		%> @brief
		%>
		%> @param
		%> @return
		% ===================================================================
		function cleanPaths(me,varargin)
			me.rootDirectory = uigetdir([],'Please select new root folder');
			rD = me.rootDirectory;
			if ~isempty(regexpi(rD,[filesep '$'])); rD = rD(1:end-1); end
			fprintf('\n--->>> Will rebuild directories using %s \n',rD);
			for i = 1:numel(me.raw)
				if isprop(me.raw{i},'rootDirectory')
					me.raw{i}.rootDirectory = me.rootDirectory;
				end
				me.raw{i}.checkPaths();
			end
			generateSitesList(me);
		end
		
		% ===================================================================
		%> @brief plot individual
		%>
		%> @param
		%> @return
		% ===================================================================
		function select(me, varargin)
			if me.nSites > 0
				tab = me.handles.axistabs.Selection;
				sel = get(me.handles.list,'Value');
				me.raw{sel}.select();
				notifyUI(me,'If you have changed the selection for a site, you will need to reanalyse/recompute averages');
			end
			generateSitesList(me);
		end
		
		% ===================================================================
		%> @brief plot individual
		%>
		%> @param
		%> @return
		% ===================================================================
		function plotSite(me, varargin)
			tab = get(me.handles.axistabs, 'Selection');
			if me.nSites > 0 && tab == 1
				sel = get(me.handles.list, 'Value');
				if ~isempty(fieldnames(me.raw{sel}.results))
					plot(me);
				else
					fprintf('--->>> There are no fieldtrip results for this site, cannot plot...\n')
				end
			end
		end
		
		% ===================================================================
		%> @brief plot individual
		%>
		%> @param
		%> @return
		% ===================================================================
		function plot(me, varargin)
			if me.nSites > 0
				analmethod = get(me.handles.analmethod, 'Value');
				sel = get(me.handles.list, 'Value');
				ho = me.handles.axisind;
				delete(ho.Children);
				h = uipanel('Parent',ho,'units', 'normalized', 'position', [0 0 1 1],'BackgroundColor',[1 1 1],'BorderType','none');
				me.raw{sel}.plotDestination = h;
				if sel ~= me.previousSelection;
					switch analmethod
						case 1
							plot(me.raw{sel},'timelock');		
						case 2
							plot(me.raw{sel},'freq');
					end
				end
				me.previousSelection = sel;
			end
		end
		
		% ===================================================================
		%> @brief setOptions shows the analysis options
		%>
		%> @param
		%> @return
		% ===================================================================
		function setOptions(me, varargin)
			initialise(me);
			setTimeFreqOptions(me);
			setStats(me);
			for i = 1:me.nSites
				if isprop(me.raw{i},'options')
					me.raw{i}.options = me.options;
					me.raw{i}.sp.options = me.options;
				end
				me.raw{i}.baselineWindow = me.baselineWindow;
				me.raw{i}.plotRange = me.plotRange;
				me.raw{i}.sp.baselineWindow = me.baselineWindow;
				me.raw{i}.sp.plotRange = me.plotRange;
			end
		end
		
		% ============================================='uipanel======================
		%> @brief
		%>
		%> @param
		%> @return
		% ===================================================================
		function editweight(me, varargin)
			if me.nSites > 0
				sel = get(me.handles.list,'Value');
				w = str2num(get(me.handles.weight,'String'));
				if length(w) == 2;
					me.sites{sel,1}.weight = w(1);
					me.sites{sel,2}.weight = w(2);
					if min(w) == 0
						s = me.list{sel};
						s = regexprep(s,'^\*+','');
						s = ['**' s];
						me.list{sel} = s;
						set(me.handles.list,'String',me.list);
					elseif min(w) < 1
						s = me.list{sel};
						s = regexprep(s,'^\*+','');
						s = ['*' s];
						me.list{sel} = s;
						set(me.handles.list,'String',me.list);
					else
						s = me.list{sel};
						s = regexprep(s,'^\*+','');
						me.list{sel} = s;
						set(me.handles.list,'String',me.list);
					end
				end
				replot(me);
			end
		end
		
		% ===================================================================
		%> @brief 
		%>
		%> @param
		%> @return
		% ===================================================================
		function remove(me, varargin)
			if me.nSites > 0
				sel = get(me.handles.list,'Value');
				me.sites(sel,:) = [];
				me.list(sel) = [];
				me.raw(sel) = [];
				if sel > 1
					set(me.handles.list,'Value',sel-1);
				end
				set(me.handles.list,'String',me.list);
			end
		end
		
		% ===================================================================
		%> @brief 
		%>
		%> @param
		%> @return
		% ===================================================================
		function reparse(me,varargin)
			if me.nSites > 0
				sel = get(me.handles.list,'Value');
				me.raw{sel}.reparse;
			end
		end

		% ===================================================================
		%> @brief 
		%>
		%> @param
		%> @return
		% ===================================================================
		function parse(me,varargin)
			if me.nSites > 0
				sel = get(me.handles.list,'Value');
				me.raw{sel}.parse;
			end
		end
		
		% ===================================================================
		%> @brief 
		%>
		%> @param
		%> @return
		% ===================================================================
		function reset(me,varargin)
			try
				notifyUI(me,'Resetting all data...');
				drawnow
				me.raw = cell(1);
				me.sites = cell(1);
				me.list = cell(1);
				if isfield(me.handles,'list')
					set(me.handles.list,'Value',1);
					set(me.handles.list,'String',{''});
				end
				ho = me.handles.axisind;
				delete(ho.Children);
				ho = me.handles.axisall;
				delete(ho.Children);
				me.handles.axistabs.SelectedChild = 1;
				me.handles.axistabs.Selection = 1;
				if isfield(me.handles,'axis1')
					me.handles.axistabs.SelectedChild=2; 
					axes(me.handles.axis2);cla
					me.handles.axistabs.SelectedChild=1; 
					axes(me.handles.axis1); cla
					set(me.handles.root,'Title',['Number of Cells Loaded: ' num2str(me.nSites)]);
				end
			end
		end
		
	end%-------------------------END HIDDEN METHODS--------------------------------%
	
	%=======================================================================
	methods (Access = protected) %------------------PRIVATE METHODS
	%=======================================================================
	
		% ===================================================================
		%> @brief generates the selection information
		%>
		%> @param
		%> @return
		% ===================================================================
		function generateSitesInfo(me,idx)
			for i = 1:2
				if ~isempty(me.raw{idx}.selectedTrials)
					me.sites{idx,i}.name = [me.raw{idx}.selectedTrials{i}.name];
				else
					me.sites{idx,i}.name = 'unknown';
				end
				me.sites{idx,i}.weight = 1;
				me.sites{idx,i}.selLFP = me.raw{idx}.selectedLFP;
				me.sites{idx,i}.selUnit = me.raw{idx}.sp.selectedUnit;
				me.sites{idx,i}.type = 'LFPAnalysis';
				me.sites{idx,i}.file = me.raw{idx}.lfpfile;
			end
		end
		% ===================================================================
		%> @brief generates the list shown in the GUI
		%>
		%> @param
		%> @return
		% ===================================================================
		function generateSitesList(me)
			for idx = 1 : me.nSites
				generateSitesInfo(me,idx);
				t = [me.sites{idx,1}.name '>>>' me.sites{idx,2}.name];
				if strcmpi(me.sites{idx,1}.type,'oPro')
					t = regexprep(t,'[\|\s][\d\-\.]+','');
				else
					
				end
				t = [me.raw{idx}.lfpfile ': ' t];
				me.list{idx,1} = t;
			end

			if size(me.list,2) > size(me.list,1)
				me.list = rot90(me.list);
				if size(me.raw,2) > size(me.raw,1)
					me.raw = rot90(me.raw);
				end
			end
			
			[me.list, indx] = sortrows(me.list);
			me.raw = me.raw(indx);
			
			v = get(me.handles.list,'Value');
			if v > me.nSites
				set(me.handles.list,'Value',me.nSites);
			end
			set(me.handles.list,'String',me.list);
		end
		
		% ===================================================================
		%> @brief 
		%>
		%> @param
		%> @return
		% ===================================================================
		function closeUI(me)
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
		function makeUI(me)
			if ~isempty(me.handles) && isfield(me.handles,'root') && isa(me.handles.root,'uix.BoxPanel')
				fprintf('---> UI already open!\n');
				return
			end
			if ~exist('parent','var')
				parent = figure('Tag','LMAMeta', ...
					'Name', ['LFP Meta Analysis V' num2str(me.version)], ...
					'MenuBar', 'none', ...
					'CloseRequestFcn', @me.quit, ...
					'NumberTitle', 'off');
				figpos(1,[1600 800])
			end
			me.handles(1).parent = parent;
			
			%make context menu
			hcmenu = uicontextmenu;
			uimenu(hcmenu,'Label','Parse (selected)','Callback',@me.parse,'Accelerator','p');
			uimenu(hcmenu,'Label','Reparse (selected)','Callback',@me.reparse,'Accelerator','e');
			uimenu(hcmenu,'Label','Select (selected)','Callback',@me.select,'Accelerator','s');
			uimenu(hcmenu,'Label','Show GUI (selected)','Callback',@me.remove,'Accelerator','g');
			uimenu(hcmenu,'Label','Remove (selected)','Callback',@me.remove,'Accelerator','x');
			uimenu(hcmenu,'Label','I. Reanalyse (all)','Callback',@me.process,'Separator','on','Accelerator','r');
			uimenu(hcmenu,'Label','II. Average (all)','Callback',@me.run,'Accelerator','a');
			uimenu(hcmenu,'Label','Toggle Saccades (all)','Callback',@me.toggleSaccades,'Separator','on');
			uimenu(hcmenu,'Label','Clean up Paths (all)','Callback',@me.cleanPaths);
			
			fs = 11;
			SansFont = 'Avenir Next';
			MonoFont = 'Menlo';
			bgcolor = [0.89 0.89 0.89];
			bgcoloredit = [0.9 0.9 0.9];

			handles.parent = me.handles.parent; %#ok<*PROP>
			handles.root = uix.BoxPanel('Parent',parent,...
				'Title','Please load some data...',...
				'FontName',SansFont,...
				'FontSize',fs+3,...
				'FontWeight','bold',...
				'Padding',0,...
				'TitleColor',[0.7 0.68 0.66],...
				'BackgroundColor',bgcolor);

			handles.hbox = uix.HBoxFlex('Parent', handles.root,'Padding',0,...
				'Spacing', 5, 'BackgroundColor', bgcolor);
			handles.axistabs = uix.TabPanel('Parent', handles.hbox,'Padding',0,...
				'BackgroundColor',bgcolor,'TabWidth',120,'FontSize', fs+1,'FontName',SansFont);
			handles.axisind = uix.Panel('Parent', handles.axistabs,'Padding',0,...
				'BackgroundColor',[1 1 0.95]);
			handles.axisall = uix.Panel('Parent', handles.axistabs,'Padding',0,...
				'BackgroundColor',[1 0.95 0.95]);
			handles.axistabs.TabTitles = {'Individual','Population'};
			
			handles.controls = uix.VBox('Parent', handles.hbox,'Padding',0,'Spacing',0,'BackgroundColor',bgcolor);
			handles.controls1 = uix.Grid('Parent', handles.controls,'Padding',4,'Spacing',2,'BackgroundColor',bgcolor);
			handles.controls3 = uix.Grid('Parent', handles.controls,'Padding',4,'Spacing',2,'BackgroundColor',bgcolor);
			handles.controls2 = uix.Grid('Parent', handles.controls,'Padding',4,'Spacing',0,'BackgroundColor',bgcolor);
			
			handles.addbutton = uicontrol('Style','pushbutton',...
				'Parent',handles.controls1,...
				'Tag','LMAaddbutton',...
				'FontName',SansFont,...
				'FontSize', fs,...
				'Tooltip','Add a singe LFP item',...
				'Callback',@me.add,...
				'String','Add');
			handles.removebutton = uicontrol('Style','pushbutton',...
				'Parent',handles.controls1,...
				'Tag','LMAremovebutton',...
				'FontName',SansFont,...
				'FontSize', fs,...
				'Tooltip','Remove a single item',...
				'Callback',@me.remove,...
				'String','Remove');
			handles.loadbutton = uicontrol('Style','pushbutton',...
				'Parent',handles.controls1,...
				'Tag','LMAloadbutton',...
				'FontName',SansFont,...
				'FontSize', fs,...
				'Tooltip','Load a previous meta analysis',...
				'Callback',@me.load,...
				'String','Load');
			handles.savebutton = uicontrol('Style','pushbutton',...
				'Parent',handles.controls1,...
				'Tag','LMAsavebutton',...
				'Tooltip','Save the meta-analysis',...
				'FontName',SansFont,...
				'FontSize', fs,...
				'Callback',@me.save,...
				'String','Save');
			handles.spawnbutton = uicontrol('Style','pushbutton',...
				'Parent',handles.controls1,...
				'Tag','LMAspawnbutton',...
				'FontName',SansFont,...
				'FontSize', fs,...
				'Callback',@me.spawn,...
				'String','Spawn');
			handles.resetbutton = uicontrol('Style','pushbutton',...
				'Parent',handles.controls1,...
				'Tag','LMAreplotbutton',...
				'FontName',SansFont,...
				'FontSize', fs,...
				'Callback',@me.reset,...
				'String','Reset');
			handles.optionsbutton = uicontrol('Style','pushbutton',...
				'Parent',handles.controls1,...
				'Tag','LMAsettingsbutton',...
				'FontName',SansFont,...
				'FontSize', fs,...
				'Callback',@me.setOptions,...
				'String','Options');
			handles.saccbutton = uicontrol('Style','pushbutton',...
				'Parent',handles.controls1,...
				'Tag','LMAsaccbutton',...
				'FontName',SansFont,...
				'FontSize', fs,...
				'Tooltip','Toggle Saccade Realign',...
				'Callback',@me.toggleSaccades,...
				'String','Saccade-toggle');
% 			handles.weight = uicontrol('Style','edit',...
% 				'Parent',handles.controls1,...
% 				'Tag','LMAweight',...
% 				'FontSize', fs,...
% 				'Enable','off',...
% 				'Tooltip','Cell Weight',...
% 				'Callback',@me.editweight,...
% 				'BackgroundColor',bgcoloredit,...
% 				'String','1 1');
			
			handles.list = uicontrol('Style','listbox',...
				'Parent',handles.controls2,...
				'Tag','LMAlistbox',...
				'Min',1,...
				'Max',1,...
				'FontSize',fs+1,...
				'FontName',MonoFont,...
				'Callback',@me.plotSite,...
				'String',{''},...
				'uicontextmenu',hcmenu);
			
			handles.analmethod = uicontrol('Style','popupmenu',...
				'Parent',handles.controls3,...
				'FontName',SansFont,...
				'FontSize', fs,...
				'Tag','LMAanalmethod',...
				'String',{'timelock','power'});
			handles.reanalbutton = uicontrol('Style','pushbutton',...
				'Parent',handles.controls3,...
				'Tag','LMAreanalbutton',...
				'FontName',SansFont,...
				'FontSize', fs,...
				'Callback',@me.process,...
				'String','I. Reanalyse All');
			handles.runbutton = uicontrol('Style','pushbutton',...
				'Parent',handles.controls3,...
				'Tag','LMAsettingsbutton',...
				'FontName',SansFont,...
				'FontSize', fs,...
				'Callback',@me.run,...
				'String','II. Average All');
			
			set(handles.hbox,'Widths', [-3 -1]);
			set(handles.controls,'Heights', [70 35 -1]);
			set(handles.controls1,'Heights', [-1 -1])
			set(handles.controls3,'Widths', [-1], 'Heights', [-1])

			me.handles = handles;
			me.openUI = true;
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
			else
				info = varargin{1};
			end
			try set(me.handles.root,'Title',info); drawnow; end %#ok<TRYNC>
		end
		
		% ===================================================================
		%> @brief 
		%>
		%> @param
		%> @return
		% ===================================================================
		function updateUI(me)
			
		end
	end	
end
