classdef ( Hidden, Sealed ) EventSource < handle
    %uix.EventSource  Event source
    %
    %  s = uix.EventSource.getInstance(o) gets the event source
    %  corresponding to the handle o.
    %
    %  In R2013b, events ObjectChildAdded and ObjectChildRemoved should be
    %  observed on the event source rather than on the object itself due to
    %  a bug whereby, when reparenting, the event ObjectChildRemoved is
    %  raised on the wrong object.
    
    %  Copyright 2009-2013 The MathWorks, Inc.
    %  $Revision: 887 $ $Date: 2013-11-26 10:53:41 +0000 (Tue, 26 Nov 2013) $
    
    properties( Access = private )
        Listeners = event.listener.empty( [0 1] ) % listeners
    end
    
    events( NotifyAccess = private )
        ObjectChildAdded % child added
        ObjectChildRemoved % child removed
    end
    
    methods( Access = private )
        
        function obj = EventSource( object )
            %uix.EventSource  Event source
            %
            %  See also: uix.EventSource/getInstance
            
            % Check input
            assert( isa( object, 'handle' ) && ...
                isequal( size( object ), [1 1] ) && isvalid( object ), ...
                'uix:InvalidArgument', 'Invalid object.' )
            
            % Create listeners
            childAddedListener = event.listener( object, ...
                'ObjectChildAdded', @obj.onObjectChildAdded );
            childAddedListener.Recursive = true;
            childRemovedListener = event.listener( object, ...
                'ObjectChildRemoved', @obj.onObjectChildRemoved );
            childRemovedListener.Recursive = true;
            
            % Store properties
            obj.Listeners = [childAddedListener; childRemovedListener];
            
        end % constructor
        
    end % structors
    
    methods( Static )
        
        function obj = getInstance( object )
            %getInstance  Get event source from object
            %
            %  s = uix.EventSource.getInstance(o) gets the event source for
            %  the object o.
            
            if isprop( object, 'EventSource' ) % exists, retrieve
                obj = object.EventSource;
            else % does not exist, create and store
                obj = uix.EventSource( object );
                p = addprop( object, 'EventSource' );
                p.Hidden = true;
                object.EventSource = obj;
            end
            
        end % getInstance
        
    end % static methods
    
    methods( Access = private )
        
        function onObjectChildAdded( obj, ~, eventData )
            %onObjectChildAdded  Event handler for 'ObjectChildAdded'
            
            % Raise event
            child = eventData.Child;
            notify( obj, 'ObjectChildAdded', uix.ChildEvent( child ) )
            
        end % onObjectChildAdded
        
        function onObjectChildRemoved( obj, source, eventData )
            %onObjectChildRemoved  Event handler for 'ObjectChildRemoved'
            
            child = eventData.Child;
            if ismember( child, hgGetTrueChildren( source ) ) % event correct
                % Raise event
                notify( obj, 'ObjectChildRemoved', uix.ChildEvent( child ) )
            else % event incorrect
                % Warn
                warning( 'uix:InvalidState', ...
                    'Incorrect source for event ''ObjectChildRemoved''.' )
                % Raise event
                parent = hgGetTrueParent( child );
                parentEventSource = uix.EventSource.getInstance( parent );
                notify( parentEventSource, 'ObjectChildRemoved', uix.ChildEvent( child ) )
            end
            
        end % onObjectChildRemoved
        
    end % event handlers
    
end % classdef

function o = hgGetTrueParent( c )
%hgGetTrueParent  Get the parent of a graphics object
%
%  p = hgGetTrueParent(c) returns the parent p of an object c.
%
%  hgGetTrueParent returns the true parent in the internal tree, which may
%  differ from the value returned by the property Parent.
%
%  See also: hgGetTrueChildren

o = nGetParent( c.Parent ); % search from the Parent down
if ~isempty( o ), return, end % return if we are done
o = nGetParent( groot() ); % search the entire tree

    function p = nGetParent( n )
        %nGetParent  Get parent
        %
        %  p = nGetParent(n) returns the parent p of an object c (defined
        %  in the outer function), beginning the search from the object n.
        %
        %  nGetParent iterates over the descendants of n, looking for c.
        %  If c is not under n then p = [].
        
        k = hgGetTrueChildren( n ); % get the children
        for ii = 1:numel( k ) % loop over the children
            if k(ii) == c % if this child matches the object
                p = n;
                return % then we are done
            else % otherwise
                p = nGetParent( k(ii) ); % continue searching below this child
                if ~isempty( p ) % if a parent is found
                    return % then we are done
                end
            end
        end
        p = gobjects( [0 0] ); % unsuccessful
        
    end % nGetParent

end % hgGetTrueParent