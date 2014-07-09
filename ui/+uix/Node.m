classdef( Hidden ) Node < dynamicprops
    %uix.Node  Node
    %
    %  n = uix.Node(o) creates a node for the handle o.
    
    %  Copyright 2009-2013 The MathWorks, Inc.
    %  $Revision: 887 $ $Date: 2013-11-26 10:53:41 +0000 (Tue, 26 Nov 2013) $
    
    properties( SetAccess = private )
        Object % object
        Children = uix.Node.empty( [0 1] ) % children
    end
    
    properties( Access = private )
        Listeners = event.listener.empty( [0 1] ) % external listeners
        ChildListeners = event.listener.empty( [0 1] ) % internal listeners
    end
    
    methods
        
        function obj = Node( object )
            %uix.Node  Node
            %
            %  n = uix.Node(o) creates a node for the handle o.
            
            % Check
            assert( isa( object, 'handle' ) && ...
                isequal( size( object ), [1 1] ) && isvalid( object ), ...
                'uix:InvalidArgument', 'Object must be a handle.' )
            
            % Set properties
            obj.Object = object;
            
        end % constructor
        
    end % structors
    
    methods
        
        function addChild( obj, child )
            %addChild  Add child
            %
            %  n.addChild(c) adds the child node c to the parent node n.
            
            % Check
            assert( isa( child, 'uix.Node' ) && ...
                isequal( size( child ), [1 1] ), ...
                'uix:InvalidArgument', 'Invalid node.' )
            
            % Add
            childListener = event.listener( child, ...
                'ObjectBeingDestroyed', @obj.onChildDeleted );
            obj.Children(end+1,:) = child;
            obj.ChildListeners(end+1,:) = childListener;
            
        end % add
        
        function removeChild( obj, child )
            %removeChild  Remove child
            %
            %  n.removeChild(c) removes the child node c from the parent
            %  node n.
            
            % Check
            assert( isa( child, 'uix.Node' ) && ...
                isequal( size( child ), [1 1] ), ...
                'uix:InvalidArgument', 'Invalid node.' )
            assert( ismember( child, obj.Children ), ...
                'uix:ItemNotFound', 'Node not found.' )
            
            % Remove
            tf = child == obj.Children;
            obj.Children(tf,:) = [];
            obj.ChildListeners(tf,:) = [];
            
        end % remove
        
        function addListener( obj, listener )
            %addListener  Add listener
            %
            %  n.addListener(l) adds the listener l to the node n.
            
            % Check
            assert( isa( listener, 'event.listener' ) && ...
                isequal( size( listener ), [1 1] ), ...
                'uix:InvalidArgument', 'Invalid listener.' )
            
            % Add
            obj.Listeners(end+1,:) = listener;
            
        end % addListener
        
    end % public methods
    
    methods( Access = private )
        
        function onChildDeleted( obj, source, ~ )
            %onChildDeleted  Event handler for deletion of child nodes
            
            % Remove
            obj.removeChild( source )
            
        end % onChildDeleted
        
    end % event handlers
    
end % classdef