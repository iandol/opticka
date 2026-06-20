function hsmCompareTest
	% Comprehensive comparison of stateMachine (flat), stateMachineHSM
	% (Option 1: struct + parent field) and stateMachineTree (Option 2:
	% node tree) for log-equivalence on flat inputs, HSM behaviour
	% correctness on both variants, and a performance micro-benchmark.
	%
	% Run with: matlab -batch "addOptickaToPath; addpath('tests'); hsmCompareTest"
	addOptickaToPath;
	traceStore = {};
	pass = 0; fail = 0;
	ck = @(name, ok) report(name, ok);

	%---------------------------------------------------------------------
	fprintf('\n############ PART A: flat-mode log equivalence ############\n');
	% A flat StateInfo (no parent column) must produce identical logs on
	% all three classes.
	entryA = { @() logTrace('enter A') };
	entryB = { @() logTrace('enter B') };
	entryC = { @() logTrace('enter C') };
	exitA  = { @() logTrace('exit A')  };
	exitB  = { @() logTrace('exit B')  };
	exitC  = { @() logTrace('exit C')  };
	transB = { @() sprintf('C') };
	flatStates = {
		'name' 'next' 'time' 'entryFcn' 'withinFcn' 'transitionFcn' 'exitFcn' 'HED';
		'A'   'B'   0.02  entryA   {}          {}        exitA    'X';
		'B'   'A'   0.02  entryB   {}          transB    exitB    'X';
		'C'   ''    0.02  entryC   {}          {}        exitC    'X';
		};
	classes = {'stateMachine','stateMachineHSM','stateMachineTree'};
	logs = struct();
	for ci = 1:length(classes)
		traceStore = {};
		sm = feval(classes{ci}, 'realTime', false, 'timeDelta', 1e-4, ...
			'waitFcn', @()( [] ), 'verbose', false, 'fnTimers', true);
		addStates(sm, flatStates);
		run(sm);
		logs.(classes{ci}) = sm.log;
		logs.(classes{ci}).trace = traceStore;
	end
	base = logs.stateMachine;
	for ci = 2:length(classes)
		other = logs.(classes{ci});
		ok = isequal(string(base.name(1:base.n)), string(other.name(1:other.n))) && ...
			 isequal(base.tick(1:base.n), other.tick(1:other.n)) && ...
			 isequal(base.trace, other.trace);
		ck(sprintf('flat log equivalence: %s == stateMachine', classes{ci}), ok);
	end

	%---------------------------------------------------------------------
	fprintf('\n############ PART B: HSM behaviour (both variants) ############\n');
	% A 3-level HSM: trial > fixate > hold -> reward (external transition)
	hStates = {
		'name'    'next'  'time' 'parent' 'entryFcn'              'withinFcn'              'transitionFcn'        'exitFcn'             'HED';
		'trial'   ''      10     ''       { @()logTrace('enter trial') } { @()logTrace('within trial') } { @()sprintf('') } { @()logTrace('exit trial') }  'X';
		'fixate'  ''      10     'trial'  { @()logTrace('enter fixate') } {}                            {}                      { @()logTrace('exit fixate') }  'X';
		'hold'    'reward' 0.3   'fixate' { @()logTrace('enter hold') }   {}                            {}                      { @()logTrace('exit hold') }    'X';
		'reward'  ''      0.2    ''       { @()logTrace('enter reward') } {}                            {}                      { @()logTrace('exit reward') }  'X';
		};
	for ci = 2:length(classes)
		traceStore = {};
		sm = feval(classes{ci}, 'realTime', false, 'timeDelta', 1e-4, ...
			'waitFcn', @()( [] ), 'verbose', false, 'fnTimers', false);
		addStates(sm, hStates);
		run(sm);
		trace = traceStore;
		it = @(s) find(strcmp(trace, s), 1);
		ok = it('enter trial') < it('enter fixate') && ...
			 it('enter fixate') < it('enter hold') && ...
			 sum(strcmp(trace,'within trial')) > 1 && ...
			 it('exit hold') < it('exit fixate') && ...
			 it('exit fixate') < it('exit trial') && ...
			 it('exit trial') < it('enter reward') && ...
			 isequal(string(sm.log.name(1:sm.log.n)'), ["hold";"reward"]);
		ck(sprintf('%s: 3-level nesting entry/exit/within chains', classes{ci}), ok);
	end

	% parent transitionFcn fires while child active
	pStates = {
		'name'  'next' 'time' 'parent' 'entryFcn'               'withinFcn' 'transitionFcn'           'exitFcn'              'HED';
		'block' ''     10     ''       { @()logTrace('enter block') } {} { @()sprintf('abort') }        { @()logTrace('exit block') }  'X';
		'stim'  ''     10     'block'  { @()logTrace('enter stim') }  {} { @()sprintf('') }             { @()logTrace('exit stim') }   'X';
		'abort' ''     0.2    ''       { @()logTrace('enter abort') } {} {}                            { @()logTrace('exit abort') }  'X';
		};
	for ci = 2:length(classes)
		traceStore = {};
		sm = feval(classes{ci}, 'realTime', false, 'timeDelta', 1e-4, ...
			'waitFcn', @()( [] ), 'verbose', false, 'fnTimers', false);
		addStates(sm, pStates);
		run(sm);
		trace = traceStore;
		ok = isequal(trace(1:2), {'enter block','enter stim'}) && ...
			 any(strcmp(trace,'exit stim')) && ...
			 any(strcmp(trace,'exit block')) && ...
			 any(strcmp(trace,'enter abort'));
		ck(sprintf('%s: parent transitionFcn catches while child active', classes{ci}), ok);
	end

	% local transition
	lStates = {
		'name' 'next' 'time' 'parent' 'entryFcn'            'withinFcn' 'transitionFcn'          'exitFcn'             'HED';
		'run'  ''     10     ''       { @()logTrace('enter run') } {} {}                               { @()logTrace('exit run') }  'X';
		'a'    ''     0.2    'run'    { @()logTrace('enter a') }  {} { @()sprintf('local:b') }      { @()logTrace('exit a') }    'X';
		'b'    ''     0.2    'run'    { @()logTrace('enter b') }  {} {}                            { @()logTrace('exit b') }    'X';
		};
	for ci = 2:length(classes)
		traceStore = {};
		sm = feval(classes{ci}, 'realTime', false, 'timeDelta', 1e-4, ...
			'waitFcn', @()( [] ), 'verbose', false, 'fnTimers', false);
		addStates(sm, lStates);
		run(sm);
		trace = traceStore;
		[~,aidx] = ismember('exit a', trace);
		ok = isequal(trace(1:2), {'enter run','enter a'}) && ...
			 strcmp(trace{aidx+1}, 'enter b') && ...
			 ~strcmp(trace{aidx+1}, 'exit run') && ...
			 any(strcmp(trace,'exit run'));
		ck(sprintf('%s: local transition within firing subtree', classes{ci}), ok);
	end

	%---------------------------------------------------------------------
	fprintf('\n############ PART C: performance micro-benchmark ############\n');
	% 100k ticks on a 3-level stack vs flat, measure per-tick cost.
	benchStates = {
		'name' 'next' 'time' 'parent' 'entryFcn' 'withinFcn' 'transitionFcn' 'exitFcn' 'HED';
		'p'    ''     1e9    ''       {}         { @()[] }   {}              {}        'X';
		'q'    ''     1e9    'p'      {}         { @()[] }   {}              {}        'X';
		'r'    ''     1e9    'q'      {}         { @()[] }   {}              {}        'X';
		};
	N = 1e5;
	for ci = 1:length(classes)
		sm = feval(classes{ci}, 'realTime', false, 'timeDelta', 1e-4, ...
			'waitFcn', @()( [] ), 'verbose', false, 'fnTimers', false);
		if ismember(classes{ci}, {'stateMachineHSM','stateMachineTree'})
			addStates(sm, benchStates);
		else
			% flat: single state, equivalent within cost
			addStates(sm, {'name' 'next' 'time' 'entryFcn' 'withinFcn' 'transitionFcn' 'exitFcn' 'HED'; ...
				'r' '' 1e9 {} { @()[] } {} {} 'X'});
		end
		start(sm);
		t0 = tic;
		for t = 1:N; update(sm); end
		elapsed = toc(t0);
		usPerTick = elapsed / N * 1e6;
		depth = 1; if ismember(classes{ci}, {'stateMachineHSM','stateMachineTree'}); depth = 3; end
		fprintf('  %-22s depth=%d  %8.0f ticks in %6.3f s  ->  %.3f us/tick\n', ...
			classes{ci}, depth, N, elapsed, usPerTick);
	end

	%---------------------------------------------------------------------
	fprintf('\n===== SUMMARY: %d passed, %d failed =====\n', pass, fail);
	if fail > 0; error('hsmCompareTest: %d assertions failed', fail); end

	function logTrace(s)
		traceStore{end+1} = s;
	end
	function report(name, ok)
		if ok
			fprintf('  [PASS] %s\n', name);
			pass = pass + 1;
		else
			fprintf('  [FAIL] %s\n', name);
			fail = fail + 1;
		end
	end
end
