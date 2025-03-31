% zmq.core.recv - Receive a message part from a socket.
%
% Usage: message = zmq.core.recv(socket)
%        message = zmq.core.recv(socket, bufferLength)
%        message = zmq.core.recv(socket, option1, option2, ...)
%        message = zmq.core.recv(socket, bufferLength, option1, option2, ...)
%        [msg, len] = zmq.core.recv(socket)
%
% Input: socket - Instantiated ZMQ socket handle (see zmq.core.socket).
%        bufferLength - Size in bytes of buffer pre-allocated to receive message.
%                       This parameter is optional with default value of 255.
%        options - List of strings containing the options' names for reception.
%
% Output: uint8 array containing binary data received. If a second output is required,
%         the length of the message will be provided.
%
% An application that processes multi-part messages must check the 'ZMQ_RCVMORE'
% option with `zmq.core.getsockopt` after calling `zmq.core.recv` to determine if there
% are further parts to receive.
%
% The following options are considered valid:
%
% * ZMQ_DONTWAIT
%       Specifies that the operation should be performed in non-blocking mode.
%       If there are no messages available on the specified socket, the
%       zmq.core.recv() function shall fail with zmq:core:recv:EAGAIN error code.
%
%
% NOTICE
%  - The message received should be a uint8 row vector. Please consider using
%    `char`, `cast` and `typecast` functions before using it. Make sure to know
%    what is the transmitter encoding when receiveing strings, so you can use
%    conversions if they're neeeded, for example:
%      `unicode2native(str, 'UTF-8')` or
%      `feature('DefaultCharacterSet', 'UTF-8')`.
%  - If the pre-allocated buffer is shorter than the message received, the returned
%    vector will be truncated and a `zmq:core:recv:bufferTooSmall` warning will be thrown.
%
% EXAMPLE
%     feature('DefaultCharacterSet', 'UTF-8');
%     try
%       message1 = zmq.core.recv(socket, 100, 'ZMQ_DONTWAIT');
%       % maximum size of message1: 100 bytes
%       fprintf('Received message1: %s\n', char(message1));
%       message2 = zmq.core.recv(socket, 'ZMQ_DONTWAIT');
%       % maximum size of message2: 255 bytes
%       fprintf('Received message2: %s\n', char(message2));
%     catch e
%       if strcmp(e.identifier, 'zmq:core:recv:EAGAIN')
%         fprintf('No message available.\n');
%       else
%         rethrow(e);
%       end
%     end
%     message3 = zmq.core.recv(socket); % this will block MATLAB until receive a message
%     % maximum size of message3: 255 bytes
%     fprintf('Received message3: %s\n', char(message3));
%
% Please refer to http://api.zeromq.org/4-0:zmq-recv for further information.
%
