function pvchk( pv )
%uix.pvchk  Check parameter value pairs
%
%  uix.pvcvk(pv) checks the cell array of parameter value pairs pv.  An
%  error is issued if:
%  * The number of parameters does not match the number of values
%  * Any parameter is not a string
%
%  This function is typically used from class constructors,
%  uix.pvchk(varargin).

%  Copyright 2009-2013 The MathWorks, Inc.
%  $Revision: 914 $ $Date: 2014-05-16 13:28:10 +0100 (Fri, 16 May 2014) $

ME = MException( 'uix:InvalidArgument', 'Invalid argument' );
if rem( numel( pv ), 2 ) ~= 0
    ME.throwAsCaller()
elseif ~all( cellfun( @ischar, pv(1:2:end) ) )
    ME.throwAsCaller()
end   
    
end % pvchk