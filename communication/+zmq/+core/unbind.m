% zmq.core.unbind - Stop accepting connections on a socket from a endpoint
%
% Usage: status = zmq.core.unbind(socket, endpoint)
%
% Input: socket   - Instantiated ZMQ socket handle (see zmq.core.socket).
%        endpoint - String consisting of a 'transport://' followed by an 'address'.
%                   (see zmq.core.bind).
%
% Output: Zero if successful, otherwise -1.
%
