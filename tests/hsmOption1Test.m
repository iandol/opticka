function hsmOption1Test
	% Test stateMachineHSM: (1) flat-mode identical to base, (2) HSM behaviours.
	addOptickaToPath;
	traceStore = {};

	fprintf('\n===== TEST 1: flat mode identical to base stateMachine =====\n');
	% same states as hsmRefactorTest, NO parent column
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
	sm = stateMachineHSM('realTime', false, 'timeDelta', 1e-4, ...
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

	fprintf('\n===== TEST 2: 3-level nesting entry/exit chains =====\n');
	traceStore = {};
	% trial > fixate > hold, then reward (root)
	tEntry  = { @() logTrace('enter trial') };
	tExit   = { @() logTrace('exit trial')  };
	tWithin = { @() logTrace('within trial') };
	fEntry  = { @() logTrace('enter fixate') };
	fExit   = { @() logTrace('exit fixate')  };
	hEntry  = { @() logTrace('enter hold')   };
	hExit   = { @() logTrace('exit hold')    };
	rEntry  = { @() logTrace('enter reward') };
	rExit   = { @() logTrace('exit reward')  };
	hStates = {
		'name'    'next'  'time' 'parent' 'entryFcn' 'withinFcn'   'transitionFcn' 'exitFcn' 'HED';
		'trial'   ''      10     ''       tEntry     tWithin        {}              tExit     'X';
		'fixate'  ''      10     'trial'  fEntry     {}             {}              fExit     'X';
		'hold'    'reward' 0.3   'fixate' hEntry     {}             {}              hExit     'X';
		'reward'  ''      0.2    ''       rEntry     {}             {}              rExit     'X';
		};
	sm2 = stateMachineHSM('realTime', false, 'timeDelta', 1e-4, ...
		'waitFcn', @()( [] ), 'verbose', false, 'fnTimers', false);
	addStates(sm2, hStates);
	% verify hierarchy helpers
	assert(strcmp(sm2.getParent('fixate'), 'trial'), 'getParent fixate');
	assert(strcmp(sm2.getParent('hold'), 'fixate'), 'getParent hold');
	assert(strcmp(sm2.getParent('trial'), ''), 'getParent trial root');
	assert(ismember('fixate', sm2.getChildren('trial')), 'getChildren trial');
	assert(ismember('hold', sm2.getChildren('fixate')), 'getChildren fixate');
	assert(sm2.isAncestorOf('trial','hold'), 'isAncestorOf trial>hold');
	assert(~sm2.isAncestorOf('hold','trial'), 'isAncestorOf hold>trial false');
	assert(sm2.isAncestorOf('trial','trial'), 'isAncestorOf self');
	fprintf('PASS: hierarchy helpers\n');
	run(sm2);
	trace = traceStore;
	fprintf('FTRACE (first 10):\n'); fprintf('  %s\n', trace{1:min(10,end)});
	names2 = sm2.log.name(1:sm2.log.n)';
	fprintf('LOG NAMES: '); disp(names2);
	% entry chain: enter trial, enter fixate, enter hold appear in order
	% (within trial also runs on entry and each tick, interleaved)
	it = @(s) find(strcmp(trace, s), 1);
	assert(it('enter trial') < it('enter fixate'), 'entry: trial before fixate');
	assert(it('enter fixate') < it('enter hold'), 'entry: fixate before hold');
	% within trial runs each tick while hold active
	assert(sum(strcmp(trace,'within trial')) > 1, 'ancestor within ran each tick');
	% exit chain on transition to reward: exit hold, exit fixate, exit trial (in order)
	assert(it('exit hold') < it('exit fixate'), 'exit: hold before fixate');
	assert(it('exit fixate') < it('exit trial'), 'exit: fixate before trial');
	% enter reward after exit chain
	assert(it('exit trial') < it('enter reward'), 'enter reward after exit chain');
	assert(any(strcmp(trace,'exit reward')), 'exit reward at finish');
	assert(isequal(string(names2), ["trial";"fixate";"hold";"reward"]), 'hsm log names');
	fprintf('PASS: 3-level nesting entry/exit chains\n');

	fprintf('\n===== TEST 3: parent transitionFcn fires while child active =====\n');
	traceStore = {};
	% parent "block" catches an abort condition; child "stim" is active leaf
	bEntry  = { @() logTrace('enter block') };
	bExit   = { @() logTrace('exit block')  };
	sEntry  = { @() logTrace('enter stim')  };
	sExit   = { @() logTrace('exit stim')   };
	aEntry  = { @() logTrace('enter abort') };
	aExit   = { @() logTrace('exit abort')  };
	% child returns empty; parent returns 'abort' immediately
	sTrans  = { @() sprintf('') };
	bTrans  = { @() sprintf('abort') };
	aStates = {
		'name'  'next' 'time' 'parent' 'entryFcn' 'withinFcn' 'transitionFcn' 'exitFcn' 'HED';
		'block' ''     10     ''       bEntry     {}          bTrans           bExit     'X';
		'stim'  ''     10     'block'  sEntry     {}          sTrans           sExit     'X';
		'abort' ''     0.2    ''       aEntry     {}          {}               aExit     'X';
		};
	sm3 = stateMachineHSM('realTime', false, 'timeDelta', 1e-4, ...
		'waitFcn', @()( [] ), 'verbose', false, 'fnTimers', false);
	addStates(sm3, aStates);
	run(sm3);
	trace = traceStore;
	fprintf('FTRACE:\n'); fprintf('  %s\n', trace{:});
	% parent transitionFcn fires -> external transition to abort:
	% exit stim, exit block, enter abort, exit abort
	assert(isequal(trace(1:2), {'enter block','enter stim'}), 'parent test entry');
	assert(any(strcmp(trace,'exit stim')), 'parent test exit stim');
	assert(any(strcmp(trace,'exit block')), 'parent test exit block');
	assert(any(strcmp(trace,'enter abort')), 'parent test enter abort');
	fprintf('PASS: parent transitionFcn fires while child active\n');

	fprintf('\n===== TEST 4: local transition stays within firing subtree =====\n');
	traceStore = {};
	% parent "run" with children "a" and "b". a's transitionFcn returns 'local:b'
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
	sm4 = stateMachineHSM('realTime', false, 'timeDelta', 1e-4, ...
		'waitFcn', @()( [] ), 'verbose', false, 'fnTimers', false);
	addStates(sm4, lStates);
	run(sm4);
	trace = traceStore;
	fprintf('FTRACE:\n'); fprintf('  %s\n', trace{:});
	% enter run, enter a, (a transitions local:b) -> exit a, enter b (run NOT exited/re-entered)
	assert(isequal(trace(1:2), {'enter run','enter a'}), 'local test entry');
	[~,aidx] = ismember('exit a', trace);
	assert(strcmp(trace{aidx+1}, 'enter b'), 'local: enter b after exit a');
	% run exit must NOT appear between exit a and enter b
	assert(~strcmp(trace{aidx+1}, 'exit run'), 'local: run should not exit');
	% run exit appears only at the very end (when b's time expires and no next -> finish)
	assert(any(strcmp(trace,'exit run')), 'local: run exits at finish');
	fprintf('PASS: local transition stays within firing subtree\n');

	fprintf('\n===== TEST 5: cycle rejection + missing parent warning =====\n');
	sm5 = stateMachineHSM('realTime', false, 'timeDelta', 1e-4, ...
		'waitFcn', @()( [] ), 'verbose', false);
	% self-parenting: a state that names itself as parent. The state is
	% added to stateList first, so isStateName(self) is true and the cycle
	% guard in validateHierarchy must catch it.
	selfStates = {
		'name' 'next' 'time' 'parent' 'entryFcn' 'withinFcn' 'transitionFcn' 'exitFcn' 'HED';
		'root' ''     1      ''       {}         {}          {}               {}        'X';
		's'    ''     1      's'      {}         {}          {}               {}        'X';
		};
	warning('off', 'stateMachineHSM:cycle');
	addStates(sm5, selfStates);
	warning('on', 'stateMachineHSM:cycle');
	assert(strcmp(sm5.getParent('s'), ''), 'cycle: self-parent treated as root');
	% missing parent: 'orphan' references a non-existent parent
	orphStates = {
		'name'   'next' 'time' 'parent' 'entryFcn' 'withinFcn' 'transitionFcn' 'exitFcn' 'HED';
		'orphan' ''     1      'ghost'  {}         {}          {}               {}        'X';
		};
	wState = warning('off','all');
	addStates(sm5, orphStates);
	warning(wState);
	assert(strcmp(sm5.getParent('orphan'), ''), 'missing parent: orphan treated as root');
	fprintf('PASS: cycle rejection + missing parent warning\n');

	fprintf('\n===== TEST 6: flat demo (inherited) still works =====\n');
	smd = stateMachineHSM('realTime', false, 'timeDelta', 1e-3, ...
		'waitFcn', @()( [] ), 'verbose', false);
	smd.fnTimers = false;
	% minimal flat run via inherited demo machinery (manual, to avoid figure)
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

	fprintf('\n===== ALL OPTION 1 TESTS PASSED =====\n');

	function logTrace(s)
		traceStore{end+1} = s;
	end
end
