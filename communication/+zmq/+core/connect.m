% zmq.core.bind - Create outgoing connection from socket on a endpoint.
%
% Usage: status = zmq.core.connect(socket, endpoint)
%
% Input: socket   - Instantiated ZMQ socket handle (see zmq.core.socket).
%        endpoint - String consisting of a 'transport://' followed by an 'address'.
%                   The 'transport' specifies the underlying protocol to use.
%                   The address specifies the transport-specific address to connect to.
%
% ZMQ provides the the following transports:
%
% * tcp       - unicast transport using TCP
% * ipc       - local inter-process communication transport
% * inproc    - local in-process (inter-thread) communication transport
% * pgm, epgm - reliable multicast transport using PGM
%
% Please refer to http://api.zeromq.org/4-0:zmq-connect for further information.
%
% Output: Zero if successful, otherwise -1.
%
