classdef Panel < matlab.ui.container.Panel & uix.mixin.Container
    
    methods
        
        function obj = Panel( varargin )
            
            % Call superclass constructors
            obj@matlab.ui.container.Panel()
            obj@uix.mixin.Container()
            
            % Set properties
            if nargin > 0
                uix.pvchk( varargin )
                set( obj, varargin{:} )
            end
            
        end % constructor
        
    end % structors
    
    methods( Access = protected )
        
        function redraw( obj )
            
            % Compute positions
            bounds = hgconvertunits( ancestor( obj, 'figure' ), ...
                [0 0 1 1], 'normalized', 'pixels', obj );
            padding = obj.Padding_;
            xSizes = uix.calcPixelSizes( bounds(3), -1, 1, padding, 0 );
            ySizes = uix.calcPixelSizes( bounds(4), -1, 1, padding, 0 );
            position = [padding+1 padding+1 xSizes ySizes];
            
            % Set positions and visibility
            children = obj.Contents_;
            selection = numel( children );
            for ii = 1:selection
                child = children(ii);
                if ii == selection
                    child.Visible = 'on';
                    child.Units = 'pixels';
                    if isa( child, 'matlab.graphics.axis.Axes' )
                        switch child.ActivePositionProperty
                            case 'position'
                                child.Position = position;
                            case 'outerposition'
                                child.OuterPosition = position;
                            otherwise
                                error( 'uix:InvalidState', ...
                                    'Unknown value ''%s'' for property ''ActivePositionProperty'' of %s.', ...
                                    child.ActivePositionProperty, class( child ) )
                        end
                        child.ContentsVisible = 'on';
                    else
                        child.Position = position;
                    end
                else
                    child.Visible = 'off';
                    if isa( child, 'matlab.graphics.axis.Axes' )
                        child.ContentsVisible = 'off';
                    end
                end
            end
            
        end % redraw
        
    end % template methods
    
end % classdef