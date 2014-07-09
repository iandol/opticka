classdef Container < matlab.ui.container.internal.UIContainer & uix.mixin.Container
    
    methods
        
        function obj = Container( varargin )
            
            % Call superclass constructors
            obj@matlab.ui.container.internal.UIContainer()
            obj@uix.mixin.Container()
            
            % Set properties
            if nargin > 0
                uix.pvchk( varargin )
                set( obj, varargin{:} )
            end
            
        end % constructor
        
    end % structors
    
end % classdef