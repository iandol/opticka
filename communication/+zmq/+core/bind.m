% zmq.core.bind - Binds the socket to a local endpoint and then accepts incoming
%            connections on that endpoint.
%
% Usage: status = zmq.core.bind(socket, endpoint)
%
% Input: socket   - Instantiated ZMQ socket handle (see zmq.core.socket).
%        endpoint - String consisting of a 'transport://' followed by an 'address'.
%                   The transport specifies the underlying protocol to use.
%                   The address specifies the transport-specific address to bind to.
%
% ZMQ provides the the following transports:
%
% * tcp       - unicast transport using TCP
% * ipc       - local inter-process communication transport
% * inproc    - local in-process (inter-thread) communication transport
% * pgm, epgm - reliable multicast transport using PGM
%
% Please refer to http://api.zeromq.org/4-0:zmq-bind for further information.
%
% Output: Zero if successful, otherwise -1.
%
