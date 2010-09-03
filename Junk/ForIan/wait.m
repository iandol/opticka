function wait( duration )
% WAIT waits for a specified duration
%
% Description:
%     Wait for a specified duration (milliseconds)
%
% Usage:
%     WAIT( duration )
%
% Arguments:
%     duration - time in milliseconds to wait
%
% Examples:
%     WAIT( 1000 ) - wait for 1000 milliseconds
%
% See also:
%     TIME, WAIT, WAITUNTIL, START_COGENT
%
% Cogent 2000 function.

t=time+duration;
while( time < t )
end
