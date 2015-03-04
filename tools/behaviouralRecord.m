% ========================================================================
%> @brief Create and update behavioural record.
%> 
% ========================================================================
classdef behaviouralRecord < optickaCore
	
	%--------------------PUBLIC PROPERTIES----------%
	properties
		%> verbosity
		verbose = true
		response = []
		rt1 = []
		rt2 = []
		date = []
		info = ''
		rewardTime = 150;
		rewardVolume = 3.6067e-04; %for 1ms
	end
	
	properties (SetAccess = protected, GetAccess = public, Transient = true)
		%> handles for the GUI
		h
	end
	
	%--------------------PRIVATE PROPERTIES----------%
	properties (SetAccess = private, GetAccess = private)
		tick
		startTime
		radius
		time
		inittime
		average
		averages
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
		function obj = behaviouralRecord(varargin)
			if nargin == 0; varargin.name = 'Behavioural Record'; end
			obj=obj@optickaCore(varargin); %superclass constructor
			if nargin>0
				obj.parseArgs(varargin,obj.allowedProperties);
			end
		end
		
		% ===================================================================
		%> @brief 
		%> 
		%> 
		% ===================================================================
		function createPlot(obj, eL)
			obj.tick = 1;
			obj.date = datestr(now);
			if ~exist('eL','var')
				eL.fixationRadius = 1;
				eL.fixationTime = 1;
				eL.fixationInitTime = 1;
			end
			t = {['INFORMATION @ ' obj.date]};
			t{end+1} = ['RUN = ' obj.comment];
			t{end+1} = ['RADIUS = ' num2str(eL.fixationRadius)];
			t{end+1} = ' ';
			t{end+1} = ['TIME = ' num2str(eL.fixationTime)];
			t{end+1} = ' ';
			t{end+1} = ['INIT TIME = ' num2str(eL.fixationInitTime)];
			
			obj.h.root = figure('NumberTitle', 'off', 'Toolbar', 'none');
			obj.h.panel = uiextras.BoxPanel('Parent',obj.h.root, ...
				'Title',obj.fullName, ...
				'FontSize',14, ...
				'TitleColor',[0.8 0.79 0.78], ...
				'BackgroundColor',[0.83 0.83 0.83]);
			obj.h.vbox = uiextras.VBoxFlex( 'Parent', obj.h.panel );
			obj.h.hbox = uiextras.HBoxFlex('Parent', obj.h.vbox);
			obj.h.info = uicontrol('Style','edit', ...
				'Parent', obj.h.vbox, ...
				'Tag','bRInfoText', ...
				'String', t, ...
				'BackgroundColor', [1 1 1], ...
				'HorizontalAlignment', 'center', ...
				'Max', 100, ...
				'FontSize', 14, ...
				'FontName','Menlo');
			obj.h.vbox2 = uiextras.VBox('Parent', obj.h.hbox);
			obj.h.axis1 = axes('Parent', obj.h.vbox2,'Units','pixels');
			obj.h.axis4 = axes('Parent', obj.h.vbox2,'Units','pixels');
			obj.h.vbox3 = uiextras.VBox('Parent', obj.h.hbox);
			obj.h.axis2 = axes('Parent', obj.h.vbox3,'Units','pixels');
			obj.h.axis3 = axes('Parent', obj.h.vbox3,'Units','pixels');
			axis([obj.h.axis1 obj.h.axis2 obj.h.axis3 obj.h.axis4], 'square');
			opticka.resizeFigure([],[900 900]);
			set(obj.h.vbox,'Sizes',[-3 -1])
			set(obj.h.hbox,'Sizes',[-2 -1])
			set(obj.h.vbox2,'Sizes',[-2 -1])
			set(obj.h.vbox3,'Sizes',[-2 -1])

			plot(obj.h.axis1, 1, 0,'ko');
			hist(obj.h.axis2, 0, 0:0.1:2);
			colormap('jet')
			bar(obj.h.axis3,rand(2,2),'stacked')
			set(obj.h.axis3,'XTickLabel', {'all';'newest'})
			plot(obj.h.axis4, 1, 0,'ko-');
			
			set([obj.h.axis1 obj.h.axis2 obj.h.axis3 obj.h.axis4], ...
				'Box','on','XGrid','on','YGrid','on','ZGrid','on');
			axis([obj.h.axis2 obj.h.axis3 obj.h.axis4], 'tight');
			
			xlabel(obj.h.axis1, 'Run Number')
			xlabel(obj.h.axis2, 'Time')
			xlabel(obj.h.axis3, 'Group')
			xlabel(obj.h.axis4, '#')
			ylabel(obj.h.axis1, 'Yes / No')
			ylabel(obj.h.axis2, 'Number #')
			ylabel(obj.h.axis3, '% success')
			ylabel(obj.h.axis4, '% success')
			title(obj.h.axis1,'Success (1) / Fail (0)')
			title(obj.h.axis2,'Response Times')
			title(obj.h.axis3,'Hit (blue) / Miss (red)')
			title(obj.h.axis4,'Average (n=10) Hit / Miss %')
			hn = findobj(obj.h.axis2,'Type','patch');
			set(hn,'FaceColor','k','EdgeColor','k');
		end
		
		% ===================================================================
		%> @brief 
		%> 
		%> 
		% ===================================================================
		function updatePlot(obj, eL, sM)
			if obj.tick == 1
				obj.startTime = clock;
			end
			if exist('eL','var') && exist('sM','var')
				if strcmpi(sM.currentName,'correct')
					obj.response(end+1) = 1;
					obj.rt1(end+1) = sM.log(end).totalTime;
					obj.rt2(end+1) = eL.fixInitLength;
				elseif strcmpi(sM.currentName,'breakfix')
					obj.response(end+1) = -1;
				else
					obj.response(end+1) = 0;
				end
				obj.radius(end+1) = eL.fixationRadius;
				obj.time(end+1) = eL.fixationTime;
				obj.inittime(end+1) = eL.fixationInitTime;
			end
			
			hitn = length( obj.response(obj.response > 0) );
			breakn = length( obj.response(obj.response < 0) );
			totaln = length(obj.response);
			missn = totaln - hitn;
			
			hitmiss = 100 * (hitn / totaln);
			breakmiss = 100 * (breakn / missn);
			if length(obj.response) < 10
				average = 100 * (hitn / totaln);
			else
				lastn = obj.response(end-9:end);				
				average = (length(lastn(lastn > 0)) / length(lastn)) * 100;
			end
			obj.averages(end+1) = average;
			hits = [hitmiss 100-hitmiss; average 100-average; breakmiss 100-breakmiss];
			
			%axis 1
			set(obj.h.axis1,'NextPlot','replacechildren')
			plot(obj.h.axis1, 1:length(obj.response), obj.response,'k.-','MarkerSize',12);
			set(obj.h.axis1,'NextPlot','add')
			plot(obj.h.axis1, 1:length(obj.response), obj.radius,'rd','MarkerSize',10);
			plot(obj.h.axis1, 1:length(obj.response), obj.inittime,'gd','MarkerSize',10);
			plot(obj.h.axis1, 1:length(obj.response), obj.time,'bd','MarkerSize',10);
			axis(obj.h.axis1, 'tight');
			%axis 2
			if length(obj.rt1) > 0
				hist(obj.h.axis2, [obj.rt1' obj.rt2'], 0:0.2:2);
				axis(obj.h.axis2, 'tight');
			end
			
			%axis 3
			bar(obj.h.axis3,hits,'stacked')
			set(obj.h.axis3,'XTickLabel', {'all';'newest';'break/abort'})
			axis(obj.h.axis3, 'tight');
			ylim(obj.h.axis3,[0 100])
			
			%axis 4
			plot(obj.h.axis4, 1:length(obj.averages), obj.averages,'k.-','MarkerSize',12);
			axis(obj.h.axis4, 'tight');
			ylim(obj.h.axis4,[0 100])
			
			set([obj.h.axis1 obj.h.axis2 obj.h.axis3 obj.h.axis4], ...
				'Box','on','XGrid','on','YGrid','on','ZGrid','on');
			
			xlabel(obj.h.axis1, 'Run Number')
			xlabel(obj.h.axis2, 'Time')
			xlabel(obj.h.axis3, 'Group')
			xlabel(obj.h.axis4, '#')
			ylabel(obj.h.axis1, 'Yes / No')
			ylabel(obj.h.axis2, 'Number #')
			ylabel(obj.h.axis3, '% success')
			ylabel(obj.h.axis4, '% success')
			title(obj.h.axis1,['Success (' num2str(hitn) ') / Fail (all=' num2str(missn) ' | break=' num2str(breakn) ' | abort=' num2str(missn-breakn) ')'])
			title(obj.h.axis2,['Response Times (mean init: ' num2str(mean(obj.rt2)) ' | mean init+fix: ' num2str(mean(obj.rt1)) ')'])
			title(obj.h.axis3,'Hit (blue) / Miss (red) / Break (blue) / Abort (red)')
			title(obj.h.axis4,'Average (n=10) Hit / Miss %')
			hn = findobj(obj.h.axis2,'Type','patch');
			%set(hn,'FaceColor','k','EdgeColor','k');
			
			t = {['INFORMATION @ ' obj.date]};
			t{end+1} = ['RUN:' obj.comment];
			t{end+1} = ['INFO:' obj.info];
			t{end+1} = ['RADIUS (red) b|n = ' num2str(obj.radius(end)) 'deg'];
			t{end+1} = ['INITIATE FIXATION TIME (green) z|x = ' num2str(obj.inittime(end)) ' secs'];
			t{end+1} = ['MAINTAIN FIXATION TIME (blue) c|v = ' num2str(obj.time(end)) ' secs'];
			t{end+1} = ' ';
			if ~isempty(obj.rt1)
				t{end+1} = ['Last/Mean Init Time = ' num2str(obj.rt2(end)) ' / ' num2str(mean(obj.rt2)) 'secs | Last/Mean Init+Fix = ' num2str(obj.rt1(end)) ' / ' num2str(mean(obj.rt1)) 'secs'];
			end
			t{end+1} = ['Overall | Latest (n=10) Hit Rate = ' num2str(hitmiss) ' | ' num2str(average)];
			t{end+1} = ['Run time = ' num2str(etime(clock,obj.startTime)/60) 'mins'];
			t{end+1} = sprintf('Estimated Volume at %gms TTL = %g mls', obj.rewardTime, (obj.rewardVolume*obj.rewardTime)*hitn);
			set(obj.h.info,'String', t')
			
			obj.tick = obj.tick + 1;
			drawnow;
			
		end
		
		% ===================================================================
		%> @brief 
		%> 
		%> 
		% ===================================================================
		function plotPerformance(obj)
			createPlot(obj);
			updatePlot(obj);
		end
		
		% ===================================================================
		%> @brief 
		%> 
		%> 
		% ===================================================================
		function clearHandles(obj)
			obj.h = [];
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
			in.clearHandles();
			lobj = in;
		end
	end
	
	%=======================================================================
	methods ( Access = protected ) %-------PRIVATE (protected) METHODS-----%
	%=======================================================================
	
	end
end