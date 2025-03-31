% zmq.core.ctx_get - Mex function for interacting with ZMQ Contexts.
%
% Usage: output = zmq.core.ctx_get(context, option_name)
%
% Input: context - Instantiated ZMQ context handle (see zmq.core.ctx_new).
%        option_name - Option string. Must be one of the following:
%                      * ZMQ_IO_THREADS - Number of I/O threads in context thread pool.
%                      * ZMQ_MAX_SOCKETS - Maximum number of sockets allowed on context.
%                      * ZMQ_IPV6 - IPv6 option.
%
% Output: output - Depending on the option_string, output will be either numeric
%                  (ZMQ_IO_THREADS and ZMQ_MAX_SOCKETS) or boolean (ZMQ_IPV6).
