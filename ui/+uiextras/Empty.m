function obj = Empty( varargin )
%uiextras.Empty  Create an empty space
%
%   obj = uiextras.Empty() creates a placeholder that can be used to add
%   gaps between elements in layouts.
%
%   obj = uiextras.Empty(param,value,...) also sets one or more property
%   values.
%
%   See the <a href="matlab:doc uiextras.Empty">documentation</a> for more detail and the list of properties.
%
%   Examples:
%   >> f = figure();
%   >> box = uiextras.HBox( 'Parent', f );
%   >> uicontrol( 'Parent', box, 'Background', 'r' )
%   >> uiextras.Empty( 'Parent', box )
%   >> uicontrol( 'Parent', box, 'Background', 'b' )

%   Copyright 2009-2013 The MathWorks, Inc.
%   $Revision: 919 $ $Date: 2014-06-03 11:05:38 +0100 (Tue, 03 Jun 2014) $

% Warn
% warning( 'uiextras:Deprecated', ...
%     'uiextras.Empty will be removed in a future release.' )

% Call uix constructor
obj = matlab.ui.control.UIControl( varargin{:}, 'Visible', 'off' );

end % uiextras.Empty