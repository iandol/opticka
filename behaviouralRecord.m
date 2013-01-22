% ========================================================================
%> @brief optickaCore base class inherited by many other opticka classes.
%> optickaCore is itself derived from handle
% ========================================================================
classdef behaviouralRecord < optickaCore
	
	%--------------------PUBLIC PROPERTIES----------%
	properties
		%> verbosity
		verbose = true
		h = []
		values = []
		rt = []
	end
	
	%--------------------PRIVATE PROPERTIES----------%
	properties (SetAccess = private, GetAccess = private)
		radius
		time
		inittime
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
		
		function createPlot(obj, eL)
			t = {'INFORMATION:'};
			t{end+1} = ' ';
			t{end+1} = ['RADIUS = ' num2str(eL.fixationRadius)];
			t{end+1} = ' ';
			t{end+1} = ['TIME = ' num2str(eL.fixationTime)];
			t{end+1} = ' ';
			t{end+1} = ['INIT TIME = ' num2str(eL.fixationInitTime)];
			
			obj.h.root = figure('NumberTitle', 'off', 'Toolbar', 'none','Menubar','none');
			obj.h.panel = uiextras.BoxPanel('Parent',obj.h.root,...
				'Title',obj.fullName,...
				'TitleColor',[0.8 0.79 0.78],...
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
			obj.h.axis1 = axes('Parent', obj.h.hbox,'Units','pixels');
			obj.h.axis2 = axes('Parent', obj.h.hbox,'Units','pixels');
			axis([obj.h.axis1 obj.h.axis2], 'square');
			figpos([],[900 900]);
			set(obj.h.vbox,'Sizes',[-3 -1])
			set(obj.h.hbox,'Sizes',[-2 -1])
			obj.values = [];
			obj.rt = [];
			plot(obj.h.axis1, 1, 0,'ko');
			hist(obj.h.axis2, 0, 0:0.1:2);
			axis(obj.h.axis2, 'tight');
			xlabel(obj.h.axis1, 'Run Number')
			xlabel(obj.h.axis2, 'Time')
			ylabel(obj.h.axis1, 'Yes / No')
			ylabel(obj.h.axis2, 'Number #')
			title(obj.h.axis1,'Success (1) / Fail (0)')
			title(obj.h.axis2,'Response Times')
			ylim(obj.h.axis1,[-0.5 1.5])
			hn = findobj(obj.h.axis2,'Type','patch');
			set(hn,'FaceColor','k','EdgeColor','w');
		end
		
		function updatePlot(obj, eL, sM)
			tic
			t = {'INFORMATION:'};
			t{end+1} = ' ';
			t{end+1} = ['RADIUS (red) = ' num2str(eL.fixationRadius) ' °'];
			t{end+1} = ' ';
			t{end+1} = ['MAINTAIN FIXATION TIME (green) = ' num2str(eL.fixationTime) ' secs'];
			t{end+1} = ' ';
			t{end+1} = ['INITIATE FIXATION TIME (blue) = ' num2str(eL.fixationInitTime) ' secs'];
			t{end+1} = ' ';
			t{end+1} = ['Last Total Response Time = ' num2str(eL.fixTotal) ' secs'];
			set(obj.h.info,'String', t')
			if strcmpi(sM.currentName,'correct')
				obj.values(end+1) = 1;
				if eL.fixTotal > 0
					obj.rt(end+1) = eL.fixTotal;
				end
			elseif strcmpi(sM.currentName,'breakfix')
				obj.values(end+1) = 0;
			end
			obj.radius(end+1) = eL.fixationRadius;
			obj.time(end+1) = eL.fixationTime;
			obj.inittime(end+1) = eL.fixationInitTime;
			if length(obj.values) > 1; hold(obj.h.axis1,'on'); end
			plot(obj.h.axis1, 1:length(obj.values), obj.values,'k.-','MarkerSize',12);
			plot(obj.h.axis1, 1:length(obj.values), obj.radius,'rd','MarkerSize',10);
			plot(obj.h.axis1, 1:length(obj.values), obj.time,'gd','MarkerSize',10);
			plot(obj.h.axis1, 1:length(obj.values), obj.inittime,'bd','MarkerSize',10);
			legend(obj.h.axis1,'yes/no','radius','fixTime','initTime');
			hold(obj.h.axis1,'off')
			hist(obj.h.axis2, obj.rt, 0:0.1:2);
			axis(obj.h.axis2, 'tight');
			xlabel(obj.h.axis1, 'Run Number')
			xlabel(obj.h.axis2, 'Time')
			ylabel(obj.h.axis1, 'Yes / No')
			ylabel(obj.h.axis2, 'Number #')
			title(obj.h.axis1,'Success (1) / Fail (0)')
			title(obj.h.axis2,'Response Times')
			ylim(obj.h.axis1,[-0.1 1.6])
			hn = findobj(obj.h.axis2,'Type','patch');
			set(hn,'FaceColor','k','EdgeColor','k');
			fprintf('Time to draw graph: %g ms\n',toc*1000)
		end
		
	end
	
	%=======================================================================
	methods ( Access = protected ) %-------PRIVATE (protected) METHODS-----%
	%=======================================================================
	
	end
end