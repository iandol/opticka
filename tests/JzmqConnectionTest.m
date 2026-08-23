% ========================================================================
%> @class JzmqConnectionTest
%> @brief Class-based unit tests for jzmqConnection (ØMQ via JeroMQ).
%>
%> Tests construction/validation, endpoint generation, socket lifecycle
%> (bind/connect types, double-open guard, context ownership on close),
%> and real loopback communication for REQ/REP (JSON command roundtrips,
%> payload matrix), PUB/SUB, PUSH/PULL, raw send/receive, flush, polling,
%> socket options and inproc/ipc transports.
%>
%> Requires the matlab-jzmq toolbox (jzmq package + jeromq jar) which
%> addOptickaToPath picks up from a sibling folder of the opticka repo;
%> Java is bundled with MATLAB so no extra runtime install is needed.
%>
%> Run with:
%>   >> runtests('tests/JzmqConnectionTest.m')
% ========================================================================
classdef JzmqConnectionTest < matlab.unittest.TestCase

	properties
		%> every connection created by helpers, closed during teardown
		conns = {}
	end

	methods (TestClassSetup)
		function setupPath(testCase)
			%> Ensure Opticka + matlab-jzmq classes are on the MATLAB path.
			addOptickaToPath;
		end
	end

	methods (TestMethodTeardown)
		function closeConnections(testCase)
			%> Close any sockets left open by a test to free ports/contexts.
			for k = numel(testCase.conns):-1:1
				try testCase.conns{k}.close(false); catch; end %#ok<*CTCH>
			end
			testCase.conns = {};
		end
	end

	methods (Test, TestTags = {'CI'})
		function testConstructionDefaults(testCase)
			c = testCase.makeConn(jzmqConnection);

			verifyEqual(testCase, c.type, jzmq.SocketType.REQ);
			verifyEqual(testCase, c.transport, 'tcp');
			verifyEqual(testCase, c.address, 'localhost');
			verifyEqual(testCase, c.port, 6666);
			verifyEmpty(testCase, c.frameSize);
			verifyEqual(testCase, c.readTimeOut, -1);
			verifyEqual(testCase, c.writeTimeOut, -1);
			verifyFalse(testCase, c.verbose);
			verifyFalse(testCase, c.alwaysPoll);
			verifyFalse(testCase, c.isOpen);
			verifyEmpty(testCase, c.context);
			verifyEmpty(testCase, c.socket);
			verifyEmpty(testCase, c.poller);
			verifyEmpty(testCase, c.messages);
		end

		function testConstructionCustomArguments(testCase)
			c = jzmqConnection('name', 'testConn', 'type', 'PUB', ...
				'transport', 'tcp', 'address', '127.0.0.1', 'port', 7777, ...
				'readTimeOut', 500, 'writeTimeOut', 600, 'frameSize', 4096, ...
				'alwaysPoll', true, 'verbose', true);
			testCase.register(c);

			verifyEqual(testCase, c.type, jzmq.SocketType.PUB);
			verifyEqual(testCase, c.address, '127.0.0.1');
			verifyEqual(testCase, c.port, 7777);
			verifyEqual(testCase, c.readTimeOut, 500);
			verifyEqual(testCase, c.writeTimeOut, 600);
			verifyEqual(testCase, c.frameSize, 4096);
			verifyTrue(testCase, c.alwaysPoll);
			verifyTrue(testCase, c.verbose);
		end

		function testAllowedButUnknownPropertiesAreTolerated(testCase)
			%> 'protocol'/'cleanup' are allowed but not real properties;
			%> parseArgs must swallow them without an error.
			c = testCase.makeConn(@() jzmqConnection('protocol', 'tcp', ...
				'cleanup', true, 'bogusProperty', 42));
			verifyEqual(testCase, c.type, jzmq.SocketType.REQ);
		end

		function testInvalidTypeInConstructorFallsBackToREQ(testCase)
			c = testCase.makeConn(@() jzmqConnection('type', 'BOGUS'));
			verifyEqual(testCase, c.type, jzmq.SocketType.REQ);
		end

		function testTypeSetterValidation(testCase)
			c = testCase.makeConn(jzmqConnection);

			c.type = 'SUB';
			verifyEqual(testCase, c.type, jzmq.SocketType.SUB);

			assertErrorThrown(testCase, @() setProp(c, 'type', 'BOGUS'));
			verifyEqual(testCase, c.type, jzmq.SocketType.SUB);
		end

		function testJarOnJavaClassPath(testCase)
			testCase.makeConn(jzmqConnection);
			verifyTrue(testCase, any(contains(javaclasspath, 'jeromq')));
		end

		function testEndpointGetter(testCase)
			c = testCase.makeConn(jzmqConnection);
			verifyEqual(testCase, c.endpoint, 'tcp://localhost:6666');

			d = jzmqConnection('transport', 'ipc', 'address', '/tmp/demo', ...
				'port', 1234);
			testCase.register(d);
			verifyEqual(testCase, d.endpoint, 'ipc:///tmp/demo:1234');
		end

		function testOpenBindsServerTypes(testCase)
			for t = ["REP", "PUB", "PUSH"]
				c = jzmqConnection('type', char(t), 'port', newPort(), ...
					'readTimeOut', 1000, 'writeTimeOut', 1000);
				testCase.register(c);
				status = c.open();
				verifyTrue(testCase, status == true, ...
					"open should bind for type " + t);
				verifyTrue(testCase, c.isOpen);
			end
		end

		function testOpenConnectsClientTypes(testCase)
			for t = ["REQ", "SUB", "PULL"]
				c = jzmqConnection('type', char(t), 'port', newPort(), ...
					'readTimeOut', 1000, 'writeTimeOut', 1000);
				testCase.register(c);
				status = c.open();
				verifyTrue(testCase, status == true, ...
					"open should connect for type " + t);
				verifyTrue(testCase, c.isOpen);
			end
		end

		function testDoubleOpenIsGuarded(testCase)
			[srv, cli] = testCase.makePair('REP', 'REQ');

			statusAgain = cli.open();
			verifyEqual(testCase, statusAgain, -1);

			[rep, ~, st] = cli.sendCommand('still-alive', {}, false);
			verifyEmpty(testCase, rep); % no reply was requested
			verifyEqual(testCase, st, 0);
			[cmd, ~] = srv.receiveCommand(true);
			verifyEqual(testCase, cmd, 'still-alive');
		end

		function testReqRepJsonRoundTripWithAutoOkReply(testCase)
			[srv, cli] = testCase.makePair('REP', 'REQ');

			payload = struct('matrix', magic(5), 'label', 'hello', ...
				'flag', true);
			[rep, ~, st] = cli.sendCommand('compute', payload, false);
			verifyEmpty(testCase, rep);
			verifyEqual(testCase, st, 0);

			[cmd, data] = srv.receiveCommand(true); % auto-replies 'ok'
			verifyEqual(testCase, cmd, 'compute');
			verifyTrue(testCase, isequaln(data, payload));

			[rep, repData] = cli.receiveObject();
			verifyEqual(testCase, rep, 'ok');
			verifyTrue(testCase, isempty(repData) || ...
				isequaln(repData, {}));
		end

		function testReqRepExplicitEchoReply(testCase)
			[srv, cli] = testCase.makePair('REP', 'REQ');

			[~, ~, st] = cli.sendCommand('echo', {1 2 3}, false);
			verifyEqual(testCase, st, 0);

			[cmd, data] = srv.receiveCommand(false); % reply is up to us
			verifyEqual(testCase, cmd, 'echo');
			verifyTrue(testCase, isequaln(data, {1 2 3}));

			srv.sendObject('echoResult', data);
			[rep, dataOut] = cli.receiveObject();
			verifyEqual(testCase, rep, 'echoResult');
			verifyTrue(testCase, isequaln(dataOut, {1 2 3}));
		end

		function testPayloadMatrixRoundTrip(testCase)
			%> PUSH/PULL keeps the focus on serialisation: no REQ
			%> send/receive alternation to trip the state machine.
			[pull, push] = testCase.makePair('PULL', 'PUSH');

			values = { magic(4), int32([7 8 9]), single(3.14), ...
				logical(eye(3)), 'plain char row', ...
				struct('name', 'abc', 'vals', [1 2; 3 4], 'flag', false), ...
				{{1, 2}, 'str', [5 6]}, [] };
			for k = 1:numel(values)
				val = values{k};
				push.sendObject('probe', val, true);
				[cmd, data] = pull.receiveObject(true);
				verifyEqual(testCase, cmd, 'probe', ...
					sprintf('payload %d lost its command frame', k));
				verifyTrue(testCase, isequaln(data, val), ...
					sprintf('payload %d did not survive the round trip', k));
			end
		end

		function testNonJsonMultipartRoundTrip(testCase)
			%> sendObject with useJSON=false sends command+data as two
			%> framed parts; receiveObject must reassemble them.
			[srv, cli] = testCase.makePair('REP', 'REQ');

			s = cli.sendObject('parted', {42}, false);
			verifyEqual(testCase, s, 0);

			[cmd, data] = srv.receiveObject(false);
			verifyEqual(testCase, cmd, 'parted');
			verifyTrue(testCase, isequaln(data, {42}), ...
				'multipart data was lost — check SNDMORE flag handling');
		end

		function testThreeFrameAssembly(testCase)
			%> A command frame plus a byte stream split across two frames
			%> must be assembled into one deserialized payload.
			[srv, cli] = testCase.makePair('REP', 'REQ');

			bytes = getByteStreamFromArray({11, 22});
			half = floor(numel(bytes) / 2);
			cli.socket.send(uint8('multi'), 'sndmore');
			cli.socket.send(bytes(1:half), 'sndmore');
			cli.socket.send(bytes(half + 1:end));

			[cmd, data] = srv.receiveObject(false);
			verifyEqual(testCase, cmd, 'multi');
			verifyTrue(testCase, isequaln(data, {11, 22}));
		end

		function testPubSubReceivesPublishedMessages(testCase)
			pub = jzmqConnection('type', 'PUB', 'port', newPort(), ...
				'readTimeOut', 1000, 'writeTimeOut', 1000);
			sub = jzmqConnection('type', 'SUB', 'port', pub.port, ...
				'readTimeOut', 2000, 'writeTimeOut', 1000);
			testCase.register(pub);
			testCase.register(sub);
			assertTrue(testCase, pub.open() == true);
			assertTrue(testCase, sub.open() == true);
			%> JeroMQ rejects zero-length subscriptions ("Unknown Option
			%> 6"), so subscribe to a prefix every JSON command shares.
			sub.socket.pointer.subscribe(uint8('{"command"'));

			got = false;
			for attempt = 1:25 % tolerate the SUB slow-joiner race
				pub.sendObject('tick', {attempt}, true);
				if sub.poll("in", 150)
					[cmd, data] = sub.receiveObject(true);
					if strcmp(cmd, 'tick')
						got = true;
						verifyTrue(testCase, isequaln(data, {attempt}));
						break;
					end
				end
			end
			verifyTrue(testCase, got, 'SUB never received a published message');
		end

		function testPushPullDeliversInOrder(testCase)
			pull = jzmqConnection('type', 'PULL', 'port', newPort(), ...
				'readTimeOut', 2000, 'writeTimeOut', 1000);
			push = jzmqConnection('type', 'PUSH', 'port', pull.port, ...
				'readTimeOut', 1000, 'writeTimeOut', 1000);
			testCase.register(pull);
			testCase.register(push);
			assertTrue(testCase, pull.open() == true); % connect first...
			assertTrue(testCase, push.open() == true); % ...then bind
			pause(0.3); % let the pipe establish before pushing

			labels = {'m1', 'm2', 'm3'};
			for i = 1:numel(labels)
				push.sendObject(labels{i}, {i}, true);
			end
			for i = 1:numel(labels)
				[cmd, data] = pull.receiveObject(true);
				verifyEqual(testCase, cmd, labels{i});
				verifyEqual(testCase, data{1}, i);
			end
		end

		function testRawSendReceiveCharAndUint8(testCase)
			[srv, cli] = testCase.makePair('REP', 'REQ');

			s = cli.send('raw text');
			verifyEqual(testCase, s, 0);
			[data, st] = srv.receive();
			verifyEqual(testCase, st, 0);
			verifyEqual(testCase, char(data), 'raw text');

			% REP answers raw (legal after a receive), which also
			% releases the REQ state machine for its next send.
			srv.send(uint8('resp'));
			[repData, st] = cli.receive();
			verifyEqual(testCase, st, 0);
			verifyEqual(testCase, char(repData), 'resp');

			s = cli.send(uint8([104 105])); % "hi"
			verifyEqual(testCase, s, 0);
			[data, st] = srv.receive();
			verifyEqual(testCase, st, 0);
			verifyTrue(testCase, isequal(uint8(data), uint8([104 105])));
		end

		function testFlushDiscardsPendingMessages(testCase)
			%> PUSH/PULL has no state machine, so queued frames sit in
			%> the receiver's pipe until flush() drains them.
			[pull, push] = testCase.makePair('PULL', 'PUSH');

			for k = 1:3
				push.sendObject(sprintf('junk%d', k), {}, true);
			end
			pause(0.3); % let the frames land in the PULL pipe
			flush(pull);

			push.sendObject('fresh', {}, true);
			[cmd, ~] = pull.receiveObject(true);
			verifyEqual(testCase, cmd, 'fresh');
		end

		function testPollReportsInOut(testCase)
			[pull, push] = testCase.makePair('PULL', 'PUSH');

			r = pull.poll("both", 10); % quiet socket: nothing to read
			verifyNumElements(testCase, r, 2);
			verifyFalse(testCase, r(1));

			pause(0.3); % pollout only reports true once the pipe is up
			verifyTrue(testCase, push.poll("out", 100)); % writable

			push.sendObject('ping', {}, true);
			verifyTrue(testCase, pull.poll("in", 2000));
			[cmd, ~] = pull.receiveObject(true);
			verifyEqual(testCase, cmd, 'ping');
		end

		function testGetSetSocketOptions(testCase)
			c = jzmqConnection('type', 'PULL', 'port', newPort(), ...
				'readTimeOut', 333, 'writeTimeOut', 777);
			testCase.register(c);
			assertTrue(testCase, c.open() == true);

			% open() applies both timeouts to the right socket options
			verifyEqual(testCase, double(c.get("ReceiveTimeOut")), 333);
			verifyEqual(testCase, double(c.get("SendTimeOut")), 777, ...
				'SendTimeOut must follow writeTimeOut');
			verifyEqual(testCase, double(c.get("Linger")), 1000);

			c.set("ReceiveTimeOut", 250);
			verifyEqual(testCase, double(c.get("ReceiveTimeOut")), 250);
			c.set("Linger", 0);
			verifyEqual(testCase, double(c.get("Linger")), 0);
		end

		function testReceiveTimeOutReturnsEmptyCleanly(testCase)
			%> A quiet REP leaves REQ hanging; a finite readTimeOut makes
			%> sendCommand return empty, and the next send hits the ØMQ
			%> finite-state machine (documented behaviour).
			[srv, cli] = testCase.makePair('REP', 'REQ', ...
				'readTimeOut', 300, 'writeTimeOut', 300);

			tic;
			rep = cli.sendCommand('lonely', {});
			elapsed = toc;
			verifyEmpty(testCase, rep);
			verifyLessThan(testCase, elapsed, 5);

			[~, ~, st] = cli.sendCommand('after-timeout', {}, false);
			verifyEqual(testCase, st, -1); % REQ state machine refuses
		end

		function testBindCollisionErrors(testCase)
			p = newPort();
			s1 = jzmqConnection('type', 'PUB', 'port', p, ...
				'readTimeOut', 500, 'writeTimeOut', 500);
			testCase.register(s1);
			assertTrue(testCase, s1.open() == true);

			s2 = jzmqConnection('type', 'PUB', 'port', p, ...
				'readTimeOut', 500, 'writeTimeOut', 500);
			testCase.register(s2);

			threwError = false;
			try
				s2.open();
			catch
				threwError = true;
			end
			verifyTrue(testCase, threwError, ...
				'binding an already bound port must error');
			verifyFalse(testCase, s2.isOpen);
		end

		function testCloseKeepContextThenReopen(testCase)
			[srv, cli] = testCase.makePair('REP', 'REQ');

			cli.close(true);
			verifyFalse(testCase, cli.isOpen);
			verifyNotEmpty(testCase, cli.context);

			status = cli.open(); % reuses the kept context
			verifyTrue(testCase, status == true);

			[~, ~, st] = cli.sendCommand('again', {}, false);
			verifyEqual(testCase, st, 0);
			[cmd, ~] = srv.receiveCommand(true);
			verifyEqual(testCase, cmd, 'again');
			[rep, ~] = cli.receiveObject();
			verifyEqual(testCase, rep, 'ok');
		end

		function testCloseDestroysOwnedContext(testCase)
			c = jzmqConnection('type', 'PUSH', 'port', newPort(), ...
				'readTimeOut', 500, 'writeTimeOut', 500);
			testCase.register(c);
			assertTrue(testCase, c.open() == true);
			verifyNotEmpty(testCase, c.context);

			c.close(false);
			verifyFalse(testCase, c.isOpen);
			verifyEmpty(testCase, c.context);

			assertTrue(testCase, c.open() == true); % fresh context created
			verifyNotEmpty(testCase, c.context);
		end

		function testInjectedContextSurvivesClientClose(testCase)
			ctx = jzmq.ZContext();
			cleanupCtx = onCleanup(@() delete(ctx)); %#ok<NASGU>

			a = jzmqConnection('type', 'PUB', 'port', newPort(), ...
				'readTimeOut', 500, 'writeTimeOut', 500);
			testCase.register(a);
			a.open(ctx);

			a.close(false); % must NOT destroy the injected context
			probe = ctx.createSocket(jzmq.SocketType.PAIR);
			probe.close();

			b = jzmqConnection('type', 'SUB', 'port', 1, ...
				'readTimeOut', 500, 'writeTimeOut', 500);
			testCase.register(b);
			status = b.open(ctx); % context still usable for new sockets
			verifyTrue(testCase, status == true);
		end

		function testInprocTransportPair(testCase)
			ctx = jzmq.ZContext();
			cleanupCtx = onCleanup(@() delete(ctx)); %#ok<NASGU>

			srv = jzmqConnection('type', 'REP', 'transport', 'inproc', ...
				'address', 'opticka.test.channel', ...
				'readTimeOut', 1000, 'writeTimeOut', 1000);
			cli = jzmqConnection('type', 'REQ', 'transport', 'inproc', ...
				'address', 'opticka.test.channel', ...
				'readTimeOut', 1000, 'writeTimeOut', 1000);
			testCase.register(srv);
			testCase.register(cli);

			assertTrue(testCase, srv.open(ctx) == true);
			assertTrue(testCase, cli.open(ctx) == true);

			cli.sendCommand('over-inproc', struct('v', 9), false);
			[cmd, data] = srv.receiveCommand(true);
			verifyEqual(testCase, cmd, 'over-inproc');
			verifyEqual(testCase, data.v, 9);
		end

		function testIpcTransportPair(testCase)
			assumeTrue(testCase, isunix && ~ismac, ...
				'ipc transport test requires Linux');

			sockPath = fullfile(tempdir, ...
				sprintf('opticka_jzmq_%s', char(java.util.UUID.randomUUID)));
			cleanupSock = onCleanup(@() ipcCleanup(sockPath)); %#ok<NASGU>

			srv = jzmqConnection('type', 'REP', 'transport', 'ipc', ...
				'address', sockPath, 'readTimeOut', 1000, ...
				'writeTimeOut', 1000);
			cli = jzmqConnection('type', 'REQ', 'transport', 'ipc', ...
				'address', sockPath, 'readTimeOut', 1000, ...
				'writeTimeOut', 1000);
			testCase.register(srv);
			testCase.register(cli);

			assertTrue(testCase, srv.open() == true);
			assertTrue(testCase, cli.open() == true);

			cli.sendCommand('over-ipc', 'payload', false);
			[cmd, data] = srv.receiveCommand(true);
			verifyEqual(testCase, cmd, 'over-ipc');
			verifyEqual(testCase, data, 'payload');
		end

		function testMessagesLogGrows(testCase)
			[srv, ~] = testCase.makePair('REP', 'REQ');

			verifyClass(testCase, srv.messages, 'string');
			verifyTrue(testCase, any(srv.messages == "Socket is opened"));
		end

		function testVerboseRoundTripSmoke(testCase)
			[srv, cli] = testCase.makePair('REP', 'REQ', 'verbose', true);

			cli.sendCommand('noisy', {1}, false);
			[cmd, ~] = srv.receiveCommand(true);
			verifyEqual(testCase, cmd, 'noisy');
			[rep, ~] = cli.receiveObject();
			verifyEqual(testCase, rep, 'ok');
		end

		function testAlwaysPollFlushSmoke(testCase)
			%> With alwaysPoll the flush loop consults the real poller
			%> instead of assuming every receive attempt is allowed.
			[pull, push] = testCase.makePair('PULL', 'PUSH', ...
				'alwaysPoll', true);

			for k = 1:2
				push.sendObject(sprintf('stale%d', k), {}, true);
			end
			pause(0.3); % let the stale frames land before draining
			flush(pull);

			push.sendObject('current', {}, true);
			[cmd, ~] = pull.receiveObject(true);
			verifyEqual(testCase, cmd, 'current');
		end

		function testDeleteDestructorCloses(testCase)
			c = jzmqConnection('type', 'PUSH', 'port', newPort(), ...
				'readTimeOut', 500, 'writeTimeOut', 500);
			testCase.register(c);
			assertTrue(testCase, c.open() == true);

			delete(c);
			%> MATLAB invalidates the handle after delete(); any property
			%> access must throw.
			threwError = false;
			try
				c.isOpen;
			catch
				threwError = true;
			end
			verifyTrue(testCase, threwError, ...
				'property access after delete must fail');
		end
	end

	methods (Access = private)
		function c = makeConn(testCase, construction)
			%> Build a jzmqConnection via function handle and track it.
			c = construction();
			testCase.register(c);
		end

		function register(testCase, c)
			testCase.conns{end + 1} = c; %#ok<AGROW>
		end

		function [srv, cli] = makePair(testCase, bindType, connectType, varargin)
			%> Build a bound+connected pair on loopback tcp, retrying on
			%> port collisions. varargin overrides default properties.
			args = {'readTimeOut', 2000, 'writeTimeOut', 2000, ...
				'verbose', false};
			for a = 1:2:numel(varargin) % merge overrides over defaults
				idx = find(strcmp(args(1:2:end), varargin{a}), 1);
				if isempty(idx)
					args = [args, varargin(a:a+1)];
				else
					args{2*idx} = varargin{a + 1};
				end
			end
			for attempt = 1:10
				port = newPort();
				srv = jzmqConnection('type', bindType, 'port', port, ...
					args{:});
				cli = jzmqConnection('type', connectType, 'port', port, ...
					args{:});
				testCase.register(srv);
				testCase.register(cli);
				try
					assertTrue(testCase, srv.open() == true, ...
						'server side failed to bind');
					assertTrue(testCase, cli.open() == true, ...
						'client side failed to connect');
					return;
				catch ME
					fprintf('pair retry %d on port %d (%s)\n', ...
						attempt, port, ME.message);
					pause(0.05);
				end
			end
			testCase.fail('Could not establish a socket pair.');
		end
	end
end

% ========================================================================
%> Local helper functions shared by test methods.
% ========================================================================
function port = newPort()
	%> Random high port to minimise collision risk between tests/runs.
	port = 20000 + randi(40000);
end

function assertErrorThrown(testCase, fcn)
	%> Verify the handle throws any MException.
	didThrow = false;
	try
		fcn();
	catch
		didThrow = true;
	end
	verifyTrue(testCase, didThrow, 'expected an error to be thrown');
end

function setProp(obj, prop, value)
	%> Trigger a property setter for validation tests.
	obj.(prop) = value;
end

function ipcCleanup(sockPath)
	%> Best-effort removal of the unix domain socket left by ipc tests.
	try
		delete([sockPath ':6666']);
	catch
	end
end
