% ========================================================================
%> @brief Create and update behavioural record.
%> 
% ========================================================================
classdef behaviouralRecord < optickaCore
	
	%--------------------PUBLIC PROPERTIES----------%
	properties
		%> verbosity
		verbose = true
		h = []
		values = []
		rt = []
		date = []
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
			t{end+1} = ' ';
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
			figpos([],[900 900]);
			set(obj.h.vbox,'Sizes',[-3 -1])
			set(obj.h.hbox,'Sizes',[-2 -1])
			set(obj.h.vbox2,'Sizes',[-2 -1])
			set(obj.h.vbox3,'Sizes',[-2 -1])
			obj.values = [];
			obj.rt = [];

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
			if strcmpi(sM.currentName,'correct')
				obj.values(end+1) = 1;
				if eL.fixTotal > 0
					obj.rt(end+1) = eL.fixTotal;
				end
			elseif strcmpi(sM.currentName,'breakfix')
				obj.values(end+1) = 0;
			else
				obj.values(end+1) = 0;
			end
			
			hitn = sum(obj.values);
			totaln = length(obj.values);
			missn = totaln - hitn;
			
			hitmiss = 100 * (hitn / totaln);
			if length(obj.values) < 10
				average = 100 * (hitn / totaln);
			else
				average = 100 * (sum(obj.values(end-9:end)) / length(obj.values(end-9:end)));
			end
			obj.averages(end+1) = average;
			hits = [hitmiss 100-hitmiss; average 100-average];
			
			%axis 1
			obj.radius(end+1) = eL.fixationRadius;
			obj.time(end+1) = eL.fixationTime;
			obj.inittime(end+1) = eL.fixationInitTime;
			set(obj.h.axis1,'NextPlot','replacechildren')
			plot(obj.h.axis1, 1:length(obj.values), obj.values,'k.-','MarkerSize',12);
			set(obj.h.axis1,'NextPlot','add')
			plot(obj.h.axis1, 1:length(obj.values), obj.radius,'rd','MarkerSize',10);
			plot(obj.h.axis1, 1:length(obj.values), obj.inittime,'gd','MarkerSize',10);
			plot(obj.h.axis1, 1:length(obj.values), obj.time,'bd','MarkerSize',10);
			axis(obj.h.axis1, 'tight');
			%axis 2
			hist(obj.h.axis2, obj.rt, 0:0.2:2);
			axis(obj.h.axis2, 'tight');
			
			%axis 3
			bar(obj.h.axis3,hits,'stacked')
			set(obj.h.axis3,'XTickLabel', {'all';'newest'})
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
			title(obj.h.axis1,['Success (' num2str(hitn) ') / Fail (' num2str(missn) ')'])
			title(obj.h.axis2,['Response Times (mean: ' num2str(mean(obj.rt)) ')'])
			title(obj.h.axis3,'Hit (blue) / Miss (red)')
			title(obj.h.axis4,'Average (n=10) Hit / Miss %')
			hn = findobj(obj.h.axis2,'Type','patch');
			set(hn,'FaceColor','k','EdgeColor','k');
			
			t = {['INFORMATION @ ' obj.date]};
			t{end+1} = ' ';
			t{end+1} = ['RADIUS (red) b|n = ' num2str(eL.fixationRadius) ' °'];
			t{end+1} = ['INITIATE FIXATION TIME (green) z|x = ' num2str(eL.fixationInitTime) ' secs'];
			t{end+1} = ['MAINTAIN FIXATION TIME (blue) c|v = ' num2str(eL.fixationTime) ' secs'];
			t{end+1} = ' ';
			t{end+1} = ['Last Total Response Time = ' num2str(eL.fixTotal) ' secs'];
			t{end+1} = ['Overall | Latest (n=10) Hit Rate = ' num2str(hitmiss) ' | ' num2str(average)];
			t{end+1} = ['Run time = ' num2str(etime(clock,obj.startTime)/60) 'mins'];
			t{end+1} = ['Estimated Volume at 300ms TTL = ' num2str(0.22*sum(obj.values)) 'mls'];
			set(obj.h.info,'String', t')
			
			obj.tick = obj.tick + 1;
		end
		
	end
	
	%=======================================================================
	methods ( Access = protected ) %-------PRIVATE (protected) METHODS-----%
	%=======================================================================
	
	end
end