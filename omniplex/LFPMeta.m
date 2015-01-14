classdef LFPMeta < analysisCore
	
	properties
		%verbosity
		verbose = true;
		%> various stats values in a structure for different analyses
		options@struct
	end
	
	properties (SetAccess = protected, GetAccess = public)
		%> cells (sites)
		cells@cell
		%> display list
		list@cell
		%> raw LFP objects
		raw@cell
		%> meta results
		results
	end
	
	properties (SetAccess = protected, GetAccess = public, Transient = true)
		%> version
		version@double = 0.81
	end
	
	properties (Dependent = true, SetAccess = private, GetAccess = public)
		%> number of loaded units
		nSites
	end
	
	properties (SetAccess = private, GetAccess = private)
		oldDir@char
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
			initialiseOptions(me);
			makeUI(me);
		end
		
		% ===================================================================
		%> @brief add LFPAnalysis objects to the meta list
		%>
		%> @param
		%> @return
		% ===================================================================
		function add(me,varargin)
			[file,path]=uigetfile('*.mat','Meta-Analysis:Choose LFP source File','Multiselect','on');
			if ~iscell(file) && ~ischar(file)
				warning('Meta-Analysis Error: No File Specified')
				return
			end
	
			cd(path);
			if ischar(file)
				file = {file};
			end
			
			addtic = tic;
			l = length(file);
			for ll = 1:length(file)
				notifyUI(me,sprintf('Loading %g of %g Cells...',ll,l));
				load(file{ll});
				if exist('lfp','var') && isa(lfp,'LFPAnalysis')
					optimiseSize(lfp);
					idx = me.nSites+1;
					me.raw{idx} = lfp;
					for i = 1:2
						if ~isempty(lfp.selectedTrials)
							me.cells{idx,i}.name = [lfp.selectedTrials{i}.name];
						else
							me.cells{idx,i}.name = 'unknown';
						end
						me.cells{idx,i}.weight = 1;
						me.cells{idx,i}.selLFP = lfp.selectedLFP;
						me.cells{idx,i}.selUnit = lfp.sp.selectedUnit;
						me.cells{idx,i}.type = 'LFPAnalysis';
					end
				else
					warndlg('This file wasn''t an LFPAnalysis MAT file...')
					return
				end

				t = [me.cells{idx,1}.name '>>>' me.cells{idx,2}.name];
				if strcmpi(me.cells{idx,1}.type,'oPro')
					t = regexprep(t,'[\|\s][\d\-\.]+','');
				else
					
				end
				t = [lfp.lfpfile ' : ' t];
				me.list{idx} = t;

				set(me.handles.list,'String',me.list);
				set(me.handles.list,'Value',me.nSites);

				clear lfp
			end
			
			fprintf('Cell loading took %.5g seconds\n',toc(addtic))
			notifyUI(me,sprintf('Loaded %g Cells, you now need to process them...',me.nSites));
			
		end
		
		
		% ===================================================================
		%> @brief plot individual
		%>
		%> @param
		%> @return
		% ===================================================================
		function plot(me,varargin)
			if me.nSites > 0
				tab = me.handles.axistabs.Selection;
				sel = get(me.handles.list,'Value');
				switch tab
					case 1
						ho = me.handles.axisind;
						delete(ho.Children);
						h = uipanel('Parent',ho,'units', 'normalized', 'position', [0 0 1 1]);
						me.raw{sel}.plotDestination = h;
						plot(me.raw{sel},'timelock');
					case 2
						ho = me.handles.axisall;
						delete(ho.Children);
						h = uipanel('Parent',ho,'units', 'normalized', 'position', [0 0 1 1]);
						me.raw{sel}.plotDestination = h;
				end
				
			end
		end
		
		% ===================================================================
		%> @brief plot individual
		%>
		%> @param
		%> @return
		% ===================================================================
		function plotSite(me,varargin)
			if me.nSites > 0
				me.handles.axistabs.Selection = 1;
				plot(me);
			end
		end
		
		% ===================================================================
		%> @brief 
		%>
		%> @param
		%> @return
		% ===================================================================
		function process(me,varargin)
			if me.nSites > 0
				am = get(me.handles.analmethod,'Value');
				for i = 1: me.nSites
					notifyUI(me,sprintf('Reprocessing the timelock/frequency analysis for site %i',i));
					me.raw{i}.doPlots = false;
					me.raw{i}.stats = me.stats;
					me.raw{i}.baselineWindow = me.baselineWindow;
					me.raw{i}.measureRange = me.measureRange;
					me.raw{i}.plotRange = me.plotRange;
					
					if am == 1 %timelock
						cfg = [];cfg.keeptrials = 'yes';
						me.raw{i}.ftTimeLockAnalysis(cfg);
	
					else
						me.raw{i}.ftFrequencyAnalysis([],...
							me.options.tw,...
							me.options.cycles,...
							me.options.smth,...
							me.options.width);
					end
					
				end
				notifyUI(me,'Reprocessing complete for %i sites',i);
			end
		end
		
		% ===================================================================
		%> @brief 
		%>
		%> @param
		%> @return
		% ===================================================================
		function run(me,varargin)
			if me.nSites > 0
				
				am = get(me.handles.analmethod,'Value');
				
				for i = 1: me.nSites
					
					me.raw{i}.doPlots = false;
					me.raw{i}.stats = me.stats;
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
						
						metaA{i} = me.raw{i}.(['fq' me.options.method]){1};
						metaB{i} = me.raw{i}.(['fq' me.options.method]){1};
						
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
				else
					
				end
				
				me.handles.axistabs.Selection = 2;
				ho = me.handles.axisall;
				delete(ho.Children);
				h = uipanel('Parent',ho,'units', 'normalized', 'position', [0 0 1 1]);
				ha = axes('Parent',h);
				e = analysisCore.var2SE(avgA.var, avgA.dof);
				areabar(avgA.time,avgA.avg, e);
				hold on
				e = analysisCore.var2SE(avgB.var, avgB.dof);
				areabar(avgB.time, avgB.avg, e);
				xlabel('Time (s)');
				ylabel('Voltage (mV)');

			end
			
		end
		% ===================================================================
		%> @brief 
		%>
		%> @param
		%> @return
		% ===================================================================
		function load(me,varargin)
			[file,path]=uigetfile('*.mat','Meta-Analysis:Choose MetaAnalysis');
			if ~ischar(file)
				errordlg('No File Specified', 'Meta-Analysis Error');
				return
			end
			
			cd(path);
			load(file);
			if exist('lfpmet','var') && isa(fgmet,'LFPMeta')
				reset(me);
				me.raw = lfpmet.raw;
				me.cells = lfpmet.cells;
				me.list = lfpmet.list;
				me.mint = lfpmet.mint;
				me.maxt = lfpmet.maxt;
				set(me.handles.list,'String',me.list);
				set(me.handles.list,'Value',me.nSites);
			end
			
			clear lfpmet
			
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
			me.oldDir = pwd;
			cd(path);
			lfpmet = me; %#ok<NASGU>
			save(file,'lfpmet');
			clear lfpmet;
			cd(me.oldDir);
		end
		
		% ===================================================================
		%> @brief
		%>
		%> @param
		%> @return
		% ===================================================================
		function spawn(me, varargin)
			gh = gca;
			h = figure;
			figpos(1,[1000 800]);
			set(h,'Color',[1 1 1]);
			hh = copyobj(gh,h);
		end
		
		% ===================================================================
		%> @brief
		%>
		%> @param
		%> @return
		% ===================================================================
		function toggleSaccades(me, varargin)
			if me.nSites > 0
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
					
				end
			end
		end
		
		% ===================================================================
		%> @brief
		%>
		%> @param
		%> @return
		% ===================================================================
		function value = get.nSites(me)
			value = length(me.list);
			if isempty(value)
				value = 0;
				return
			elseif value == 1 && iscell(me.list) && isempty(me.list{1})
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
		
		% ===================================================================
		%> @brief showInfo shows the info box for the plexon parsed data
		%>
		%> @param
		%> @return
		% ===================================================================
		function options = setOptions(me, varargin)
			initialiseOptions(me);
			
			mlist1={'fix1', 'fix2', 'mtm1','mtm2','morlet','tfr'};
			mt = 'p';
			for i = 1:length(mlist1)
				if strcmpi(mlist1{i},me.options.method)
					mt = [mt '|¤' mlist1{i}];
				else
					mt = [mt '|' mlist1{i}];
				end
			end
			
			mlist2={'no','relative','absolute','dB'};
			bline = 'p';
			for i = 1:length(mlist2)
				if strcmpi(mlist2{i},me.options.bline)
					bline = [bline '|¤' mlist2{i}];
				else
					bline = [bline '|' mlist2{i}];
				end
			end

			mtitle   = ['Select Statistics Settings'];
			options  = {[mt],'Main LFP Method (method):'; ...
				[bline],'Baseline Correction (bline):'; ...
				['t|' num2str(me.options.tw)],'LFP Time Window (tw):'; ...
				['t|' num2str(me.options.cycles)],'LFP # Cycles (cycles):'; ...
				['t|' num2str(me.options.smth)],'Smoothing Value (smth):'; ...
				['t|' num2str(me.options.width)],'LFP Taper Width (width):'; ...
				};
			
			answer = menuN(mtitle,options);
			drawnow;
			if iscell(answer) && ~isempty(answer)
				me.options.method		= mlist1{answer{1}};
				me.options.bline		= mlist2{answer{2}};
				me.options.tw			= str2num(answer{3});
				me.options.cycles		= str2num(answer{4});
				me.options.smth		= str2num(answer{5});
				me.options.width		= str2num(answer{6});
			end
			
			options = me.options;
			setStats(me);
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
		function editweight(me, varargin)
			if me.nSites > 0
				sel = get(me.handles.list,'Value');
				w = str2num(get(me.handles.weight,'String'));
				if length(w) == 2;
					me.cells{sel,1}.weight = w(1);
					me.cells{sel,2}.weight = w(2);
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
				me.cells(sel,:) = [];
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
		function reset(me,varargin)
			try
				notifyUI(me,'Resetting all data...');
				drawnow
				me.raw = cell(1);
				me.cells = cell(1);
				me.list = cell(1);
				if isfield(me.handles,'list')
					set(me.handles.list,'Value',1);
					set(me.handles.list,'String',{''});
				end
				ho = me.handles.axisind;
				delete(ho.Children);
				ho = me.handles.axisall;
				delete(ho.Children);
				me.handles.axistabs.SelectedChild=1;
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
		%> @brief
		%>
		%> @param
		%> @return
		% ===================================================================
		function initialiseOptions(me)
			if ~isfield(me.options,'method') || isempty(me.options.method)
				me.options(1).method = 'fix1';
			end
			if ~isfield(me.options,'bline') || isempty(me.options.bline)
				me.options(1).bline = 'no';
			end
			if ~isfield(me.options,'tw') || isempty(me.options.tw)
				me.options(1).tw = 0.2;
			end
			if ~isfield(me.options,'cycles') || isempty(me.options.cycles)
				me.options(1).cycles = 3;
			end
			if ~isfield(me.options,'smth') || isempty(me.options.smth)
				me.options(1).smth = 0.3;
			end
			if ~isfield(me.options,'width') || isempty(me.options.width)
				me.options(1).width = 7;
			end
		end
		
		% ===================================================================
		%> @brief
		%>
		%> @param
		%> @return
		% ===================================================================
		function [psth1,psth2,time]=computeAverage(me)
			
			for idx = 1:me.nSites
				
				
			end
			
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
			uimenu(hcmenu,'Label','Reparse (select)','Callback',@me.reparse,'Accelerator','e');
			uimenu(hcmenu,'Label','Plot (select)','Callback',@me.plot,'Accelerator','p');
			uimenu(hcmenu,'Label','Remove (select)','Callback',@me.remove,'Accelerator','r');
			uimenu(hcmenu,'Label','Process (all)','Callback',@me.process,'Separator','on');
			uimenu(hcmenu,'Label','Run (all)','Callback',@me.run);
			uimenu(hcmenu,'Label','Toggle Saccade (all)','Callback',@me.toggleSaccades);
			uimenu(hcmenu,'Label','Reset (all)','Callback',@me.reset);
			
			fs = 10;
			SansFont = 'Helvetica';
			MonoFont = 'Consolas';
			bgcolor = [0.89 0.89 0.89];
			bgcoloredit = [0.9 0.9 0.9];

			handles.parent = me.handles.parent; %#ok<*PROP>
			handles.root = uix.BoxPanel('Parent',parent,...
				'Title','Please load some data...',...
				'FontName',SansFont,...
				'FontSize',fs,...
				'FontWeight','normal',...
				'Padding',0,...
				'TitleColor',[0.8 0.78 0.76],...
				'BackgroundColor',bgcolor);

			handles.hbox = uix.HBoxFlex('Parent', handles.root,'Padding',0,...
				'Spacing', 5, 'BackgroundColor', bgcolor);
			handles.axistabs = uix.TabPanel('Parent', handles.hbox,'Padding',0,...
				'BackgroundColor',bgcolor,'TabWidth',120,'FontSize', fs+1,'FontName',SansFont);
			handles.axisind = uix.Panel('Parent', handles.axistabs,'Padding',0,...
				'BackgroundColor',bgcolor);
			handles.axisall = uix.Panel('Parent', handles.axistabs,'Padding',0,...
				'BackgroundColor',bgcolor);
			handles.axistabs.TabTitles = {'Individual','Population'};

			handles.controls = uix.VBox('Parent', handles.hbox,'Padding',0,'Spacing',0,'BackgroundColor',bgcolor);
			handles.controls1 = uix.Grid('Parent', handles.controls,'Padding',4,'Spacing',2,'BackgroundColor',bgcolor);
			handles.controls2 = uix.Grid('Parent', handles.controls,'Padding',4,'Spacing',0,'BackgroundColor',bgcolor);
			handles.controls3 = uix.Grid('Parent', handles.controls,'Padding',4,'Spacing',2,'BackgroundColor',bgcolor);
			
			handles.loadbutton = uicontrol('Style','pushbutton',...
				'Parent',handles.controls1,...
				'Tag','LMAloadbutton',...
				'FontSize', fs,...
				'Tooltip','Load a previous meta analysis',...
				'Callback',@me.load,...
				'String','Load');
			handles.savebutton = uicontrol('Style','pushbutton',...
				'Parent',handles.controls1,...
				'Tag','LMAsavebutton',...
				'Tooltip','Save the meta-analysis',...
				'FontSize', fs,...
				'Callback',@me.save,...
				'String','Save');
			handles.addbutton = uicontrol('Style','pushbutton',...
				'Parent',handles.controls1,...
				'Tag','LMAaddbutton',...
				'FontSize', fs,...
				'Tooltip','Add a singe LFP item',...
				'Callback',@me.add,...
				'String','Add');
			handles.removebutton = uicontrol('Style','pushbutton',...
				'Parent',handles.controls1,...
				'Tag','LMAremovebutton',...
				'FontSize', fs,...
				'Tooltip','Remove a single item',...
				'Callback',@me.remove,...
				'String','Remove');
