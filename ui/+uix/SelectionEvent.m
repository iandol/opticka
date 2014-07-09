classdef( Hidden, Sealed ) SelectionEvent < event.EventData
    %uix.SelectionEvent  Event data for selection event
    %
    %  e = uix.SelectionEvent(o,n) creates event data including the old
    %  value o and the new value n.
    
    %  Copyright 2009-2013 The MathWorks, Inc.
    %  $Revision: 887 $ $Date: 2013-11-26 10:53:41 +0000 (Tue, 26 Nov 2013) $
    
    properties( SetAccess = private )
        OldValue % old value
        NewValue % newValue
    end
    
    methods
        
        function obj = SelectionEvent( oldValue, newValue )
            %uix.SelectionEvent  Event data for selection event
            %
            %  e = uix.SelectionEvent(o,n) creates event data including the
            %  old value o and the new value n.
            
            % Set properties
            obj.OldValue = oldValue;
            obj.NewValue = newValue;
            
        end % constructor
        
    end % structors
    
end % classdef