classdef ButtonGroup < handle
    %ButtonGroup Abstract parent for HButtonGroup and VButtonGroup
    %
    % As an abstract class ButtonGroup can not be directly instantiated. It
    % requires the GUI Layout Toolbox by Ben Tordoff and David Sampson
    % available at:
    % http://www.mathworks.com/matlabcentral/fileexchange/27758-gui-layout-toolbox
    %
    % The uiextras.ButtonGroup should be placed in the +uiextras folder in
    % the GUI Layout Toolbox or in another folder called +uiextras that
    % resides under a folder on your path. It is recommended to run rehash
    % path after doing this.
    % 
    % See also uiextras.HButtonGroup, uiextras.VButtonGroup,
    % uiextras.HButtonBox, uiextras.VButtonBox
    
    % Copyright 2010-2011 Matt Whitaker
    
    properties 
        SelectionChangeFcn = [];    %Callback executed when control slection is changed.
    end  %properties
    
    properties(Dependent, Transient)
        ButtonStyle;    %Control style - {'Radio'}|'Toggle' 
        SelectedChild;  %Index of the currently slected child
        Buttons;           %List of button label strings- may be a cell array of strings or an mxn string array where each row is a label
    end %properties
    
    properties (Dependent, Transient, SetAccess = protected)
        SelectedObject;  %HG handle of the currently selected object.
    end 
    
    properties (Access = protected, Hidden = true)
        ButtonStyle_ = 'Radio';
        SelectedChild_ = [];
        GroupHandles = []; %handles of mutually exclusive uicontrols controlled by object
    end 
    
    methods 
        function obj = ButtonGroup(varargin)
            % BUTTONGROUP Creates a mutually exclusive button group.
        end %
    end %methods
   
    methods
        function val = get.ButtonStyle(obj)
            val = obj.ButtonStyle_;
        end %get.ButtonStyle
        
        function set.ButtonStyle(obj,val)
            if ~ischar( val ) || ~ismember( lower( val ), {'radio','toggle'} )
                error( 'GUILayout:ButtonGroup:InvalidPropertyValue', ...
                    'Property ''ButtonStyle'' must be ''radio'' or ''toggle''.' );
            end
            if ~isempty(obj.GroupHandles)
                set(obj.GroupHandles,'Style',val);
            end %if                
            obj.ButtonStyle_ = [upper( val(1) ),lower( val(2:end) )];
            eventData = struct( ...
                'Property', 'ButtonStyle', ...
                'Value', obj.ButtonStyle );
            obj.onButtonStyleChanged(obj,eventData);
        end %setButtonStyle   
        
        function val = get.SelectedChild(obj)
            val = obj.SelectedChild_;
        end %getSelectedChild
        
        function set.SelectedChild(obj,val)
            %handle empty being passed
            if isempty(val)  
                if ~isempty(obj.GroupHandles)
                    set(obj.GroupHandles,'Value',0,'Enable','on');
                end%if
                if ~isempty(obj.SelectedChild)
                    obj.SelectedChild_ = [];
                end %if
                return;
            end %if
            validateattributes(val,{'numeric'},{'scalar','integer','positive'},'uiextras.HButtonGroup','SelectedChild');
            %do we have enough children
            numChild = numel(obj.GroupHandles);
            if val > numChild;
                error('uiextras:ButtonGroup:InvalidSelectedChild',...
                    'The selected child value %d exceeds the number of controlled children: %d',...
                    val,numChild);
            end %if
            
            groupIdx = 1:numChild;
            if ~isempty(groupIdx)
                groupIdx(val) = [];
                if ~isempty(groupIdx)
                    set(obj.GroupHandles(groupIdx),'Value',0,'Enable','on');
                end %if
                set(obj.GroupHandles(val),'Value',1,'Enable','inactive');
                obj.SelectedChild_ = val;
            end %if
        end %setSelectedChild    
        
        function val = get.Buttons(obj)
            if isempty(obj.GroupHandles)
                val = {};
                return;
            end %if
            
            val = get(obj.GroupHandles,'String');
            
        end %getButtons  
        
        function set.Buttons(obj,val)
            if ~ischar(val) && ~iscellstr(val) && ~isstruct(val)
                error('uiextras:HButtonGroup:InvalidButtonValue','Buttons property must be passed a character array or a cell array of strings.');                
            end %if
            if ischar(val)
                v = val;
                val = {};
                for n = 1:size(v,1)
                    val{n}  = v(n,:);
                end %for
            end %if
            if ~isempty(obj.GroupHandles)
                delete(obj.GroupHandles(ishandle(obj.GroupHandles)));
            end %if
            for n = 1:numel(val)
                uicontrol('Style',obj.ButtonStyle,...
                    'Parent',obj,...
                    'String',val{n});
            end %for
        end %
        
        function val = get.SelectedObject(obj)
            if isempty(obj.SelectedChild) || isempty(obj.GroupHandles)
                val = [];
                return;
            end %if
            
            val = obj.GroupHandles(obj.SelectedChild);
        end %getSelectedObject       
       
    end %methods
    
    methods ( Abstract = true, Access = protected , Hidden = true)
        onButtonStyleChanged( obj, source, eventData );
    end % abstract protected methods    
    
%% Protected Methods    
    methods (Access = protected, Hidden = true)
        function onButtonPress(obj,src,evt,idx) %#ok
            % Call the user defined callback in SelectionChangeFcn
            % event field names to be consistent with uibuttongroup
            evt = struct( ...
                'Source', obj, ...
                'EventName','SelectionChanged',...                
                'OldValue', obj.SelectedChild, ...
                'NewValue', idx );
            obj.SelectedChild = idx;
            uiextras.callCallback( obj.SelectionChangeFcn, obj, evt );            

        end %onButtonPress
    end %protectedMethods   
        
end %ButtonGroup