% zmq.core.poll - Poll ZMQ sockets for events
%
% Usage: [results, count] = zmq.core.poll(items, timeout)
%
% Input: items   - Structure array of poll items with fields:
%                  socket: ZMQ socket handle
%                  events: Bit mask of ZMQ_POLLIN and/or ZMQ_POLLOUT
%        timeout - Timeout in milliseconds. Use -1 for infinite wait,
%                 0 for immediate return.
%
% Output: results - Structure array with fields:
%                  socket: ZMQ socket handle
%                  revents: Bit mask of events that occurred
%         count   - Number of sockets with events (optional)
%
% Events: ZMQ_POLLIN  - At least one message can be received
%         ZMQ_POLLOUT - At least one message can be sent
%
% % Example usage:
% items(1).socket = socket1;
% items(1).events = bitor(ZMQ_POLLIN, ZMQ_POLLOUT);
% items(2).socket = socket2;
% items(2).events = ZMQ_POLLIN;%
% % Poll with 1000ms timeout
% [results, count] = zmq.core.poll(items, 1000);%
% % Check results
% for i = 1:length(results)
%     if bitand(results(i).revents, ZMQ_POLLIN)
%         % Socket is ready for reading
%     end
%     if bitand(results(i).revents, ZMQ_POLLOUT)
%         % Socket is ready for writing
%     end
% end