% 			handles.saccbutton = uicontrol('Style','pushbutton',...
% 				'Parent',handles.controls1,...
% 				'Tag','LMAsaccbutton',...
% 				'FontSize', fs,...
% 				'Tooltip','Toggle Saccade Realign',...
% 				'Callback',@me.toggleSaccades,...
% 				'String','Toggle Saccades');
			handles.processbutton = uicontrol('Style','pushbutton',...
				'Parent',handles.controls1,...
				'Tag','LMArunbutton',...
				'FontSize', fs,...
				'Tooltip','(Re)Process the individual LFPs',...
				'Callback',@me.process,...
				'String','Process');
			handles.runbutton = uicontrol('Style','pushbutton',...
				'Parent',handles.controls1,...
				'Tag','LMArunbutton',...
				'FontSize', fs,...
				'Callback',@me.run,...
				'String','Run');
			handles.spawnbutton = uicontrol('Style','pushbutton',...
				'Parent',handles.controls1,...
				'Tag','LMAspawnbutton',...
				'FontSize', fs,...
				'Callback',@me.spawn,...
				'String','Spawn');
			handles.resetbutton = uicontrol('Style','pushbutton',...
				'Parent',handles.controls1,...
				'Tag','LMAreplotbutton',...
				'FontSize', fs,...
				'Callback',@me.reset,...
				'String','Reset');
			handles.optionsbutton = uicontrol('Style','pushbutton',...
				'Parent',handles.controls1,...
				'Tag','LMAsettingsbutton',...
				'FontSize', fs,...
				'Callback',@me.setOptions,...
				'String','Options');
