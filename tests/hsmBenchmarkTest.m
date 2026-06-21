function hsmBenchmarkTest
	% Benchmark comparing timing precision across the three state machine
	% classes (stateMachine, stateMachineHSM, stateMachineTree).
	%
	% Creates IDENTICAL states and transitions for each class, runs many
	% iterations, and compares three aspects recorded in the stateMachine
	% log:
	%   1. Within-state time precision: overshoot of actual state duration
	%      (log.tnow - log.entryTime) over the nominal state.time. This is
	%      the polling/trigger latency.
	%   2. Inter-state delay: the dead time between one state's exit and
	%      the next state's entry, computed as
	%      log.entryTime(n+1) - log.tnow(n). This captures the transition
	%      overhead (exit fcn eval + LCA/chain computation + entry fcn
	%      eval) — i.e. delays from when one state ends to the next starts.
	%   3. Function evaluation timers: log.fevalEnter, log.fevalExit,
	%      log.fevalStore (milliseconds) — per-state-visit cost of
	%      running the entry/exit function handles and the log-store step.
	%
	% All three classes run the same flat state set (no `parent` column)
	% so the comparison isolates per-class overhead. A bonus nested-HSM
	% run (3-level depth) is included to show the hierarchy cost.
	%
	% Run: matlab -batch "addOptickaToPath; addpath('tests'); hsmBenchmarkTest"
	addOptickaToPath;
	clear stateMachine stateMachineHSM stateMachineTree
	classes = {'stateMachine','stateMachineHSM','stateMachineTree'};
	N = 50;                                  %> number of A->B->C cycles
	stateTime = 0.02;                        %> 20 ms per state
	warmupCycles = 2;                        %> discard first 2 cycles per run
	results = struct();
	% shared closure state for nested helpers (visible to anonymous fns)
	cycleCount = 0;
	workVec = randn(64,1);

	fprintf('\n############ HSM TIMING BENCHMARK ############\n');
	fprintf('States: A(%.0fms)->B->C  cycling %d times -> end  (realTime, GetSecs)\n\n', ...
		stateTime*1e3, N);

	for ci = 1:length(classes)
		cls = classes{ci};
		cycleCount = 0;                       %> reset cycle counter per run
		workVec = randn(64,1);
		entryFcn = { @()workFcn() };
		exitFcn  = { @()workFcn() };
		withinFcn = {};
		% C's entry increments the visit counter; its transitionFcn checks
		% the counter and returns 'end' once N cycles are complete. This
		% counts state VISITS, not per-tick calls.
		cEntryFcn = { @()workFcn(), @()incrCycle() };
		cTrans = { @()checkCycle(N, 'end') };
		states = {
			'name' 'next' 'time'     'entryFcn' 'withinFcn' 'transitionFcn' 'exitFcn' 'HED';
			'A'    'B'     stateTime entryFcn   {}          {}              exitFcn  'X';
			'B'    'C'     stateTime entryFcn   {}          {}              exitFcn  'X';
			'C'    'A'     stateTime cEntryFcn  {}          cTrans          exitFcn  'X';
			'end'  ''      stateTime entryFcn   {}          {}              exitFcn  'X';
			};
		sm = feval(cls, 'realTime', true, 'timeDelta', 0, ...
			'clockFcn', @GetSecs, 'verbose', false, 'fnTimers', true, 'name', cls);
		addStates(sm, states);
		t0 = tic;
		run(sm);
		wallTime = toc(t0);
		results.(cls) = analyseLog(sm.log, sm.log.n, stateTime, warmupCycles);
		results.(cls).wallTime = wallTime;
		results.(cls).nVisits = sm.log.n;
		fprintf('  ran %-22s  %d visits  %.3f s\n', cls, sm.log.n, wallTime);
	end

	%> bonus: nested HSM run (3-level depth) to show hierarchy cost
	for ci = 2:length(classes)
		cls = classes{ci};
		cycleCount = 0;
		workVec = randn(64,1);
		entryFcn = { @()workFcn() };
		exitFcn  = { @()workFcn() };
		cEntryFcn = { @()workFcn(), @()incrCycle() };
		cTrans = { @()checkCycle(N, 'end') };
		nestStates = {
			'name' 'next' 'time'    'parent' 'entryFcn' 'withinFcn' 'transitionFcn' 'exitFcn' 'HED';
			'root' ''     1e6       ''       {}        {}          {}          {}        'X';
			'mid'  ''     1e6       'root'   {}        {}          {}          {}        'X';
			'A'    'B'    stateTime 'mid'    entryFcn  {}          {}          exitFcn   'X';
			'B'    'C'    stateTime 'mid'    entryFcn  {}          {}          exitFcn   'X';
			'C'    'A'    stateTime 'mid'    cEntryFcn {}          cTrans      exitFcn   'X';
			'end'   ''    stateTime ''       entryFcn  {}          {}          exitFcn   'X';
			};
		sm = feval(cls, 'realTime', true, 'timeDelta', 0, ...
			'clockFcn', @GetSecs, 'verbose', false, 'fnTimers', true, 'name', [cls '-nested']);
		addStates(sm, nestStates);
		t0 = tic;
		run(sm);
		wallTime = toc(t0);
		key = [cls '_nested'];
		results.(key) = analyseLog(sm.log, sm.log.n, stateTime, warmupCycles);
		results.(key).wallTime = wallTime;
		results.(key).nVisits = sm.log.n;
		fprintf('  ran %-22s  %d visits  %.3f s\n', key, sm.log.n, wallTime);
	end

	printTable(results, classes);
	assertChecks(results, classes);
	fprintf('\n===== BENCHMARK COMPLETE: all timing checks passed =====\n');

	%==================== nested helper functions ====================
	%> increment the cycle visit counter (called from C's entryFcn).
	%> Shares cycleCount with the parent scope.
	function incrCycle()
		cycleCount = cycleCount + 1;
	end

	%> return endName once N cycles have been entered, else '' (lets the
	%> time-trigger loop via the state's `next` field). Shares cycleCount.
	function r = checkCycle(nCycles, endName)
		if cycleCount >= nCycles
			r = endName;
		else
			r = '';
		end
	end

	%> fixed-work function for entry/exit fns so feval timers are
	%> meaningful. Dot product + sort of a small vector. Shares workVec.
	function workFcn()
		s = sum(workVec .* workVec);
		[~, ~] = sort(workVec);
		if s < 0; s = 0; end %> prevent dead-code elimination
	end
end

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

function assertChecks(results, classes)
	%> Sanity bounds: HSM variants should not be wildly worse than flat.
	flat = results.(classes{1});
	for ci = 2:length(classes)
		r = results.(classes{ci});
		%> within-state overshoot: HSM polling latency within 1ms of flat
		assert(abs(r.overMean - flat.overMean) < 1e-3, ...
			'%s within-state overshoot drift > 1ms vs flat', classes{ci});
		%> inter-state gap: HSM transition overhead within 5ms of flat
		assert(r.gapMean - flat.gapMean < 5e-3, ...
			'%s inter-state gap mean > 5ms worse than flat', classes{ci});
		%> feval timers: HSM entry/exit chain within 5ms of flat
		assert(r.feEnterMean - flat.feEnterMean < 5, ...
			'%s fevalEnter mean > 5ms worse than flat', classes{ci});
		assert(r.feExitMean - flat.feExitMean < 5, ...
			'%s fevalExit mean > 5ms worse than flat', classes{ci});
		fprintf('  [OK] %s: timing within bounds of flat baseline\n', classes{ci});
	end
	%> nested variants: gap may be larger due to chain depth, but bounded
	for ci = 2:length(classes)
		k = [classes{ci} '_nested'];
		r = results.(k);
		assert(r.gapMean - flat.gapMean < 1e-3, ...
			'%s nested inter-state gap > 1ms worse than flat', classes{ci});
		fprintf('  [OK] %s (nested, depth 3): gap within 1ms of flat\n', classes{ci});
	end
end
