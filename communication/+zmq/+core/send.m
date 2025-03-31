% zmq.core.send - Send a message part on a socket.
%
% Usage: msgLen = zmq.core.send(socket, message)
%        msgLen = zmq.core.send(socket, message)
%        msgLen = zmq.core.send(socket, message, option1, ...)
%        msgLen = zmq.core.send(socket, message, option1, option2, ...)
%
% Input: socket   - Instantiated ZMQ socket handle (see zmq.core.socket).
%        message  - uint8 array containing binary data to be queued for transmission
%        options  - List of strings containing the options' names for transmission.
% Output:  number of bytes in the message if successful, otherwise -1.
%
% If the message cannot be queued on the socket, the zmq.core.send() function shall
% fail with zmq:core:send:EAGAIN error code.
%
% The following options are considered valid:
%
% * ZMQ_DONTWAIT
%       For socket types (DEALER, PUSH) that block when there are no available peers
%       (or all peers have full high-water mark), specifies that the operation should
%       be performed in non-blocking mode.
% * ZMQ_SNDMORE
%       Specifies that the message being sent is a multi-part message, and that
%       further message parts are to follow.
%
%
% NOTICE
%  - A successful invocation of zmq.core.send() does not indicate that the message
%    has been transmitted to the network, only that it has been queued on the
%    socket and ZMQ has assumed responsibility for the message.
%  - The message to be sent should be a uint8 row vector. It's recommended that
%    you use functions like `uint8`, `cast` and `typecast` before send it. When
%    sending scripts, it's also recommended that you ensure the use of UTF-8 encoding.
%    You can do by this using, for example:
%      `native2unicode(str, 'UTF-8')` or
%      `feature('DefaultCharacterSet', 'UTF-8')`.
%  - Consider splitting long messages in shorter parts by using 'ZMQ_SNDMORE' option
%    to avoid truncating them, due to the buffer length set in the receiver.
%
% EXAMPLE
%     feature('DefaultCharacterSet', 'UTF-8');
%     % Send a multi-part message consisting of three parts to socket
%     rc = zmq.core.send(socket, uint8('ABC'), 'ZMQ_SNDMORE');
%     assert(rc == 3);
%     rc = zmq.core.send(socket, uint8('DEFGH'), 'ZMQ_SNDMORE');
%     assert(rc == 5);
%     % Final part; no more parts to follow
%     rc = zmq.core.send(socket, uint8('IJ'));
%     assert (rc == 2);
%
% Please refer to http://api.zeromq.org/4-0:zmq-send for further information.
%
