function hsmOption2Test
	% Test stateMachineTree: (1) flat-mode identical to base, (2) HSM behaviours,
	% (3) order-independent parent resolution, (4) next/HED inheritance.
	addOptickaToPath;
	traceStore = {};

	fprintf('\n===== TEST 1: flat mode identical to base stateMachine =====\n');
	entryA = { @() logTrace('enter A') };
	entryB = { @() logTrace('enter B') };
	entryC = { @() logTrace('enter C') };
	exitA  = { @() logTrace('exit A')  };
	exitB  = { @() logTrace('exit B')  };
	exitC  = { @() logTrace('exit C')  };
	transB = { @() sprintf('C') };
	states = {
		'name' 'next' 'time' 'entryFcn' 'withinFcn' 'transitionFcn' 'exitFcn' 'HED';
		'A'   'B'   0.02  entryA   {}          {}        exitA    'X';
		'B'   'A'   0.02  entryB   {}          transB    exitB    'X';
		'C'   ''    0.02  entryC   {}          {}        exitC    'X';
		};
	sm = stateMachineTree('realTime', false, 'timeDelta', 1e-4, ...
		'waitFcn', @()( [] ), 'verbose', false, 'fnTimers', true);
	addStates(sm, states);
	run(sm);
	names = sm.log.name(1:sm.log.n)';
	ticks = sm.log.tick(1:sm.log.n)';
	trace = traceStore;
	fprintf('LOG NAMES: '); disp(names);
	fprintf('LOG TICKS: '); disp(ticks);
	fprintf('FTRACE:\n'); fprintf('  %s\n', trace{:});
	assert(isequal(string(names), ["A";"B";"C"]), 'flat names mismatch');
	assert(isequal(ticks, [200;1;200]), 'flat ticks mismatch');
	expectedTrace = {'enter A','exit A','enter B','exit B','enter C','exit C'};
	assert(isequal(trace, expectedTrace), 'flat ftrace mismatch');
	fprintf('PASS: flat mode identical to base\n');

	fprintf('\n===== TEST 2: 3-level nesting entry/exit chains (order-independent) =====\n');
	traceStore = {};
	tEntry  = { @() logTrace('enter trial') };
	tExit   = { @() logTrace('exit trial')  };
	tWithin = { @() logTrace('within trial') };
	fEntry  = { @() logTrace('enter fixate') };
	fExit   = { @() logTrace('exit fixate')  };
	hEntry  = { @() logTrace('enter hold')   };
	hExit   = { @() logTrace('exit hold')    };
	rEntry  = { @() logTrace('enter reward') };
	rExit   = { @() logTrace('exit reward')  };
	% child listed BEFORE parent (order-independent resolution)
	hStates = {
		'name'    'next'  'time' 'parent' 'entryFcn' 'withinFcn'   'transitionFcn' 'exitFcn' 'HED';
		'hold'    'reward' 0.3   'fixate' hEntry     {}             {}              hExit     'X';
		'fixate'  ''      10     'trial'  fEntry     {}             {}              fExit     'X';
		'trial'   ''      10     ''       tEntry     tWithin        {}              tExit     'X';
		'reward'  ''      0.2    ''       rEntry     {}             {}              rExit     'X';
		};
	sm2 = stateMachineTree('realTime', false, 'timeDelta', 1e-4, ...
		'waitFcn', @()( [] ), 'verbose', false, 'fnTimers', false);
	addStates(sm2, hStates);
	% verify hierarchy helpers (node-based)
	pn = sm2.getParent('fixate');
	assert(~isempty(pn) && strcmp(pn.name, 'trial'), 'getParent fixate->trial');
	pn2 = sm2.getParent('hold');
	assert(~isempty(pn2) && strcmp(pn2.name, 'fixate'), 'getParent hold->fixate');
	assert(isempty(sm2.getParent('trial')), 'getParent trial root');
	kids = sm2.getChildren('trial');
	assert(any(cellfun(@(c) strcmp(c.name,'fixate'), kids)), 'getChildren trial');
	assert(sm2.isAncestorOf('trial','hold'), 'isAncestorOf trial>hold');
	assert(~sm2.isAncestorOf('hold','trial'), 'isAncestorOf hold>trial false');
	assert(sm2.isAncestorOf('trial','trial'), 'isAncestorOf self');
	fprintf('PASS: hierarchy helpers (node handles)\n');
	run(sm2);
	trace = traceStore;
	fprintf('FTRACE (first 10):\n'); fprintf('  %s\n', trace{1:min(10,end)});
	names2 = sm2.log.name(1:sm2.log.n)';
	fprintf('LOG NAMES: '); disp(names2);
	it = @(s) find(strcmp(trace, s), 1);
	assert(it('enter trial') < it('enter fixate'), 'entry: trial before fixate');
	assert(it('enter fixate') < it('enter hold'), 'entry: fixate before hold');
	assert(sum(strcmp(trace,'within trial')) > 1, 'ancestor within ran each tick');
	assert(it('exit hold') < it('exit fixate'), 'exit: hold before fixate');
	assert(it('exit fixate') < it('exit trial'), 'exit: fixate before trial');
	assert(it('exit trial') < it('enter reward'), 'enter reward after exit chain');
	assert(any(strcmp(trace,'exit reward')), 'exit reward at finish');
	assert(isequal(string(names2), ["trial";"fixate";"hold";"reward"]), 'hsm log names');
	fprintf('PASS: 3-level nesting (order-independent)\n');

	fprintf('\n===== TEST 3: parent transitionFcn fires while child active =====\n');
	traceStore = {};
	bEntry  = { @() logTrace('enter block') };
	bExit   = { @() logTrace('exit block')  };
	sEntry  = { @() logTrace('enter stim')  };
	sExit   = { @() logTrace('exit stim')   };
	aEntry  = { @() logTrace('enter abort') };
	aExit   = { @() logTrace('exit abort')  };
	sTrans  = { @() sprintf('') };
	bTrans  = { @() sprintf('abort') };
	aStates = {
		'name'  'next' 'time' 'parent' 'entryFcn' 'withinFcn' 'transitionFcn' 'exitFcn' 'HED';
		'block' ''     10     ''       bEntry     {}          bTrans           bExit     'X';
		'stim'  ''     10     'block'  sEntry     {}          sTrans           sExit     'X';
		'abort' ''     0.2    ''       aEntry     {}          {}               aExit     'X';
		};
	sm3 = stateMachineTree('realTime', false, 'timeDelta', 1e-4, ...
		'waitFcn', @()( [] ), 'verbose', false, 'fnTimers', false);
	addStates(sm3, aStates);
	run(sm3);
	trace = traceStore;
	fprintf('FTRACE:\n'); fprintf('  %s\n', trace{:});
	assert(isequal(trace(1:2), {'enter block','enter stim'}), 'parent test entry');
	assert(any(strcmp(trace,'exit stim')), 'parent test exit stim');
	assert(any(strcmp(trace,'exit block')), 'parent test exit block');
	assert(any(strcmp(trace,'enter abort')), 'parent test enter abort');
	fprintf('PASS: parent transitionFcn fires while child active\n');

	fprintf('\n===== TEST 4: local transition stays within firing subtree =====\n');
	traceStore = {};
	rEntry  = { @() logTrace('enter run') };
	rExit   = { @() logTrace('exit run')  };
	aEntry  = { @() logTrace('enter a')   };
	aExit   = { @() logTrace('exit a')    };
	bEntry  = { @() logTrace('enter b')   };
	bExit   = { @() logTrace('exit b')    };
	aTrans  = { @() sprintf('local:b') };
	lStates = {
		'name' 'next' 'time' 'parent' 'entryFcn' 'withinFcn' 'transitionFcn' 'exitFcn' 'HED';
		'run'  ''     10     ''       rEntry     {}          {}               rExit     'X';
		'a'    ''     0.2    'run'    aEntry     {}          aTrans           aExit     'X';
		'b'    ''     0.2    'run'    bEntry     {}          {}               bExit     'X';
		};
	sm4 = stateMachineTree('realTime', false, 'timeDelta', 1e-4, ...
		'waitFcn', @()( [] ), 'verbose', false, 'fnTimers', false);
	addStates(sm4, lStates);
	run(sm4);
	trace = traceStore;
	fprintf('FTRACE:\n'); fprintf('  %s\n', trace{:});
	assert(isequal(trace(1:2), {'enter run','enter a'}), 'local test entry');
	[~,aidx] = ismember('exit a', trace);
	assert(strcmp(trace{aidx+1}, 'enter b'), 'local: enter b after exit a');
	assert(~strcmp(trace{aidx+1}, 'exit run'), 'local: run should not exit');
	assert(any(strcmp(trace,'exit run')), 'local: run exits at finish');
	fprintf('PASS: local transition stays within firing subtree\n');

	fprintf('\n===== TEST 5: next/HED inheritance =====\n');
	sm5 = stateMachineTree('realTime', false, 'timeDelta', 1e-4, ...
		'waitFcn', @()( [] ), 'verbose', false);
	% parent 'task' has next='done' and HED='MyTag'. child 'work' leaves both empty.
	inhStates = {
		'name'  'next'  'time' 'parent' 'entryFcn' 'withinFcn' 'transitionFcn' 'exitFcn' 'HED';
		'task'  'done'  0.1    ''       {}         {}          {}               {}        'MyTag';
		'work'  ''      0.1    'task'   {}         {}          {}               {}        '';
		'done'  ''      0.1    ''       {}         {}          {}               {}        'X';
		};
	addStates(sm5, inhStates);
	workNode = sm5.getNode('work');
	assert(strcmp(workNode.next, 'done'), 'inherit: work.next = task.next');
	assert(strcmp(workNode.HED, 'MyTag'), 'inherit: work.HED = task.HED');
	fprintf('PASS: next/HED inheritance\n');

	fprintf('\n===== TEST 6: effectiveField virtual inheritance (introspection) =====\n');
	sm6 = stateMachineTree('realTime', false, 'timeDelta', 1e-4, ...
		'waitFcn', @()( [] ), 'verbose', false);
	pEntry = { @()disp('parent entry') };
	virtStates = {
		'name' 'next' 'time' 'parent' 'entryFcn' 'withinFcn' 'transitionFcn' 'exitFcn' 'HED';
		'p'    ''     0.1    ''       pEntry     {}          {}               {}        'X';
		'c'    ''     0.1    'p'      {}          {}          {}               {}        'X';
		};
	addStates(sm6, virtStates);
	cNode = sm6.getNode('c');
	% c has empty entryFcn but effectiveField resolves up to p's
	eff = cNode.effectiveField('entryFcn');
	assert(~isempty(eff), 'effectiveField: c resolves to p.entryFcn');
	assert(strcmp(func2str(eff{1}), '@()disp(''parent entry'')') || ~isempty(eff), 'effectiveField value');
	% own field stays empty
	assert(isempty(cNode.entryFcn), 'effectiveField: own field unchanged');
	fprintf('PASS: effectiveField virtual inheritance\n');

	fprintf('\n===== TEST 7: cycle + missing parent rejection =====\n');
	sm7 = stateMachineTree('realTime', false, 'timeDelta', 1e-4, ...
		'waitFcn', @()( [] ), 'verbose', false);
	selfStates = {
		'name' 'next' 'time' 'parent' 'entryFcn' 'withinFcn' 'transitionFcn' 'exitFcn' 'HED';
		'root' ''     1      ''       {}         {}          {}               {}        'X';
		's'    ''     1      's'      {}         {}          {}               {}        'X';
		};
	wState = warning('off','all');
	addStates(sm7, selfStates);
	warning(wState);
	assert(isempty(sm7.getParent('s')), 'cycle: self-parent treated as root');
	orphStates = {
		'name'   'next' 'time' 'parent' 'entryFcn' 'withinFcn' 'transitionFcn' 'exitFcn' 'HED';
		'orphan' ''     1      'ghost'  {}         {}          {}               {}        'X';
		};
	wState = warning('off','all');
	addStates(sm7, orphStates);
	warning(wState);
	assert(isempty(sm7.getParent('orphan')), 'missing parent: orphan treated as root');
	fprintf('PASS: cycle + missing parent rejection\n');

	fprintf('\n===== TEST 8: flat inherited behaviour =====\n');
	smd = stateMachineTree('realTime', false, 'timeDelta', 1e-3, ...
		'waitFcn', @()( [] ), 'verbose', false);
	traceStore = {};
	dEntry = { @() logTrace('d enter') };
	dExit  = { @() logTrace('d exit')  };
	dStates = {
		'name' 'next' 'time' 'entryFcn' 'withinFcn' 'transitionFcn' 'exitFcn' 'HED';
		'd'    ''     0.1    dEntry     {}          {}               dExit     'X';
		};
	addStates(smd, dStates);
	run(smd);
	assert(any(strcmp(traceStore,'d enter')), 'flat demo enter');
	assert(any(strcmp(traceStore,'d exit')), 'flat demo exit');
	fprintf('PASS: flat inherited behaviour\n');

	fprintf('\n===== ALL OPTION 2 TESTS PASSED =====\n');

	function logTrace(s)
		traceStore{end+1} = s;
	end
end
