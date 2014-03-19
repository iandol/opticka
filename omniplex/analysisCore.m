% ========================================================================
%> @brief analysisCore base class inherited by other analysis classes.
%> analysidCore is itself derived from optickaCore.
% ========================================================================
classdef analysisCore < optickaCore
	
	%--------------------PUBLIC PROPERTIES----------%
	properties
		doPlots@logical = true
	end
	
	%--------------------ABSTRACT PROPERTIES----------%
	properties (Abstract = true)
		
	end
	
	%--------------------HIDDEN PROPERTIES------------%
	properties (SetAccess = protected, Hidden = true)
		
	end
	
	%--------------------VISIBLE PROPERTIES-----------%
	properties (SetAccess = protected, GetAccess = public)
		
	end
	
	%--------------------DEPENDENT PROPERTIES----------%
	properties (SetAccess = private, Dependent = true)
		
	end
	
	%--------------------TRANSIENT PROPERTIES----------%
	properties (SetAccess = protected, GetAccess = protected, Transient = true)
		
	end
	
	%--------------------PROTECTED PROPERTIES----------%
	properties (SetAccess = protected, GetAccess = protected)
		
	end
	
	%--------------------PRIVATE PROPERTIES----------%
	properties (SetAccess = private, GetAccess = private)
		%> allowed properties passed to object upon construction
		allowedProperties@char = ''
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
		end
		
		% ===================================================================
		%> @brief 
		%>
		%> @param
		%> @return
		% ===================================================================
		function showEyePlots(ego)
			if ~isprop(ego,'p') || ~isa(ego.p,'plxReader') || isempty(ego.p.eA)
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
				return
			end
			if ~isempty(ego.p.info)
				infoBox(ego.p);
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
		%> @param
		%> @return
		% ===================================================================
		function ftout=subselectFieldTripTrials(ft,idx)
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
		%> @brief a wrapper to make plotyy more friendly to errorbars
		%>
		%> @param
		% ===================================================================
		function [h]=plotYY(x,y)
			[m,e] = stderr(y);
			if size(m) == size(x)
				h=areabar(x,m,e);
			end
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
			if		len == 2,		row = 2;	col = 1;
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
		%>
		%> @param
		% ===================================================================
		function colors = optimalColours(n_colors,bg,func)
			% Copyright 2010-2011 by Timothy E. Holy
			
			% Parse the inputs
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
	
		
		
	end %---END PROTECTED METHODS---%
	
end %---END CLASSDEF---%