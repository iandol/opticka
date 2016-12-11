classdef ScrollingPanel < uix.Container & uix.mixin.Panel
    %uix.ScrollingPanel  Scrolling panel
    %
    %  p = uix.ScrollingPanel(p1,v1,p2,v2,...) constructs a scrolling panel
    %  and sets parameter p1 to value v1, etc.
    %
    %  A scrolling panel is a standard container (uicontainer) that shows
    %  one its contents and hides the others.
    %
    %  See also: uix.Panel, uix.BoxPanel, uix.TabPanel, uicontainer
    
    %  Copyright 2009-2016 The MathWorks, Inc.
    %  $Revision: 1165 $ $Date: 2015-12-06 03:09:17 -0500 (Sun, 06 Dec 2015) $
    
    properties( Dependent )
        Heights % heights of contents, in pixels and/or weights
        VerticalOffsets % vertical offsets of contents, in pixels
        VerticalSteps % vertical slider steps, in pixels
        Widths % widths of contents, in pixels and/or weights
        HorizontalOffsets % horizontal offsets of contents, in pixels
        HorizontalSteps % horizontal slider steps, in pixels
    end
    
    properties( Access = protected )
        Heights_ = zeros( [0 1] ) % backing for Heights
        Widths_ = zeros( [0 1] ) % backing for Widths
        HorizontalSliders = matlab.ui.control.UIControl.empty( [0 1] ) % sliders
        VerticalSliders = matlab.ui.control.UIControl.empty( [0 1] ) % sliders
        BlankingPlates = matlab.ui.control.UIControl.empty( [0 1] ) % blanking plates
        HorizontalSteps_ = zeros( [0 1] ) % steps
        VerticalSteps_ = zeros( [0 1] ) % steps
    end
    
    properties( Constant, Access = protected )
        SliderSize = 20 % slider size, in pixels
        SliderStep = 10 % slider step, in pixels
    end
    
    methods
        
        function obj = ScrollingPanel( varargin )
            %uix.ScrollingPanel  Scrolling panel constructor
            %
            %  p = uix.ScrollingPanel() constructs a scrolling panel.
            %
            %  p = uix.ScrollingPanel(p1,v1,p2,v2,...) sets parameter p1 to
            %  value v1, etc.
            
            % Set properties
            if nargin > 0
                try
                    assert( rem( nargin, 2 ) == 0, 'uix:InvalidArgument', ...
                        'Parameters and values must be provided in pairs.' )
                    set( obj, varargin{:} )
                catch e
                    delete( obj )
                    e.throwAsCaller()
                end
            end
            
        end % constructor
        
    end % structors
    
    methods
        
        function value = get.Heights( obj )
            
            value = obj.Heights_;
            
        end % get.Heights
        
        function set.Heights( obj, value )
            
            % For those who can't tell a column from a row...
            if isrow( value )
                value = transpose( value );
            end
            
            % Check
            assert( isa( value, 'double' ), 'uix:InvalidPropertyValue', ...
                'Property ''Heights'' must be of type double.' )
            assert( all( isreal( value ) ) && ~any( isinf( value ) ) && ...
                ~any( isnan( value ) ), 'uix:InvalidPropertyValue', ...
                'Elements of property ''Heights'' must be real and finite.' )
            assert( isequal( size( value ), size( obj.Contents_ ) ), ...
                'uix:InvalidPropertyValue', ...
                'Size of property ''Heights'' must match size of contents.' )
            
            % Set
            obj.Heights_ = value;
            
            % Mark as dirty
            obj.Dirty = true;
            
        end % set.Heights
        
        function value = get.VerticalOffsets( obj )
            
            sliders = obj.VerticalSliders;
            if isempty( sliders )
                value = zeros( size( sliders ) );
            else
                value = -vertcat( sliders.Value ) - 1;
                value(value<0) = 0;
            end
            
        end % get.VerticalOffsets
        
        function set.VerticalOffsets( obj, value )
            
            % Check
            assert( isa( value, 'double' ), 'uix:InvalidPropertyValue', ...
                'Property ''VerticalOffsets'' must be of type double.' )
            assert( all( isreal( value ) ) && ~any( isinf( value ) ) && ...
                ~any( isnan( value ) ), 'uix:InvalidPropertyValue', ...
                'Elements of property ''VerticalOffsets'' must be real and finite.' )
            assert( isequal( size( value ), size( obj.Contents_ ) ), ...
                'uix:InvalidPropertyValue', ...
                'Size of property ''VerticalOffsets'' must match size of contents.' )
            
            % Set
            sliders = obj.VerticalSliders;
            heights = obj.Heights_;
            for ii = 1:numel( sliders )
                if heights(ii) > 0
                    sliders(ii).Value = -value(ii) - 1;
                end
            end
            
            % Mark as dirty
            obj.Dirty = true;
            
        end % set.VerticalOffsets
        
        function value = get.VerticalSteps( obj )
            
            value = obj.VerticalSteps_;
            
        end % get.VerticalSteps
        
        function set.VerticalSteps( obj, value )
            
            % For those who can't tell a column from a row...
            if isrow( value )
                value = transpose( value );
            end
            
            % Check
            assert( isa( value, 'double' ), 'uix:InvalidPropertyValue', ...
                'Property ''VerticalSteps'' must be of type double.' )
            assert( all( isreal( value ) ) && ~any( isinf( value ) ) && ...
                ~any( isnan( value ) ) && all( value > 0 ), ...
                'uix:InvalidPropertyValue', ...
                'Elements of property ''VerticalSteps'' must be real, finite and positive.' )
            assert( isequal( size( value ), size( obj.Contents_ ) ), ...
                'uix:InvalidPropertyValue', ...
                'Size of property ''VerticalSteps'' must match size of contents.' )
            
            % Set
            obj.VerticalSteps_ = value;
            
            % Mark as dirty
            obj.Dirty = true;
            
        end % set.VerticalSteps
        
        function value = get.Widths( obj )
            
            value = obj.Widths_;
            
        end % get.Widths
        
        function set.Widths( obj, value )
            
            % For those who can't tell a column from a row...
            if isrow( value )
                value = transpose( value );
            end
            
            % Check
            assert( isa( value, 'double' ), 'uix:InvalidPropertyValue', ...
                'Property ''Widths'' must be of type double.' )
            assert( all( isreal( value ) ) && ~any( isinf( value ) ) && ...
                ~any( isnan( value ) ), 'uix:InvalidPropertyValue', ...
                'Elements of property ''Widths'' must be real and finite.' )
            assert( isequal( size( value ), size( obj.Contents_ ) ), ...
                'uix:InvalidPropertyValue', ...
                'Size of property ''Widths'' must match size of contents.' )
            
            % Set
            obj.Widths_ = value;
            
            % Mark as dirty
            obj.Dirty = true;
            
        end % set.Widths
        
        function value = get.HorizontalOffsets( obj )
            
            sliders = obj.HorizontalSliders;
            if isempty( sliders )
                value = zeros( size( sliders ) );
            else
                value = vertcat( sliders.Value );
                value(value<0) = 0;
            end
            
        end % get.HorizontalOffsets
        
        function set.HorizontalOffsets( obj, value )
            
            % Check
            assert( isa( value, 'double' ), 'uix:InvalidPropertyValue', ...
                'Property ''HorizontalOffsets'' must be of type double.' )
            assert( all( isreal( value ) ) && ~any( isinf( value ) ) && ...
                ~any( isnan( value ) ), 'uix:InvalidPropertyValue', ...
                'Elements of property ''HorizontalOffsets'' must be real and finite.' )
            assert( isequal( size( value ), size( obj.Contents_ ) ), ...
                'uix:InvalidPropertyValue', ...
                'Size of property ''HorizontalOffsets'' must match size of contents.' )
            
            % Set
            sliders = obj.HorizontalSliders;
            widths = obj.Widths_;
            for ii = 1:numel( sliders )
                if widths(ii) > 0
                    sliders(ii).Value = value(ii);
                end
            end
            
            % Mark as dirty
            obj.Dirty = true;
            
        end % set.HorizontalOffsets
        
        function value = get.HorizontalSteps( obj )
            
            value = obj.HorizontalSteps_;
            
        end % get.HorizontalSteps
        
        function set.HorizontalSteps( obj, value )
            
            % For those who can't tell a column from a row...
            if isrow( value )
                value = transpose( value );
            end
            
            % Check
            assert( isa( value, 'double' ), 'uix:InvalidPropertyValue', ...
                'Property ''HorizontalSteps'' must be of type double.' )
            assert( all( isreal( value ) ) && ~any( isinf( value ) ) && ...
                ~any( isnan( value ) ) && all( value > 0 ), ...
                'uix:InvalidPropertyValue', ...
                'Elements of property ''HorizontalSteps'' must be real, finite and positive.' )
            assert( isequal( size( value ), size( obj.Contents_ ) ), ...
                'uix:InvalidPropertyValue', ...
                'Size of property ''HorizontalSteps'' must match size of contents.' )
            
            % Set
            obj.HorizontalSteps_ = value;
            
            % Mark as dirty
            obj.Dirty = true;
            
        end % set.HorizontalSteps
        
    end % accessors
    
    methods( Access = protected )
        
        function redraw( obj )
            %redraw  Redraw
            
            % Return if no contents
            selection = obj.Selection_;
            if selection == 0, return, end
            
            % Retrieve width and height of selected contents
            contentsWidth = obj.Widths_(selection);
            contentsHeight = obj.Heights_(selection);
            
            % Retrieve selected contents and corresponding decorations
            child = obj.Contents_(selection);
            vSlider = obj.VerticalSliders(selection);
            hSlider = obj.HorizontalSliders(selection);
            plate = obj.BlankingPlates(selection);
            
            % Compute dimensions
            bounds = hgconvertunits( ancestor( obj, 'figure' ), ...
                [0 0 1 1], 'normalized', 'pixels', obj );
            width = bounds(3);
            height = bounds(4);
            sliderSize = obj.SliderSize; % slider size
            vSliderWidth = sliderSize * (contentsHeight > height); % first pass
            hSliderHeight = sliderSize * (contentsWidth > width - vSliderWidth);
            vSliderWidth = sliderSize * (contentsHeight > height - hSliderHeight); % second pass
            vSliderWidth = min( vSliderWidth, width ); % limit
            hSliderHeight = min( hSliderHeight, height ); % limit
            vSliderHeight = height - hSliderHeight;
            hSliderWidth = width - vSliderWidth;
            widths = uix.calcPixelSizes( width, [contentsWidth;vSliderWidth], [0;0], 0, 0 );
            contentsWidth = widths(1); % to be offset
            heights = uix.calcPixelSizes( height, [contentsHeight;hSliderHeight], [0;0], 0, 0 );
            contentsHeight = heights(1); % to be offset
            
            % Compute positions
            contentsPosition = [1 1+hSliderHeight+vSliderHeight-contentsHeight contentsWidth contentsHeight];
            vSliderPosition = [1+hSliderWidth 1+hSliderHeight vSliderWidth vSliderHeight];
            hSliderPosition = [1 1 hSliderWidth hSliderHeight];
            platePosition = [1+hSliderWidth 1 vSliderWidth hSliderHeight];
            
            % Compute and set vertical slider properties
            if vSliderWidth == 0 || vSliderHeight == 0 || vSliderHeight <= vSliderWidth
                % Slider is invisible or incorrectly oriented
                set( vSlider, 'Style', 'text', 'Enable', 'inactive', ...
                    'Position', vSliderPosition, ...
                    'Min', 0, 'Max', 1, 'Value', 1 )
            else
                % Compute properties
                vSliderMin = 0;
                vSliderMax = contentsHeight - vSliderHeight;
                vSliderValue = -vSlider.Value; % negative sign convention
                vSliderValue = max( vSliderValue, vSliderMin ); % limit
                vSliderValue = min( vSliderValue, vSliderMax ); % limit
                vStep = obj.VerticalSteps_(selection);
                vSliderStep(1) = min( vStep / vSliderMax, 1 );
                vSliderStep(2) = max( vSliderHeight / vSliderMax, vSliderStep(1) );
                contentsPosition(2) = contentsPosition(2) + vSliderValue;
                % Set properties
                set( vSlider, 'Style', 'slider', 'Enable', 'on', ...
                    'Position', vSliderPosition, ...
                    'Min', -vSliderMax, 'Max', -vSliderMin, ...
                    'Value', -vSliderValue, 'SliderStep', vSliderStep )
            end
            
            % Compute and set horizontal slider properties
            if hSliderHeight == 0 || hSliderWidth == 0 || hSliderWidth <= hSliderHeight
                % Slider is invisible or incorrectly oriented
                set( hSlider, 'Style', 'text', 'Enable', 'inactive', ...
                    'Position', hSliderPosition, ...
                    'Min', -1, 'Max', 0, 'Value', -1 )
            else
                % Compute properties
                hSliderMin = 0;
                hSliderMax = contentsWidth - hSliderWidth;
                hSliderValue = hSlider.Value; % positive sign convention
                hSliderValue = max( hSliderValue, hSliderMin ); % limit
                hSliderValue = min( hSliderValue, hSliderMax ); % limit
                hStep = obj.HorizontalSteps_(selection);
                hSliderStep(1) = min( hStep / hSliderMax, 1 );
                hSliderStep(2) = max( hSliderWidth / hSliderMax, hSliderStep(1) );
                contentsPosition(1) = contentsPosition(1) - hSliderValue;
                % Set properties
                set( hSlider, 'Style', 'slider', 'Enable', 'on', ...
                    'Position', hSliderPosition, ...
                    'Min', hSliderMin, 'Max', hSliderMax, ...
                    'Value', hSliderValue, 'SliderStep', hSliderStep )
            end
            
            % Set contents and blanking plate positions
            uix.setPosition( child, contentsPosition, 'pixels' )
            set( plate, 'Position', platePosition )
            
        end % redraw
        
        function addChild( obj, child )
            %addChild  Add child
            %
            %  c.addChild(d) adds the child d to the container c.
            
            % Add to sizes
            obj.Widths_(end+1,:) = -1;
            obj.Heights_(end+1,:) = -1;
            obj.VerticalSliders(end+1,:) = uicontrol( ...
                'Internal', true, 'Parent', obj, 'Units', 'pixels', ...
                'Style', 'slider', 'Callback', @obj.onSliderClicked );
            obj.HorizontalSliders(end+1,:) = uicontrol( ...
                'Internal', true, 'Parent', obj, 'Units', 'pixels', ...
                'Style', 'slider', 'Callback', @obj.onSliderClicked );
            obj.BlankingPlates(end+1,:) = uicontrol( ...
                'Internal', true, 'Parent', obj, 'Units', 'pixels', ...
                'Style', 'text', 'Enable', 'inactive' );
            obj.VerticalSteps_(end+1,:) = obj.SliderStep;
            obj.HorizontalSteps_(end+1,:) = obj.SliderStep;
            
            % Call superclass method
            addChild@uix.mixin.Panel( obj, child )
            
        end % addChild
        
        function removeChild( obj, child )
            %removeChild  Remove child
            %
            %  c.removeChild(d) removes the child d from the container c.
            
            % Remove from sizes
            tf = obj.Contents_ == child;
            obj.Widths_(tf,:) = [];
            obj.Heights_(tf,:) = [];
            obj.VerticalSliders(tf,:) = [];
            obj.HorizontalSliders(tf,:) = [];
            obj.BlankingPlates(tf,:) = [];
            obj.VerticalSteps_(tf,:) = [];
            obj.HorizontalSteps_(tf,:) = [];
            
            % Call superclass method
            removeChild@uix.mixin.Panel( obj, child )
            
        end % removeChild
        
        function reorder( obj, indices )
            %reorder  Reorder contents
            %
            %  c.reorder(i) reorders the container contents using indices
            %  i, c.Contents = c.Contents(i).
            
            % Reorder
            obj.Widths_ = obj.Widths_(indices,:);
            obj.Heights_ = obj.Heights_(indices,:);
            obj.VerticalSliders = obj.VerticalSliders(indices,:);
            obj.HorizontalSliders = obj.HorizontalSliders(indices,:);
            obj.BlankingPlates = obj.BlankingPlates(indices,:);
            obj.VerticalSteps_ = obj.VerticalSteps_(indices,:);
            obj.HorizontalSteps_ = obj.HorizontalSteps_(indices,:);
            
            % Call superclass method
            reorder@uix.mixin.Panel( obj, indices )
            
        end % reorder
        
        function showSelection( obj )
            %showSelection  Show selected child, hide the others
            %
            %  c.showSelection() shows the selected child of the container
            %  c, and hides the others.
            
            % Call superclass method
            showSelection@uix.mixin.Panel( obj )
            
            % Show and hide sliders based on selection
            selection = obj.Selection_;
            for ii = 1:numel( obj.Contents_ )
                if ii == selection
                    obj.VerticalSliders(ii).Visible = 'on';
                    obj.HorizontalSliders(ii).Visible = 'on';
                    obj.BlankingPlates(ii).Visible = 'on';
                else
                    obj.VerticalSliders(ii).Visible = 'off';
                    obj.HorizontalSliders(ii).Visible = 'off';
                    obj.BlankingPlates(ii).Visible = 'off';
                end
            end
            
        end % showSelection
        
    end % template methods
    
    methods( Access = private )
        
        function onSliderClicked( obj, ~, ~ )
            %onSliderClicked  Event handler
            
            % Mark as dirty
            obj.Dirty = true;
            
        end % onSliderClicked
        
    end % event handlers
    
end % classdef