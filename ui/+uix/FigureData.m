classdef ( Hidden, Sealed ) FigureData < event.EventData
    %uix.FigureData  Event data for FigureChanged on uix.FigureObserver
    
    %  Copyright 2014 The MathWorks, Inc.
    %  $Revision: 115 $ $Date: 2015-07-29 05:03:09 +0100 (Wed, 29 Jul 2015) $
    
    properties( SetAccess = private )
        OldFigure % old figure
        NewFigure % new figure
    end
    
    methods( Access = ?uix.FigureObserver )
        
        function obj = FigureData( oldFigure, newFigure )
            %uix.FigureData  Create event data
            %
            %  d = uix.FigureData(oldFigure,newFigure)
            
            obj.OldFigure = oldFigure;
            obj.NewFigure = newFigure;
            
        end % constructor
        
    end % methods
    
end % classdef