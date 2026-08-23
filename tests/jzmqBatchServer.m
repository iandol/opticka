function jzmqBatchServer(cfg)
%> jzmqBatchServer — headless ØMQ server driven by JzmqCrossProcessTest.
%>
%> Runs in a secondary MATLAB instance (`matlab -batch`) and executes
%> three sequential phases, each controlled by handshake files created
%> inside cfg.tmpDir by the test process:
%>
%>   1. REP echo server bound to cfg.repPort, auto-replying 'ok' to every
%>      command, recording received payloads, until quit.rep appears.
%>   2. PULL collector connecting to cfg.pushPort (client binds PUSH),
%>      recording received command labels, until quit.pull appears.
%>   3. PUB broadcaster bound to cfg.pubPort sending 'beat' messages at
%>      ~5 Hz until quit.pub appears.
%>
%> On completion saves a results struct to <tmpDir>/results.mat and
%> creates <tmpDir>/done. Every wait loop is bounded by cfg.timeoutSec so
%> a crashed client can never orphan this MATLAB process.
%>
%> @param cfg struct with fields tmpDir, repPort, pushPort, pubPort,
%>            timeoutSec.

	addOptickaToPath;

	results = struct();
	results.repEcho = {};
	results.pushReceived = {};
	results.pubCount = 0;

	% --- Phase 1: REP echo -------------------------------------------------
	rep = jzmqConnection('type', 'REP', 'port', cfg.repPort, ...
		'readTimeOut', 500, 'writeTimeOut', 2000);
	rep.open();
	touchFile(fullfile(cfg.tmpDir, 'ready.rep'));

	t = tic;
	while ~exist(fullfile(cfg.tmpDir, 'quit.rep'), 'file') ...
			&& toc(t) < cfg.timeoutSec
		[cmd, data] = rep.receiveCommand(true);
		if ~isempty(cmd)
			n = numel(results.repEcho);
			results.repEcho{n + 1} = struct('command', char(cmd), ...
				'data', data);
		end
		pause(0.02);
	end
	rep.close(false);

	% --- Phase 2: PULL collector -------------------------------------------
	pull = jzmqConnection('type', 'PULL', 'port', cfg.pushPort, ...
		'readTimeOut', 500, 'writeTimeOut', 2000);
	pull.open();
	touchFile(fullfile(cfg.tmpDir, 'ready.pull'));

	t = tic;
	while ~exist(fullfile(cfg.tmpDir, 'quit.pull'), 'file') ...
			&& toc(t) < cfg.timeoutSec
		if pull.poll("in", 100)
			[cmd, data] = pull.receiveObject(true);
			if ~isempty(cmd)
				n = numel(results.pushReceived);
				results.pushReceived{n + 1} = struct('command', ...
					char(cmd), 'data', data);
			end
		end
	end
	pull.close(false);

	% --- Phase 3: PUB broadcaster -------------------------------------------
	pub = jzmqConnection('type', 'PUB', 'port', cfg.pubPort, ...
		'readTimeOut', 500, 'writeTimeOut', 2000);
	pub.open();
	touchFile(fullfile(cfg.tmpDir, 'ready.pub'));

	t = tic;
	while ~exist(fullfile(cfg.tmpDir, 'quit.pub'), 'file') ...
			&& toc(t) < cfg.timeoutSec
		pub.sendObject('beat', {results.pubCount}, true);
		results.pubCount = results.pubCount + 1;
		pause(0.2);
	end
	pub.close(false);

	save(fullfile(cfg.tmpDir, 'results.mat'), 'results', '-v7');
	touchFile(fullfile(cfg.tmpDir, 'done'));
end

function touchFile(path)
	%> Create/refresh an empty handshake file.
	fid = fopen(path, 'w');
	if fid ~= -1
		fclose(fid);
	end
end