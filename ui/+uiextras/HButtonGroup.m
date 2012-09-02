classdef HButtonGroup < uiextras.HButtonBox & uiextras.ButtonGroup
    %HButtonGroup Create container object to exclusively manage radio
    %buttons and toggle buttons in a horizontal row
    %
    % HButtonGroup requires the GUI Layout Toolbox by Ben Tordoff and David
    % Sampson available at:
    % http://www.mathworks.com/matlabcentral/fileexchange/27758-gui-layout-toolbox
    % and the uiextras.ButtonGroup file.
    %
    % The uiextras.HButtonGroup should be placed in the +uiextras folder in
    % the GUI Layout Toolbox or in another folder called +uiextras that
    % resides under a folder on your path. It is recommended to run rehash
    % path after doing this.    
    %
    %Example:
    %function buttonGroupExample
    %     f = figure;
    %     vb = uiextras.VBox('Parent',f);
    %     bgH = uiextras.HButtonGroup('Parent',vb,'Buttons',{'1','2','3'},'Spacing',50,'Padding',10,'SelectedChild',1,'SelectionChangeFcn',@onSelectionChange);
    %     hb = uiextras.HBox('Parent',vb);
    %     bgV = uiextras.VButtonGroup('Parent',hb,'Buttons',('123')','Spacing',20,'Padding',10,'SelectedChild',3,'SelectionChangeFcn',@onSelectionChange);
    %     p = uiextras.Panel('Parent',hb);
    %     set(hb,'Sizes',[100,-1]);
    %     lblDisplay = uicontrol('Parent',p,'FontSize',16,'Style','text');
    %     onSelectionChange([],[]);
    %     function onSelectionChange(src,evt)
    %         disp(evt);
    %         set(lblDisplay,'String',int2str([bgH.SelectedChild,bgV.SelectedChild]));
    %     end %onSelectionChange
    % end %buttonGroupExample
    %
    % See also uiextras.VButtonGroup
  
%% Constructor    
    methods
        function obj = HButtonGroup(varargin)
            obj = obj@uiextras.HButtonBox(varargin{:});
            obj= obj@uiextras.ButtonGroup(varargin{:});
            obj.redraw();
        end %HButtonGroup constructor
                
    end %methods
    
    methods (Access = protected, Hidden = true)
        function onButtonStyleChanged(obj,src,evt) %#ok
            obj.redraw();
        end %onButtonStyleChange
        
        function onChildAdded(obj,src,evt) %#ok
            if isa(evt.Child,'uicontrol') 
                if strmatch(lower(obj.ButtonStyle),lower(get(evt.Child,'Style')))
                    if ismember(double(evt.Child),obj.GroupHandles)
                        return;
                    end%if
                    obj.GroupHandles(end+1) = evt.Child;
                    set(evt.Child,'Callback',{@obj.onButtonPress,numel(obj.GroupHandles)});
                    if get(obj.GroupHandles(end),'Value')
                        if isempty(obj.SelectedChild)
                            %then set it as the currently selected
                            %this is a bit arbitrary but it is necessary to
                            %select one or the other.
                            obj.SelectedChild = numel(obj.GroupHandles);
                        else
                            %there can be only one!
                            set(obj.GroupHandles(end),'Value',0,'Enable','on');
                        end %if
                    end %if
                end %if
            end %if
            obj.redraw();
        end %onChildAdded
        
        function onChildRemoved(obj,src,evt) %#ok
            if isa(evt.Child,'uicontrol') 
                [inList,idx] = ismember(double(evt.Child),obj.GroupHandles);
                if inList
                    if obj.SelectedChild == idx
                        obj.SelectedChild_ = [];
                    end %if
                    obj.GroupHandles(idx) = [];
                    %re-index remaining buttons
                    for n = 1:numel(obj.GroupHandles)
                        set(obj.GroupHandles(n),'Callback',{@obj.onButtonPress,n});    
                        if get(obj.GroupHandles(n),'Value')
                            obj.SelectedChild_ = n;
                        end %if
                    end %for
                end %if                   
            end %if
            obj.redraw();            
        end %onChildRemoved
    end %protected methods
    
end %HButtonGroup