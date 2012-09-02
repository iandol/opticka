classdef MousePointerHandler < handle
    %MousePointerHandler  A class to handle mouse-over events
    %
    %   MousePointerHandler(fig) attaches the handler to the figure FIG
    %   so that it will intercept all mouse-over events. The handler is
    %   stored in the MousePointerHandler app-data of the figure so that
    %   functions can listen in for scroll-events.
    %
    %   Examples:
    %   >> f = figure();
    %   >> u = uicontrol();
    %   >> mph = uiextras.MousePointerHandler(f);
    %   >> mph.register( u, 'fleur' )
    %
    %   See also: uiextras.ScrollWheelEvent
    
    %   Copyright 2008-2010 The MathWorks Ltd.
    %   $Revision: 372 $   
    %   $Date: 2011-04-04 09:36:14 +0100 (Mon, 04 Apr 2011) $
    
    properties( SetAccess = private, GetAccess = public )
        CurrentObject
    end % read-only public properties
    
    properties( SetAccess = private , GetAccess = private )
        CurrentObjectPosition
        OldPointer
        Parent
        List
    end % private properties
    
    methods
        
        function obj = MousePointerHandler(fig)
            % Check that a mouse-pointer-handler is not already there
            if ~isa( fig, 'figure' )
                fig = ancestor( fig, 'figure' );
            end
            if isappdata(fig,'MousePointerHandler')
                obj = getappdata(fig,'MousePointerHandler');
            else
                set(fig,'WindowButtonMotionFcn', @obj.onMouseMoved);
                setappdata(fig,'MousePointerHandler',obj);
                obj.Parent = fig;
            end
        end % MousePointerHandler
        
        function register( obj, widget, pointer )
            % We need to be sure to remove the entry if it dies
            if isHGUsingMATLABClasses()
                % New style
                l = event.listener( widget, 'ObjectBeingDestroyed', @obj.onWidgetBeingDestroyedEvent );
            else
                % Old school
                l = handle.listener( widget, 'ObjectBeingDestroyed', @obj.onWidgetBeingDestroyedEvent );
            end
            entry = struct( ...
                'Widget', widget, ...
                'Pointer', pointer, ...
                'Listener', l );
            if isempty(obj.List)
                obj.List = entry;
            else
                obj.List(end+1,1) = entry;
            end
        end % register
        
    end % public methods
    
    methods( Access = private )
        
        function onMouseMoved( obj, src, evt ) %#ok<INUSD>
            if isempty( obj.List )
                return;
            end
            figh = obj.Parent;
            figUnits = get( figh, 'Units' );
            currpos = get( figh, 'CurrentPoint' );
            if ~strcmpi( figUnits, 'Pixels' )
                currpos = hgconvertunits( figh, [currpos,0,0], figUnits, 'pixels', 0 );
            end
            if ~isempty( obj.CurrentObjectPosition )
                cop = obj.CurrentObjectPosition;
                if currpos(1) >= cop(1) ...
                        && currpos(1) < cop(1)+cop(3) ...
                        && currpos(2) >= cop(2) ...
                        && currpos(2) < cop(2)+cop(4)
                    % Still inside, so do nothing
                    return;
                else
                    % Left the object
                    obj.leaveWidget()
                end
            end
            % OK, now scan the objects to see if we're inside
            for ii=1:numel(obj.List)
                % We need to be careful of widgets that aren't capable of
                % returning a PixelPosition
                try
                    widgetpos = getpixelposition( obj.List(ii).Widget, true );
                    if currpos(1) >= widgetpos(1) ...
                            && currpos(1) < widgetpos(1)+widgetpos(3) ...
                            && currpos(2) >= widgetpos(2) ...
                            && currpos(2) < widgetpos(2)+widgetpos(4)
                        % Inside
                        obj.enterWidget( obj.List(ii).Widget, widgetpos, obj.List(ii).Pointer )
                        break; % we don't need to carry on looking
                    end
                catch err %#ok<NASGU>
                    warning( 'MousePointerHandler:BadWidget', 'GETPIXELPOSITION failed for widget %d', ii )
                end
            end
            
        end % onMouseMoved
        
        function onWidgetBeingDestroyedEvent( obj, src,evt ) %#ok<INUSD>
            idx = cellfun( @isequal, {obj.List.Widget}, repmat( {double(src)}, 1,numel(obj.List) ) );
            obj.List(idx) = [];
            % Also take care if it's the active object
            if isequal( src, obj.CurrentObject )
                obj.leaveWidget()
            end
        end % onWidgetBeingDestroyedEvent
        
        function enterWidget( obj, widget, pixpos, pointer )
            % Mouse has moved onto a widget
            obj.CurrentObjectPosition = pixpos;
            obj.CurrentObject = widget;
            obj.OldPointer = get( obj.Parent, 'Pointer' );
            set( obj.Parent, 'Pointer', pointer );
            %fprintf( 'Enter widget ''%s''\n', get( widget, 'Tag' ) );
        end % enterWidget
        
        function leaveWidget( obj )
            % Mouse has moved off a widget
            %if ~isempty( obj.CurrentObject )
            %    fprintf( 'Leave widget ''%s''\n', get( obj.CurrentObject, 'Tag' ) );
            %end
            obj.CurrentObjectPosition = [];
            obj.CurrentObject = [];
            set( obj.Parent, 'Pointer', obj.OldPointer );
        end % leaveWidget
        
    end % private methods
    
end % classdef