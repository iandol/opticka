% zmq.core.disconnect - Disconnect a socket from a endpoint
%
% Usage: status = zmq.core.disconnect(socket, endpoint)
%
% Input: socket   - Instantiated ZMQ socket handle (see zmq.core.socket).
%        endpoint - String consisting of a 'transport://' followed by an 'address'.
%                   (see zmq.core.connect).
%
% Output: Zero if successful, otherwise -1.
%
