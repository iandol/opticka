% ========================================================================
%> @class StateNodeTest
%> @brief Class-based unit tests for stateNode.
%>
%> Tests tree construction, addChild, ancestors, lcaWith, effectiveField,
%> resolveLeaf, findByName, isAncestorOf, hasParentCycle, inheritFrom,
%> setFromStruct, and the lazy ancestor cache.
%>
%> stateNode is a pure handle class with no PTB dependencies, so all
%> tests run in CI.
%>
%> Run with:
%>   >> runtests('tests/StateNodeTest.m')
%>
%> Copyright (c) 2026 Ian Max Andolina — LGPL3, see LICENCE.md
% ========================================================================
classdef StateNodeTest < matlab.unittest.TestCase

	methods (TestClassSetup)
		function setupPath(testCase)
			%> Add Opticka to MATLAB path once for all tests.
			addOptickaToPath;
		end
	end

	methods (Test)
		% ===================================================================
		%> @brief Test basic construction with name-value pairs.
		% ===================================================================
		function testConstruction(testCase)
			node = stateNode('name', 'root', 'time', 2.0, 'next', 'childA');
			verifyEqual(testCase, node.name, 'root', 'name should be set');
			verifyEqual(testCase, node.time, 2.0, 'time should be set');
			verifyEqual(testCase, node.next, 'childA', 'next should be set');
			verifyEmpty(testCase, node.parent, 'root parent should be empty');
			verifyEmpty(testCase, node.children, 'should have no children');
			verifyEqual(testCase, node.index, 0, 'default index should be 0');
			verifyEqual(testCase, node.HED, 'Experiment_control', ...
				'default HED should be Experiment_control');
		end

		% ===================================================================
		%> @brief Test default construction with no arguments.
		% ===================================================================
		function testDefaultConstruction(testCase)
			node = stateNode;
			verifyEqual(testCase, node.name, '', 'default name should be empty');
			verifyEqual(testCase, node.time, 1, 'default time should be 1');
			verifyEqual(testCase, node.next, '', 'default next should be empty');
			verifyEmpty(testCase, node.entryFcn, 'default entryFcn should be empty');
			verifyEmpty(testCase, node.withinFcn, 'default withinFcn should be empty');
			verifyEmpty(testCase, node.transitionFcn, 'default transitionFcn should be empty');
			verifyEmpty(testCase, node.exitFcn, 'default exitFcn should be empty');
			verifyFalse(testCase, node.skipExitFcn, 'skipExitFcn should default false');
		end

		% ===================================================================
		%> @brief Test addChild sets parent and children correctly.
		% ===================================================================
		function testAddChild(testCase)
			root = stateNode('name', 'root');
			child1 = stateNode('name', 'child1');
			child2 = stateNode('name', 'child2');

			root.addChild(child1);
			root.addChild(child2);

			verifyEqual(testCase, length(root.children), 2, 'root should have 2 children');
			verifyEqual(testCase, root.children{1}.name, 'child1', 'first child name');
			verifyEqual(testCase, root.children{2}.name, 'child2', 'second child name');
			verifyTrue(testCase, child1.parent == root, 'child1 parent should be root');
			verifyTrue(testCase, child2.parent == root, 'child2 parent should be root');
		end

		% ===================================================================
		%> @brief Test addChild invalidates cached ancestors.
		% ===================================================================
		function testAddChildInvalidatesCache(testCase)
			root = stateNode('name', 'root');
			child = stateNode('name', 'child');
			grandchild = stateNode('name', 'grandchild');

			root.addChild(child);
			% Build the cache
			stack = child.ancestors;
			verifyEqual(testCase, length(stack), 2, 'child ancestors: root + child');

			% Now add grandchild — child's cache should remain valid
			% (we're adding to child, not changing child's parent)
			child.addChild(grandchild);
			stack = child.ancestors;
			verifyEqual(testCase, length(stack), 2, 'child ancestors should still be 2');

			% grandchild's ancestors should be 3: root, child, grandchild
			stack = grandchild.ancestors;
			verifyEqual(testCase, length(stack), 3, 'grandchild ancestors should be 3');
			verifyEqual(testCase, stack{1}.name, 'root', 'first ancestor should be root');
			verifyEqual(testCase, stack{2}.name, 'child', 'second ancestor should be child');
			verifyEqual(testCase, stack{3}.name, 'grandchild', 'third should be grandchild');
		end

		% ===================================================================
		%> @brief Test ancestors returns [root .. self] ordering.
		% ===================================================================
		function testAncestorsOrdering(testCase)
			a = stateNode('name', 'A');
			b = stateNode('name', 'B');
			c = stateNode('name', 'C');
			a.addChild(b);
			b.addChild(c);

			stack = c.ancestors;
			verifyEqual(testCase, length(stack), 3, 'should have 3 ancestors');
			verifyEqual(testCase, stack{1}.name, 'A', 'first should be root A');
			verifyEqual(testCase, stack{2}.name, 'B', 'second should be B');
			verifyEqual(testCase, stack{3}.name, 'C', 'third should be C (self)');
		end

		% ===================================================================
		%> @brief Test ancestors cache is reused (lazy cache).
		% ===================================================================
		function testAncestorsCache(testCase)
			root = stateNode('name', 'root');
			child = stateNode('name', 'child');
			root.addChild(child);

			% Before first call, cache should be empty
			verifyEmpty(testCase, child.cachedAncestors, ...
				'cache should be empty before first call');

			% First call builds cache
			stack1 = child.ancestors;
			verifyEqual(testCase, length(child.cachedAncestors), 2, ...
				'cache should have 2 entries after first call');

			% Second call should return the cached value
			stack2 = child.ancestors;
			verifyEqual(testCase, stack1, stack2, 'cached result should match first call');
		end

		% ===================================================================
		%> @brief Test resolveLeaf returns the deepest first-child.
		% ===================================================================
		function testResolveLeaf(testCase)
			root = stateNode('name', 'root');
			child = stateNode('name', 'child');
			grandchild = stateNode('name', 'grandchild');
			root.addChild(child);
			child.addChild(grandchild);

			leaf = root.resolveLeaf;
			verifyEqual(testCase, leaf.name, 'grandchild', ...
				'resolveLeaf should return the deepest first child');

			% A leaf node resolves to itself
			leaf2 = grandchild.resolveLeaf;
			verifyTrue(testCase, leaf2 == grandchild, 'leaf should resolve to itself');
		end

		% ===================================================================
		%> @brief Test resolveLeaf with no children returns self.
		% ===================================================================
		function testResolveLeafNoChildren(testCase)
			node = stateNode('name', 'solo');
			leaf = node.resolveLeaf;
			verifyTrue(testCase, leaf == node, 'node with no children should resolve to self');
		end

		% ===================================================================
		%> @brief Test effectiveField resolves inherited values.
		% ===================================================================
		function testEffectiveFieldInheritance(testCase)
			root = stateNode('name', 'root');
			root.entryFcn = {@() disp('root entry')};
			child = stateNode('name', 'child');
			root.addChild(child);

			% Child has empty entryFcn, should inherit from root
			val = child.effectiveField('entryFcn');
			verifyFalse(testCase, isempty(val), 'child should inherit entryFcn from root');
			verifyEqual(testCase, val, root.entryFcn, 'inherited value should match root');

			% Child with its own value should return its own
			child.withinFcn = {@() disp('child within')};
			val = child.effectiveField('withinFcn');
			verifyEqual(testCase, val, child.withinFcn, 'should return own value when set');
		end

		% ===================================================================
		%> @brief Test effectiveField returns empty when no ancestor has
		%> the field set.
		% ===================================================================
		function testEffectiveFieldEmpty(testCase)
			root = stateNode('name', 'root');
			child = stateNode('name', 'child');
			root.addChild(child);

			val = child.effectiveField('entryFcn');
			verifyEmpty(testCase, val, 'should return empty when no ancestor has entryFcn');
		end

		% ===================================================================
		%> @brief Test isAncestorOf detects ancestor relationships.
		% ===================================================================
		function testIsAncestorOf(testCase)
			a = stateNode('name', 'A');
			b = stateNode('name', 'B');
			c = stateNode('name', 'C');
			a.addChild(b);
			b.addChild(c);

			verifyTrue(testCase, a.isAncestorOf(c), 'A should be ancestor of C');
			verifyTrue(testCase, a.isAncestorOf(b), 'A should be ancestor of B');
			verifyTrue(testCase, b.isAncestorOf(c), 'B should be ancestor of C');
			verifyFalse(testCase, c.isAncestorOf(a), 'C should not be ancestor of A');
			verifyFalse(testCase, b.isAncestorOf(a), 'B should not be ancestor of A');
			verifyTrue(testCase, a.isAncestorOf(a), 'node should be ancestor of itself');
		end

		% ===================================================================
		%> @brief Test lcaWith computes lowest common ancestor.
		% ===================================================================
		function testLcaWith(testCase)
			root = stateNode('name', 'root');
			a = stateNode('name', 'A');
			b = stateNode('name', 'B');
			c = stateNode('name', 'C');
			d = stateNode('name', 'D');
			root.addChild(a);
			root.addChild(b);
			a.addChild(c);
			b.addChild(d);

			% LCA of C and D should be root
			lca = c.lcaWith(d);
			verifyEqual(testCase, lca.name, 'root', 'LCA of C and D should be root');

			% LCA of C and A should be A
			lca = c.lcaWith(a);
			verifyEqual(testCase, lca.name, 'A', 'LCA of C and A should be A');

			% LCA of C and C should be C
			lca = c.lcaWith(c);
			verifyEqual(testCase, lca.name, 'C', 'LCA of C and C should be C');
		end

		% ===================================================================
		%> @brief Test lcaWith returns empty for disconnected trees.
		% ===================================================================
		function testLcaWithDisconnected(testCase)
			root1 = stateNode('name', 'root1');
			root2 = stateNode('name', 'root2');

			lca = root1.lcaWith(root2);
			verifyEmpty(testCase, lca, 'LCA of disconnected nodes should be empty');
		end

		% ===================================================================
		%> @brief Test findByName does BFS search of subtree.
		% ===================================================================
		function testFindByName(testCase)
			root = stateNode('name', 'root');
			a = stateNode('name', 'A');
			b = stateNode('name', 'B');
			c = stateNode('name', 'C');
			root.addChild(a);
			root.addChild(b);
			a.addChild(c);

			% Find direct child
			found = root.findByName('A');
			verifyEqual(testCase, found.name, 'A', 'should find A');

			% Find grandchild
			found = root.findByName('C');
			verifyEqual(testCase, found.name, 'C', 'should find C under A');

			% Find root itself
			found = root.findByName('root');
			verifyEqual(testCase, found.name, 'root', 'should find root');

			% Non-existent
			found = root.findByName('Z');
			verifyEmpty(testCase, found, 'should return empty for non-existent name');
		end

		% ===================================================================
		%> @brief Test hasParentCycle detects self-references.
		% ===================================================================
		function testHasParentCycleNoCycle(testCase)
			root = stateNode('name', 'root');
			child = stateNode('name', 'child');
			root.addChild(child);

			verifyFalse(testCase, root.hasParentCycle, 'root should have no cycle');
			verifyFalse(testCase, child.hasParentCycle, 'child should have no cycle');
		end

		% ===================================================================
		%> @brief Test hasParentCycle detects a cycle.
		% ===================================================================
		function testHasParentCycleDetected(testCase)
			a = stateNode('name', 'A');
			b = stateNode('name', 'B');
			a.addChild(b);
			% Create a cycle: b.parent = a, a.parent = b
			a.parent = b;

			verifyTrue(testCase, a.hasParentCycle, 'should detect cycle A->B->A');
		end

		% ===================================================================
		%> @brief Test inheritFrom copies next and HED from parent.
		% ===================================================================
		function testInheritFrom(testCase)
			parent = stateNode('name', 'parent', 'next', 'defaultNext', 'HED', 'Parent-tag');
			child = stateNode('name', 'child');

			child.inheritFrom(parent);
			verifyEqual(testCase, child.next, 'defaultNext', 'child should inherit next from parent');
			verifyEqual(testCase, child.HED, 'Parent-tag', 'child should inherit HED from parent');
		end

		% ===================================================================
		%> @brief Test inheritFrom does not overwrite non-empty fields.
		% ===================================================================
		function testInheritFromPreservesExisting(testCase)
			parent = stateNode('name', 'parent', 'next', 'parentNext', 'HED', 'ParentHED');
			child = stateNode('name', 'child', 'next', 'childNext', 'HED', 'ChildHED');

			child.inheritFrom(parent);
			verifyEqual(testCase, child.next, 'childNext', 'should keep own next');
			verifyEqual(testCase, child.HED, 'ChildHED', 'should keep own HED');
		end

		% ===================================================================
		%> @brief Test inheritFrom with empty parent is a no-op.
		% ===================================================================
		function testInheritFromEmptyParent(testCase)
			child = stateNode('name', 'child', 'next', 'myNext');
			child.inheritFrom([]);
			verifyEqual(testCase, child.next, 'myNext', 'should be unchanged with empty parent');
		end

		% ===================================================================
		%> @brief Test setFromStruct copies fields from a struct.
		% ===================================================================
		function testSetFromStruct(testCase)
			node = stateNode('name', 'initial');
			s.name = 'fromStruct';
			s.next = 'nextState';
			s.time = 3.5;
			s.HED = 'Test-tag';
			s.skipExitFcn = true;
			s.entryFcn = {@() disp('entry')};

			node.setFromStruct(s);
			verifyEqual(testCase, node.name, 'fromStruct', 'name should be set from struct');
			verifyEqual(testCase, node.next, 'nextState', 'next should be set from struct');
			verifyEqual(testCase, node.time, 3.5, 'time should be set from struct');
			verifyEqual(testCase, node.HED, 'Test-tag', 'HED should be set from struct');
			verifyTrue(testCase, node.skipExitFcn, 'skipExitFcn should be set from struct');
			verifyEqual(testCase, length(node.entryFcn), 1, 'entryFcn should be set from struct');
		end

		% ===================================================================
		%> @brief Test setFromStruct ignores non-existent fields
		%> gracefully.
		% ===================================================================
		function testSetFromStructPartial(testCase)
			node = stateNode('name', 'initial', 'time', 1.0);
			s.name = 'updated';

			node.setFromStruct(s);
			verifyEqual(testCase, node.name, 'updated', 'name should be updated');
			verifyEqual(testCase, node.time, 1.0, 'time should remain unchanged');
		end

		% ===================================================================
		%> @brief Test a multi-level tree with multiple children per
		%> node, verifying ancestors and LCA across branches.
		% ===================================================================
		function testComplexTree(testCase)
			% Build:
			%        root
			%       /    \
			%      A      B
			%     / \      \
			%    C   D      E
			%   /
			%  F
			root = stateNode('name', 'root');
			a = stateNode('name', 'A');
			b = stateNode('name', 'B');
			c = stateNode('name', 'C');
			d = stateNode('name', 'D');
			e = stateNode('name', 'E');
			f = stateNode('name', 'F');

			root.addChild(a);
			root.addChild(b);
			a.addChild(c);
			a.addChild(d);
			b.addChild(e);
			c.addChild(f);

			% F's ancestors should be [root, A, C, F]
			stack = f.ancestors;
			verifyEqual(testCase, length(stack), 4, 'F should have 4 ancestors');
			verifyEqual(testCase, {stack{:}.name}, {'root', 'A', 'C', 'F'}, ...
				'F ancestor names should be root, A, C, F');

			% LCA of F and E should be root
			lca = f.lcaWith(e);
			verifyEqual(testCase, lca.name, 'root', 'LCA of F and E should be root');

			% LCA of F and D should be A
			lca = f.lcaWith(d);
			verifyEqual(testCase, lca.name, 'A', 'LCA of F and D should be A');

			% findByName from root should find E
			found = root.findByName('E');
			verifyEqual(testCase, found.name, 'E', 'should find E in the tree');

			% resolveLeaf from root should follow first children: A -> C -> F
			leaf = root.resolveLeaf;
			verifyEqual(testCase, leaf.name, 'F', 'resolveLeaf should reach F');
		end
	end
end
