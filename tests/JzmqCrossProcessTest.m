% ========================================================================
%> @class JzmqCrossProcessTest
%> @brief Cross-process ØMQ tests using a secondary MATLAB instance.
%>
%> Spawns a detached headless MATLAB (`matlab -batch`, optionally under
%> xvfb-run) running jzmqBatchServer as an independent ØMQ peer, then
%> drives three real inter-process sessions from this process:
%>
%>   1. REQ client -> REP server: five JSON command/payload roundtrips.
%>   2. PUSH client -> PULL server: ordered message delivery across
%>      processes, verified from the server's saved results.
%>   3. SUB client <- PUB server: subscribing to a live broadcast stream.
%>
%> Handshaking uses files in a temp directory (ready/quit/done), so the
%> two processes never share state. All waits are bounded; the spawned
%> process self-terminates after cfg.timeoutSec even if the client dies,
%> and the test kills the recorded PID during teardown.
%>
%> Tagged 'hardware': skipped on GitHub Actions (concurrent MATLAB
%> licensing there is not guaranteed) but runs locally, where concurrent
%> `-batch` sessions are licensed.
%>
%> Run with:
%>   >> runtests('tests/JzmqCrossProcessTest.m')
% ========================================================================
classdef JzmqCrossProcessTest < matlab.unittest.TestCase

	properties
		%> scratch directory shared with the spawned process
		tmpDir = ''
		%> file holding the spawned process PID
		pidFile = ''
	end

	methods (TestClassSetup)
		function setupPath(testCase)
			%> Ensure Opticka + matlab-jzmq classes are on the path.
			addOptickaToPath;
		end
	end

	methods (TestMethodTeardown)
		function cleanupProcess(testCase)
			%> Kill the spawned MATLAB and remove the scratch directory.
			testCase.killServer();
			if ~isempty(testCase.tmpDir) && exist(testCase.tmpDir, 'dir')
				rmdir(testCase.tmpDir, 's');
			end
		end
	end

	methods (Test, TestTags = {'hardware'})
		function testThreePhaseInterProcessSession(testCase)
			assumeFalse(testCase, ~isempty(getenv('GITHUB_ACTIONS')), ...
				'Skip cross-process MATLAB test in CI');
			assumeTrue(testCase, isunix, ...
				'Spawn mechanics are POSIX-specific');

			testCase.tmpDir = tempname;
			mkdir(testCase.tmpDir);
			repPort = newPort();
			pushPort = newPort();
			pubPort = newPort();
			timeoutSec = 240;

			testCase.spawnServer(repPort, pushPort, pubPort, timeoutSec);

			% --- Phase 1: REQ -> REP JSON roundtrips ------------------------
			waitForFile(testCase, fullfile(testCase.tmpDir, 'ready.rep'), 180);

			cli = jzmqConnection('type', 'REQ', 'port', repPort, ...
				'readTimeOut', 10000, 'writeTimeOut', 5000);
			cleanupCli = onCleanup(@() closeConn(cli)); %#ok<NASGU>
			assertTrue(testCase, cli.open() == true);

			commands = {'cmd1', 'cmd2', 'cmd3', 'cmd4', 'cmd5'};
			payloads = { struct('id', 1, 'matrix', magic(4)), ...
				{{'nested'}, [9 8 7]}, 'plain char', int32([4 5 6]), [] };
			for k = 1:numel(commands)
				rep = cli.sendCommand(commands{k}, payloads{k});
				verifyEqual(testCase, rep, 'ok', ...
					sprintf('roundtrip %d got no ok reply', k));
			end

			writeQuit(testCase.tmpDir, 'quit.rep');
			waitForFile(testCase, fullfile(testCase.tmpDir, 'ready.pull'), 60);

			% --- Phase 2: PUSH -> PULL across processes ---------------------
			push = jzmqConnection('type', 'PUSH', 'port', pushPort, ...
				'readTimeOut', 1000, 'writeTimeOut', 3000);
			cleanupPush = onCleanup(@() closeConn(push)); %#ok<NASGU>
			assertTrue(testCase, push.open() == true);
			pause(0.3); % give the server PULL pipe time to establish

			labels = {'p1', 'p2', 'p3'};
			for i = 1:numel(labels)
				sent = false;
				for attempt = 1:20 % server PULL may still be connecting
					if push.sendObject(labels{i}, {}, true) ~= 0
						continue;
					end
					sent = true;
					break;
				end
				verifyTrue(testCase, sent, ...
					sprintf('failed to push %s across processes', labels{i}));
			end
			pause(1.5); % let the server drain its queue before quitting it

			writeQuit(testCase.tmpDir, 'quit.pull');
			waitForFile(testCase, fullfile(testCase.tmpDir, 'ready.pub'), 60);

			% --- Phase 3: SUB <- PUB live broadcast -------------------------
			sub = jzmqConnection('type', 'SUB', 'port', pubPort, ...
				'readTimeOut', 2000, 'writeTimeOut', 2000);
			cleanupSub = onCleanup(@() closeConn(sub)); %#ok<NASGU>
			assertTrue(testCase, sub.open() == true);
			%> JeroMQ rejects zero-length subscriptions, so match on the
			%> prefix shared by every JSON command the server publishes.
			sub.socket.pointer.subscribe(uint8('{"command"'));

			beats = 0;
			t = tic;
			while toc(t) < 8 && beats < 3
				if sub.poll("in", 250)
					[cmd, ~] = sub.receiveObject(true);
					if strcmp(cmd, 'beat')
						beats = beats + 1;
					end
				end
			end
			writeQuit(testCase.tmpDir, 'quit.pub');

			% --- Verify the server-side record -------------------------------
			waitForFile(testCase, fullfile(testCase.tmpDir, 'done'), 90);
			S = load(fullfile(testCase.tmpDir, 'results.mat'));
			results = S.results;

			verifyNumElements(testCase, results.repEcho, numel(commands));
			for k = 1:numel(commands)
				verifyEqual(testCase, results.repEcho{k}.command, commands{k});
				verifyTrue(testCase, ...
					isequaln(results.repEcho{k}.data, payloads{k}), ...
					sprintf('server payload %d mismatched', k));
			end

			verifyNumElements(testCase, results.pushReceived, numel(labels));
			for k = 1:numel(labels)
				verifyEqual(testCase, results.pushReceived{k}.command, ...
					labels{k});
			end

			verifyGreaterThanOrEqual(testCase, results.pubCount, 3);
			verifyGreaterThanOrEqual(testCase, beats, 3, ...
				'SUB received fewer than three broadcast beats');
		end
	end

	methods (Access = private)
		function spawnServer(testCase, repPort, pushPort, pubPort, timeoutSec)
			%> Launch jzmqBatchServer in a detached secondary MATLAB.
			testsDir = fileparts(mfilename('fullpath'));
			driverFile = fullfile(testCase.tmpDir, 'serverDriver.m');
			logFile = fullfile(testCase.tmpDir, 'server.log');
			testCase.pidFile = fullfile(testCase.tmpDir, 'server.pid');

			fid = fopen(driverFile, 'w');
			assertFalse(testCase, fid == -1, 'cannot write driver script');
			fprintf(fid, ['addOptickaToPath;\naddpath(''%s'');\n' ...
				'cfg = struct(''tmpDir'',''%s'',''repPort'',%d,' ...
				'''pushPort'',%d,''pubPort'',%d,''timeoutSec'',%d);\n' ...
				'jzmqBatchServer(cfg);\n'], testsDir, testCase.tmpDir, ...
				repPort, pushPort, pubPort, timeoutSec);
			fclose(fid);

			[hasXvfb] = system('command -v xvfb-run > /dev/null 2>&1');
			if hasXvfb == 0
				prefix = 'xvfb-run -a ';
			else
				prefix = '';
				warning('xvfb-run not found — startup.m noise expected');
			end
			sysCmd = sprintf(['%smatlab -batch "run(''%s'')" ' ...
				'> ''%s'' 2>&1 & echo $! > ''%s'''], prefix, ...
				driverFile, logFile, testCase.pidFile);
			system(sysCmd);
			% Teardown (which always runs) kills the PID recorded above.
		end

		function killServer(testCase)
			%> Best-effort termination of the spawned MATLAB process.
			if isempty(testCase.pidFile) || ~exist(testCase.pidFile, 'file')
				return;
			end
			pid = strtrim(fileread(testCase.pidFile));
			if isempty(pid)
				return;
			end
			system(sprintf('kill -TERM %s 2>/dev/null', pid));
			system(sprintf('pkill -P %s 2>/dev/null', pid));
			pause(0.3);
			system(sprintf('kill -KILL %s 2>/dev/null', pid));
		end
	end
end

% ========================================================================
%> Local helper functions shared by test methods.
% ========================================================================
function port = newPort()
	%> Random high port to minimise collision risk between runs.
	port = 20000 + randi(40000);
end

function waitForFile(testCase, path, timeoutSec)
	%> Poll for a handshake file, failing after timeoutSec seconds.
	t = tic;
	while ~exist(path, 'file') && toc(t) < timeoutSec
		pause(0.25);
	end
	assertTrue(testCase, exist(path, 'file') == 2, ...
		sprintf('timed out after %gs waiting for %s', timeoutSec, path));
end

function writeQuit(tmpDir, name)
	%> Signal the server to finish the current phase.
	fid = fopen(fullfile(tmpDir, name), 'w');
	if fid ~= -1
		fclose(fid);
	end
end

function closeConn(c)
	%> onCleanup target for client connections.
	try c.close(false); catch; end
end