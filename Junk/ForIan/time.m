function t=time
% TIME returns current time in milliseconds since START_COGENT called.
%
% Description:
%     Returns current time in milliseconds since START_COGENT called.
%
% Usage:
%     t = TIME
%
% Arguments:
%     t - time in milliseconds
%
% Examples:
%
% See also:
%     TIME, WAIT, WAITUNTIL, START_COGENT
%
% Cogent 2000 function.

%t = floor( cogstd('sGetTime',-1) / 1e3 ); % from J.R. 1v116 onwards time is returned as seconds not microseconds. 19-2-2002 e.f.
t = floor( cogstd('sGetTime',-1) * 1e3 );