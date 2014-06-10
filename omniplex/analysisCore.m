% ========================================================================
%> @brief analysisCore base class inherited by other analysis classes.
%> analysidCore is itself derived from optickaCore.
% ========================================================================
classdef analysisCore < optickaCore
	
	%--------------------PUBLIC PROPERTIES----------%
	properties
		%> generate plots?
		doPlots@logical = true
		%> various stats values in a structure for different analyses
		stats@struct
		%> ± time window for baseline estimation/removal
		baselineWindow@double = [-0.2 0]
		%> default range to measure values from
		measureRange@double = [0.1 0.2]
		%> default range to plot
		plotRange@double = [-0.2 0.4]
		%> root directory to check for data if files can't be found
		rootDirectory@char = ''
	end
	
	%--------------------ABSTRACT PROPERTIES----------%
	properties (Abstract = true)
		
	end
	
	%--------------------HIDDEN PROPERTIES------------%
	properties (SetAccess = protected, Hidden = true)
		
	end
	
	%--------------------VISIBLE PROPERTIES-----------%
	properties (SetAccess = protected, GetAccess = public)
		%>getDensity stats object
		gd@getDensity
	end
	
	%--------------------DEPENDENT PROPERTIES----------%
	properties (SetAccess = private, Dependent = true)
		
	end
	
	%------------------TRANSIENT PROPERTIES----------%
	properties (SetAccess = protected, GetAccess = protected, Transient = true)
		%> UI panels
		panels@struct = struct()
		%> do we yoke the selection to the parent function (e.g. LFPAnalysis)
		yokedSelection@logical = false
	end
	
	%--------------------PROTECTED PROPERTIES----------%
	properties (SetAccess = protected, GetAccess = protected)
		
	end
	
	%--------------------PRIVATE PROPERTIES----------%
	properties (SetAccess = private, GetAccess = private)
		%> allowed properties passed to object upon construction
		allowedProperties@char = 'doPlots|baselineWindow|measureRange|plotRange|stats'
	end
	
	%=======================================================================
	methods %------------------PUBLIC METHODS
		%=======================================================================
		
		% ==================================================================
		%> @brief Class constructor
		%>
		%> More detailed description of what the constructor does.
		%>
		%> @param args are passed as a structure of properties which is
		%> parsed.
		%> @return instance of class.
		% ==================================================================
		function ego = analysisCore(varargin)
			if nargin == 0; varargin.name = ''; end
			ego=ego@optickaCore(varargin); %superclass constructor
			if nargin>0; ego.parseArgs(varargin, ego.allowedProperties); end
			initialiseStats(ego);
		end
		
		% ===================================================================
		%> @brief checkPaths
		%>
		%> @param
		%> @return
		% ===================================================================
		function checkPaths(ego)
			if isprop(ego,'dir')
				if ~exist(ego.dir,'dir')
					if isprop(ego,'file')
						fn = ego.file;
					elseif isprop(ego,'lfpfile')
						fn = ego.lfpfile;
					else
						fn = '';
					end
					p = uigetdir('',['Please find new directory for: ' fn]);
					if p ~= 0
						ego.dir = p;
					else
						warning('Can''t find valid source directory')
					end
				end
				if ~isempty(regexpi(ego.dir,'^/Users/'))
					re = regexpi(ego.dir,'^(?<us>/Users/[^/]+)(?<rd>.+)','names');
					if ~isempty(re.rd)
						ego.dir = ['~' re.rd];
					end
				end
			end
			if isprop(ego,'p') && isa(ego.p,'plxReader')
				ego.p.dir = ego.dir;
				checkPaths(ego.p);
			end
			if isprop(ego,'sp') && isprop(ego.sp,'p') && isa(ego.sp.p,'plxReader')
				ego.sp.p.dir = ego.dir;
				checkPaths(ego.sp.p);
			end
		end
		
		% ===================================================================
		%> @brief
		%>
		%> @param
		%> @return
		% ===================================================================
		function showEyePlots(ego)
			if ~isprop(ego,'p') || ~isa(ego.p,'plxReader') || isempty(ego.p.eA) || ~isa(ego.p.eA,'eyelinkAnalysis')
				disp('Eyelink data not parsed yet, try plotTogether for LFP data and parse for spike data');
				return
			end
			if isprop(ego,'nSelection')
				if ~isempty(ego.selectedTrials)
					for i = 1:length(ego.selectedTrials)
						disp(['---> Plotting eye position for: ' ego.selectedTrials{i}.name]);
						ego.p.eA.plot(ego.selectedTrials{i}.idx,[],[],ego.selectedTrials{i}.name);
					end
				end
			else
				ego.p.eA.plot();
			end
		end
		
		% ===================================================================
		%> @brief showInfo shows the info box for the plexon parsed data
		%>
		%> @param
		%> @return
		% ===================================================================
		function showInfo(ego)
			if ~isprop(ego,'p') || ~isa(ego.p,'plxReader')
				if isprop(ego,'sp') && isa(ego.sp,'spikeAnalysis')
					showInfo(ego.sp);
				else
					disp('No Info present...')
					return
				end
			else
				infoBox(ego.p);
			end
		end
		
		% ===================================================================
		%> @brief showInfo shows the info box for the plexon parsed data
		%>
		%> @param
		%> @return
		% ===================================================================
		function stats = setStats(ego)
			initialiseStats(ego);
			s=ego.stats;
			
			mlist1={'analytic', 'montecarlo', 'stats'};
			mt = 'p';
			for i = 1:length(mlist1)
				if strcmpi(mlist1{i},ego.stats.method)
					mt = [mt '|¤' mlist1{i}];
				else
					mt = [mt '|' mlist1{i}];
				end
			end
			
			mlist2={'indepsamplesT','indepsamplesF','indepsamplesregrT','indepsamplesZcoh','depsamplesT','depsamplesFmultivariate','depsamplesregrT','actvsblT','ttest','ttest2','anova1','kruskalwallis'};
			statistic = 'p';
			for i = 1:length(mlist2)
				if strcmpi(mlist2{i},ego.stats.statistic)
					statistic = [statistic '|¤' mlist2{i}];
				else
					statistic = [statistic '|' mlist2{i}];
				end
			end
			
			mlist3={'no','cluster','bonferroni','holm','fdr','hochberg'};
			mc = 'p';
			for i = 1:length(mlist3)
				if strcmpi(mlist3{i},ego.stats.correctm)
					mc = [mc '|¤' mlist3{i}];
				else
					mc = [mc '|' mlist3{i}];
				end
			end
			
			mlist4={'permutation','bootstrap'};
			rs = 'p';
			for i = 1:length(mlist4)
				if strcmpi(mlist4{i},ego.stats.resampling)
					rs = [rs '|¤' mlist4{i}];
				else
					rs = [rs '|' mlist4{i}];
				end
			end
			
			mlist5={'-1','0','1'};
			tail = 'p';
			for i = 1:length(mlist5)
				if strcmpi(mlist5{i},num2str(ego.stats.tail))
					tail = [tail '|¤' mlist5{i}];
				else
					tail = [tail '|' mlist5{i}];
				end
			end
			
			if isprop(ego,'measureRange')
				mr = ego.measureRange;
			else mr = [-inf inf]; end
			
			if isprop(ego,'baselineWindow')
				bw = ego.baselineWindow;
			else bw = [-inf inf]; end
			
			mlist6={'no','linear','nan','pchip','cubic','spline'};
			interp = 'p';
			for i = 1:length(mlist6)
				if strcmpi(mlist6{i},num2str(ego.stats.interp))
					interp = [interp '|¤' mlist6{i}];
				else
					interp = [interp '|' mlist6{i}];
				end
			end
			
			mlist7={'SEM','95%'};
			ploterror = 'p';
			for i = 1:length(mlist7)
				if strcmpi(mlist7{i},ego.stats.ploterror)
					ploterror = [ploterror '|¤' mlist7{i}];
				else
					ploterror = [ploterror '|' mlist7{i}];
				end
			end
			
			mtitle   = ['Select Statistics Settings'];
			options  = {['t|' num2str(s.alpha,6)],'Set the Statistical Alpha Value (alpha):'; ...
				[mt],'Main LFP Statistical Method (method):'; ...
				[statistic],'LFP Statistical Type (statistic):'; ...
				[mc],'LFP Multiple Correction Methodology (correctm):'; ...
				[tail],'Tail [0 is a two-tailed test] (tail):'; ...
				[rs],'LFP MonteCarlo Resampling Method (resampling):'; ...
				['t|' num2str(s.nrand)],'Set # Resamples for LFP Monte Carlo Method (nrand):'; ...
				['t|' num2str(mr)],'Global Measurement Range (measureRange):'; ...
				['t|' num2str(bw)],'Global Baseline Window (baselineWindow):'; ...
				[interp],'Interpolation Method for Spike-LFP Interpolation?:'; ...
				['t|' num2str(ego.stats.interpw)],'Spike-LFP Interpolation Window (s):'; ...
				['t|' num2str(ego.stats.customFreq)],'LFP Frequency Stats Custom Frequency Band:'; ...
				['t|' num2str(ego.stats.smoothing,12)],'Smoothing Value to use for Curves:'; ...
				[ploterror],'Error data for Tuning Curves?:'; ...
				};
			
			answer = menuN(mtitle,options);
			drawnow;
			if iscell(answer) && ~isempty(answer)
				ego.stats.alpha = str2num(answer{1});
				ego.stats.method = mlist1{answer{2}};
				ego.stats.statistic = mlist2{answer{3}};
				ego.stats.correctm = mlist3{answer{4}};
				ego.stats.tail = str2num(mlist5{answer{5}});
				ego.stats.resampling = mlist4{answer{6}};
				ego.stats.nrand = str2num(answer{7});
				if isprop(ego,'measureRange'); ego.measureRange = str2num(answer{8}); end
				if isprop(ego,'baselineWindow'); ego.baselineWindow = str2num(answer{9}); end
				ego.stats.interp = mlist6{answer{10}};
				ego.stats.interpw = str2num(answer{11});
				ego.stats.customFreq = str2num(answer{12});
				ego.stats.smoothing = eval(answer{13});
				ego.stats.ploterror = mlist7{answer{14}};
			end
			
			stats = ego.stats;
			
		end
		
		% ===================================================================
		%> @brief
		%>
		%> @param
		%> @return
		% ===================================================================
		function set.baselineWindow(ego,in)
			if isnumeric(in) && length(in)==2 && in(1)<in(2)
				if ~isequal(ego.baselineWindow, in)
					ego.baselineWindow = in;
					disp('You should REPARSE the data to fully enable this change')
				end
			else
				disp('baselineWindow input invalid.');
			end
		end
		
	end %---END PUBLIC METHODS---%
	
	%=======================================================================
	methods ( Static = true) %-------STATIC METHODS-----%
		%=======================================================================
		
		% ===================================================================
		%> @brief selectFTTrials cut out trials where the ft function fails
		%> to use cfg.trials
		%>
		%> @param ft fieldtrip structure
		
		%> @return
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
		%> @brief find nearest value in a vector
		%>
		%> @param in input vector
		%> @param value value to find
		%> @return idx index position of nearest value
		%> @return val value of nearest value
		%> @return delta the difference between val and value
		% ==================================================================
		function [idx,val,delta]=findNearest(in,value)
			tmp = abs(in-value);
			[~,idx] = min(tmp);
			val = in(idx);
			delta = abs(value - val);
		end
		
		% ===================================================================
		%> @brief variance to standard eror
		%>
		%> @param
		% ===================================================================
		function [err]=var2SE(var,dof)
			err = sqrt(var ./ dof);
		end
		
		% ===================================================================
		%> @brief preferred row col layout for multiple plots
		%> @param
		% ===================================================================
		function [row,col]=optimalLayout(len)
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
		%> @param
		% ===================================================================
		function colors = optimalColours(n_colors,bg,func)
			if (nargin < 2)
				bg = [1 1 1];  % default white background
			else
				if iscell(bg)
					% User specified a list of colors as a cell aray
					bgc = bg;
					for i = 1:length(bgc)
						bgc{i} = parsecolor(bgc{i});
					end
					bg = cat(1,bgc{:});
				else
					% User specified a numeric array of colors (n-by-3)
					bg = parsecolor(bg);
				end
			end
			
			% Generate a sizable number of RGB triples. This represents our space of
			% possible choices. By starting in RGB space, we ensure that all of the
			% colors can be generated by the monitor.
			n_grid = 30;  % number of grid divisions along each axis in RGB space
			x = linspace(0,1,n_grid);
			[R,G,B] = ndgrid(x,x,x);
			rgb = [R(:) G(:) B(:)];
			if (n_colors > size(rgb,1)/3)
				error('You can''t readily distinguish that many colors');
			end
			
			% Convert to Lab color space, which more closely represents human
			% perception
			if (nargin > 2)
				lab = func(rgb);
				bglab = func(bg);
			else
				C = makecform('srgb2lab');
				lab = applycform(rgb,C);
				bglab = applycform(bg,C);
			end
			
			% If the user specified multiple background colors, compute distances
			% from the candidate colors to the background colors
			mindist2 = inf(size(rgb,1),1);
			for i = 1:size(bglab,1)-1
				dX = bsxfun(@minus,lab,bglab(i,:)); % displacement all colors from bg
				dist2 = sum(dX.^2,2);  % square distance
				mindist2 = min(dist2,mindist2);  % dist2 to closest previously-chosen color
			end
			
			% Iteratively pick the color that maximizes the distance to the nearest
			% already-picked color
			colors = zeros(n_colors,3);
			lastlab = bglab(end,:);   % initialize by making the "previous" color equal to background
			for i = 1:n_colors
				dX = bsxfun(@minus,lab,lastlab); % displacement of last from all colors on list
				dist2 = sum(dX.^2,2);  % square distance
				mindist2 = min(dist2,mindist2);  % dist2 to closest previously-chosen color
				[~,index] = max(mindist2);  % find the entry farthest from all previously-chosen colors
				colors(i,:) = rgb(index,:);  % save for output
				lastlab = lab(index,:);  % prepare for next iteration
			end
			
			function c = parsecolor(s)
				if ischar(s)
					c = colorstr2rgb(s);
				elseif isnumeric(s) && size(s,2) == 3
					c = s;
				else
					error('MATLAB:InvalidColorSpec','Color specification cannot be parsed.');
				end
			end
			
			function c = colorstr2rgb(c)
				% Convert a color string to an RGB value.
				% This is cribbed from Matlab's whitebg function.
				% Why don't they make this a stand-alone function?
				rgbspec = [1 0 0;0 1 0;0 0 1;1 1 1;0 1 1;1 0 1;1 1 0;0 0 0];
				cspec = 'rgbwcmyk';
				k = find(cspec==c(1));
				if isempty(k)
					error('MATLAB:InvalidColorString','Unknown color string.');
				end
				if k~=3 || length(c)==1,
					c = rgbspec(k,:);
				elseif length(c)>2,
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
	methods ( Access = protected ) %-------PROTECTED METHODS-----%
		%=======================================================================
		% ===================================================================
		%> @brief Allows two analysis objects to share a single plxReader object
		%>
		%> @param
		% ===================================================================
		function inheritPlxReader(ego,p)
			if exist('p','var') && isa(p,'plxReader')
				if isprop(ego,'p')
					ego.p = p;
				end
			end
		end
		
		% ===================================================================
		%> @brief set trials / var parsing from outside, override dialog, used when
		%> yoked to another analysis object
		%>
		%> @param in structure
		%> @return
		% ===================================================================
		function setSelection(ego, in)
			if isfield(in,'yokedSelection') && isprop(ego,'yokedSelection')
				ego.yokedSelection = in.yokedSelection;
			else
				ego.yokedSelection = false;
			end
			if isfield(in,'cutTrials') && isprop(ego,'cutTrials')
				ego.cutTrials = in.cutTrials;
			end
			if isfield(in,'selectedTrials') && isprop(ego,'selectedTrials')
				ego.selectedTrials = in.selectedTrials;
				ego.yokedSelection = true;
			end
			if isfield(in,'map') && isprop(ego,'map')
				ego.map = in.map;
			end
			if isfield(in,'plotRange') && isprop(ego,'plotRange')
				ego.plotRange = in.plotRange;
			end
			if isfield(in,'plotRange') && isprop(ego,'plotRange')
				ego.plotRange = in.plotRange;
			end
			if isfield(in,'measureRange') && isprop(ego,'measureRange')
				ego.measureRange = in.measureRange;
			end
			if isfield(in,'baselineWindow') && isprop(ego,'baselineWindow')
				ego.baselineWindow = in.baselineWindow;
			end
			if isfield(in,'alpha') && isfield(ego.stats,'alpha')
				ego.stats.alpha = in.alpha;
			end
			if isfield(in,'selectedBehaviour') && isprop(ego,'selectedBehaviour')
				if ischar(in.selectedBehaviour)
					ego.selectedBehaviour = cell(1);
					ego.selectedBehaviour{1} = in.selectedBehaviour;
				elseif iscell(in.selectedBehaviour)
					ego.selectedBehaviour = cell(1);
					ego.selectedBehaviour = in.selectedBehaviour;
				else
					ego.selectedBehaviour = cell(1);
					ego.selectedBehaviour{1}='correct';
				end
			end
		end
		
		% ===================================================================
		%> @brief
		%>
		%> @param
		%> @return
		% ===================================================================
		function initialiseStats(ego)
			if ~isfield(ego.stats,'alpha') || isempty(ego.stats.alpha)
				ego.stats(1).alpha = 0.05;
			end
			if ~isfield(ego.stats,'method') || isempty(ego.stats.method)
				ego.stats(1).method = 'analytic';
			end
			if ~isfield(ego.stats,'statistic') || isempty(ego.stats.statistic)
				ego.stats(1).statistic = 'indepsamplesT';
			end
			if ~isfield(ego.stats,'correctm') || isempty(ego.stats.correctm)
				ego.stats(1).correctm = 'no';
			end
			if ~isfield(ego.stats,'nrand') || isempty(ego.stats.nrand)
				ego.stats(1).nrand = 1000;
			end
			if ~isfield(ego.stats,'tail') || isempty(ego.stats.tail)
				ego.stats(1).tail = 0;
			end
			if ~isfield(ego.stats,'parameter') || isempty(ego.stats.parameter)
				ego.stats(1).parameter = 'trial';
			end
			if ~isfield(ego.stats,'resampling') || isempty(ego.stats.resampling)
				ego.stats(1).resampling = 'permutation';
			end
			if ~isfield(ego.stats,'interp') || isempty(ego.stats.interp)
				ego.stats(1).interp = 'linear';
			end
			if ~isfield(ego.stats,'interpw') || isempty(ego.stats.interpw)
				ego.stats(1).interpw = [-0.001 0.004];
			end
			if ~isfield(ego.stats,'customFreq') || isempty(ego.stats.customFreq)
				ego.stats(1).customFreq = [60 70];
			end
			if ~isfield(ego.stats,'smoothing') || isempty(ego.stats.smoothing)
				ego.stats(1).smoothing = 0;
			end
			if ~isfield(ego.stats,'ploterror') || isempty(ego.stats.ploterror)
				ego.stats(1).ploterror = 'SEM';
			end
		end
		
		% ===================================================================
		%> @brief format data for ROC
		%>
		%> @param dp scores for "signal" distribution
		%> @param dn scores for "noise" distribution
		%> @return data - [class , score] matrix
		% ===================================================================
		function data = formatByClass(ego,dp,dn)
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
		function [tp,fp] = roc(ego,data)
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
			[uY,idx] = unique(Y);
			tp = tp(idx);
			fp = fp(idx);
			
			% add trivial end-points
			tp = [0 ; tp ; 1];
			fp = [0 ; fp ; 1];
		end
		
		% ===================================================================
		%> @brief Area under ROC
		%>
		%> @param data - [class , score] matrix
		%> @param alpha    - level for confidence intervals (eg., enter 0.05 if you want 95% CIs)
		%> @param flag     - 'hanley' yields Hanley-McNeil (1982) asymptotic CI; 'maxvar' yields maximum variance CI;'mann-whitney';'logit';'boot' yields bootstrapped CI (DEFAULT)
		%> @param nboot - if 'boot' is set, specifies # of resamples, default=1000
		%> @param varargin - additional arguments to pass to BOOTCI, only valid for 'boot' this assumes you have the STATs toolbox, otherwise it's ignored and a crude percentile bootstrap is estimated.
		%> @return A   - area under ROC
		%> @return Aci - confidence intervals
		% ===================================================================
		function [A,Aci] = auc(ego,data,alpha,flag,nboot,varargin)
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
			
			[tp,fp] = ego.roc(data);
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
							Aci = bootci(nboot,{@ego.auc,data},varargin{:})';
						else
							Aci = bootci(nboot,{@ego.auc,data},'type','per')';
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
		function p = aucBootstrap(ego,data,nboot,flag,H0)
			
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
				A_boot(i) = ego.auc(data(ind,:));
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