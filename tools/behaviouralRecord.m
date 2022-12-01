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
		response			= []
		rt1					= []
		rt2					= []
		date				= []
		info				= ''
		xAll				= []
		yAll				= [];
		correctStateName	= '^correct'
		correctStateValue	= 1;
		breakStateName		= '^(breakfix|incorrect)'
		breakStateValue		= -1;
		rewardTime			= 150;
		rewardVolume		= 3.6067e-04; %for 1ms
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
			me.plotOnly = true;
			createPlot(me);
			updatePlot(me);
			plot(me);
			me.plotOnly = false;
		end
		
		% ===================================================================
		%> @brief 
		%> 
		%> 
		% ===================================================================
		function createPlot(me, eL)
			tt=tic;
			if ~me.plotOnly
				reset(me);
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
			tx{end+1} = ['RUN = ' me.comment];
			tx{end+1} = ['RADIUS = ' num2str(eL.fixation.radius)];
			tx{end+1} = ' ';
			tx{end+1} = ['TIME = ' num2str(eL.fixation.time)];
			tx{end+1} = ' ';
			tx{end+1} = ['INIT TIME = ' num2str(eL.fixation.initTime)];
			
			if ismac
				nfont = 'avenir next';
				mfont = 'menlo';
			elseif ispc
				nfont = 'calibri';
				mfont = 'consolas';
			else %linux
				nfont = 'Liberation Sans'; %get(0,'defaultAxesFontName');
				mfont = 'Liberation Mono';
			end

			me.h.root = uifigure('Name',me.fullName);
			me.h.root.Units = 'normalized';
			me.h.root.Position = [0.6 0 0.4 1];
			me.h.grid = uigridlayout(me.h.root,[2 1]);
			me.h.grid.RowHeight = {'4x' '1x'};
			me.h.grid.RowSpacing = 2;
			me.h.grid.Padding = [3 3 3 3];
			me.h.panel = uipanel(me.h.grid);
			me.h.info = uitextarea(me.h.grid, 'HorizontalAlignment', 'center',...
				'FontName', mfont, 'Editable', 'off', 'WordWrap', 'off');
			me.h.box = tiledlayout(me.h.panel,3,3);
			me.h.box.Padding='compact';
			me.h.axis1 = nexttile(me.h.box, [2 2]);
			me.h.axis2 = nexttile(me.h.box, [1 2]);
			me.h.axis3 = nexttile(me.h.box);
			me.h.axis4 = nexttile(me.h.box);
			me.h.axis5 = nexttile(me.h.box);

			figure(me.h.root);
			colormap(me.h.root, 'turbo');
			set([me.h.axis1 me.h.axis2 me.h.axis3 me.h.axis4 me.h.axis5], ...
				{'Box','XGrid','YGrid'},{'on','on','on'});
			
			xlabel(me.h.axis1, 'Run Number');
			xlabel(me.h.axis2, 'Time');
			xlabel(me.h.axis3, 'Group');
			xlabel(me.h.axis4, '#');
			xlabel(me.h.axis5, 'x');
			ylabel(me.h.axis1, 'Yes / No');
			ylabel(me.h.axis2, 'Number #');
			ylabel(me.h.axis3, '% success');
			ylabel(me.h.axis4, '% success');
			ylabel(me.h.axis5, 'y');
			title(me.h.axis1,'Success () / Fail ()');
			title(me.h.axis2,'Response Times');
			title(me.h.axis3,'Hit (blue) / Miss (red)');
			title(me.h.axis4,'Average (n=10) Hit / Miss %');
			title(me.h.axis5,'Last Eye Position');
			me.isOpen = true;
			fprintf('bR create took %3.2f ms\n',toc(tt)*1000);
		end
		
		% ===================================================================
		function updatePlot(me, rE)
		%> @fn  updatePlot 
		%> @brief updates the behaviouralRecord details, use drawPlot() to draw it
		%> 
		%> @param rE runExperiment object
		% ===================================================================
			if exist('rE','var') && isa(rE,"runExperiment")
				sM = rE.stateMachine;
				eT = rE.eyeTracker;
			else
				return;
			end	
			tt = tic;
			if me.tick == 1
				reset(me);
				me.startTime = datetime('now');
			end
			if exist('sM','var')
				if ~isempty(regexpi(sM.currentName,me.correctStateName,'once'))
					me.response(me.tick) = me.correctStateValue;
					me.rt1(me.tick) = sM.log(end).stateTimeToNow * 1e3;
				elseif ~isempty(regexpi(sM.currentName,me.breakStateName,'once'))
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
				me.radius(me.tick) = eT.fixation.radius;
				me.time(me.tick) = mean(eT.fixation.time);
				me.inittime(me.tick) = eT.fixation.initTime;
				me.xAll = eT.xAll;
				me.yAll = eT.yAll;
			else
				me.rt2(me.tick) = NaN;
				me.radius(me.tick) = NaN;
				me.time(me.tick) = NaN;
				me.inittime(me.tick) = NaN;
			end
			if ~isempty(me.response)
				n = length(me.response);
				me.trials(n).now = datetime('now');
				me.trials(n).info = me.info;
				me.trials(n).tick = me.tick;
				me.trials(n).comment = me.comment;
				me.trials(n).response = me.response(n);
				me.trials(n).xAll = me.xAll;
				me.trials(n).yAll = me.yAll;
			end
			fprintf('bR update took %3.2f ms\n',toc(tt)*1000);
		end
		
		% ===================================================================
		%> @brief 
		%> 
		%> 
		% ===================================================================
		function plotAsyn(me, drawNow)
			parfeval(backgroundPool,@me.plot,0,drawNow);
		end
		

		% ===================================================================
		%> @brief 
		%> 
		%> 
		% ===================================================================
		function plot(me, drawNow)
			if ~me.isOpen; return; end
			if ~exist('drawNow','var'); drawNow = true; end
			tt = tic;
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
			ylim(me.h.axis1,[min([min(me.radius) min(me.inittime) min(me.time)])-1 max([max(me.radius) max(me.inittime) max(me.time)])+1]);
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
				for i = 1:length(me.trials)
					set(me.h.axis5,'NextPlot','add')
					if isfield(me.trials(i),'xAll')
						plot(me.h.axis5, me.trials(i).xAll, me.trials(i).yAll, 'MarkerSize',15,'Marker', '.');
					end
				end
			else
				if ~isempty(me.xAll)
					hold(me.h.axis5,'off');
					plot(me.h.axis5, me.xAll, me.yAll, 'b.','MarkerSize',15,'Color',[0.5 0.5 0.8]);
					hold(me.h.axis5,'on');
					plot(me.h.axis5, me.xAll(1), me.yAll(1), 'g.','MarkerSize',18);
					plot(me.h.axis5, me.xAll(end), me.yAll(end), 'r.','MarkerSize',18,'Color',[1 0.5 0]);
				end
			end
			axis(me.h.axis5, 'ij');
			xlim(me.h.axis5,[-15 15]);
			ylim(me.h.axis5,[-15 15]);
			
			set([me.h.axis1 me.h.axis2 me.h.axis3 me.h.axis4 me.h.axis5], ...
				'Box','on','XGrid','on','YGrid','on');
			
			xlabel(me.h.axis1, 'Trial Number')
			xlabel(me.h.axis2, 'Averaged Point')
			xlabel(me.h.axis4, 'Time (ms)')
			xlabel(me.h.axis5, 'X')
			ylabel(me.h.axis2, '% success')
			ylabel(me.h.axis3, '% success')
			ylabel(me.h.axis4, 'N')
			ylabel(me.h.axis5, 'Y')
			title(me.h.axis1,['Success (' num2str(hitn) ') / Fail (all=' num2str(missn) ' | break=' num2str(breakn) ' | abort=' num2str(missn-breakn) ')'])
			title(me.h.axis4,sprintf('Time:  total: %g | fixinit: %g',mean(me.rt1),mean(me.rt2)));
			title(me.h.axis3,'Hit (blue) / Miss (red)')
			title(me.h.axis2,'Average (n=10) Hit / Miss %')
			title(me.h.axis5,'Last Eye Position');

			t = {['START @ ' char(me.date)]};
			d = me.trials(end).now - me.startTime;
			t{end+1} = ['RUN time = ' char(d)];
			t{end+1} = ['RUN:' me.comment];
			t{end+1} = ['INFO:' me.info];
			t{end+1} = ['RADIUS (red) b|n = ' num2str(me.radius(end)) 'deg'];
			t{end+1} = ['INITIATE FIXATION TIME (green) z|x = ' num2str(me.inittime(end)) ' secs'];
			t{end+1} = ['MAINTAIN FIXATION TIME (blue) c|v = ' num2str(me.time(end)) ' secs'];
			t{end+1} = ' ';
			if ~isempty(me.rt1)
				t{end+1} = ['Last/Mean Init Time = ' num2str(me.rt2(end)) ' / ' num2str(mean(me.rt2)) 'secs | Last/Mean Init+Fix = ' num2str(me.rt1(end)) ' / ' num2str(mean(me.rt1)) 'secs'];
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
				t{end+1} = ['#' num2str(i) '<' num2str(me.trials(i).response) '>: ' me.trials(i).info ' <> ' me.trials(i).comment];
			end
			me.h.info.Value = t';
			if ~me.plotOnly
				me.tick = me.tick + 1;
			end
			fprintf('bR plot %3.2f ms\n',toc(tt)*1000);
			tt=tic;
			if drawNow; drawnow(); end
			fprintf('bR plot drawnow %3.2f ms\n',toc(tt)*1000);
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
			me.comment = '';
		end
		
		% ===================================================================
		%> @brief 
		%> 
		%> 
		% ===================================================================
		function clearHandles(me)
			me.h = [];
		end
		
		% ===================================================================
		%> @brief called on save
		%>
		%> @param
		% ===================================================================
		function out = saveobj(me)
			%clearHandles(me);
			fprintf('===> Saving behaviouralRecord object...\n');
			out = me;
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
			if isa(in,'behaviouralRecord') && ~isempty(in.h)
				in.clearHandles();
			end
			lobj = in;
		end
	end
	
	%=======================================================================
	methods ( Access = protected ) %-------PRIVATE (protected) METHODS-----%
	%=======================================================================
	
	end
end