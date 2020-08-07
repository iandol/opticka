% ========================================================================
%> @brief analysisCore base class inherited by other analysis classes.
%> analysisCore is itself derived from optickaCore. Provides a set of shared methods
%> and some core properties and stats GUI for various analysis classes.
% ========================================================================
classdef analysisCore < optickaCore
	
	%--------------------PUBLIC PROPERTIES----------%
	properties
		%> generate plots?
		doPlots logical = true
		%> +- time window (s) for baseline estimation/removal
		baselineWindow double = [-0.2 0]
		%> default range (s) to measure values from
		measureRange double = [0.1 0.2]
		%> default range to plot data
		plotRange double = [-0.2 0.4]
		%> root directory to check for data if files can't be found
		rootDirectory char = ''
	end
	
	%------------------PUBLIC TRANSIENT PROPERTIES----------%
	properties (Transient = true)
		%>getDensity stats object, used for group comparisons
		gd getDensity
	end
	
	%--------------------VISIBLE PROPERTIES-----------%
	properties (SetAccess = protected, GetAccess = public)
		%> various stats values in a structure for different analyses
		options struct
	end
	
	%------------------TRANSIENT PROPERTIES----------%
	properties (SetAccess = protected, GetAccess = protected, Transient = true)
		%> UI panels
		panels struct = struct()
		%> do we yoke the selection to the parent object (e.g. LFPAnalysis > spikeAnalysis)
		yokedSelection logical = false
		%> handles for the GUI
		handles struct
	end
	
	%------------------VISIBLE TRANSIENT PROPERTIES----------%
	properties (SetAccess = protected, GetAccess = public, Transient = true)
		%> is the UI opened?
		openUI logical = false
	end
	
	%--------------------PRIVATE PROPERTIES----------%
	properties (SetAccess = private, GetAccess = private)
		%> allowed properties passed to object upon construction
		allowedProperties char = 'doPlots|baselineWindow|measureRange|plotRange|rootDirectory'
	end
	
	%=======================================================================
	methods %------------------PUBLIC METHODS
	%=======================================================================
		
		% ==================================================================
		%> @brief Class constructor
		%>
		%> @param varargin args are passed as a set of properties which is
		%> parsed by optickaCore.parseArgs
		%> @return instance of class.
		% ==================================================================
		function me = analysisCore(varargin)
			if nargin == 0; varargin.name = ''; end
			me=me@optickaCore(varargin); %superclass constructor
			if nargin>0; me.parseArgs(varargin, me.allowedProperties); end
			initialiseOptions(me);
		end
		
		% ===================================================================
		%> @brief checkPaths: if we've saved an object then load it on a new machine paths to
		%> source files may be wrong. If so then allows us to find a new directory for the
		%> source files.
		%>
		%> @param varargin
		%> @return
		% ===================================================================
		function checkPaths(me,varargin)
			if isprop(me,'dir')
				oldDir = me.dir;
				checkPaths@optickaCore(me);
				if isprop(me,'file')
					fn = me.file;
				elseif isprop(me,'lfpfile')
					fn = me.lfpfile;
				else
					fn = '';
				end
				rD = me.rootDirectory;
				isDir = false;
				if ~exist(me.dir,'dir')
					if ~isempty(regexpi(oldDir,[filesep '$'])); oldDir = oldDir(1:end-1); end
					seps = regexpi(oldDir,filesep,'split');
					while ~isDir
						nd = [rD filesep seps{end}];
						if exist(nd,'dir')
							me.dir = nd;
							isDir = true;
						elseif numel(seps) == 1
							nd = '';
							break
						else
							nd = '';
							seps{end-1} = [seps{end-1} filesep seps{end}];
							seps = seps(1:end-1);
						end
					end
				else
					isDir = true;
				end
				if ~isempty(regexpi(me.dir,'^/Users/'))
					re = regexpi(me.dir,'^(?<us>/Users/[^/]+)(?<rd>.+)','names');
					if ~isempty(re.rd)
						me.dir = ['~' re.rd];
					end
				end
				if isDir
					fprintf('--->>> Found %s based on %s for %s file %s\n',me.dir,oldDir,me.className,fn)
					if isprop(me,'sp') && isa(me.sp,'spikeAnalysis')
						me.sp.dir = me.dir;
						if isprop(me.sp,'rootDirectory')
							me.sp.rootDirectory = me.rootDirectory;
						end
						if isprop(me.sp,'p')
							me.sp.p.dir = me.dir;
						end
					end
				else
					fprintf('---!!! Couldn''t find: %s, please copy file %s to correct folders\n',oldDir,fn);
				end
			end
		end
		
		% ===================================================================
		%> @brief showEyePlots if we have a linked eyelink file show the raw data plots
		%>
		%> @param
		%> @return
		% ===================================================================
		function showEyePlots(me, varargin)
			if ~isprop(me,'p') || ~isa(me.p,'plxReader') || isempty(me.p.eA) || ~isa(me.p.eA,'eyelinkAnalysis')
				disp('Eyelink data not parsed yet, try plotTogether for LFP data and parse for spike data');
				return
			end
			if isprop(me,'nSelection')
				if ~isempty(me.selectedTrials)
					for i = 1:length(me.selectedTrials)
						disp(['---> Plotting eye position for: ' me.selectedTrials{i}.name]);
						me.p.eA.plot(me.selectedTrials{i}.idx,[],[],me.selectedTrials{i}.name);
					end
				end
			else
				me.p.eA.plot();
			end
		end
		
		% ===================================================================
		%> @brief showInfo shows the info box for the plexon parsed data
		%>
		%> @param
		%> @return
		% ===================================================================
		function showInfo(me, varargin)
			if ~isprop(me,'p') || ~isa(me.p,'plxReader')
				if isprop(me,'sp') && isa(me.sp,'spikeAnalysis')
					showInfo(me.sp);
				else
					disp('No Info present...')
					return
				end
			else
				infoBox(me.p);
			end
		end
		
		% ===================================================================
		%> @brief setStats set up the stats structure used in many Fieldtrip analyses
		%>
		%> @param
		%> @return
		% ===================================================================
		function stats = setStats(me, varargin)
			initialiseStats(me);
			s=me.options.stats;
			
			mlist1={'analytic', 'montecarlo', 'stats'};
			mt = 'p';
			for i = 1:length(mlist1)
				if strcmpi(mlist1{i},me.options.stats.method)
					mt = [mt '|�' mlist1{i}];
				else
					mt = [mt '|' mlist1{i}];
				end
			end
			
			mlist2={'indepsamplesT','indepsamplesF','indepsamplesregrT','indepsamplesZcoh','depsamplesT','depsamplesFmultivariate','depsamplesregrT','actvsblT','ttest','ttest2','anova1','kruskalwallis'};
			statistic = 'p';
			for i = 1:length(mlist2)
				if strcmpi(mlist2{i},me.options.stats.statistic)
					statistic = [statistic '|�' mlist2{i}];
				else
					statistic = [statistic '|' mlist2{i}];
				end
			end
			
			mlist3={'no','cluster','bonferroni','holm','fdr','hochberg'};
			mc = 'p';
			for i = 1:length(mlist3)
				if strcmpi(mlist3{i},me.options.stats.correctm)
					mc = [mc '|�' mlist3{i}];
				else
					mc = [mc '|' mlist3{i}];
				end
			end
			
			mlist4={'permutation','bootstrap'};
			rs = 'p';
			for i = 1:length(mlist4)
				if strcmpi(mlist4{i},me.options.stats.resampling)
					rs = [rs '|�' mlist4{i}];
				else
					rs = [rs '|' mlist4{i}];
				end
			end
			
			mlist5={'-1','0','1'};
			tail = 'p';
			for i = 1:length(mlist5)
				if strcmpi(mlist5{i},num2str(me.options.stats.tail))
					tail = [tail '|�' mlist5{i}];
				else
					tail = [tail '|' mlist5{i}];
				end
			end
			
			if isprop(me,'measureRange')
				mr = me.measureRange;
			else mr = [-inf inf]; end
			
			if isprop(me,'baselineWindow')
				bw = me.baselineWindow;
			else bw = [-inf inf]; end
			
			mlist6={'no','linear','nan','pchip','cubic','spline'};
			interp = 'p';
			for i = 1:length(mlist6)
				if strcmpi(mlist6{i},num2str(me.options.stats.interp))
					interp = [interp '|�' mlist6{i}];
				else
					interp = [interp '|' mlist6{i}];
				end
			end
			
			mlist7={'SEM','95%'};
			ploterror = 'p';
			for i = 1:length(mlist7)
				if strcmpi(mlist7{i},me.options.stats.ploterror)
					ploterror = [ploterror '|�' mlist7{i}];
				else
					ploterror = [ploterror '|' mlist7{i}];
				end
			end
			
			mtitle   = ['Global Statistics Settings'];
			options  = {['t|' num2str(s.alpha,6)],'Global Alpha Value (alpha):'; ...
				[mt],'FieldTrip Statistical Method (method):'; ...
				[statistic],'FieldTrip Statistical Type (statistic):'; ...
				[mc],'Multi-Sample Correction Method (correctm):'; ...
				[tail],'Tail [0 is a two-tailed test] (tail):'; ...
				[rs],'FieldTrip MonteCarlo Resampling Method (resampling):'; ...
				['t|' num2str(s.nrand)],'Set # Resamples for Monte Carlo Method (nrand):'; ...
				['t|' num2str(mr)],'Global Measurement Range (measureRange):'; ...
				['t|' num2str(bw)],'Global Baseline Window (baselineWindow):'; ...
				[interp],'Interpolation Method for Spike-LFP Interpolation?:'; ...
				['t|' num2str(me.options.stats.interpw)],'Spike-LFP Interpolation Window (s):'; ...
				['t|' num2str(me.options.stats.customFreq)],'LFP Frequency Stats Custom Frequency Band:'; ...
				['t|' num2str(me.options.stats.smoothing,12)],'Smoothing Value to use for Curves:'; ...
				[ploterror],'Error data for Tuning Curves?:'; ...
				['t|' num2str(me.options.stats.spikelfptaper)],'Spike LFP Taper Method:'; ...
				['t|' num2str(me.options.stats.spikelfptaperopt)],'Spike LFP Taper Options [Cycles Smooth]:'; ...
				['t|' num2str(me.options.stats.spikelfppcw)],'Spike LFP PPC Window [Size Step]:'; ...
				};
			
			answer = menuN(mtitle,options);
			drawnow;
			if iscell(answer) && ~isempty(answer)
				me.options.stats.alpha = str2num(answer{1});
				me.options.stats.method = mlist1{answer{2}};
				me.options.stats.statistic = mlist2{answer{3}};
				me.options.stats.correctm = mlist3{answer{4}};
				me.options.stats.tail = str2num(mlist5{answer{5}});
				me.options.stats.resampling = mlist4{answer{6}};
				me.options.stats.nrand = str2num(answer{7});
				if isprop(me,'measureRange'); me.measureRange = str2num(answer{8}); end
				if isprop(me,'baselineWindow'); me.baselineWindow = str2num(answer{9}); end
				me.options.stats.interp = mlist6{answer{10}};
				me.options.stats.interpw = str2num(answer{11});
				me.options.stats.customFreq = str2num(answer{12});
				me.options.stats.smoothing = eval(answer{13});
				me.options.stats.ploterror = mlist7{answer{14}};
				me.options.stats.spikelfptaper = answer{15};
				me.options.stats.spikelfptaperopt = str2num(answer{16});
				me.options.stats.spikelfppcw = str2num(answer{17});
			end
			
			stats = me.options.stats;
			
		end
		
		% ===================================================================
		%> @brief
		%>
		%> @param
		%> @return
		% ===================================================================
		function set.baselineWindow(me,in)
			if isnumeric(in) && length(in)==2 && in(1)<in(2)
				if ~isequal(me.baselineWindow, in)
					me.baselineWindow = in;
					disp('You should REPARSE the data to fully enable this change')
				end
			else
				disp('baselineWindow input invalid.');
			end
		end
		
		% ===================================================================
		%> @brief optimiseSize remove the raw matrices etc. to reduce memory
		%>
		% ===================================================================
		function optimiseSize(me)
			if isa(me, 'LFPAnalysis')
				for i = 1: me.nLFPs
					me.LFPs(i).sample = [];
					me.LFPs(i).data = [];
					me.LFPs(i).time = [];
				end
				me.results = struct([]);
				optimiseSize(me.p);
				if isa(me.sp, 'spikeAnalysis') && ~isempty(me.sp)
					if strcmpi(me.p.uuid,me.sp.uuid) %same plexon file
						me.p.tsList = struct(); %the spikeAnalysis object alone should hold spikes
					end
					optimiseSize(me.sp);
					optimiseSize(me.sp.p);
				end
			end
			if isa(me, 'spikeAnalysis')
				if ~isempty(me.spike); me.p.tsList = struct(); end
				optimiseSize(me.p);
			end
		end
		
		% ===================================================================
		%> @brief show a GUI if available for analysis object
		%>
		%> @param
		%> @return
		% ===================================================================
		function GUI(me, varargin)
			makeUI(me, varargin);
		end
		
	end %---END PUBLIC METHODS---%
	
	%=======================================================================
	methods ( Hidden = true ) %-------HIDDEN METHODS-----%
	%=======================================================================
		
		% ===================================================================
		%> @brief
		%>
		%> @param
		%> @return
		% ===================================================================
		function initialise(me, varargin)
			initialiseOptions(me);
		end
		
		% ===================================================================
		%> @brief setTimeFreqOptions for Fieldtrip time freq analysis of LFP data
		%>
		%> @param
		%> @return
		% ===================================================================
		function options = setTimeFreqOptions(me, varargin)
			initialiseOptions(me);
			
			mlist1={'fix1', 'fix2', 'mtm1','mtm2','morlet','tfr'};
			mt = 'p';
			for i = 1:length(mlist1)
				if strcmpi(mlist1{i},me.options.method)
					mt = [mt '|�' mlist1{i}];
				else
					mt = [mt '|' mlist1{i}];
				end
			end
			
			mlist2={'no','absolute', 'relative', 'relchange','db', 'vssum'};
			bline = 'p';
			for i = 1:length(mlist2)
				if strcmpi(mlist2{i},me.options.bline)
					bline = [bline '|�' mlist2{i}];
				else
					bline = [bline '|' mlist2{i}];
				end
			end

			mtitle   = ['Select Statistics Settings'];
			options  = {[mt],'Main LFP Method (method):'; ...
				[bline],'Baseline Correction (bline):'; ...
				['t|' num2str(me.options.tw)],'LFP Time Window (tw [fix1]):'; ...
				['t|' num2str(me.options.cycles)],'LFP # Cycles per time window (cycles [fix2,mtm1,mtm2]):'; ...
				['t|' num2str(me.options.smth)],'Smoothing Value (smth [mtm1,mtm2]):'; ...
				['t|' num2str(me.options.width)],'LFP Taper Width in cycles (width [morlet,tfr]):'; ...
				['t|' me.options.toi],'Time of interest (min:step:max in seconds):'; ...
				['t|' me.options.foi],'Frequencies of Interest (min:step:max in Hz):'; ...
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
				me.options.toi			= answer{7};
				me.options.foi			= answer{8};
			end
			
			options = me.options;
		end
	end
	
	%=======================================================================
	methods ( Static = true) %-------STATIC METHODS-----%
	%=======================================================================
		
		% ===================================================================
		%> @brief phaseDifference basic phase diff measurement
		%>
		%> @param x - first signal in the time domain
		%> @param y - second signal in the time domain
		%> @return phase - phase difference Y -> X, degrees
		%> @return angX - phase X, degrees
		%> @return angY - phase Y, degrees
		% ===================================================================
		function [PhDiff, angX, angY] = phaseDifference(x,y)	
			if size(x, 2) > 1 ; x = x'; end% represent x as column-vector if it is not
			if size(y, 2) > 1; y = y';	end% represent y as column-vector if it is not
			% signals length
			xlen = length(x);
			ylen = length(y);
			% window preparation
			xwin = hanning(xlen, 'periodic');
			ywin = hanning(ylen, 'periodic');
			% fft of the first signal
			X = fft(x.*xwin);
			% fft of the second signal
			Y = fft(y.*ywin);
			% phase difference calculation
			[~, indx] = max(abs(X));
			[~, indy] = max(abs(Y));
			angY = angle(Y(indy));
			angX = angle(X(indx));
			PhDiff = angY - angX;
			PhDiff = PhDiff * (180/pi);
		end
		
		% ===================================================================
		%> @brief phase basic phase measurement
		%>
		%> @param x - signal in the time domain
		%> @return phase - phase, degrees
		% ===================================================================
		function angX = phase(x)	
			if size(x, 2) > 1 ; x = x'; end% represent x as column-vector if it is not
			xlen = length(x); % signals length
			xwin = hanning(xlen, 'periodic'); % window preparation
			X = fft(x.*xwin); % fft of the signal
			[~, indx] = max(abs(X)); % phase difference calculation
			angX = angle(X(indx));
		end
		
		% ===================================================================
		%> @brief subselectFieldTripTrials sub-select trials where the ft function fails
		%> to use cfg.trials
		%>
		%> @param ft fieldtrip structure
		%> @param idx index to use for selection
		%> @return ftout modified ft structure
		% ===================================================================
		function ftout=subselectFieldTripTrials(ft,idx)
			if size(idx,2)>size(idx,1); idx = idx'; end
			ftout								= ft;
			ftout.trialidx					= idx;
			if isfield(ft,'nUnits') %assume a spike structure
				ftout.trialtime			= ft.trialtime(idx,:);
				ftout.sampleinfo			= ft.sampleinfo(idx,:);
				ftout.cfg.trl				= ft.cfg.trl(idx,:);
				for j = 1:ft.nUnits
					sel						= ismember(ft.trial{j},idx);
					ftout.timestamp{j}	= ft.timestamp{j}(sel);
					ftout.time{j}			= ft.time{j}(sel);
					ftout.trial{j}			= ft.trial{j}(sel);
				end
			else %assume continuous
				ftout.sampleinfo			= ft.sampleinfo(idx,:);
				ftout.trialinfo			= ft.trialinfo(idx,:);
				if isfield(ft.cfg,'trl')
					ftout.cfg.trl			= ft.cfg.trl(idx,:);
				end
				ftout.time					= ft.time(idx);
				ftout.trial					= ft.trial(idx);
			end
		end
		
		% ==================================================================
		%> @brief find nearest value in a vector, if more than 1 index return the first
		%>
		%> @param in input vector
		%> @param value value to find
		%> @return idx index position of nearest value
		%> @return val value of nearest value
		%> @return delta the difference between val and value
		% ==================================================================
		function [idx,val,delta]=findNearest(in,value)
			%find nearest value in a vector, if more than 1 index return the first	
			[~,idx] = min(abs(in - value));
			val = in(idx);
			delta = abs(value - val);
		end

		% ===================================================================
		%> @brief convert variance to standard error
		%>
		%> @param var variance
		%> @param dof degrees of freedom
		%> @return err standard error
		% ===================================================================
		function err = var2SE(var,dof)
			%convert variance to standard error
			err = sqrt(var ./ dof);
		end
		
		% ===================================================================
		function alpha = rad2ang(alphain,rect,rot)
			if nargin<3 
				rot=0; 
			end 
			if nargin<2 
				rect=0; 
			end 

			alpha = alphain * (180/pi); 

			for i=1:length(alpha)	 
				if rot==1 
					if alpha(i)>=0 
						alpha(i)=alpha(i)-180; 
					else 
						alpha(i)=alpha(i)+180; 
					end			 
					%alpha(i)=180+alpha(i); 
					if alpha(i)==360 
						alpha(i)=0; 
					end 
				end 
				if rect==1 && alpha(i)<0  
					alpha(i)=360+alpha(i); 
				end 
			end 
		end
		
		% ===================================================================
		function alpha = ang2rad(alpha)
			alpha = alpha * pi /180;
		end
		
		% ===================================================================
		%> Plots mean and error choosable by switches
		%>
		%> [mean,error] = stderr(data,type,onlyerror,alpha)
		%>
		%> Switches: SE 2SE SD 2SD 3SD V FF CV AF
		% ===================================================================
		function [avg,error] = stderr(data,type,onlyerror,alpha,dim,avgfn)
			if nargin==0;disp('[avg,error]=stderr(data,type,onlyerror,alpha,dim)');return;end
			if nargin<6 || isempty(avgfn); avgfn = @nanmean; end
			if nargin<5 || isempty(dim); dim=1; end
			if nargin<4 || isempty(alpha); alpha=0.05; end
			if nargin<3 || isempty(onlyerror); onlyerror=false; end
			if nargin<2 || isempty(type); type='SE';	end
			if size(data,1)==1 && size(data,2)>1; data=reshape(data,size(data,2),1); end
			if size(data,1) > 1 && size(data,2) > 1 
				nvals = size(data,dim);
			else
				nvals = length(data); 
			end
			avg=avgfn(data,dim);
			switch(type)
				case 'SE'
					err=nanstd(data,0,dim);
					error=sqrt(err.^2/nvals);
				case '2SE'
					err=nanstd(data,0,dim);
					error=sqrt(err.^2/nvals);
					error = error*2;
				case 'CIMEAN'
					if dim == 2;data = data';end
					[error, raw] = bootci(1000,{@nanmean,data},'alpha',alpha);
					avg = nanmean(raw);
				case 'CIMEDIAN'
					if dim == 2;data = data';end
					[error, raw] = bootci(1000,{@nanmedian,data},'alpha',alpha);
					avg = nanmedian(raw);
				case 'SD'
					error=nanstd(data,0,dim);
				case '2SD'
					error=(nanstd(data,0,dim))*2;
				case '3SD'
					error=(nanstd(data,0,dim))*3;
				case 'V'
					error=nanstd(data,0,dim).^2;
				case 'F'
					if max(data)==0
						error=0;
					else
						error=nanvar(data,0,dim)/nanmean(data,dim);
					end
				case 'C'
					if max(data)==0
						error=0;
					else
						error=nanstd(data,0,dim)/nanmean(data,dim);
					end
				case 'A'
					if max(data)==0
						error=0;
					else
						error=nanvar(diff(data),0,dim)/(2*nanmean(data,dim));
					end
			end
			if onlyerror
				avg=error; clear error;
			end
		end
		
		% ===================================================================
		%> Plots X and Y value data with error bar shown as a shaded
		%> area. Use:
		%> areabar(x,y,error,c1,alpha,plotoptions)
		%>     where c1 is the colour of the shaded options and plotoptions are
		%>     passed to the line plot
		% ===================================================================
		function handles = areabar(xv, yv, ev, c1, alpha, varargin)
			if nargin==0;disp('handles = areabar(x,y,error,c1,alpha,varargin)');return;end
			if min(size(xv)) > 1 || min(size(yv)) > 1 || min(size(ev)) > 2
				warning('Sorry, you can only plot vector data.')
				return;
			end
			if strcmpi(get(gca,'NextPlot'),'add');NextPlot = 'add';else;NextPlot = 'replacechildren';end
			if nargin <4 || isempty(c1) || length(c1)~=3; c1=[0.3 0.3 0.3]; end
			if nargin < 5 || isempty(alpha); alpha = 0.2;end
			if size(xv,1) < size(xv,2); xv=xv'; end %need to organise to rows
			if size(yv,1) < size(yv,2); yv=yv'; ev=ev'; end %err is expected to share same structure as y
			idx=find(isnan(yv));
			yv(idx)=[]; xv(idx)=[]; ev(idx,:)=[];
			ev(isnan(ev)) = 0;
			x=length(xv);
			if size(ev,2) == 2
				err=zeros(x+x,1);
				err(1:x,1)=ev(1,:);
				err(x+1:x+x,1)=flipud(ev(2,:));
			else
				err=zeros(x+x,1);
				err(1:x,1)=yv+ev;
				err(x+1:x+x,1)=flipud(yv-ev);
			end
			areax=zeros(x+x,1);
			areax(1:x,1)=xv;
			areax(x+1:x+x,1)=flipud(xv);
			axis auto
			if max(c1) > 1; c1 = c1 / max(c1); end
			handles.fill = fill(areax,err,c1,'EdgeColor','none','FaceAlpha',alpha);
			set(get(get(handles.fill,'Annotation'),'LegendInformation'),'IconDisplayStyle','off'); % Exclude line from legend
			handles.axis = (gca);
			set(gca,'NextPlot','add');
			handles.plot = plot(xv, yv, 'Color', c1/1.2, varargin{:});
			set(gca,'NextPlot',NextPlot);
			uistack(handles.plot,'top')
			set(gca,'Layer','bottom');
			if alpha == 1; set(gcf,'Renderer','painters'); end
		end
		
		% ===================================================================
		%> cellArray2Num
		%>
		%> out = cellArray2Num(data)
		%>
		%> 
		% ===================================================================
		function out = cellArray2Num(data)
			if iscellstr(data)
				out = [];
				for i = 1:numel(data)
					out = [out str2num(data{i})];
				end
			end
		end
		
		% ===================================================================
		%> @brief calculates preferred row col layout for multiple plots
		%> @param len length of data points to plot
		%> @return row number of rows
		%> @return col number of columns
		% ===================================================================
		function [row,col] = optimalLayout(len)
			%calculates preferred row col layout for multiple plots
			if ~isnumeric(len);warning('Please enter a number!');return;end
			row=1; col=1;
			if			len == 2,	row = 2;	col = 1;
			elseif	len == 3,	row = 3;	col = 1;
			elseif	len == 4,	row = 2;	col = 2;
			elseif	len < 7,		row = 3;	col = 2;
			elseif	len < 9,		row = 4;	col = 2;
			elseif	len < 10,	row = 3;	col = 3;
			elseif	len < 13,	row = 4;	col = 3;
			elseif	len < 17,	row = 4;	col = 4;
			elseif	len < 21,	row = 5;	col = 4;
			elseif	len < 26,	row = 5;	col = 5;
			elseif	len < 31,	row = 6;	col = 5;
			elseif	len < 37,	row = 6;	col = 6;
			else						row = ceil(len/10); col = 10;
			end
		end
		
		% ===================================================================
		%> @brief make optimally different colours for plots
		%> Copyright 2010-2011 by Timothy E. Holy
		%> @param n_colors
		% ===================================================================
		function colors = optimalColours(n_colors,bg,func) %make optimally different colours for plots
			if nargin < 1; n_colors = 20; end
			if ~exist('makecform','file') %no im proc toolbox, just return default colours
				colors = colormap(parula(n_colors));
				colors = [0 0 0; 0.8 0 0; 0 0.8 0; 0 0 0.8; 0.5 0.5 0.5; 1 0.5 0; colors];
				return;
			end
			if nargin < 2
				bg = [1 1 1];  % default white background
			else
				if iscell(bg)
					bgc = bg;% User specified a list of colors as a cell aray
					for i = 1:length(bgc); bgc{i} = parsecolor(bgc{i}); end
					bg = cat(1,bgc{:});
				else
					bg = parsecolor(bg);% User specified a numeric array of colors (n-by-3)
				end
			end
			% Generate a sizable number of RGB triples. This represents our space of possible choices. By starting in RGB space, we ensure that all of the colors can be generated by the monitor.
			n_grid = 30;  % number of grid divisions along each axis in RGB space
			x = linspace(0,1,n_grid);
			[R,G,B] = ndgrid(x,x,x);
			rgb = [R(:) G(:) B(:)];
			if (n_colors > size(rgb,1)/3); error('You can''t readily distinguish that many colors'); end
			if (nargin > 2)% Convert to Lab color space, which more closely represents human perception
				lab = func(rgb); bglab = func(bg);
			else
				C = makecform('srgb2lab'); lab = applycform(rgb,C); bglab = applycform(bg,C);
			end
			mindist2 = inf(size(rgb,1),1); % If the user specified multiple background colors, compute distances from the candidate colors to the background colors
			for i = 1:size(bglab,1)-1
				dX = bsxfun(@minus,lab,bglab(i,:)); % displacement all colors from bg
				dist2 = sum(dX.^2,2);  % square distance
				mindist2 = min(dist2,mindist2);  % dist2 to closest previously-chosen color
			end
			colors = zeros(n_colors,3); % Iteratively pick the color that maximizes the distance to the nearest already-picked color
			lastlab = bglab(end,:);   % initialize by making the "previous" color equal to background
			for i = 1:n_colors
				dX = bsxfun(@minus,lab,lastlab); % displacement of last from all colors on list
				dist2 = sum(dX.^2,2);  % square distance
				mindist2 = min(dist2,mindist2);  % dist2 to closest previously-chosen color
				[~,index] = max(mindist2);  % find the entry farthest from all previously-chosen colors
				colors(i,:) = rgb(index,:);  % save for output
				lastlab = lab(index,:);  % prepare for next iteration
			end
			colors = [0 0 0; colors]; %add black to front
			colors(2,:) = [1 0 0]; colors(3,:) = [0 0 1]; %swap red and blue entries
			colors(5,:) = [0.2 0.2 0.2]; %not too different to black!
			function c = parsecolor(s)
				if ischar(s)
					c = colorstr2rgb(s);
				elseif isnumeric(s) && size(s,2) == 3
					c = s;
				else
					error('MATLAB:InvalidColorSpec','Color specification cannot be parsed.');
				end
			end
			function c = colorstr2rgb(c) % Convert a color string to an RGB value.This is cribbed from Matlab's whitebg function.Why don't they make this a stand-alone function?
				rgbspec = [1 0 0;0 1 0;0 0 1;1 1 1;0 1 1;1 0 1;1 1 0;0 0 0];
				cspec = 'rgbwcmyk';
				k = find(cspec==c(1));
				if isempty(k); error('MATLAB:InvalidColorString','Unknown color string.');end
				if k~=3 || length(c)==1
					c = rgbspec(k,:);
				elseif length(c)>2
					if strcmpi(c(1:3),'bla')
						c = [0 0 0];
					elseif strcmpi(c(1:3),'blu')
						c = [0 0 1];
					else
						error('MATLAB:UnknownColorString', 'Unknown color string.');
					end
				end
			end
			
		end
		
	end %---END STATIC METHODS---%
	
	%=======================================================================
	methods ( Abstract = true, Access = protected ) %-------Abstract METHODS-----%
	%=======================================================================
		%> make the UI for the analysis object
		makeUI(me)
		%> close the UI for the analysis object
		closeUI(me)
		%> update the UI for the analysis object
		updateUI(me)
		%> modify text of the UI for the analysis object
		notifyUI(me, varargin)
	end %---END Abstract METHODS---%
	
	%=======================================================================
	methods ( Access = protected ) %-------PROTECTED METHODS-----%
	%=======================================================================
	
		% ===================================================================
		%> @brief initialise settings for fieldtrip time frequency analysis
		%>
		%> @param
		%> @return
		% ===================================================================
		function initialiseOptions(me)
			%initialise settings for fieldtrip time frequency analysis
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
			if ~isfield(me.options,'toi') || isempty(me.options.toi)
				me.options(1).toi = '-0.4:0.01:0.4';
			end
			if ~isfield(me.options,'foi') || isempty(me.options.foi)
				me.options(1).foi = '4:2:100';
			end
			%initialise settings for stats analysis
			if ~isfield(me.options,'stats') || isempty(me.options.stats)
				me.options(1).stats = struct();
				initialiseStats(me);
			end
		end
		
		% ===================================================================
		%> @brief Allows two analysis objects to share a single plxReader object. This is
		%> important in cases where for e.g. an LFPAnalysis object uses the same plexon file as
		%> its spikeAnalysis child used for spike-LFP anaysis.
		%>
		%> @param
		% ===================================================================
		function inheritPlxReader(me,p)
			%Allows two analysis objects to share a single plxReader object
			if exist('p','var') && isa(p,'plxReader')
				if isprop(me,'p')
					me.p = p;
				end
			end
		end
		
		% ===================================================================
		%> @brief set trials / var parsing from outside, override dialog, used when
		%> yoked to another analysis object, for example when spikeAnalysis is a child of
		%> LFPAnalysis
		%>
		%> @param in structure
		%> @return
		% ===================================================================
		function setSelection(me, in)
			if isfield(in,'yokedSelection') && isprop(me,'yokedSelection')
				me.yokedSelection = in.yokedSelection;
			else
				me.yokedSelection = false;
			end
			if isfield(in,'cutTrials') && isprop(me,'cutTrials')
				me.cutTrials = in.cutTrials;
			end
			if isfield(in,'selectedTrials') && isprop(me,'selectedTrials')
				me.selectedTrials = in.selectedTrials;
				me.yokedSelection = true;
			end
			if isfield(in,'map') && isprop(me,'map')
				me.map = in.map;
			end
			if isfield(in,'plotRange') && isprop(me,'plotRange')
				me.plotRange = in.plotRange;
			end
			if isfield(in,'measureRange') && isprop(me,'measureRange')
				me.measureRange = in.measureRange;
			end
			if isfield(in,'baselineWindow') && isprop(me,'baselineWindow')
				me.baselineWindow = in.baselineWindow;
			end
			if isfield(in,'alpha') && isfield(me.options.stats,'alpha')
				me.options.stats.alpha = in.alpha;
			end
			if isfield(in,'selectedBehaviour') && isprop(me,'selectedBehaviour')
				if ischar(in.selectedBehaviour)
					me.selectedBehaviour = cell(1);
					me.selectedBehaviour{1} = in.selectedBehaviour;
				elseif iscell(in.selectedBehaviour)
					me.selectedBehaviour = cell(1);
					me.selectedBehaviour = in.selectedBehaviour;
				else
					me.selectedBehaviour = cell(1);
					me.selectedBehaviour{1}='correct';
				end
			end
		end
		
		% ===================================================================
		%> @brief initialise the statistics options, see setStats()
		%>
		%> @param
		%> @return
		% ===================================================================
		function initialiseStats(me)
			%initialise the statistics options
			if isempty(me.options); initialiseOptions(me); end
			if ~isfield(me.options, 'stats'); me.options.stats(1) = struct(); end
			if ~isfield(me.options.stats,'alpha') || isempty(me.options.stats.alpha)
				me.options.stats(1).alpha = 0.05;
			end
			if ~isfield(me.options.stats,'method') || isempty(me.options.stats.method)
				me.options.stats(1).method = 'analytic';
			end
			if ~isfield(me.options.stats,'statistic') || isempty(me.options.stats.statistic)
				me.options.stats(1).statistic = 'indepsamplesT';
			end
			if ~isfield(me.options.stats,'correctm') || isempty(me.options.stats.correctm)
				me.options.stats(1).correctm = 'no';
			end
			if ~isfield(me.options.stats,'nrand') || isempty(me.options.stats.nrand)
				me.options.stats(1).nrand = 1000;
			end
			if ~isfield(me.options.stats,'tail') || isempty(me.options.stats.tail)
				me.options.stats(1).tail = 0;
			end
			if ~isfield(me.options.stats,'parameter') || isempty(me.options.stats.parameter)
				me.options.stats(1).parameter = 'trial';
			end
			if ~isfield(me.options.stats,'resampling') || isempty(me.options.stats.resampling)
				me.options.stats(1).resampling = 'permutation';
			end
			if ~isfield(me.options.stats,'interp') || isempty(me.options.stats.interp)
				me.options.stats(1).interp = 'linear';
			end
			if ~isfield(me.options.stats,'interpw') || isempty(me.options.stats.interpw)
				me.options.stats(1).interpw = [-0.001 0.004];
			end
			if ~isfield(me.options.stats,'customFreq') || isempty(me.options.stats.customFreq)
				me.options.stats(1).customFreq = [60 70];
			end
			if ~isfield(me.options.stats,'smoothing') || isempty(me.options.stats.smoothing)
				me.options.stats(1).smoothing = 0;
			end
			if ~isfield(me.options.stats,'ploterror') || isempty(me.options.stats.ploterror)
				me.options.stats(1).ploterror = 'SEM';
			end
			if ~isfield(me.options.stats,'spikelfptaper') || isempty(me.options.stats.spikelfptaper)
				me.options.stats(1).spikelfptaper = 'dpss';
			end
			if ~isfield(me.options.stats,'spikelfptaperopt') || isempty(me.options.stats.spikelfptaperopt)
				me.options.stats(1).spikelfptaperopt = [3 0.3];
			end
			if ~isfield(me.options.stats,'spikelfppcw') || isempty(me.options.stats.spikelfppcw)
				me.options.stats(1).spikelfppcw = [0.2 0.02];
			end
		end
		
		% ===================================================================
		%> @brief format data for ROC
		%>
		%> @param dp scores for "signal" distribution
		%> @param dn scores for "noise" distribution
		%> @return data - [class , score] matrix
		% ===================================================================
		function data = formatByClass(me,dp,dn)
			dp = dp(:);
			dn = dn(:);
			y = [dp ; dn];
			t = logical([ ones(size(dp)) ; zeros(size(dn)) ]);
			data = [t,y];
		end
		
		% ===================================================================
		%> @brief ROC see http://www.subcortex.net/research/code/area_under_roc_curve
		%>
		%> @param data - [class , score] matrix
		%> @return tp   - true positive rate
		%> @return fp   - false positive rate
		% ===================================================================
		function [tp,fp] = roc(me,data)
			if size(data,2) ~= 2
				error('Incorrect input size in ROC!');
			end
			
			t = data(:,1);
			y = data(:,2);
			
			% process targets
			t = t > 0;
			
			% sort by classifier output
			[Y,idx] = sort(-y);
			t       = t(idx);
			
			% compute true positive and false positive rates
			tp = cumsum(t)/sum(t);
			fp = cumsum(~t)/sum(~t);
			
			% handle equally scored instances (BL 030708, see pg. 10 of Fawcett)
			[~,idx] = unique(Y);
			tp = tp(idx);
			fp = fp(idx);
			
			% add trivial end-points
			tp = [0 ; tp ; 1];
			fp = [0 ; fp ; 1];
		end
		
		% ===================================================================
		%> @brief Area under ROC
		%>
		%> @param me - object
		%> @param data - [class , score] matrix
		%> @param alpha    - level for confidence intervals (eg., enter 0.05 if you want 95% CIs)
		%> @param flag     - 'hanley' yields Hanley-McNeil (1982) asymptotic CI; 'maxvar' yields maximum variance CI;'mann-whitney';'logit';'boot' yields bootstrapped CI (DEFAULT)
		%> @param nboot - if 'boot' is set, specifies # of resamples, default=1000
		%> @param varargin - additional arguments to pass to BOOTCI, only valid for 'boot' this assumes you have the STATs toolbox, otherwise it's ignored and a crude percentile bootstrap is estimated.
		%> @return A   - area under ROC
		%> @return Aci - confidence intervals
		% ===================================================================
		function [A,Aci] = auc(me,data,alpha,flag,nboot,varargin)
			%     $ Copyright (C) 2011 Brian Lau http://www.subcortex.net/ $
			if size(data,2) ~= 2
				error('Incorrect input size in AUC!');
			end
			
			if ~exist('flag','var')
				flag = 'boot';
			elseif isempty(flag)
				flag = 'boot';
			else
				flag = lower(flag);
			end
			
			if ~exist('nboot','var')
				nboot = 1000;
			elseif isempty(nboot)
				nboot = 1000;
			end
			
			if ~exist('alpha','var')
				alpha = 0.05;
			elseif isempty(alpha)
				alpha = 0.05;
			end
			
			if (nargin>3) & (nargout==1)
				warning('Confidence intervals will be computed, but not output in AUC!');
			end
			
			if (nargin>4) & (strcmp(flag,'hanley')|strcmp(flag,'maxvar'))
				warning('Asymptotic intervals requested in AUC, extra inputs ignored.');
			end
			
			% Count observations by class
			m = sum(data(:,1)>0);
			n = sum(data(:,1)<=0);
			
			[tp,fp] = me.roc(data);
			% Integrate ROC, A = trapz(fp,tp);
			A = sum((fp(2:end) - fp(1:end-1)).*(tp(2:end) + tp(1:end-1)))/2;
			
			% % Method for calculating AUC without integrating ROC from Will Dwinnell's function SampleError.m
			% % It's actually slower!
			% % Rank scores
			% R = tiedrank(data(:,2));
			% % Calculate AUC
			% A = (sum(R(data(:,1)==1)) - (m^2 + m)/2) / (m * n);
			
			% Confidence intervals
			if nargout == 2
				if strcmp(flag,'hanley') % See Hanley & McNeil, 1982; Cortex & Mohri, 2004
					Q1 = A / (2-A);
					Q2 = (2*A^2) / (1+A);
					
					Avar = A*(1-A) + (m-1)*(Q1-A^2) + (n-1)*(Q2-A^2);
					Avar = Avar / (m*n);
					
					Ase = sqrt(Avar);
					z = norminv(1-alpha/2);
					Aci = [A-z*Ase A+z*Ase];
				elseif strcmp(flag,'maxvar') % Maximum variance
					Avar = (A*(1-A)) / min(m,n);
					
					Ase = sqrt(Avar);
					z = norminv(1-alpha/2);
					Aci = [A-z*Ase A+z*Ase];
				elseif strcmp(flag,'mann-whitney')
					% Reverse labels to keep notation like Qin & Hotilovac
					m = sum(data(:,1)<=0);
					n = sum(data(:,1)>0);
					X = data(data(:,1)<=0,2);
					Y = data(data(:,1)>0,2);
					temp = [sort(X);sort(Y)];
					temp = tiedrank(temp);
					
					R = temp(1:m);
					S = temp(m+1:end);
					Rbar = mean(R);
					Sbar = mean(S);
					S102 = (1/((m-1)*n^2)) * (sum((R-(1:m)').^2) - m*(Rbar - (m+1)/2)^2);
					S012 = (1/((n-1)*m^2)) * (sum((S-(1:n)').^2) - n*(Sbar - (n+1)/2)^2);
					S2 = (m*S012 + n*S102) / (m+n);
					
					Avar = ((m+n)*S2) / (m*n);
					Ase = sqrt(Avar);
					z = norminv(1-alpha/2);
					Aci = [A-z*Ase A+z*Ase];
				elseif strcmp(flag,'logit')
					% Reverse labels to keep notation like Qin & Hotilovac
					m = sum(data(:,1)<=0);
					n = sum(data(:,1)>0);
					X = data(data(:,1)<=0,2);
					Y = data(data(:,1)>0,2);
					temp = [sort(X);sort(Y)];
					temp = tiedrank(temp);
					
					R = temp(1:m);
					S = temp(m+1:end);
					Rbar = mean(R);
					Sbar = mean(S);
					S102 = (1/((m-1)*n^2)) * (sum((R-(1:m)').^2) - m*(Rbar - (m+1)/2)^2);
					S012 = (1/((n-1)*m^2)) * (sum((S-(1:n)').^2) - n*(Sbar - (n+1)/2)^2);
					S2 = (m*S012 + n*S102) / (m+n);
					
					Avar = ((m+n)*S2) / (m*n);
					Ase = sqrt(Avar);
					logitA = log(A/(1-A));
					z = norminv(1-alpha/2);
					LL = logitA - z*(Ase)/(A*(1-A));
					UL = logitA + z*(Ase)/(A*(1-A));
					
					Aci = [exp(LL)/(1+exp(LL)) exp(UL)/(1+exp(UL))];
				elseif strcmp(flag,'boot') % Bootstrap
					if exist('bootci') ~= 2
						warning('BOOTCI function not available, resorting to simple percentile bootstrap in AUC.')
						N = m + n;
						for i = 1:nboot
							ind = unidrnd(N,[N 1]);
							A_boot(i) = auc(data(ind,:));
						end
						Aci = prctile(A_boot,100*[alpha/2 1-alpha/2]);
					else
						if exist('varargin','var')
							Aci = bootci(nboot,{@me.auc,data},varargin{:})';
						else
							Aci = bootci(nboot,{@me.auc,data},'type','per')';
						end
					end
				else
					error('Bad FLAG for AUC!')
				end
			end
		end
		
		% ===================================================================
		%> @brief AUC bootstrap
		%>
		% ===================================================================
		function p = aucBootstrap(me,data,nboot,flag,H0)
			
			if size(data,2) ~= 2
				error('Incorrect input size in AUC_BOOTSTRAP!');
			end
			
			if ~exist('H0','var')
				H0 = 0.5;
			elseif isempty(H0)
				H0 = 0.5;
			end
			
			if ~exist('flag','var')
				flag = 'both';
			elseif isempty(flag)
				flag = 'both';
			else
				flag = lower(flag);
			end
			
			if ~exist('nboot','var')
				nboot = 1000;
			elseif isempty(nboot)
				nboot = 1000;
			end
			
			N = size(data,1);
			for i = 1:nboot
				ind = unidrnd(N,[N 1]);
				A_boot(i) = me.auc(data(ind,:));
			end
			
			% http://www.stat.umn.edu/geyer/old03/5601/examp/tests.html
			% lower-tailed test of A = H0
			ltpv = mean(A_boot <= H0);
			% upper-tailed test of A = H0
			utpv = mean(A_boot >= H0);
			% two-tailed test of A = H0, equal-tailed two-sided intervals
			ttpv = 2*min(ltpv,utpv);
			
			if strcmp(flag,'upper')
				p = ltpv;
			elseif strcmp(flag,'lower')
				p = utpv;
			else
				p = ttpv;
			end
		end

	end %---END PROTECTED METHODS---%
	
end %---END CLASSDEF---%