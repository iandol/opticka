% zmq.core.ctx_new - Create a ZMQ socket
%
% Usage: socket = zmq.core.socket(context, type)
%
% Input: context - Instantiated ZMQ context handle (see zmq.core.ctx_new).
%        type    - type string of messaging pattern to be executed by this socket.
%                  Please refer to http://api.zeromq.org/master:zmq-socket for a
%                  complete description. Examples:7
%                  * ZMQ_REQ: used by a client to send requests to and receive replies from a service
%                  * ZMQ_REP: used by a service to receive requests from and send replies to a client
%                  * ZMQ_PUB: used by a publisher to distribute data. Messages sent are distributed
%                             in a fan out fashion to all connected peers.
%                  * ZMQ_SUB: used by a subscriber to subscribe to data distributed by a publisher.
%                             Initially a ZMQ_SUB socket is not subscribed to any messages,
%                             use the ZMQ_SUBSCRIBE option of zmq.core.setsockopt to specify which
%                             messages to subscribe to.
%
% Output: Handle to the newly created socket, unbound, and not associated with endpoints.
%         In order to establish a message flow a socket must first be connected to at least one
%         endpoint (see zmq.core.connect), or at least one endpoint must be created for accepting
%         incoming connections with (see zmq.core.bind).
