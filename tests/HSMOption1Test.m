% ========================================================================
%> @class HSMOption1Test
%> @brief Class-based unit tests for stateMachineHSM (Option 1: struct + parent field).
%>
%> Converted from the legacy function-based hsmOption1Test.m to use
%> MATLAB's matlab.unittest.TestCase framework. Each original TEST section
%> becomes a Test method; assertions use verifyEqual / verifyTrue.
%>
%> Run with:
%>   >> runtests('tests/HSMOption1Test.m')
%> Or via GitHub Actions matlab-actions/run-tests.
%>
%> Copyright (c) 2026 Ian Max Andolina — LGPL3, see LICENCE.md
% ========================================================================
classdef HSMOption1Test < matlab.unittest.TestCase

	properties
		%> cell array of trace strings recorded by anonymous function handles
		traceStore cell = {}
	end

	methods (TestClassSetup)
		function setupPath(testCase)
			%> Add Opticka to MATLAB path once for all tests.
			addOptickaToPath;
		end
	end

	methods (TestMethodSetup)
		function resetTrace(testCase)
			%> Clear the trace store before each test method.
			testCase.traceStore = {};
		end
	end

	methods (Test)
		% ===================================================================
		%> @brief Test 1: flat mode (no parent column) produces identical
		%> results to the base stateMachine.
		% ===================================================================
		function testFlatModeIdenticalToBase(testCase)
			entryA = { @() testCase.appendTrace('enter A') };
			entryB = { @() testCase.appendTrace('enter B') };
			entryC = { @() testCase.appendTrace('enter C') };
			exitA  = { @() testCase.appendTrace('exit A')  };
			exitB  = { @() testCase.appendTrace('exit B')  };
			exitC  = { @() testCase.appendTrace('exit C')  };
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
			names  = sm.log.name(1:sm.log.n)';
			ticks  = sm.log.tick(1:sm.log.n)';
			trace  = testCase.traceStore;
			verifyEqual(testCase, string(names), ["A";"B";"C"], 'flat names mismatch');
			verifyEqual(testCase, ticks, [200;1;200], 'flat ticks mismatch');
			expectedTrace = {'enter A','exit A','enter B','exit B','enter C','exit C'};
			verifyEqual(testCase, trace, expectedTrace, 'flat trace mismatch');
		end

		% ===================================================================
		%> @brief Test 2: 3-level nesting produces correct entry/exit
		%> chains and within-function execution order.
		% ===================================================================
		function testThreeLevelNestingEntryExitChains(testCase)
			tEntry  = { @() testCase.appendTrace('enter trial') };
			tExit   = { @() testCase.appendTrace('exit trial')  };
			tWithin = { @() testCase.appendTrace('within trial') };
			fEntry  = { @() testCase.appendTrace('enter fixate') };
			fExit   = { @() testCase.appendTrace('exit fixate')  };
			hEntry  = { @() testCase.appendTrace('enter hold')   };
			hExit   = { @() testCase.appendTrace('exit hold')    };
			rEntry  = { @() testCase.appendTrace('enter reward') };
			rExit   = { @() testCase.appendTrace('exit reward')  };
			hStates = {
				'name'    'next'  'time' 'parent' 'entryFcn' 'withinFcn'   'transitionFcn' 'exitFcn' 'HED';
				'trial'   ''      10     ''       tEntry     tWithin        {}              tExit     'X';
				'fixate'  ''      10     'trial'  fEntry     {}             {}              fExit     'X';
				'hold'    'reward' 0.3   'fixate' hEntry     {}             {}              hExit     'X';
				'reward'  ''      0.2    ''       rEntry     {}             {}              rExit     'X';
				};
			sm = stateMachineHSM('realTime', false, 'timeDelta', 1e-4, ...
				'waitFcn', @()( [] ), 'verbose', false, 'fnTimers', false);
			addStates(sm, hStates);
			% verify hierarchy helpers
			verifyEqual(testCase, sm.getParent('fixate'), 'trial', 'getParent fixate');
			verifyEqual(testCase, sm.getParent('hold'), 'fixate', 'getParent hold');
			verifyEqual(testCase, sm.getParent('trial'), '', 'getParent trial root');
			verifyTrue(testCase, ismember('fixate', sm.getChildren('trial')), 'getChildren trial');
			verifyTrue(testCase, ismember('hold', sm.getChildren('fixate')), 'getChildren fixate');
			verifyTrue(testCase, sm.isAncestorOf('trial','hold'), 'isAncestorOf trial>hold');
			verifyFalse(testCase, sm.isAncestorOf('hold','trial'), 'isAncestorOf hold>trial false');
			verifyTrue(testCase, sm.isAncestorOf('trial','trial'), 'isAncestorOf self');
			run(sm);
			trace = testCase.traceStore;
			it = @(s) find(strcmp(trace, s), 1);
			verifyTrue(testCase, it('enter trial') < it('enter fixate'), 'entry: trial before fixate');
			verifyTrue(testCase, it('enter fixate') < it('enter hold'), 'entry: fixate before hold');
			verifyTrue(testCase, sum(strcmp(trace,'within trial')) > 1, 'ancestor within ran each tick');
			verifyTrue(testCase, it('exit hold') < it('exit fixate'), 'exit: hold before fixate');
			verifyTrue(testCase, it('exit fixate') < it('exit trial'), 'exit: fixate before trial');
			verifyTrue(testCase, it('exit trial') < it('enter reward'), 'enter reward after exit chain');
			verifyTrue(testCase, any(strcmp(trace,'exit reward')), 'exit reward at finish');
			names2 = sm.log.name(1:sm.log.n)';
			verifyEqual(testCase, string(names2), ["trial";"fixate";"hold";"reward"], 'hsm log names');
		end

		% ===================================================================
		%> @brief Test 3: parent transitionFcn fires while child is the
		%> active leaf, triggering an external transition.
		% ===================================================================
		function testParentTransitionFcnFiresWhileChildActive(testCase)
			bEntry  = { @() testCase.appendTrace('enter block') };
			bExit   = { @() testCase.appendTrace('exit block')  };
			sEntry  = { @() testCase.appendTrace('enter stim')  };
			sExit   = { @() testCase.appendTrace('exit stim')   };
			aEntry  = { @() testCase.appendTrace('enter abort') };
			aExit   = { @() testCase.appendTrace('exit abort')  };
			sTrans  = { @() sprintf('') };
			bTrans  = { @() sprintf('abort') };
			aStates = {
				'name'  'next' 'time' 'parent' 'entryFcn' 'withinFcn' 'transitionFcn' 'exitFcn' 'HED';
				'block' ''     10     ''       bEntry     {}          bTrans           bExit     'X';
				'stim'  ''     10     'block'  sEntry     {}          sTrans           sExit     'X';
				'abort' ''     0.2    ''       aEntry     {}          {}               aExit     'X';
				};
			sm = stateMachineHSM('realTime', false, 'timeDelta', 1e-4, ...
				'waitFcn', @()( [] ), 'verbose', false, 'fnTimers', false);
			addStates(sm, aStates);
			run(sm);
			trace = testCase.traceStore;
			verifyEqual(testCase, trace(1:2), {'enter block','enter stim'}, 'parent test entry');
			verifyTrue(testCase, any(strcmp(trace,'exit stim')), 'parent test exit stim');
			verifyTrue(testCase, any(strcmp(trace,'exit block')), 'parent test exit block');
			verifyTrue(testCase, any(strcmp(trace,'enter abort')), 'parent test enter abort');
		end

		% ===================================================================
		%> @brief Test 4: local transition keeps the firing state's parent
		%> active (does not exit/re-enter the ancestor).
		% ===================================================================
		function testLocalTransitionWithinFiringSubtree(testCase)
			rEntry  = { @() testCase.appendTrace('enter run') };
			rExit   = { @() testCase.appendTrace('exit run')  };
			aEntry  = { @() testCase.appendTrace('enter a')   };
			aExit   = { @() testCase.appendTrace('exit a')    };
			bEntry  = { @() testCase.appendTrace('enter b')   };
			bExit   = { @() testCase.appendTrace('exit b')    };
			aTrans  = { @() sprintf('local:b') };
			lStates = {
				'name' 'next' 'time' 'parent' 'entryFcn' 'withinFcn' 'transitionFcn' 'exitFcn' 'HED';
				'run'  ''     10     ''       rEntry     {}          {}               rExit     'X';
				'a'    ''     0.2    'run'    aEntry     {}          aTrans           aExit     'X';
				'b'    ''     0.2    'run'    bEntry     {}          {}               bExit     'X';
				};
			sm = stateMachineHSM('realTime', false, 'timeDelta', 1e-4, ...
				'waitFcn', @()( [] ), 'verbose', false, 'fnTimers', false);
			addStates(sm, lStates);
			run(sm);
			trace = testCase.traceStore;
			verifyEqual(testCase, trace(1:2), {'enter run','enter a'}, 'local test entry');
			[~,aidx] = ismember('exit a', trace);
			verifyTrue(testCase, aidx > 0, 'exit a found in trace');
			verifyEqual(testCase, trace{aidx+1}, 'enter b', 'local: enter b after exit a');
			verifyNotEqual(testCase, trace{aidx+1}, 'exit run', 'local: run should not exit');
			verifyTrue(testCase, any(strcmp(trace,'exit run')), 'local: run exits at finish');
		end

		% ===================================================================
		%> @brief Test 5: cycle rejection (self-parenting) and missing
		%> parent both gracefully treated as root.
		% ===================================================================
		function testCycleRejectionAndMissingParent(testCase)
			sm = stateMachineHSM('realTime', false, 'timeDelta', 1e-4, ...
				'waitFcn', @()( [] ), 'verbose', false);
			% self-parenting: cycle guard must catch it
			selfStates = {
				'name' 'next' 'time' 'parent' 'entryFcn' 'withinFcn' 'transitionFcn' 'exitFcn' 'HED';
				'root' ''     1      ''       {}         {}          {}               {}        'X';
				's'    ''     1      's'      {}         {}          {}               {}        'X';
				};
			warning('off', 'stateMachineHSM:cycle');
			addStates(sm, selfStates);
			warning('on', 'stateMachineHSM:cycle');
			verifyEqual(testCase, sm.getParent('s'), '', 'cycle: self-parent treated as root');
			% missing parent: orphan references non-existent parent
			orphStates = {
				'name'   'next' 'time' 'parent' 'entryFcn' 'withinFcn' 'transitionFcn' 'exitFcn' 'HED';
				'orphan' ''     1      'ghost'  {}         {}          {}               {}        'X';
				};
			wState = warning('off','all');
			addStates(sm, orphStates);
			warning(wState);
			verifyEqual(testCase, sm.getParent('orphan'), '', 'missing parent: orphan treated as root');
		end

		% ===================================================================
		%> @brief Test 6: flat inherited behaviour (single state, no
		%> parent column) still works correctly.
		% ===================================================================
		function testFlatInheritedBehaviour(testCase)
			sm = stateMachineHSM('realTime', false, 'timeDelta', 1e-3, ...
				'waitFcn', @()( [] ), 'verbose', false);
			sm.fnTimers = false;
			dEntry = { @() testCase.appendTrace('d enter') };
			dExit  = { @() testCase.appendTrace('d exit')  };
			dStates = {
				'name' 'next' 'time' 'entryFcn' 'withinFcn' 'transitionFcn' 'exitFcn' 'HED';
				'd'    ''     0.1    dEntry     {}          {}               dExit     'X';
				};
			addStates(sm, dStates);
			run(sm);
			verifyTrue(testCase, any(strcmp(testCase.traceStore,'d enter')), 'flat demo enter');
			verifyTrue(testCase, any(strcmp(testCase.traceStore,'d exit')), 'flat demo exit');
		end
	end

	methods (Access = private)
		% ===================================================================
		%> @brief Append a string to the trace store. Called from anonymous
		%> function handles during state machine execution.
		%> @param s string to record in the trace
		% ===================================================================
		function appendTrace(testCase, s)
			testCase.traceStore{end+1} = s;
		end
	end
end
