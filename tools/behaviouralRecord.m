% ========================================================================
classdef behaviouralRecord < optickaCore
%> @class behaviouralRecord
%> @brief Create a GUI and update performance plots for a behavioural
%> task
%> 
%>
%> Copyright ©2014-2022 Ian Max Andolina — released: LGPL3, see LICENCE.md
% ========================================================================
	
	%--------------------PUBLIC PROPERTIES----------%
	properties
		%> verbosity
		verbose				= true
		% response list
		response			= []
		rt1					= []
		rt2					= []
		date				= []
		info				= ''
		% a local copy of X position (eye or touch)
		xAll				= []
		% a local copy of Y position (eye or touch)
		yAll				= []
		% pupil size (eye only)
		pupilAll			= []
		% the name of the state which is equivalent to a "correct"
		correctStateName	= "correct"
		% the value to assign a correct
		correctStateValue	= 1;
		% the name of the states which are equivalent to "incorrect"
		breakStateName		= ["breakfix", "incorrect"]
		breakStateValue		= -1
		rewardTime			= 300
		rewardVolume		= 3.6067e-04 %for 1ms
	end
	
	properties (GetAccess = public, SetAccess = protected)
		trials
		tick
		isOpen				= false
		startTime
		radius
		time
		inittime
		average
		averages
	end
	
	properties (Transient = true, SetAccess = ?runExperiment)
		%> handles for the GUI
		h
	end
	
	%--------------------PRIVATE PROPERTIES----------%
	properties (SetAccess = private, GetAccess = private)
		plotOnly			= false
		%> allowed properties passed to object upon construction
		allowedProperties = 'verbose'
		lf
		SansFont
	end
	
	%=======================================================================
	methods %------------------PUBLIC METHODS
	%=======================================================================
		
		% ===================================================================
		%> @brief Class constructor
		%>
		%> More detailed description of what the constructor does.
		%>
		%> @param args are passed as a structure of properties which is
		%> parsed.
		%> @return instance of class.
		% ===================================================================
		function me = behaviouralRecord(varargin)
			args = optickaCore.addDefaults(varargin,struct('name','Behavioural Record'));
			me=me@optickaCore(args); %we call the superclass constructor first
			me.parseArgs(args, me.allowedProperties);
		end
		
		% ===================================================================
		%> @brief 
		%> 
		%> 
		% ===================================================================
		function plotPerformance(me)
			if isempty(me.response); warning('No data available'); return; end
			op = me.plotOnly;
			me.plotOnly = true;
			if isempty(me.h) || ~(isfield(me.h,'root') && isgraphics(me.h.root))
				createPlot(me);
			end
			updatePlot(me);
			plot(me);
			me.plotOnly = op;
		end
		
		% ===================================================================
		%> @brief 
		%> 
		%> 
		% ===================================================================
		function createPlot(me, eL)
			if ~me.plotOnly
				me.date = datetime('now');
			end
			if isfield(me.h,'root') && ~isempty(findobj(me.h.root))
				close(me.h.root);
			end
			me.h = [];
			if ~exist('eL','var')
				eL.fixation.radius = 1;
				eL.fixation.time = 1;
				eL.fixation.initTime = 1;
			end
			tx = {['START @ ' char(me.date)]};
			if ~isempty(me.comment)
				c=char(me.comment(1,:));
			else
				c = '';
			end
			tx{end+1} = ['RUN = ' c];
			tx{end+1} = ['RADIUS = ' num2str(eL.fixation.radius)];
			tx{end+1} = ' ';
			tx{end+1} = ['TIME = ' num2str(eL.fixation.time)];
			tx{end+1} = ' ';
			tx{end+1} = ['INIT TIME = ' num2str(eL.fixation.initTime)];
			
			lf = listfonts; %#ok<*PROPLC>
			if ismac
				SansFont = 'Avenir Next'; %get(0,'defaultAxesFontName');
				MonoFont = 'Menlo';
			elseif ispc
				SansFont = 'Calibri';
				MonoFont = 'Consolas';
			else %linux
				SansFont = 'Ubuntu'; 
				MonoFont = 'Ubuntu Mono';
			end
			if any(matches(lf,'Source Sans 3'))
				SansFont = 'Source Sans 3';
			end
			if any(matches(lf,'Fira Code'))
				MonoFont = 'Fira Code';
			end
			me.lf = lf;
			me.SansFont = SansFont;
			
			me.h.root = uifigure('Name',me.fullName,'Tag','opticka');
			me.h.root.Units = 'normalized';
			me.h.root.Position = [0.6 0 0.4 1];
			me.h.grid = uigridlayout(me.h.root,[2 1]);
			me.h.grid.RowHeight = {'4x' '1x'};
			me.h.grid.RowSpacing = 2;
			me.h.grid.Padding = [1 1 1 1];
			me.h.panel = uipanel(me.h.grid);
			me.h.info = uitextarea(me.h.grid, 'HorizontalAlignment', 'center',...
				'FontName', MonoFont, 'Editable', 'off', 'WordWrap', 'off');
			me.h.box = tiledlayout(me.h.panel,3,3);
			me.h.box.Padding='compact';
			me.h.axis1 = nexttile(me.h.box, [2 2]); me.h.axis1.FontName = SansFont;
			me.h.axis2 = nexttile(me.h.box); me.h.axis2.FontName = SansFont;
			me.h.axis3 = nexttile(me.h.box); me.h.axis3.FontName = SansFont;
			me.h.axis4 = nexttile(me.h.box); me.h.axis4.FontName = SansFont;
			me.h.axis5 = nexttile(me.h.box); me.h.axis5.FontName = SansFont;
			me.h.axis6 = nexttile(me.h.box); me.h.axis5.FontName = SansFont;

			figure(me.h.root);
			colormap(me.h.root, 'turbo');
			
			xlabel(me.h.axis1, 'Run Number');
			xlabel(me.h.axis2, 'Time');
			xlabel(me.h.axis3, 'Group');
			xlabel(me.h.axis4, '#');
			xlabel(me.h.axis5, 'x');
			xlabel(me.h.axis6, 'Sample');
			ylabel(me.h.axis1, 'Yes / No');
			ylabel(me.h.axis2, 'Number #');
			ylabel(me.h.axis3, '% success');
			ylabel(me.h.axis4, '% success');
			ylabel(me.h.axis5, 'y');
			xlabel(me.h.axis6, 'Pupil Size');
			title(me.h.axis1,'Success () / Fail ()');
			title(me.h.axis2,'Response Times');
			title(me.h.axis3,'Hit (blue) / Miss (red)');
			title(me.h.axis4,'Average (n=10) Hit / Miss %');
			title(me.h.axis5,'Last Eye Position');
			title(me.h.axis6,'Last Pupil Size');
			set([me.h.axis1 me.h.axis2 me.h.axis3 me.h.axis4 me.h.axis5 me.h.axis6], ...
				{'Box','XGrid','YGrid','FontName'},{'on','on','on',SansFont});
			WaitSecs('YieldSecs',0.02);
			drawnow;
			WaitSecs('YieldSecs',0.02);
			me.isOpen = true;
		end
		
		% ===================================================================
		function updatePlot(me, rE)
		%> @fn  updatePlot 
		%> @brief updates the behaviouralRecord details, use plot() to draw it
		%> 
		%> @param rE runExperiment object
		% ===================================================================
			if exist('rE','var') && isa(rE,"runExperiment")
				sM = rE.stateMachine;
				eT = rE.eyeTracker;
			else
				return;
			end	
			if isempty(me.tick) || me.tick == 1
				reset(me);
				me.startTime = datetime('now','Format','yyyy-MM-dd HH:mm:ss:SSSS');
				me.tick = 1;
			end
			if exist('sM','var')
				if matches(sM.currentName, me.correctStateName)
					me.response(me.tick) = me.correctStateValue;
					me.rt1(me.tick) = sM.log.tnow(sM.log.n)-sM.log.startTime * 1e3;
				elseif matches(sM.currentName, me.breakStateName)
					me.response(me.tick) = me.breakStateValue;
					me.rt1(me.tick) = 0;
				else
					me.response(me.tick) = 0;
					me.rt1(me.tick) = 0;
				end
			else
				me.response(me.tick) = NaN;
				me.rt1(me.tick) = NaN;
			end
			if exist('eT','var')
				me.rt2(me.tick) = eT.fixInitLength * 1e3;
				if isscalar(eT.fixation.radius)
					me.radius(me.tick) = eT.fixation.radius;
				elseif length(eT.fixation.radius) == 2
					me.radius(me.tick) = sqrt(eT.fixation.radius(1)^2 + eT.fixation.radius(1)^2);
				else
					me.radius(me.tick) = NaN;
				end
				me.time(me.tick) = mean(eT.fixation.time);
				me.inittime(me.tick) = eT.fixation.initTime;
				me.xAll = eT.xAll;
				me.yAll = eT.yAll;
				me.pupilAll = eT.pupilAll;
			else
				me.rt2(me.tick) = NaN;
				me.radius(me.tick) = NaN;
				me.time(me.tick) = NaN;
				me.inittime(me.tick) = NaN;
			end
			if ~isempty(me.response)
				n = length(me.response);
				me.trials(n).now = datetime('now','Format','yyyy-MM-dd HH:mm:ss:SSSS');
				me.trials(n).info = me.info;
				me.trials(n).tick = me.tick;
				me.trials(n).comment = '';
				me.trials(n).response = me.response(n);
				me.trials(n).xAll = me.xAll;
				me.trials(n).yAll = me.yAll;
				me.trials(n).pupilAll = me.pupilAll;
			end
		end
		
		% ===================================================================
		%> @brief 
		%> 
		%> 
		% ===================================================================
		function plotAsync(me, drawNow)
			parfeval(backgroundPool,@me.plot,0,drawNow);
		end
		
		% ===================================================================
		%> @brief 
		%> 
		%> 
		% ===================================================================
		function plot(me, drawNow)
			if isempty(me.response); warning('No data available'); return; end
			if ~me.isOpen || ~isfield(me.h,'root'); me.createPlot; me.plotOnly = true; end
			if ~exist('drawNow','var'); drawNow = true; end
			hitn = length( me.response(me.response > 0) );
			breakn = length( me.response(me.response < 0) );
			totaln = length(me.response);
			missn = totaln - hitn;
			
			hitmiss = 100 * (hitn / totaln);
			breakmiss = 100 * (breakn / missn);
			if length(me.response) < 10
				avg = 100 * (hitn / totaln);
			else
				lastn = me.response(end-9:end);				
				avg = (length(lastn(lastn > 0)) / length(lastn)) * 100;
			end
			me.averages(me.tick) = avg;
			hits = [hitmiss 100-hitmiss; avg 100-avg; breakmiss 100-breakmiss];
			
			%axis 1
			me.h.axis1.NextPlot = 'replaceall';
			colororder(me.h.axis1,[0 0 0;0.5 0.2 0.2])
			yyaxis(me.h.axis1, 'left');
			plot(me.h.axis1, 1:length(me.response), me.response,'k.-','MarkerSize',20,'MarkerFaceColor',[0.2 0.2 0.2]);
			ylim(me.h.axis1,[-1.25 1.25])
			yticks(me.h.axis1,[-1 0 1]);
			yticklabels(me.h.axis1,{'incorrect','undefined','correct'});
			ytickangle(me.h.axis1, 80);
			ylabel(me.h.axis1, 'Response');
			yyaxis(me.h.axis1, 'right');
			if ~isempty(me.radius) && ~all(isnan(me.radius))
				hold(me.h.axis1, 'on');
				plot(me.h.axis1, 1:length(me.radius), me.radius,'ro','MarkerSize',8);
				plot(me.h.axis1, 1:length(me.inittime), me.inittime,'go','MarkerSize',8);
				plot(me.h.axis1, 1:length(me.time), me.time,'bo','MarkerSize',8);
				hold(me.h.axis1, 'off');
			end
			try ylim(me.h.axis1,[min([min(me.radius) min(me.inittime) min(me.time)])-1 max([max(me.radius) max(me.inittime) max(me.time)])+1]); end
			legend(me.h.axis1,{'response','radius','inittime','time'})
			ylabel(me.h.axis1, 'Fixation Parameters (secs or degs)');

			%axis 2
			plot(me.h.axis2, 1:length(me.averages), me.averages,'k.-','MarkerSize',12);
			ylim(me.h.axis2,[-1 101])
			
			%axis 3
			bar(me.h.axis3,hits,'stacked');
			set(me.h.axis3,'XTickLabel', {'all';'newest';'break/abort'});
			ylim(me.h.axis3,[-1 101])

			%axis 4
			if ~isempty(me.rt1) && ~all(isnan(me.rt1))
				if max(me.rt1) == 0 && max(me.rt2) > 0
					histogram(me.h.axis4, [me.rt2'], 8);
				elseif max(me.rt1) > 0 && max(me.rt2) == 0
					histogram(me.h.axis4, [me.rt1'], 8);
				elseif max(me.rt1) > 0 && max(me.rt2) > 0
					histogram(me.h.axis4, [me.rt2'], 8); hold(me.h.axis4,'on');
					histogram(me.h.axis4, [me.rt1'], 8); hold(me.h.axis4,'off');
				end
			end

			%axis 5
			if me.plotOnly && length(me.trials) > 1
				set(me.h.axis5,'NextPlot','add')
				for i = 1:length(me.trials)
					if isfield(me.trials(i),'xAll')
						plot(me.h.axis5, me.trials(i).xAll, me.trials(i).yAll, 'MarkerSize',15,'Marker', '.');
					end
				end
			else
				if ~isempty(me.xAll)
					hold(me.h.axis5,'off');
					plot(me.h.axis5, me.xAll, me.yAll, '-','Color',[0.5 0.5 0.8]);
					hold(me.h.axis5,'on');
					plot(me.h.axis5, me.xAll(1), me.yAll(1), 'g.','MarkerSize',18);
					plot(me.h.axis5, me.xAll(end), me.yAll(end), 'r.','MarkerSize',18,'Color',[1 0.5 0]);
				end
			end
			axis(me.h.axis5, 'ij');
			xlim(me.h.axis5,[-15 15]);
			ylim(me.h.axis5,[-15 15]);

			%axis 6
			if me.plotOnly && length(me.trials) > 1
				set(me.h.axis6,'NextPlot','add')
				for i = 1:length(me.trials)
					if isfield(me.trials(i),'pupilAll')
						plot(me.h.axis6, me.trials(i).pupilAll, 'k-');
					end
				end
			else
				if ~isempty(me.pupilAll)
					plot(me.h.axis6, me.pupilAll,'k-');
				end
			end
			
			set([me.h.axis1 me.h.axis2 me.h.axis3 me.h.axis4 me.h.axis5 me.h.axis6], ...
				{'Box','XGrid','YGrid','FontName'},{'on','on','on',me.SansFont});
			
			xlabel(me.h.axis1, 'Trial Number')
			xlabel(me.h.axis2, 'Averaged Point')
			xlabel(me.h.axis4, 'Time (ms)')
			xlabel(me.h.axis5, 'X')
			xlabel(me.h.axis6, 'Sample')
			ylabel(me.h.axis2, '% success')
			ylabel(me.h.axis3, '% success')
			ylabel(me.h.axis4, 'N')
			ylabel(me.h.axis5, 'Y')
			ylabel(me.h.axis6, 'Pupil Size')
			title(me.h.axis1,['Success (' num2str(hitn) ') / Fail (all=' num2str(missn) ' | break=' num2str(breakn) ' | abort=' num2str(missn-breakn) ')'])
			title(me.h.axis4,sprintf('Time:  total: %g | fixinit: %g',mean(me.rt1),mean(me.rt2)));
			title(me.h.axis3,'Hit (blue) / Miss (red)')
			title(me.h.axis2,'Average (n=10) Hit / Miss %')
			title(me.h.axis5,'Last Eye Position');
			title(me.h.axis6,'Last Pupil Data');

			if ~isempty(me.comment)
				c=char(me.comment(1,:));
			else
				c = '';
			end
			t = {['START @ ' char(me.date)]};
			try d = me.trials(end).now - me.startTime; catch; d = 0; end
			t{end+1} = ['RUN time = ' char(d)];
			t{end+1} = ['RUN: ' c];
			t{end+1} = ['INFO:' me.info];
			if ~isempty(me.radius) && ~isempty(me.inittime) && ~isempty(me.time)
				t{end+1} = ['RADIUS (red) b|n = ' num2str(me.radius(end)) 'deg'];
				t{end+1} = ['INITIATE FIXATION TIME (green) z|x = ' num2str(me.inittime(end)) ' secs'];
				t{end+1} = ['MAINTAIN FIXATION TIME (blue) c|v = ' num2str(me.time(end)) ' secs'];
			end
			t{end+1} = ' ';
			if ~isempty(me.rt1)
				t{end+1} = ['Last/Mean Init Time = ' num2str(me.rt2(end)) ...
					' / ' num2str(mean(me.rt2)) 'secs | Last/Mean Init+Fix = ' ...
					num2str(me.rt1(end)) ' / ' num2str(mean(me.rt1)) 'secs'];
			end
			t{end+1} = ['Overall | Latest (n=10) Hit Rate = ' num2str(hitmiss) ' | ' num2str(avg)];
			t{end+1} = sprintf('Estimated Volume at %gms TTL = %g mls', me.rewardTime, (me.rewardVolume*me.rewardTime)*hitn);
			
			t{end+1} = ' ';
			t{end+1} = '============Logged trial info============';
			if me.plotOnly
				startt = 1; endt = length(me.trials);
			elseif length(me.trials) <= 10
				startt = 1; endt = length(me.trials);
			else
				startt = length(me.trials)-10; endt = length(me.trials);
			end
			for i = startt:endt
				t{end+1} = ['#' num2str(i) '<' num2str(me.trials(i).response) '>: ' ...
					char(me.trials(i).info)];
			end
			me.h.info.Value = t';
			if ~me.plotOnly
				me.tick = me.tick + 1;
			end
			if drawNow; drawnow(); end
		end

		% ===================================================================
		%> @brief 
		%> 
		%> 
		% ===================================================================
		function reset(me)
			me.tick = 1;
			me.trials = [];
			me.startTime = [];
			me.response = [];
			me.rt1 = [];
			me.rt2 = [];
			me.radius = [];
			me.time = [];
			me.inittime = [];
			me.xAll = [];
			me.yAll = [];
			me.comment = "";
		end
		
		% ===================================================================
		%> @brief 
		%> 
		%> 
		% ===================================================================
		function clearHandles(me)
			if isfield(me.h,'root') && isgraphics(me.h.root)
				try close(me.h.root); end
			end
			me.h = [];
		end
		
	end
	
	%=======================================================================
	methods (Static = true) %------------------STATIC METHODS
	%=======================================================================
		% ===================================================================
		%> @brief loadobj
		%> To be backwards compatible to older saved protocols, we have to parse 
		%> structures / objects specifically during object load
		%> @param in input object/structure
		% ===================================================================
		function lobj=loadobj(in)
			if isa(in,'behaviouralRecord') 
				if ~isempty(in.h);in.clearHandles();end
				lobj = in;
			else
				lobj = behaviouralRecord;
				fn = properties(lobj);
				for i = 1:length(fn)
					if isfield(in, fn{i})
						lobj.(fn{i}) = in.(fn{i});
					end
				end
			end
			
			if contains(lobj.correctStateName,'correct')
				lobj.correctStateName = "correct";
			end
			if contains(lobj.breakStateName,'breakfix')
				lobj.breakStateName = ["breakfix" "incorrect"];
			end
			lobj.h = [];
			lobj.isOpen = false;
			lobj.plotOnly = true;
		end
	end
	
	%=======================================================================
	methods ( Access = protected ) %-------PRIVATE (protected) METHODS-----%
	%=======================================================================
	
	end
end