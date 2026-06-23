% ========================================================================
%> @class HSMCompareTest
%> @brief Class-based unit tests comparing stateMachine (flat),
%> stateMachineHSM (Option 1), and stateMachineTree (Option 2) for
%> log-equivalence on flat inputs and HSM behaviour correctness.
%>
%> Converted from the legacy function-based hsmCompareTest.m to use
%> MATLAB's matlab.unittest.TestCase framework. The original test had
%> three parts (A: flat equivalence, B: HSM behaviour, C: benchmark);
%> each assertion becomes a verifyEqual / verifyTrue call.
%>
%> Run with:
%>   >> runtests('tests/HSMCompareTest.m')
%> Or via GitHub Actions matlab-actions/run-tests.
%>
%> Copyright (c) 2026 Ian Max Andolina — LGPL3, see LICENCE.md
% ========================================================================
classdef HSMCompareTest < matlab.unittest.TestCase

	properties
		%> cell array of trace strings recorded by anonymous function handles
		traceStore cell = {}
		%> the three state machine classes under comparison
		classes = {'stateMachine','stateMachineHSM','stateMachineTree'}
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
		%> @brief Part A: flat-mode log equivalence — all three classes
		%> must produce identical logs when no parent column is present.
		% ===================================================================
		function testFlatLogEquivalence(testCase)
			entryA = { @() testCase.appendTrace('enter A') };
			entryB = { @() testCase.appendTrace('enter B') };
			entryC = { @() testCase.appendTrace('enter C') };
			exitA  = { @() testCase.appendTrace('exit A')  };
			exitB  = { @() testCase.appendTrace('exit B')  };
			exitC  = { @() testCase.appendTrace('exit C')  };
			transB = { @() sprintf('C') };
			flatStates = {
				'name' 'next' 'time' 'entryFcn' 'withinFcn' 'transitionFcn' 'exitFcn' 'HED';
				'A'   'B'   0.02  entryA   {}          {}        exitA    'X';
				'B'   'A'   0.02  entryB   {}          transB    exitB    'X';
				'C'   ''    0.02  entryC   {}          {}        exitC    'X';
				};
			logs = struct();
			for ci = 1:length(testCase.classes)
				testCase.traceStore = {};
				sm = feval(testCase.classes{ci}, 'realTime', false, 'timeDelta', 1e-4, ...
					'waitFcn', @()( [] ), 'verbose', false, 'fnTimers', true);
				addStates(sm, flatStates);
				run(sm);
				logs.(testCase.classes{ci}) = sm.log;
				logs.(testCase.classes{ci}).trace = testCase.traceStore;
			end
			base = logs.stateMachine;
			for ci = 2:length(testCase.classes)
				other = logs.(testCase.classes{ci});
				ok = isequal(string(base.name(1:base.n)), string(other.name(1:other.n))) && ...
					 isequal(base.tick(1:base.n), other.tick(1:other.n)) && ...
					 isequal(base.trace, other.trace);
				verifyTrue(testCase, ok, ...
					sprintf('flat log equivalence: %s == stateMachine', testCase.classes{ci}));
			end
		end

		% ===================================================================
		%> @brief Part B: 3-level HSM nesting entry/exit/within chains
		%> are correct for both HSM variants.
		% ===================================================================
		function testThreeLevelNestingChains(testCase)
			hStates = {
				'name'    'next'  'time' 'parent' 'entryFcn'                          'withinFcn'                          'transitionFcn'        'exitFcn'                             'HED';
				'trial'   ''      10     ''       { @()testCase.appendTrace('enter trial') } { @()testCase.appendTrace('within trial') } { @()sprintf('') } { @()testCase.appendTrace('exit trial') }  'X';
				'fixate'  ''      10     'trial'  { @()testCase.appendTrace('enter fixate') } {}                            {}                      { @()testCase.appendTrace('exit fixate') }  'X';
				'hold'    'reward' 0.3   'fixate' { @()testCase.appendTrace('enter hold') }   {}                            {}                      { @()testCase.appendTrace('exit hold') }    'X';
				'reward'  ''      0.2    ''       { @()testCase.appendTrace('enter reward') } {}                            {}                      { @()testCase.appendTrace('exit reward') }  'X';
				};
			for ci = 2:length(testCase.classes)
				testCase.traceStore = {};
				sm = feval(testCase.classes{ci}, 'realTime', false, 'timeDelta', 1e-4, ...
					'waitFcn', @()( [] ), 'verbose', false, 'fnTimers', false);
				addStates(sm, hStates);
				run(sm);
				trace = testCase.traceStore;
				it = @(s) find(strcmp(trace, s), 1);
				ok = it('enter trial') < it('enter fixate') && ...
					 it('enter fixate') < it('enter hold') && ...
					 sum(strcmp(trace,'within trial')) > 1 && ...
					 it('exit hold') < it('exit fixate') && ...
					 it('exit fixate') < it('exit trial') && ...
					 it('exit trial') < it('enter reward') && ...
					 isequal(string(sm.log.name(1:sm.log.n)'), ["trial";"fixate";"hold";"reward"]);
				verifyTrue(testCase, ok, ...
					sprintf('%s: 3-level nesting entry/exit/within chains', testCase.classes{ci}));
			end
		end

		% ===================================================================
		%> @brief Part B: parent transitionFcn fires while child is active
		%> in both HSM variants.
		% ===================================================================
		function testParentTransitionCatchesWhileChildActive(testCase)
			pStates = {
				'name'  'next' 'time' 'parent' 'entryFcn'                        'withinFcn' 'transitionFcn'           'exitFcn'                          'HED';
				'block' ''     10     ''       { @()testCase.appendTrace('enter block') } {} { @()sprintf('abort') }        { @()testCase.appendTrace('exit block') }  'X';
				'stim'  ''     10     'block'  { @()testCase.appendTrace('enter stim') }  {} { @()sprintf('') }             { @()testCase.appendTrace('exit stim') }   'X';
				'abort' ''     0.2    ''       { @()testCase.appendTrace('enter abort') } {} {}                            { @()testCase.appendTrace('exit abort') }  'X';
				};
			for ci = 2:length(testCase.classes)
				testCase.traceStore = {};
				sm = feval(testCase.classes{ci}, 'realTime', false, 'timeDelta', 1e-4, ...
					'waitFcn', @()( [] ), 'verbose', false, 'fnTimers', false);
				addStates(sm, pStates);
				run(sm);
				trace = testCase.traceStore;
				ok = isequal(trace(1:2), {'enter block','enter stim'}) && ...
					 any(strcmp(trace,'exit stim')) && ...
					 any(strcmp(trace,'exit block')) && ...
					 any(strcmp(trace,'enter abort'));
				verifyTrue(testCase, ok, ...
					sprintf('%s: parent transitionFcn catches while child active', testCase.classes{ci}));
			end
		end

		% ===================================================================
		%> @brief Part B: local transition within firing subtree works
		%> in both HSM variants.
		% ===================================================================
		function testLocalTransitionWithinFiringSubtree(testCase)
			lStates = {
				'name' 'next' 'time' 'parent' 'entryFcn'                     'withinFcn' 'transitionFcn'          'exitFcn'                          'HED';
				'run'  ''     10     ''       { @()testCase.appendTrace('enter run') } {} {}                               { @()testCase.appendTrace('exit run') }  'X';
				'a'    ''     0.2    'run'    { @()testCase.appendTrace('enter a') }  {} { @()sprintf('local:b') }      { @()testCase.appendTrace('exit a') }    'X';
				'b'    ''     0.2    'run'    { @()testCase.appendTrace('enter b') }  {} {}                            { @()testCase.appendTrace('exit b') }    'X';
				};
			for ci = 2:length(testCase.classes)
				testCase.traceStore = {};
				sm = feval(testCase.classes{ci}, 'realTime', false, 'timeDelta', 1e-4, ...
					'waitFcn', @()( [] ), 'verbose', false, 'fnTimers', false);
				addStates(sm, lStates);
				run(sm);
				trace = testCase.traceStore;
				[~,aidx] = ismember('exit a', trace);
				ok = isequal(trace(1:2), {'enter run','enter a'}) && ...
					 strcmp(trace{aidx+1}, 'enter b') && ...
					 ~strcmp(trace{aidx+1}, 'exit run') && ...
					 any(strcmp(trace,'exit run'));
				verifyTrue(testCase, ok, ...
					sprintf('%s: local transition within firing subtree', testCase.classes{ci}));
			end
		end

		% ===================================================================
		%> @brief Part C: performance micro-benchmark — HSM variants
		%> should not be wildly slower than flat. This is a smoke test
		%> that the benchmark runs without error; timing assertions are
		%> in HSMBenchmarkTest.
		% ===================================================================
		function testBenchmarkRunsForAllClasses(testCase)
			benchStates = {
				'name' 'next' 'time' 'parent' 'entryFcn' 'withinFcn' 'transitionFcn' 'exitFcn' 'HED';
				'p'    ''     1e-4    ''       {}         { @()[] }   {}              {}        'X';
				'q'    ''     1e-4    'p'      {}         { @()[] }   {}              {}        'X';
				'r'    's'    1e-4    'q'      {}         { @()[] }   {}              {}        'X';
				's'    'p'    1e-4    ''       {}         { @()[] }   {}              {}        'X';
				};
			benchStatesFlat = {
				'name' 'next' 'time' 'entryFcn' 'withinFcn' 'transitionFcn' 'exitFcn' 'HED';
				'p'    'q'     1e-4   {}         { @()[] }   {}              {}        'X';
				'q'    'r'     1e-4   {}         { @()[] }   {}              {}        'X';
				'r'    's'     1e-4   {}         { @()[] }   {}              {}        'X';
				's'    'p'     1e-4   {}         { @()[] }   {}              {}        'X';
				};
			N = 1e4;
			for ci = 1:length(testCase.classes)
				sm = feval(testCase.classes{ci}, 'realTime', false, 'timeDelta', 1e-4, ...
					'verbose', false, 'fnTimers', false);
				if ismember(testCase.classes{ci}, {'stateMachineHSM','stateMachineTree'})
					addStates(sm, benchStates);
				else
					addStates(sm, benchStatesFlat);
				end
				start(sm);
				for t = 1:N
					update(sm);
				end
				verifyTrue(testCase, sm.log.n > 0, ...
					sprintf('%s: benchmark ran and produced log entries', testCase.classes{ci}));
			end
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
