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
			
			obj.h.root = figure;
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
			figpos([],[800 800])
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
			title(obj.h.axis2,'Reaction Times')
			ylim(obj.h.axis1,[-0.5 1.5])
			hn = findobj(obj.h.axis2,'Type','patch');
			set(hn,'FaceColor','k','EdgeColor','w');
		end
		
		function updatePlot(obj, eL, sM)
			t = {'INFORMATION:'};
			t{end+1} = ' ';
			t{end+1} = ['RADIUS = ' num2str(eL.fixationRadius)];
			t{end+1} = ' ';
			t{end+1} = ['TIME = ' num2str(eL.fixationTime)];
			t{end+1} = ' ';
			t{end+1} = ['INIT TIME = ' num2str(eL.fixationInitTime)];
			t{end+1} = ' ';
			t{end+1} = ['Reaction Time = ' num2str(eL.fixTotal)];
			set(obj.h.info,'String', t')
			if strcmpi(sM.currentName,'correct')
				obj.values(end+1) = 1;
				if eL.fixTotal > 0
					obj.rt(end+1) = eL.fixTotal;
				end
			elseif strcmpi(sM.currentName,'breakfix')
				obj.values(end+1) = 0;
			end
			plot(obj.h.axis1, 1:length(obj.values), obj.values,'ko');
			hist(obj.h.axis2, obj.rt, 0:0.1:2);
			axis(obj.h.axis2, 'tight');
			xlabel(obj.h.axis1, 'Run Number')
			xlabel(obj.h.axis2, 'Time')
			ylabel(obj.h.axis1, 'Yes / No')
			ylabel(obj.h.axis2, 'Number #')
			title(obj.h.axis1,'Success (1) / Fail (0)')
			title(obj.h.axis2,'Reaction Times')
			ylim(obj.h.axis1,[-0.5 1.5])
			hn = findobj(obj.h.axis2,'Type','patch');
			set(hn,'FaceColor','k','EdgeColor','w');
		end
		
	end
	
	%=======================================================================
	methods ( Access = protected ) %-------PRIVATE (protected) METHODS-----%
	%=======================================================================
	
	end
end