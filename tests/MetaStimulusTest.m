% ========================================================================
%> @class MetaStimulusTest
%> @brief Class-based unit tests for metaStimulus.
%>
%> Tests construction, stimulus management (add/show/hide/showSet),
%> cell indexing, n/nMask dependent properties, mask handling,
%> stimulusSets, edit, and reset. CI-safe tests run without PTB;
%> hardware-tagged tests exercise setup/draw/animate/update with a
%> real PTB window.
%>
%> Run with:
%>   >> runtests('tests/MetaStimulusTest.m')
%>   >> runtests('tests/MetaStimulusTest.m', '-ExcludeTag', 'hardware')
%>
%> Copyright (c) 2026 Ian Max Andolina — LGPL3, see LICENCE.md
% ========================================================================
classdef MetaStimulusTest < matlab.unittest.TestCase

	methods (TestClassSetup)
		function setupPath(testCase)
			addOptickaToPath;
		end
	end

	% ===================================================================
	% CI-SAFE TESTS
	% ===================================================================
	methods (Test)
		function testConstructionDefaults(testCase)
			ms = metaStimulus('verbose', false);
			verifyEmpty(testCase, ms.stimuli, 'default stimuli should be empty');
			verifyEmpty(testCase, ms.maskStimuli, 'default maskStimuli should be empty');
			verifyFalse(testCase, ms.showMask, 'default showMask should be false');
			verifyEqual(testCase, ms.family, 'meta', 'family should be meta');
			verifyEqual(testCase, ms.setChoice, 0, 'default setChoice should be 0');
			verifyEqual(testCase, ms.name, 'metaStimulus', 'default name');
		end

		function testNIsZeroByDefault(testCase)
			ms = metaStimulus('verbose', false);
			verifyEqual(testCase, ms.n, 0, 'n should be 0 with no stimuli');
			verifyEqual(testCase, ms.nMask, 0, 'nMask should be 0 with no masks');
		end

		function testAddStimuli(testCase)
			ms = metaStimulus('verbose', false);
			d1 = discStimulus('verbose', false, 'name', 'disc1');
			d2 = discStimulus('verbose', false, 'name', 'disc2');
			ms.stimuli = {d1 d2};
			verifyEqual(testCase, ms.n, 2, 'n should be 2');
		end

		function testAddMaskStimuli(testCase)
			ms = metaStimulus('verbose', false);
			d1 = discStimulus('verbose', false);
			d2 = discStimulus('verbose', false);
			ms.maskStimuli = {d1 d2};
			verifyEqual(testCase, ms.nMask, 2, 'nMask should be 2');
		end

		function testShowHide(testCase)
			ms = metaStimulus('verbose', false);
			d1 = discStimulus('verbose', false, 'name', 'd1');
			d2 = discStimulus('verbose', false, 'name', 'd2');
			ms.stimuli = {d1 d2};
			assert(ms.n == 2); % initialise n_ cache
			hide(ms);
			verifyFalse(testCase, d1.isVisible, 'd1 should be hidden');
			verifyFalse(testCase, d2.isVisible, 'd2 should be hidden');
			show(ms);
			verifyTrue(testCase, d1.isVisible, 'd1 should be visible');
			verifyTrue(testCase, d2.isVisible, 'd2 should be visible');
		end

		function testShowSpecificStimulus(testCase)
			ms = metaStimulus('verbose', false);
			d1 = discStimulus('verbose', false, 'name', 'd1');
			d2 = discStimulus('verbose', false, 'name', 'd2');
			ms.stimuli = {d1 d2};
			assert(ms.n == 2); % initialise n_ cache
			hide(ms);
			show(ms, 1);
			verifyTrue(testCase, d1.isVisible, 'd1 should be visible');
			verifyFalse(testCase, d2.isVisible, 'd2 should remain hidden');
		end

		function testHideSpecificStimulus(testCase)
			ms = metaStimulus('verbose', false);
			d1 = discStimulus('verbose', false);
			d2 = discStimulus('verbose', false);
			ms.stimuli = {d1 d2};
			hide(ms, 2);
			verifyTrue(testCase, d1.isVisible, 'd1 should still be visible');
			verifyFalse(testCase, d2.isVisible, 'd2 should be hidden');
		end

		function testShowSet(testCase)
			ms = metaStimulus('verbose', false);
			d1 = discStimulus('verbose', false);
			d2 = discStimulus('verbose', false);
			d3 = discStimulus('verbose', false);
			ms.stimuli = {d1 d2 d3};
			ms.stimulusSets = {[1], [2 3]};
			assert(ms.n == 3); % initialise n_ cache
			showSet(ms, 1);
			verifyTrue(testCase, d1.isVisible, 'd1 in set 1 should be visible');
			verifyFalse(testCase, d2.isVisible, 'd2 not in set 1 should be hidden');
			verifyFalse(testCase, d3.isVisible, 'd3 not in set 1 should be hidden');
			showSet(ms, 2);
			verifyFalse(testCase, d1.isVisible, 'd1 not in set 2 should be hidden');
			verifyTrue(testCase, d2.isVisible, 'd2 in set 2 should be visible');
			verifyTrue(testCase, d3.isVisible, 'd3 in set 2 should be visible');
		end

		function testShowSetZeroNoOp(testCase)
			ms = metaStimulus('verbose', false);
			d1 = discStimulus('verbose', false);
			ms.stimuli = {d1};
			ms.stimulusSets = {[1]};
			show(ms);
			showSet(ms, 0); % should be no-op
			verifyTrue(testCase, d1.isVisible, 'd1 should still be visible');
		end

		function testEdit(testCase)
			ms = metaStimulus('verbose', false);
			d1 = discStimulus('verbose', false);
			d2 = discStimulus('verbose', false);
			ms.stimuli = {d1 d2};
			edit(ms, [1 2], 'size', 8);
			verifyEqual(testCase, d1.size, 8, 'd1 size should be 8');
			verifyEqual(testCase, d2.size, 8, 'd2 size should be 8');
		end

		function testReset(testCase)
			ms = metaStimulus('verbose', false);
			d1 = discStimulus('verbose', false);
			ms.stimuli = {d1};
			% reset should not error even without setup
			reset(ms);
			verifyTrue(testCase, true, 'reset completed without error');
		end

		function testUUID(testCase)
			ms = metaStimulus('verbose', false);
			verifyTrue(testCase, ~isempty(ms.uuid), 'should have UUID');
		end

		function testFullName(testCase)
			ms = metaStimulus('verbose', false, 'name', 'MyMeta');
			verifyTrue(testCase, contains(ms.fullName, 'MyMeta'), 'fullName contains name');
			verifyTrue(testCase, contains(ms.fullName, 'metaStimulus'), 'fullName contains class');
		end

		function testShowMaskProperty(testCase)
			ms = metaStimulus('verbose', false);
			verifyFalse(testCase, ms.showMask, 'showMask should be false by default');
			ms.showMask = true;
			verifyTrue(testCase, ms.showMask, 'showMask should be true');
		end

		function testStimulusTable(testCase)
			ms = metaStimulus('verbose', false);
			d1 = discStimulus('verbose', false);
			ms.stimuli = {d1};
			ms.stimulusTable = struct('stimuli', {1}, 'name', 'size', ...
				'values', {4}, 'offset', []);
			verifyEqual(testCase, length(ms.stimulusTable), 1, 'should have 1 table entry');
		end
	end

	% ===================================================================
	% HARDWARE TESTS
	% ===================================================================
	methods (Test, TestTags = {'hardware'})
		function testSetupDrawAnimateUpdate(testCase)
			assumeFalse(testCase, ~isempty(getenv('GITHUB_ACTIONS')), 'Skip in CI');
			sM = screenManager; sM.windowed = [0 0 800 600];
			sM.disableSyncTests = true; sM.visualDebug = true; sM.bitDepth = '8bit';
			open(sM); cleanup = onCleanup(@() close(sM));
			d1 = discStimulus('verbose', false, 'size', 4, 'xPosition', -3);
			d2 = discStimulus('verbose', false, 'size', 4, 'xPosition', 3);
			ms = metaStimulus('verbose', false);
			ms.stimuli = {d1 d2};
			setup(ms, sM);
			verifyTrue(testCase, d1.isSetup, 'd1 should be setup');
			verifyTrue(testCase, d2.isSetup, 'd2 should be setup');
			draw(ms);
			verifyEqual(testCase, d1.drawTick, 1, 'd1 drawTick should be 1');
			verifyEqual(testCase, d2.drawTick, 1, 'd2 drawTick should be 1');
			animate(ms);
			update(ms);
			verifyTrue(testCase, true, 'animate and update completed');
			reset(ms);
		end

		function testSetupWithMasks(testCase)
			assumeFalse(testCase, ~isempty(getenv('GITHUB_ACTIONS')), 'Skip in CI');
			sM = screenManager; sM.windowed = [0 0 800 600];
			sM.disableSyncTests = true; sM.visualDebug = true; sM.bitDepth = '8bit';
			open(sM); cleanup = onCleanup(@() close(sM));
			d1 = discStimulus('verbose', false, 'size', 4);
			m1 = discStimulus('verbose', false, 'size', 6, 'colour', [1 1 1 0.5]);
			ms = metaStimulus('verbose', false);
			ms.stimuli = {d1};
			ms.maskStimuli = {m1};
			setup(ms, sM);
			verifyTrue(testCase, d1.isSetup, 'd1 should be setup');
			verifyTrue(testCase, m1.isSetup, 'm1 should be setup');
			verifyEqual(testCase, ms.n, 1, 'should have 1 stimulus');
			verifyEqual(testCase, ms.nMask, 1, 'should have 1 mask');
			reset(ms);
		end

		function testDrawWithMask(testCase)
			assumeFalse(testCase, ~isempty(getenv('GITHUB_ACTIONS')), 'Skip in CI');
			sM = screenManager; sM.windowed = [0 0 800 600];
			sM.disableSyncTests = true; sM.visualDebug = true; sM.bitDepth = '8bit';
			open(sM); cleanup = onCleanup(@() close(sM));
			d1 = discStimulus('verbose', false, 'size', 4);
			m1 = discStimulus('verbose', false, 'size', 6);
			ms = metaStimulus('verbose', false);
			ms.stimuli = {d1};
			ms.maskStimuli = {m1};
			setup(ms, sM);
			% Draw normal stimuli
			draw(ms);
			verifyEqual(testCase, d1.drawTick, 1, 'd1 should be drawn');
			verifyEqual(testCase, m1.drawTick, 0, 'm1 should not be drawn');
			% Draw with mask
			ms.showMask = true;
			draw(ms);
			verifyGreaterThan(testCase, m1.drawTick, 0, 'm1 should be drawn when showMask');
			reset(ms);
		end
	end
end
