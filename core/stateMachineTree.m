% ========================================================================
%> @class stateMachineTree
%> @brief hierarchical state machine built from a tree of stateNode handles.
%>
%> stateMachineTree extends stateMachine to support hierarchical (nested)
%> states using a handle-class tree (stateNode). Each state becomes a
%> stateNode with `parent`/`children` links. Nesting is N-level deep.
%>
%> This is the "Option 2" HSM variant. It differs from stateMachineHSM
%> (Option 1) in:
%>  - Data model: a tree of stateNode handles (parent/children links)
%>    vs a struct array with a `parent` name field.
%>  - Order-independent parent resolution: StateInfo rows may list a
%>    child before its parent; parent links are resolved in a second
%>    pass after all states are loaded.
%>  - Handle-based API: getParent/getChildren/isAncestorOf return
%>    stateNode handles; node.ancestors, node.lcaWith, node.resolveLeaf
%>    are available for programmatic introspection.
%>  - Field inheritance: a child with an empty `next` inherits the
%>    parent's `next`, and an empty `HED` inherits the parent's `HED`
%>    (active, build-time copy). Function fields use virtual inheritance
%>    via stateNode.effectiveField for introspection only.
%>
%> Runtime semantics (shared with stateMachineHSM):
%>  - The active configuration is a stack [root .. leaf]. Only the leaf
%>    is timed and logged; `currentState` mirrors the leaf.
%>  - WITHIN: each tick, every state on the active stack runs its
%>    withinFcn, root -> leaf.
%>  - TRANSITION: transitionFcn is evaluated leaf -> root; the first
%>    non-empty return wins. Returning a name -> external transition
%>    (exit chain to LCA, entry chain to target). `local:<name>` ->
%>    local transition (firing state not exited).
%>  - Entry/exit run for every state on the stack (chain execution).
%>
%> Backward compatibility: flat StateInfo files (no `parent` column) run
%> unchanged; every state is a root and behaviour degenerates to flat.
%>
%> To run a demo:
%> ~~~~~~~~~~~~~~~~~~~~~~
%> >> sm = stateMachineTree;
%> >> demoHSM(sm);
%> ~~~~~~~~~~~~~~~~~~~~~~
%>
%> Copyright ©2014-2026 Ian Max Andolina — released: LGPL3, see LICENCE.md
% ========================================================================
classdef stateMachineTree < stateMachine

	properties (SetAccess = protected, GetAccess = protected)
		%> map of state name -> stateNode handle
		nameMap
		%> cell array of root stateNode handles
		rootNodes cell = {}
		%> active stack of stateNode handles, root -> leaf
		currentStackNodes cell = {}
	end

	methods %------------------PUBLIC METHODS

		% ===================================================================
		%> @brief Class constructor
		% ===================================================================
		function me = stateMachineTree(varargin)
			args = optickaCore.addDefaults(varargin, struct('name','state machine tree'));
			me = me@stateMachine(args);
			me.parseArgs(args, me.allowedProperties);
			me.stateFields   = [me.stateFields,   "parent"];
			me.stateDefaults = [me.stateDefaults, {''}];
			reset(me);
			initialiseLog(me, 1);
		end

		% ===================================================================
		%> @brief add states from a cell-array table. Builds stateNode
		%> handles, populates the stateList mirror (via base addState),
		%> then resolves parent links in a second pass (order-independent).
		% ===================================================================
		function newStateIndexes = addStates(me, newStates)
			sz = size(newStates);
			newStates(1,:) = regexprep(newStates(1,:),'Fn$','Fcn');
			newStateIndexes = zeros(1, sz(1)-1);
			nodes = cell(1, sz(1)-1);
			% pass 1: add each state to stateList mirror + create node
			for ii = 2:sz(1)
				newState = cell2struct(newStates(ii,:), newStates(1,:), 2);
				if isfield(newState,'name') && ~isempty(newState.name)
					newStateIndexes(ii-1) = me.addState(newState);
					node = stateNode();
					node.setFromStruct(newState);
					node.index = newStateIndexes(ii-1);
					nodes{ii-1} = node;
					me.nameMap(newState.name) = node;
				end
			end
			% pass 2: resolve parent links + active inheritance
			for ii = 1:length(nodes)
				node = nodes{ii};
				if isempty(node); continue; end
				parentName = me.stateList(node.index).parent;
				if ~isempty(parentName)
					if isKey(me.nameMap, parentName)
						parentNode = me.nameMap(parentName);
						parentNode.addChild(node);
						if node.hasParentCycle
							warning('stateMachineTree: cycle detected in parent chain of "%s", treating as root', node.name);
							% detach: remove from parent's children, clear parent
							parentNode.children(cellfun(@(c) c == node, parentNode.children)) = [];
							node.parent = [];
							me.stateList(node.index).parent = '';
						else
							node.inheritFrom(parentNode);
						end
					else
						warning('stateMachineTree: state "%s" has unknown parent "%s", treating as root', node.name, parentName);
						me.stateList(node.index).parent = '';
					end
				else
					me.rootNodes{end+1} = node;
				end
			end
		end

		% ===================================================================
		%> @brief get the parent stateNode of a named state (or [] if root)
		% ===================================================================
		function parentNode = getParent(me, stateName)
			parentNode = [];
			if isKey(me.nameMap, char(stateName))
				parentNode = me.nameMap(char(stateName)).parent;
			end
		end

		% ===================================================================
		%> @brief get the child stateNodes of a named state
		% ===================================================================
		function children = getChildren(me, stateName)
			children = {};
			if isKey(me.nameMap, char(stateName))
				children = me.nameMap(char(stateName)).children;
			end
		end

		% ===================================================================
		%> @brief test whether a state is an ancestor of another
		% ===================================================================
		function tf = isAncestorOf(me, ancestorName, stateName)
			tf = false;
			if isKey(me.nameMap, char(ancestorName)) && isKey(me.nameMap, char(stateName))
				tf = me.nameMap(char(ancestorName)).isAncestorOf(me.nameMap(char(stateName)));
			end
		end

		% ===================================================================
		%> @brief get the stateNode handle for a named state (or [] if missing)
		% ===================================================================
		function node = getNode(me, stateName)
			node = [];
			if isKey(me.nameMap, char(stateName))
				node = me.nameMap(char(stateName));
			end
		end

		% ===================================================================
		%> @brief return the active state stack as a struct array
		%> (root -> leaf). Empty when not running.
		% ===================================================================
		function stack = currentStateStack(me)
			stack = struct([]);
			if ~isempty(me.currentStackNodes)
				idxs = cellfun(@(n) n.index, me.currentStackNodes);
				stack = me.stateList(idxs);
			end
		end

		% ===================================================================
		%> @brief reset the object
		% ===================================================================
		function reset(me)
			reset@stateMachine(me);
			me.nameMap = containers.Map('KeyType','char','ValueType','any');
			me.rootNodes = {};
			me.currentStackNodes = {};
		end

		% ===================================================================
		%> @brief demo of a hierarchical state machine with 3-level nesting
		% ===================================================================
		function demoHSM(me)
			oldVerbose = me.verbose;
			oldTimers = me.fnTimers;
			me.verbose = true;
			me.fnTimers = true;
			fprintf('\n===>>> stateMachineTree Demo (3-level nesting, node tree)\n\n');
			trialEntry  = { @()fprintf('\ttrial: enter\n') };
			trialExit   = { @()fprintf('\ttrial: exit\n') };
			trialWithin = { @()fprintf('.') };
			fixEntry    = { @()fprintf('\t\tfixate: enter\n') };
			fixExit     = { @()fprintf('\t\tfixate: exit\n') };
			holdEntry   = { @()fprintf('\t\t\thold: enter\n') };
			holdExit    = { @()fprintf('\t\t\thold: exit\n') };
			trialTrans  = { @()sprintf('') };
			holdNext    = 'reward';
			rewEntry    = { @()fprintf('\treward: enter\n') };
			rewExit     = { @()fprintf('\treward: exit\n') };
			% note: child 'hold' listed BEFORE parent 'fixate' (order-independent)
			statesInfo = {
				'name'    'next'  'time' 'parent' 'entryFcn'   'withinFcn'   'transitionFcn' 'exitFcn'  'HED';
				'hold'    holdNext 0.3   'fixate' holdEntry    {}            {}              holdExit   'Experiment_control';
				'fixate'  ''      5      'trial'  fixEntry     {}            {}              fixExit    'Experiment_control';
				'trial'   ''      10     ''       trialEntry   trialWithin   trialTrans      trialExit  'Experiment_control';
				'reward'  ''      0.3    ''       rewEntry     {}            {}              rewExit    'Experiment_control';
				};
			addStates(me, statesInfo);
			disp('>--------------------------------------------------')
			disp(' HSM demo state table (child listed before parent!):  ')
			disp(statesInfo)
			disp('>--------------------------------------------------')
			me.waitFcn(0.3);
			me.timeDelta = 1e-4; me.realTime = false; me.waitFcn = @()( []);
			run(me);
			me.waitFcn(0.3);
			showLog(me);
			disp('>--------------------------------------------------')
			reset(me);
			me.verbose = oldVerbose;
			me.fnTimers = oldTimers;
		end
	end

	methods %------------------PUBLIC (update override)
		% ===================================================================
		%> @brief update the state machine, HSM-aware within/transition
		%> (node-based). Must be public to match the superclass.
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
				stack = me.currentStackNodes;
				transitioned = false;
				for k = length(stack):-1:1
					node = stack{k};
					tcn = node.transitionFcn;
					if ~isempty(tcn)
						tname = strtok(tcn{1}());
						if ~isempty(tname)
							isLocal = startsWith(tname, 'local:');
							if isLocal; tname = strtrim(tname(7:end)); end
							if ~isempty(tname) && isStateName(me, tname)
								if isLocal
									me.transitionToStateWithName(['local:' tname], node);
								else
									me.transitionToStateWithName(tname, node);
								end
								transitioned = true; break
							elseif strcmp(tname, 'tempNextState') && ~isempty(me.tempNextState) && isStateName(me, me.tempNextState)
								me.transitionToStateWithName(me.tempNextState, node);
								transitioned = true; break
							end
						end
					end
				end
				if ~transitioned
					for k = 1:length(stack)
						node = stack{k};
						for jj = 1:length(node.withinFcn)
							feval(node.withinFcn{jj});
						end
					end
				end
			end
		end
	end

	methods (Access = protected) %-------PROTECTED METHODS-----%

		% ===================================================================
		%> @brief transition to a named state (HSM external/local semantics)
		%> @param nextName target state name (optionally prefixed `local:`)
		%> @param firingNode stateNode whose transitionFcn fired
		% ===================================================================
		function transitionToStateWithName(me, nextName, firingNode)
			if ~exist('firingNode','var') || isempty(firingNode)
				firingNode = me.currentStackNodes{end};
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
			dstNode = me.nameMap(nextName);
			dstLeaf = dstNode.resolveLeaf;
			srcLeaf = me.currentStackNodes{end};
			srcStack = srcLeaf.ancestors;
			dstStack = dstLeaf.ancestors;
			lcaNode = srcLeaf.lcaWith(dstLeaf);
			if isLocal
				if firingNode.isAncestorOf(dstLeaf) && firingNode ~= dstLeaf
					lcaNode = firingNode;
				else
					lcaNode = srcLeaf.lcaWith(dstLeaf);
				end
			end
			me.exitChainToLCA(srcStack, lcaNode, nextName);
			me.enterChainFromLCA(dstStack, lcaNode, dstLeaf);
		end

		% ===================================================================
		%> @brief enter a state index (resolves to leaf, enters full stack
		%> from root). Used by start() and the error-recovery path.
		% ===================================================================
		function enterStateAtIndex(me, thisIndex)
			if me.nStates >= thisIndex
				name = me.stateList(thisIndex).name;
				dstNode = me.nameMap(name);
				dstLeaf = dstNode.resolveLeaf;
				dstStack = dstLeaf.ancestors;
				me.enterChainFromLCA(dstStack, [], dstLeaf);
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
			srcStack = me.currentStackNodes{end}.ancestors;
			me.exitChainToLCA(srcStack, [], '');
			me.currentStackNodes = {};
		end

		% ===================================================================
		%> @brief run exitFcn for nodes from leaf up to (not incl) the LCA,
		%> then write a single log row for the exiting leaf.
		% ===================================================================
		function exitChainToLCA(me, srcStack, lcaNode, nextName)
			if me.fnTimers; tx = tic; end
			% find LCA position in srcStack (handles lcaNode == [])
			lcaPos = 0;
			if ~isempty(lcaNode)
				for k = 1:length(srcStack)
					if srcStack{k} == lcaNode; lcaPos = k; break; end
				end
			end
			for k = length(srcStack):-1:(lcaPos+1)
				node = srcStack{k};
				skip = false;
				if ~isempty(me.skipExitStates)
					for i = 1:size(me.skipExitStates,1)
						if contains(node.name, me.skipExitStates{i,1}) && contains(nextName, me.skipExitStates{i,2})
							skip = true; break
						end
					end
				end
				if ~skip && ~node.skipExitFcn
					for jj = 1:length(node.exitFcn)
						feval(node.exitFcn{jj});
					end
				end
				node.skipExitFcn = false; % reset after use
			end
			if me.fnTimers
				me.log.fevalExit(me.thisN) = toc(tx)*1000;
				txs = tic;
			end
			me.writeLogForCurrent();
			if me.fnTimers
				me.log.fevalStore(me.thisN) = toc(txs)*1000;
			end
			me.tempNextState = '';
			if me.verbose
				me.logOutput(['EXIT: ' me.currentState.name ...
					' @ ' num2str(me.log.tnow(me.log.n)-me.log.startTime,'%.2f') ...
					's | state time: ' num2str(me.log.tnow(me.log.n)-me.log.entryTime(me.log.n),'%.2f') ...
					's | ' num2str(me.log.tick(me.log.n)) '/' num2str(me.totalTicks) ...
					' ticks'],'');
			end
		end

		% ===================================================================
		%> @brief run entryFcn (+ withinFcn once) for nodes from the LCA
		%> boundary down to the leaf, set timing on the leaf, install the
		%> new active stack. Increments thisN.
		% ===================================================================
		function enterChainFromLCA(me, dstStack, lcaNode, dstLeaf)
			me.thisN = me.thisN + 1;
			if me.thisN == 1; me.log.startTime = me.startTime; end
			if me.fnTimers; tt = tic; end
			lcaPos = 0;
			if ~isempty(lcaNode)
				for k = 1:length(dstStack)
					if dstStack{k} == lcaNode; lcaPos = k; break; end
				end
			end
			me.enterLeafTiming(dstLeaf.index);
			for k = (lcaPos+1):length(dstStack)
				me.runEntryFcnsNode(dstStack{k});
			end
			me.currentStackNodes = dstStack;
			if me.fnTimers; me.log.fevalEnter(me.thisN) = toc(tt)*1000; end
			if me.verbose
				me.logOutput(['ENTER: ' me.currentState.name ...
					' @ ' num2str(me.currentEntryTime-me.startTime, ...
					'%.2f') 's - ' num2str(me.totalTicks) ' ticks'],'');
			end
		end

		% ===================================================================
		%> @brief run a node's entryFcn then withinFcn
		% ===================================================================
		function runEntryFcnsNode(me, node)
			for jj = 1:length(node.entryFcn)
				feval(node.entryFcn{jj});
			end
			for jj = 1:length(node.withinFcn)
				feval(node.withinFcn{jj});
			end
		end

	end
end