% 			handles.max = uicontrol('Style','edit',...
% 				'Parent',handles.controls1,...
% 				'Tag','LMAmax',...
% 				'Tooltip','Cell Max Override',...
% 				'FontSize', fs,...
% 				'Callback',@me.editmax,...
% 				'String','0');
			handles.weight = uicontrol('Style','edit',...
				'Parent',handles.controls1,...
				'Tag','LMAweight',...
				'FontSize', fs,...
				'Tooltip','Cell Weight',...
				'Callback',@me.editweight,...
				'String','1 1');
			
			handles.list = uicontrol('Style','listbox',...
				'Parent',handles.controls2,...
				'Tag','LMAlistbox',...
				'Min',1,...
				'Max',1,...
				'FontSize',fs-1,...
				'FontName',MonoFont,...
				'Callback',@me.plotSite,...
				'String',{''},...
				'uicontextmenu',hcmenu);
			
			handles.analmethod = uicontrol('Style','popupmenu',...
				'Parent',handles.controls3,...
				'FontSize', fs,...
				'Tag','LMAanalmethod',...
				'String',{'timelock','power'});
			handles.selectbars = uicontrol('Style','checkbox',...
				'Parent',handles.controls3,...
				'Tag','LMAselectbars',...
				'FontSize', fs,...
				'BackgroundColor',bgcolor,...
				'String','');
			handles.symmetricgaussian = uicontrol('Style','checkbox',...
				'Parent',handles.controls3,...
				'Tag','symmetricgaussian',...
				'Value',1,...
				'FontSize', fs,...
				'BackgroundColor',bgcolor,...
				'String','');
			uix.Empty('Parent',handles.controls3,'BackgroundColor',bgcolor)
			handles.smoothstep = uicontrol('Style','edit',...
				'Parent',handles.controls3,...
				'Tag','LMAsmoothstep',...
				'Tooltip','...',...
				'FontSize', fs,...
				'String','1');
			handles.gaussstep = uicontrol('Style','edit',...
				'Parent',handles.controls3,...
				'Tag','LMAgaussstep',...
				'Tooltip','...',...
				'FontSize', fs,...
				'String','0'); %'Callback',@me.replot,
			handles.offset = uicontrol('Style','edit',...
				'Parent',handles.controls3,...
				'Tag','LMAoffset',...
				'Tooltip','...',...
				'FontSize', fs,...
				'String','200');
			
			set(handles.hbox,'Widths', [-2 -1]);
			set(handles.controls,'Heights', [50 -1 95]);
			set(handles.controls1,'Heights', [-1 -1])
			set(handles.controls3,'Widths', [-1 -1 -1], 'Heights', [-1 -1 -1])

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