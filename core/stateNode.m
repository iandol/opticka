% ========================================================================
%> @class stateNode
%> @brief a single hierarchical state node (handle) for stateMachineTree.
%>
%> stateNode is a handle class representing one state in a hierarchical
%> state machine tree. Each node has a `parent` (another stateNode, or []
%> for a root) and a `children` cell array of stateNode handles. Nesting
%> is N-level deep.
%>
%> Field inheritance (virtual): a child with an empty function field
%> (entryFcn/withinFcn/transitionFcn/exitFcn) does not store a copy of
%> the parent's functions; instead `effectiveField(f)` walks up the tree
%> to report the inherited value for introspection. The HSM chain
%> execution runs each node's OWN functions only, so inheritance never
%> causes double execution.
%>
%> Active inheritance (build-time copy) is applied for the non-function
%> fields `next` and `HED`: a child with an empty `next` inherits the
%> parent's `next`, and an empty `HED` inherits the parent's `HED`. This
%> gives children a sensible default transition target / metadata tag
%> without redefining them.
%>
%> Copyright ©2014-2026 Ian Max Andolina — released: LGPL3, see LICENCE.md
% ========================================================================
classdef stateNode < handle

	properties
		%> state name (unique within a stateMachineTree)
		name char = ''
		%> parent stateNode handle, [] for a root state
		parent = []
		%> cell array of child stateNode handles
		children cell = {}
		%> index into the stateMachineTree.stateList mirror (runtime compat)
		index double = 0
		%> default next state name (external transition on time-trigger)
		next char = ''
		%> state duration (seconds). Only the active leaf's time drives triggers.
		time double = 1
		%> entry functions (run on entering this node)
		entryFcn cell = {}
		%> within functions (run each tick while this node is on the active stack)
		withinFcn cell = {}
		%> transition functions (return a state name to trigger a transition)
		transitionFcn cell = {}
		%> exit functions (run on exiting this node)
		exitFcn cell = {}
		%> skip this node's exitFcn on the next exit (set at runtime)
		skipExitFcn logical = false
		%> HED tag metadata
		HED char = 'Experiment_control'
	end

	methods

		% ===================================================================
		%> @brief construct a stateNode from name/value pairs
		% ===================================================================
		function obj = stateNode(varargin)
			for k = 1:2:nargin
				if isprop(obj, varargin{k})
					obj.(varargin{k}) = varargin{k+1};
				end
			end
		end

		% ===================================================================
		%> @brief copy state fields from a struct (as produced by addStates)
		%> @param s struct with fields name/next/time/entryFcn/withinFcn/
		%>        transitionFcn/exitFcn/skipExitFcn/HED
		% ===================================================================
		function setFromStruct(obj, s)
			fields = {'name','next','time','entryFcn','withinFcn', ...
				'transitionFcn','exitFcn','skipExitFcn','HED'};
			for i = 1:length(fields)
				f = fields{i};
				if isfield(s, f)
					obj.(f) = s.(f);
				end
			end
		end

		% ===================================================================
		%> @brief attach a child node to this node (sets child.parent)
		% ===================================================================
		function addChild(obj, child)
			child.parent = obj;
			obj.children{end+1} = child;
		end

		% ===================================================================
		%> @brief active inheritance: copy `next` and `HED` from parent if
		%> the child left them empty. Function fields are NOT copied (they
		%> are resolved virtually via effectiveField).
		% ===================================================================
		function inheritFrom(obj, parentNode)
			if isempty(parentNode); return; end
			if isempty(obj.next) && ~isempty(parentNode.next)
				obj.next = parentNode.next;
			end
			if isempty(obj.HED) && ~isempty(parentNode.HED)
				obj.HED = parentNode.HED;
			end
		end

		% ===================================================================
		%> @brief resolve a field's effective value by walking up the tree
		%> (virtual inheritance for introspection). Returns the node's own
		%> value if non-empty, else the nearest ancestor's, else [].
		%> @param fieldName char name of a function field
		% ===================================================================
		function val = effectiveField(obj, fieldName)
			val = obj.(fieldName);
			if ~isempty(val); return; end
			p = obj.parent;
			while ~isempty(p)
				val = p.(fieldName);
				if ~isempty(val); return; end
				p = p.parent;
			end
			val = [];
		end

		% ===================================================================
		%> @brief return the ancestor stack [root .. obj] as a cell array
		%> of stateNode handles
		% ===================================================================
		function stack = ancestors(obj)
			stack = {obj};
			p = obj.parent;
			while ~isempty(p)
				stack = [{p}, stack];
				p = p.parent;
			end
		end

		% ===================================================================
		%> @brief resolve to the deepest first-child leaf of this node
		% ===================================================================
		function leaf = resolveLeaf(obj)
			leaf = obj;
			while ~isempty(leaf.children)
				leaf = leaf.children{1};
			end
		end

		% ===================================================================
		%> @brief test whether this node is an ancestor of (or equal to) another
		% ===================================================================
		function tf = isAncestorOf(obj, other)
			tf = (obj == other);
			p = other.parent;
			while ~tf && ~isempty(p)
				tf = (p == obj);
				p = p.parent;
			end
		end

		% ===================================================================
		%> @brief compute the lowest common ancestor of this node and another.
		%> Returns [] if they share no common ancestor.
		% ===================================================================
		function lca = lcaWith(obj, other)
			a = obj.ancestors;
			b = other.ancestors;
			lca = [];
			n = min(length(a), length(b));
			for k = 1:n
				if a{k} == b{k}
					lca = a{k};
				else
					break
				end
			end
		end

		% ===================================================================
		%> @brief find a node by name within this node's subtree (BFS)
		% ===================================================================
		function node = findByName(obj, name)
			node = [];
			queue = {obj};
			while ~isempty(queue)
				cur = queue{1};
				queue(1) = [];
				if strcmp(cur.name, name); node = cur; return; end
				queue = [queue, cur.children];
			end
		end

		% ===================================================================
		%> @brief detect a cycle in this node's parent chain (self-reference)
		%> @return tf logical, true if cycling back to this node
		% ===================================================================
		function tf = hasParentCycle(obj)
			tf = false;
			p = obj.parent;
			hops = 0;
			while ~isempty(p)
				if p == obj; tf = true; return; end
				p = p.parent;
				hops = hops + 1;
				if hops > 1e4; return; end % safety
			end
		end
	end
end
