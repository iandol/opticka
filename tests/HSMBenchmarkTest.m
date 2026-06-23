% ========================================================================
%> @class HSMBenchmarkTest
%> @brief Class-based unit tests for timing precision comparison across
%> stateMachine (flat), stateMachineHSM (Option 1), and stateMachineTree
%> (Option 2).
%>
%> Converted from the legacy function-based hsmBenchmarkTest.m to use
%> MATLAB's matlab.unittest.TestCase framework. The benchmark logic is
%> preserved; timing assertions use verifyLessThan / verifyTrue.
%>
%> Run with:
%>   >> runtests('tests/HSMBenchmarkTest.m')
%> Or via GitHub Actions matlab-actions/run-tests.
%>
%> Copyright (c) 2026 Ian Max Andolina — LGPL3, see LICENCE.md
% ========================================================================
classdef HSMBenchmarkTest < matlab.unittest.TestCase

	properties (Constant)
		%> number of A->B->C cycles per run
		N double = 50
		%> state duration in seconds (20 ms)
		stateTime double = 0.02
		%> warmup cycles to discard
		warmupCycles double = 2
	end

	properties
		%> the three state machine classes under comparison
		classes = {'stateMachine','stateMachineHSM','stateMachineTree'}
		%> shared closure state for nested helpers (visible to anonymous fns)
		cycleCount double = 0
		%> work vector for fixed-work function
		workVec double = randn(64,1)
	end

	methods (TestClassSetup)
		function setupPath(testCase)
			%> Add Opticka to MATLAB path once for all tests.
			addOptickaToPath;
		end
	end

	methods (TestMethodSetup)
		function resetCounters(testCase)
			%> Reset cycle counter and work vector before each test method.
			testCase.cycleCount = 0;
			testCase.workVec = randn(64,1);
		end
	end

	methods (Test)
		% ===================================================================
		%> @brief Run the full timing benchmark across all three classes
		%> and verify that HSM variants are within acceptable timing
		%> bounds of the flat baseline.
		% ===================================================================
		function testTimingWithinBounds(testCase)
			results = struct();
			fprintf('\n############ HSM TIMING BENCHMARK ############\n');
			fprintf('States: A(%.0fms)->B->C  cycling %d times -> end  (realTime, GetSecs)\n\n', ...
				testCase.stateTime*1e3, testCase.N);

			%--- flat runs for all three classes ---
			for ci = 1:length(testCase.classes)
				cls = testCase.classes{ci};
				testCase.cycleCount = 0;
				testCase.workVec = randn(64,1);
				entryFcn  = { @()testCase.workFcn() };
				exitFcn   = { @()testCase.workFcn() };
				withinFcn = {};
				cEntryFcn = { @()testCase.workFcn(), @()testCase.incrCycle() };
				cTrans    = { @()testCase.checkCycle(testCase.N, 'end') };
				states = {
					'name' 'next' 'time'          'entryFcn' 'withinFcn' 'transitionFcn' 'exitFcn' 'HED';
					'A'    'B'     testCase.stateTime entryFcn   {}          {}              exitFcn  'X';
					'B'    'C'     testCase.stateTime entryFcn   {}          {}              exitFcn  'X';
					'C'    'A'     testCase.stateTime cEntryFcn  {}          cTrans          exitFcn  'X';
					'end'  ''      testCase.stateTime entryFcn   {}          {}              exitFcn  'X';
					};
				sm = feval(cls, 'realTime', true, 'timeDelta', 0, ...
					'clockFcn', @GetSecs, 'verbose', false, 'fnTimers', true, 'name', cls);
				addStates(sm, states);
				t0 = tic;
				run(sm);
				wallTime = toc(t0);
				results.(cls) = analyseLog(sm.log, sm.log.n, testCase.stateTime, testCase.warmupCycles);
				results.(cls).wallTime = wallTime;
				results.(cls).nVisits = sm.log.n;
				fprintf('  ran %-22s  %d visits  %.3f s\n', cls, sm.log.n, wallTime);
			end

			%--- nested HSM runs (3-level depth) ---
			for ci = 2:length(testCase.classes)
				cls = testCase.classes{ci};
				testCase.cycleCount = 0;
				testCase.workVec = randn(64,1);
				entryFcn  = { @()testCase.workFcn() };
				exitFcn   = { @()testCase.workFcn() };
				cEntryFcn = { @()testCase.workFcn(), @()testCase.incrCycle() };
				cTrans    = { @()testCase.checkCycle(testCase.N, 'end') };
				nestStates = {
					'name' 'next' 'time'             'parent' 'entryFcn' 'withinFcn' 'transitionFcn' 'exitFcn' 'HED';
					'root' ''     1e6                 ''       {}        {}          {}          {}        'X';
					'mid'  ''     1e6                 'root'   {}        {}          {}          {}        'X';
					'A'    'B'    testCase.stateTime  'mid'    entryFcn  {}          {}          exitFcn   'X';
					'B'    'C'    testCase.stateTime  'mid'    entryFcn  {}          {}          exitFcn   'X';
					'C'    'A'    testCase.stateTime  'mid'    cEntryFcn {}          cTrans      exitFcn   'X';
					'end'   ''    testCase.stateTime  ''       entryFcn  {}          {}          exitFcn   'X';
					};
				sm = feval(cls, 'realTime', true, 'timeDelta', 0, ...
					'clockFcn', @GetSecs, 'verbose', false, 'fnTimers', true, 'name', [cls '-nested']);
				addStates(sm, nestStates);
				t0 = tic;
				run(sm);
				wallTime = toc(t0);
				key = [cls '_nested'];
				results.(key) = analyseLog(sm.log, sm.log.n, testCase.stateTime, testCase.warmupCycles);
				results.(key).wallTime = wallTime;
				results.(key).nVisits = sm.log.n;
				fprintf('  ran %-22s  %d visits  %.3f s\n', key, sm.log.n, wallTime);
			end

			printTable(results, testCase.classes);

			%--- assertions: HSM variants within bounds of flat ---
			flat = results.(testCase.classes{1});
			for ci = 2:length(testCase.classes)
				cls = testCase.classes{ci};
				r = results.(cls);
				% within-state overshoot: HSM polling latency within 1ms of flat
				verifyLessThan(testCase, abs(r.overMean - flat.overMean), 1e-3, ...
					sprintf('%s within-state overshoot drift > 1ms vs flat', cls));
				% inter-state gap: HSM transition overhead within 5ms of flat
				verifyLessThan(testCase, r.gapMean - flat.gapMean, 5e-3, ...
					sprintf('%s inter-state gap mean > 5ms worse than flat', cls));
				% feval timers: HSM entry/exit chain within 5ms of flat
				verifyLessThan(testCase, r.feEnterMean - flat.feEnterMean, 5, ...
					sprintf('%s fevalEnter mean > 5ms worse than flat', cls));
				verifyLessThan(testCase, r.feExitMean - flat.feExitMean, 5, ...
					sprintf('%s fevalExit mean > 5ms worse than flat', cls));
				fprintf('  [OK] %s: timing within bounds of flat baseline\n', cls);
			end

			% nested variants: gap may be larger due to chain depth, but bounded
			for ci = 2:length(testCase.classes)
				cls = testCase.classes{ci};
				k = [cls '_nested'];
				r = results.(k);
				verifyLessThan(testCase, r.gapMean - flat.gapMean, 1e-3, ...
					sprintf('%s nested inter-state gap > 1ms worse than flat', cls));
				fprintf('  [OK] %s (nested, depth 3): gap within 1ms of flat\n', cls);
			end

			fprintf('\n===== BENCHMARK COMPLETE: all timing checks passed =====\n');
		end
	end

	methods (Access = private)
		% ===================================================================
		%> @brief Increment the cycle visit counter (called from C's
		%> entryFcn). Shares cycleCount with the test case scope.
		% ===================================================================
		function incrCycle(testCase)
			testCase.cycleCount = testCase.cycleCount + 1;
		end

		% ===================================================================
		%> @brief Return endName once N cycles have been entered, else ''
		%> (lets the time-trigger loop via the state's `next` field).
		%> @param nCycles number of cycles to complete
		%> @param endName state name to transition to when done
		%> @return r state name string or empty
		% ===================================================================
		function r = checkCycle(testCase, nCycles, endName)
			if testCase.cycleCount >= nCycles
				r = endName;
			else
				r = '';
			end
		end

		% ===================================================================
		%> @brief Fixed-work function for entry/exit fns so feval timers
		%> are meaningful. Dot product + sort of a small vector.
		% ===================================================================
		function workFcn(testCase)
			s = sum(testCase.workVec .* testCase.workVec);
			[~, ~] = sort(testCase.workVec);
			if s < 0; s = 0; end  %> prevent dead-code elimination
		end
	end
end

%==========================================================================
% Local functions (outside the classdef, as in the original test)
%==========================================================================

function s = analyseLog(log, n, expectedTime, warmupCycles)
	%> Compute timing statistics from a stateMachine log.
	%> warmupCycles: number of initial A->B->C cycles (3 states each) to
	%> discard to avoid JIT/cache warmup effects.
	%> The final C (truncated by the cycle-end transition) and the
	%> terminal 'end' state are excluded (last 2 entries).
	discard = warmupCycles * 3;
	lo = discard + 1;
	hi = n - 2;                              %> exclude truncated C + 'end'
	s.nAnalysed = hi - lo + 1;
	if s.nAnalysed < 4
		s = emptyStats(); return
	end
	%> 1. within-state overshoot: actual - expected
	dur = log.tnow(lo:hi) - log.entryTime(lo:hi);
	over = dur - expectedTime;
	s.durMean = mean(dur);
	s.overMean = mean(over);
	s.overStd = std(over);
	s.overMax = max(over);
	%> 2. inter-state delay: entryTime(n+1) - tnow(n) for consecutive visits
	gap = log.entryTime(lo+1:hi) - log.tnow(lo:hi-1);
	s.gapMean = mean(gap);
	s.gapStd = std(gap);
	s.gapMax = max(gap);
	s.gapMed = median(gap);
	%> 3. function-eval timers (ms)
	fe = log.fevalEnter(lo:hi);
	fx = log.fevalExit(lo:hi);
	fs = log.fevalStore(lo:hi);
	s.feEnterMean = mean(fe);
	s.feEnterStd = std(fe);
	s.feEnterMax = max(fe);
	s.feExitMean = mean(fx);
	s.feExitStd = std(fx);
	s.feExitMax = max(fx);
	s.feStoreMean = mean(fs);
	s.feStoreMax = max(fs);
end

function s = emptyStats()
	s.nAnalysed=0;
	s.durMean=NaN; s.overMean=NaN; s.overStd=NaN; s.overMax=NaN;
	s.gapMean=NaN; s.gapStd=NaN; s.gapMax=NaN; s.gapMed=NaN;
	s.feEnterMean=NaN; s.feEnterStd=NaN; s.feEnterMax=NaN;
	s.feExitMean=NaN; s.feExitStd=NaN; s.feExitMax=NaN;
	s.feStoreMean=NaN; s.feStoreMax=NaN;
end

function printTable(results, classes)
	rkeys = [classes, {'stateMachineHSM_nested','stateMachineTree_nested'}];
	fprintf('\n%-26s %8s %8s %9s %9s %9s\n', ...
		'Class','visits','wall(s)','durMean','overMean','overMax');
	fprintf('%s\n', repmat('-',1,80));
	for i = 1:length(rkeys)
		k = rkeys{i};
		if ~isfield(results, k); continue; end
		r = results.(k);
		fprintf('%-26s %8d %8.3f %9.5f %9.6f %9.6f\n', ...
			k, r.nVisits, r.wallTime, r.durMean, r.overMean, r.overMax);
	end
	fprintf('\n%-26s %10s %10s %10s %10s\n', ...
		'Inter-state delay (s)','gapMean','gapStd','gapMed','gapMax');
	fprintf('%s\n', repmat('-',1,80));
	for i = 1:length(rkeys)
		k = rkeys{i};
		if ~isfield(results, k); continue; end
		r = results.(k);
		fprintf('%-26s %10.6f %10.6f %10.6f %10.6f\n', ...
			k, r.gapMean, r.gapStd, r.gapMed, r.gapMax);
	end
	fprintf('\n%-26s %10s %11s %10s %11s %10s\n', ...
		'Fcn timers (ms)','feEnter','feEnterMax','feExit','feExitMax','feStore');
	fprintf('%s\n', repmat('-',1,90));
	for i = 1:length(rkeys)
		k = rkeys{i};
		if ~isfield(results, k); continue; end
		r = results.(k);
		fprintf('%-26s %10.4f %11.4f %10.4f %11.4f %10.4f\n', ...
			k, r.feEnterMean, r.feEnterMax, r.feExitMean, r.feExitMax, r.feStoreMean);
	end
end
