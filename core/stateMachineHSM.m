% ========================================================================
%> @class stateMachineHSM
%> @brief hierarchical state machine (HSM) with parent/child nesting.
%>
%> stateMachineHSM extends stateMachine to support hierarchical (nested)
%> states. Each state may declare a `parent` field (a state name). A state
%> with an empty parent is a top-level (root) state. A state with a parent
%> becomes a child; multiple children may share one parent and nesting is
%> N-level deep (root > parent > child > grandchild ...).
%>
%> Semantics:
%>  - The active configuration is a stack [root .. leaf]. Only the leaf
%>    is timed and logged; `currentState` mirrors the leaf so existing
%>    readers (runExperiment) work unchanged.
%>  - WITHIN: each tick, every state on the active stack runs its
%>    withinFcn, root -> leaf.
%>  - TRANSITION: each tick, transitionFcn is evaluated leaf -> root;
%>    the first non-empty return wins. Returning a state name triggers an
%>    external transition (exit chain up to the lowest common ancestor,
%>    entry chain down to target). Returning `local:<name>` triggers a
%>    local transition (the firing state is not exited; target must be
%>    within the firing state's subtree).
%>  - Time-trigger transitions (state.time expiring) and tempNextState
%>    use external semantics with the leaf as source.
%>  - Entry: on entering a target, entryFcn (then withinFcn once) runs
%>    for every state on the new stack from the LCA boundary down to the
%>    leaf, root -> leaf.
%>  - Exit: on exiting, exitFcn runs for every state from the leaf up to
%>    (not including) the LCA, leaf -> root.
%>
%> Backward compatibility:
%>  - If no state declares a parent, every state is a root, the active
%>    stack is always [currentIndex], and all behaviour degenerates to
%>    the flat stateMachine. Existing StateInfo cell-array files run
%>    unchanged (the `parent` column is optional; missing -> '').
%>
%> To run a demo:
%> ~~~~~~~~~~~~~~~~~~~~~~
%> >> sm = stateMachineHSM;
%> >> demoHSM(sm);
%> ~~~~~~~~~~~~~~~~~~~~~~
%>
%> Copyright ©2014-2026 Ian Max Andolina — released: LGPL3, see LICENCE.md
% ========================================================================
classdef stateMachineHSM < stateMachine

	properties (SetAccess = protected, GetAccess = protected)
		%> map of state name -> cell array of child state names
		childMap
		%> active stack of state indices, root -> leaf
		currentStack double = []
		%> log row number (thisN) for each position on the current stack.
		%> Used to update parent log entries on exit.
		stackLogN double = []
		%> me.totalTicks at entry time for each position on the current
		%> stack. Used to compute per-state tick count at exit.
		stackEntryTicks double = []
	end

	methods %------------------PUBLIC METHODS
		% ===================================================================
		%> @brief Class constructor
		%> @param args property struct parsed by optickaCore.addDefaults
		%> @return instance of stateMachineHSM
		% ===================================================================
		function me = stateMachineHSM(varargin)
			args = optickaCore.addDefaults(varargin, struct('name','state machine HSM'));
			me = me@stateMachine(args);
			me.parseArgs(args, me.allowedProperties);
			% extend the state schema with a `parent` field
			me.stateFields   = [me.stateFields,   "parent"];
			me.stateDefaults = [me.stateDefaults, {''}];
			% re-initialise with the extended schema
			reset(me);
			initialiseLog(me, 1);
		end

		% ===================================================================
		%> @brief get the parent name of a state (or '' if root)
		%> @param stateName name of a state
		%> @return parentName char, '' if root or unknown
		% ===================================================================
		function parentName = getParent(me, stateName)
			parentName = '';
			[isState, idx] = me.isStateName(stateName);
			if isState
				parentName = me.stateList(idx).parent;
			end
		end

		% ===================================================================
		%> @brief get the child state names of a state
		%> @param stateName name of a state
		%> @return children cell array of child state names (empty if none)
		% ===================================================================
		function children = getChildren(me, stateName)
			children = {};
			sname = char(stateName);
			if isKey(me.childMap, sname)
				children = me.childMap(sname);
			end
		end

		% ===================================================================
		%> @brief test whether a state is an ancestor of (or equal to) another
		%> @param ancestorName name of the candidate ancestor
		%> @param stateName name of the candidate descendant
		%> @return tf logical
		% ===================================================================
		function tf = isAncestorOf(me, ancestorName, stateName)
			tf = false;
			[isA, aIdx] = me.isStateName(ancestorName);
			[isB, bIdx] = me.isStateName(stateName);
			if isA && isB
				tf = me.isAncestorIndex(aIdx, bIdx);
			end
		end

		% ===================================================================
		%> @brief return the active state stack as a struct array
		%> (root -> leaf). Empty when not running.
		%> @return stack struct array of states on the active stack
		% ===================================================================
		function stack = currentStateStack(me)
			stack = struct([]);
			if ~isempty(me.currentStack)
				stack = me.stateList(me.currentStack);
			end
		end

		% ===================================================================
		%> @brief reset the object
		% ===================================================================
		function reset(me)
			reset@stateMachine(me);
			me.childMap = containers.Map('KeyType','char','ValueType','any');
			me.currentStack = [];
			me.stackLogN = [];
			me.stackEntryTicks = [];
		end

		% ===================================================================
		%> @brief demo of a hierarchical state machine with 3-level nesting
		% ===================================================================
		function demoHSM(me)
			oldVerbose = me.verbose;
			oldTimers = me.fnTimers;
			me.verbose = true;
			me.fnTimers = true;
			fprintf('\n===>>> stateMachineHSM Demo (3-level nesting)\n\n');
			% a parent "trial" with child "fixate" which has grandchild "hold"
			startEntry  = { @()fprintf('\tstart (root): enter\n') };
			startExit   = { @()fprintf('\tstart (root): exit\n') };
			trialEntry  = { @()fprintf('\ttrial (root): enter\n') };
			trialExit   = { @()fprintf('\ttrial (root): exit\n') };
			trialWithin = { @()fprintf('') };
			pfixEntry   = { @()fprintf('\t\tprefix (leaf): enter\n') };
			pfixExit    = { @()fprintf('\t\tprefix (leaf): exit\n') };
			fixEntry    = { @()fprintf('\t\tfixate (leaf): enter\n') };
			fixExit     = { @()fprintf('\t\tfixate (leaf): exit\n') };
			holdEntry   = { @()fprintf('\t\t\thold (leaf2): enter\n') };
			holdExit    = { @()fprintf('\t\t\thold (leaf2): exit\n') };
			% parent-level transition: abort the whole trial subtree
			trialTrans  = { @()sprintf('') }; % no abort in this demo
			% leaf transition: when hold time done, go to feedback (outside trial)
			fbEntry    = { @()fprintf('\feedback: enter\n') };
			fbExit     = { @()fprintf('\feedback: exit\n') };
			rewEntry    = { @()fprintf('\treward: enter\n') };
			rewExit     = { @()fprintf('\treward: exit\n') };
			statesInfo = {
				'name'    'next'     'time' 'parent'   'entryFcn'   'withinFcn'   'transitionFcn' 'exitFcn'  'HED';
				'start'   'trial'    0.25   ''         startEntry   {}            {}              startExit  'Experiment_control';
				'trial'   ''         10     ''         trialEntry   trialWithin   trialTrans      trialExit  'Experiment_control';
				'prefix'  'fixate'   1      'trial'    pfixEntry    {}            {}              pfixExit   'Experiment_control';
				'fixate'  ''         1      'trial'    fixEntry     {}            {}              fixExit    'Experiment_control';
				'hold'    'feedback' 1      'fixate'   holdEntry    {}            {}              holdExit   'Experiment_control';
				'feedback' ''        1      ''         fbEntry      {}            {}              fbExit     'Experiment_control';
				'reward'   ''        1      'feedback' rewEntry     {}            {}              rewExit    'Experiment_control';
				};
			addStates(me, statesInfo);
			disp('>--------------------------------------------------')
			disp(' HSM demo state table (note the parent column):  ')
			disp(statesInfo)
			disp('>--------------------------------------------------')
			me.waitFcn(0.5);
			run(me);
			me.waitFcn(0.5);
			showLog(me);
			disp('>--------------------------------------------------')
			reset(me);
			me.verbose = oldVerbose;
			me.fnTimers = oldTimers;
		end
		% ===================================================================
		%> @brief add a single state, extending base to maintain childMap
		%> and validate the parent hierarchy (no cycles, parent exists)
		% ===================================================================
		function newStateIndex = addState(me, newState)
			newStateIndex = addState@stateMachine(me, newState);
			name = me.stateList(newStateIndex).name;
			parent = me.stateList(newStateIndex).parent;
			if ~isempty(parent)
				if ~me.isStateName(parent)
					warning('stateMachineHSM: state "%s" has unknown parent "%s", treating as root', name, parent);
					me.stateList(newStateIndex).parent = '';
					return
				end
				if ~isKey(me.childMap, parent); me.childMap(parent) = {}; end
				kids = me.childMap(parent);
				kids{end+1} = name;
				me.childMap(parent) = kids;
				me.validateHierarchy(newStateIndex);
			end
		end

		% ===================================================================
		%> @brief update the state machine, HSM-aware within/transition
		% ===================================================================
		function update(me)
			if ~me.isRunning; return; end
			me.currentTick = me.currentTick + 1;
			me.totalTicks = me.totalTicks + 1;
			me.currentTime = me.clockFcn();
			if me.realTime
				trigger = me.currentTime >= me.nextTimeOut;
			else
				trigger = me.currentTick >= me.nextTickOut;
			end
			if trigger
				if ~isempty(me.tempNextState) && isStateName(me, me.tempNextState)
					me.transitionToStateWithName(me.tempNextState);
				elseif ~isempty(me.stateList(me.currentIndex).next)
					me.transitionToStateWithName(me.stateList(me.currentIndex).next);
				else
					me.exitCurrentState;
					me.isRunning = false;
					me.isFinishing = true;
					finish(me);
				end
			else
				stack = me.currentStack;
				transitioned = false;
				% evaluate transitionFcn leaf -> root
				for k = length(stack):-1:1
					st = me.stateList(stack(k));
					tcn = st.transitionFcn;
					if ~isempty(tcn)
						tname = strtok(tcn{1}());
						if ~isempty(tname)
							isLocal = startsWith(tname, 'local:');
							if isLocal; tname = strtrim(tname(7:end)); end
							if ~isempty(tname) && isStateName(me, tname)
								if isLocal
									me.transitionToStateWithName(['local:' tname], stack(k));
								else
									me.transitionToStateWithName(tname, stack(k));
								end
								transitioned = true; break
							elseif strcmp(tname, 'tempNextState') && ~isempty(me.tempNextState) && isStateName(me, me.tempNextState)
								me.transitionToStateWithName(me.tempNextState, stack(k));
								transitioned = true; break
							end
						end
					end
				end
				if ~transitioned
					% run withinFcn root -> leaf
					for k = 1:length(stack)
						st = me.stateList(stack(k));
						for jj = 1:length(st.withinFcn)
							feval(st.withinFcn{jj});
						end
					end
				end
			end
		end
	end

	methods (Access = protected) %-------PROTECTED METHODS-----%

		% ===================================================================
		%> @brief validate no cycle in the parent chain of a state
		% ===================================================================
		function validateHierarchy(me, idx)
			name = me.stateList(idx).name;
			p = me.stateList(idx).parent;
			visited = {name};
			while ~isempty(p)
				if any(strcmp(visited, p))
					warning('stateMachineHSM: cycle detected in parent chain of "%s", treating as root', name);
					me.stateList(idx).parent = '';
					return
				end
				visited{end+1} = p;
				pidx = me.stateListIndex(p);
				p = me.stateList(pidx).parent;
			end
		end

		% ===================================================================
		%> @brief resolve a state index to its deepest first-child leaf
		%> @param idx index into stateList
		%> @return leafIdx index of the leaf reached by following first children
		% ===================================================================
		function leafIdx = resolveLeaf(me, idx)
			name = me.stateList(idx).name;
			while true
				kids = me.getChildren(name);
				if isempty(kids); break; end
				name = kids{1};
				idx = me.stateListIndex(name);
			end
			leafIdx = idx;
		end

		% ===================================================================
		%> @brief build the ancestor stack [root .. idx] for a state index
		% ===================================================================
		function stack = ancestorStack(me, idx)
			stack = idx;
			p = me.stateList(idx).parent;
			while ~isempty(p)
				pidx = me.stateListIndex(p);
				stack = [pidx, stack];
				p = me.stateList(pidx).parent;
			end
		end

		% ===================================================================
		%> @brief test whether aIdx is an ancestor of (or equal to) bIdx
		% ===================================================================
		function tf = isAncestorIndex(me, aIdx, bIdx)
			tf = (aIdx == bIdx);
			p = me.stateList(bIdx).parent;
			while ~tf && ~isempty(p)
				pidx = me.stateListIndex(p);
				tf = (pidx == aIdx);
				p = me.stateList(pidx).parent;
			end
		end

		% ===================================================================
		%> @brief compute the lowest common ancestor index of two stacks.
		%> Returns 0 if they share no common ancestor (disjoint roots).
		% ===================================================================
		function lcaIdx = computeLCA(me, srcStack, dstStack)
			lcaIdx = 0;
			n = min(length(srcStack), length(dstStack));
			for k = 1:n
				if srcStack(k) == dstStack(k)
					lcaIdx = srcStack(k);
				else
					break
				end
			end
		end

		% ===================================================================
		%> @brief transition to a named state (HSM external/local semantics)
		%> @param nextName target state name (optionally prefixed `local:`)
		%> @param firingIdx index of the state whose transitionFcn fired
		%        (defaults to the active leaf)
		% ===================================================================
		function transitionToStateWithName(me, nextName, firingIdx)
			if ~exist('firingIdx','var') || isempty(firingIdx)
				firingIdx = me.currentStack(end);
			end
			if ~exist('nextName','var') || strcmpi(nextName,'useTemp'); nextName = me.tempNextState; end
			isLocal = startsWith(nextName, 'local:');
			if isLocal; nextName = strtrim(nextName(7:end)); end
			[isState, dstIdx] = isStateName(me, nextName);
			if ~isState
				me.logOutput('transitionToStateWithName method', ...
					['ERROR, could not find state: ' nextName '; default to return to first state!!!\n'], true);
				enterStateAtIndex(me, 1);
				return
			end
			dstLeaf = me.resolveLeaf(dstIdx);
			srcLeaf = me.currentStack(end);
			srcStack = me.ancestorStack(srcLeaf);
			dstStack = me.ancestorStack(dstLeaf);
			lcaIdx = me.computeLCA(srcStack, dstStack);
			if isLocal
				% local = the firing state is not exited. If the target is
				% within the firing state's subtree, clamp LCA to the firing
				% state so it (and ancestors) stay active. If the target is
				% outside the firing subtree, local degenerates to external.
				if me.isAncestorIndex(firingIdx, dstLeaf) && firingIdx ~= dstLeaf
					lcaIdx = firingIdx;
				else
					lcaIdx = me.computeLCA(srcStack, dstStack);
				end
			end
			me.exitChainToLCA(srcStack, lcaIdx, nextName);
			me.enterChainFromLCA(dstStack, lcaIdx, dstLeaf);
		end

		% ===================================================================
		%> @brief enter a state index (resolves to leaf, enters full stack
		%> from root). Used by start() and the error-recovery path.
		% ===================================================================
		function enterStateAtIndex(me, thisIndex)
			if me.nStates >= thisIndex
				dstLeaf = me.resolveLeaf(thisIndex);
				dstStack = me.ancestorStack(dstLeaf);
				me.enterChainFromLCA(dstStack, 0, dstLeaf);
			else
				if me.verbose; me.logOutput('enterStateAtIndex method', 'newIndex is greater than stateList length'); end
				me.isFinishing = true;
				finish(me);
			end
		end

		% ===================================================================
		%> @brief exit the entire active stack (used on finish / no-next)
		% ===================================================================
		function exitCurrentState(me)
			srcStack = me.currentStack;
			me.exitChainToLCA(srcStack, 0, '');
			me.currentStack = [];
		end

		% ===================================================================
		%> @brief run exitFcn for states from leaf up to (not incl) the LCA,
		%> then update each state's log entry with exit time/tick/timers.
		% ===================================================================
		function exitChainToLCA(me, srcStack, lcaIdx, nextName)
			if lcaIdx == 0
				lcaPos = 0;
			else
				lcaPos = find(srcStack == lcaIdx, 1);
				if isempty(lcaPos); lcaPos = 0; end
			end
			for k = length(srcStack):-1:(lcaPos+1)
				logN = me.stackLogN(k);
				st = me.stateList(srcStack(k));
				skip = false;
				if ~isempty(me.skipExitStates)
					for i = 1:size(me.skipExitStates,1)
						if contains(st.name, me.skipExitStates{i,1}) && contains(nextName, me.skipExitStates{i,2})
							skip = true; break
						end
					end
				end
				if me.fnTimers; tx = tic; end
				if ~skip
					for jj = 1:length(st.exitFcn)
						feval(st.exitFcn{jj});
					end
				end
				if me.fnTimers
					me.log.fevalExit(logN) = toc(tx)*1000;
					txs = tic;
				end
				% update this state's log entry with exit info
				me.log.tnow(logN) = me.currentTime;
				me.log.tick(logN) = me.totalTicks - me.stackEntryTicks(k);
				if k == length(srcStack)  % leaf
					me.log.nextTimeOut(logN) = me.nextTimeOut;
					me.log.nextTickOut(logN) = me.nextTickOut;
				end
				if me.fnTimers
					me.log.fevalStore(logN) = toc(txs)*1000;
				end
				if me.useExternalLog
					me.externalLog.addMessage(logN, me.log.entryTime(logN), ...
						me.currentTime, ...
						sprintf("State #%i Details: %s %s %g %g %.3f", logN, ...
							st.name, me.log.uuid{logN}, ...
							me.currentTime, me.log.entryTime(logN),...
							me.currentTime - me.log.entryTime(logN)), ...
						me.clockFcnName, ...
						"Event-stream, Time-block-state"+num2str(logN));
				end
				if me.verbose
					me.logOutput(['EXIT: ' st.name ...
						' @ ' num2str(me.log.tnow(logN)-me.log.startTime,'%.2f') ...
						's | state time: ' num2str(me.log.tnow(logN)-me.log.entryTime(logN),'%.2f') ...
						's | ' num2str(me.log.tick(logN)) '/' num2str(me.totalTicks) ...
						' ticks'],'');
				end
			end
			me.tempNextState = '';
		end

		% ===================================================================
		%> @brief run entryFcn (+ withinFcn once) for states from the LCA
		%> boundary down to the leaf, create a log entry per state, and
		%> install the new active stack. Increments thisN per state.
		% ===================================================================
		function enterChainFromLCA(me, dstStack, lcaIdx, dstLeaf)
			if lcaIdx == 0
				lcaPos = 0;
			else
				lcaPos = find(dstStack == lcaIdx, 1);
				if isempty(lcaPos); lcaPos = 0; end
			end
			stackLogN = NaN(1, length(dstStack));
			stackEntryTicks = NaN(1, length(dstStack));
			% preserve mapping for states above the LCA (still active)
			if lcaPos > 0 && ~isempty(me.stackLogN) && length(me.stackLogN) >= lcaPos
				stackLogN(1:lcaPos) = me.stackLogN(1:lcaPos);
				stackEntryTicks(1:lcaPos) = me.stackEntryTicks(1:lcaPos);
			end
			for k = (lcaPos+1):length(dstStack)
				me.thisN = me.thisN + 1;
				if me.thisN == 1; me.log.startTime = me.startTime; end
				stateIdx = dstStack(k);
				st = me.stateList(stateIdx);
				% set identity and timing for this state
				me.currentIndex = stateIdx;
				me.currentState = st;
				me.currentEntryTime = me.clockFcn();
				me.currentTick = 0;
				me.currentUUID = dec2hex(me.thisN);
				if k == length(dstStack)  % leaf: set timeout
					if length(st.time) == 2
						st.time = randi([st.time(1)*1e3, st.time(2)*1e3]) / 1e3;
					end
					me.nextTimeOut = me.currentEntryTime + st.time;
					me.nextTickOut = floor(st.time / me.timeDelta);
				end
				% run this state's entry+within fcn (timed individually)
				if me.fnTimers; tt = tic; end
				me.runEntryFcns(st);
				if me.fnTimers; me.log.fevalEnter(me.thisN) = toc(tt)*1000; end
				% write initial log entry for THIS state
				me.log.n = me.thisN;
				me.log.index(me.thisN) = stateIdx;
				me.log.name{me.thisN} = st.name;
				me.log.uuid{me.thisN} = me.currentUUID;
				me.log.entryTime(me.thisN) = me.currentEntryTime;
				% tnow, tick, nextTimeOut, nextTickOut filled on exit
				stackLogN(k) = me.thisN;
				stackEntryTicks(k) = me.totalTicks;
				if me.verbose
					me.logOutput(['ENTER: ' st.name ...
						' @ ' num2str(me.currentEntryTime-me.startTime, ...
						'%.2f') 's - ' num2str(me.totalTicks) ' ticks'],'');
				end
			end
			me.currentStack = dstStack;
			me.stackLogN = stackLogN;
			me.stackEntryTicks = stackEntryTicks;
		end

	end
end
