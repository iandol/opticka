% ========================================================================
%> @class TaskSequenceTest
%> @brief Class-based unit tests for taskSequence.
%>
%> Tests block-based variable randomisation, block/trial factors,
%> dependent properties, findRun, updateTask, resetRun, validate,
%> and sequential (non-randomised) mode.
%>
%> All tests use a fixed randomSeed for reproducibility and run
%> without PTB (no screen, no GetSecs). The updateTask method calls
%> GetSecs for runTime — we patch that by passing a fake runTime
%> argument.
%>
%> Run with:
%>   >> runtests('tests/TaskSequenceTest.m')
%>
%> Copyright (c) 2026 Ian Max Andolina — LGPL3, see LICENCE.md
% ========================================================================
classdef TaskSequenceTest < matlab.unittest.TestCase

	properties
		%> a taskSequence instance for reuse
		ts
	end

	methods (TestClassSetup)
		
	end

	methods (TestMethodSetup)
		function createTask(testCase)
			%> Create a fresh taskSequence with a known seed.
			testCase.ts = taskSequence('nBlocks', 2, 'randomSeed', 42, 'verbose', false);
		end
	end

	methods (Test, TestTags = {'CI'})
		% ===================================================================
		%> @brief Test default construction and dependent properties.
		% ===================================================================
		function testDefaultConstruction(testCase)
			ts = testCase.ts;
			verifyEqual(testCase, ts.nBlocks, 2, 'nBlocks should be 2');
			verifyTrue(testCase, ts.randomise, 'randomise should default true');
			verifyTrue(testCase, ts.realTime, 'realTime should default true');
			verifyFalse(testCase, ts.addBlank, 'addBlank should default false');
			verifyEqual(testCase, ts.randomGenerator, 'mt19937ar', ...
				'default RNG should be mt19937ar');
			verifyEqual(testCase, ts.nVars, 0, 'no variables defined yet');
			verifyEqual(testCase, ts.minTrials, 0, 'no trials without vars');
			verifyEqual(testCase, ts.nRuns, 0, 'nRuns = minTrials * nBlocks = 0');
			verifyFalse(testCase, ts.taskInitialised, 'should not be initialised');
			verifyFalse(testCase, ts.taskFinished, 'should not be finished');
			verifyNotEmpty(testCase, ts.uuid, 'uuid should be set by optickaCore');
		end

		% ===================================================================
		%> @brief Test nVar setting via the set.nVar method.
		% ===================================================================
		function testSetNVar(testCase)
			ts = testCase.ts;
			ts.nVar(1) = struct('name', 'contrast', 'values', [0 0.5 1], ...
				'stimulus', [1 2], 'offsetstimulus', [], 'offsetvalue', []);
			verifyEqual(testCase, ts.nVars, 1, 'should have 1 variable');
			verifyEqual(testCase, ts.minTrials, 3, 'minTrials = 3 values');
			verifyEqual(testCase, ts.nRuns, 6, 'nRuns = 3 * 2 blocks');

			% Add a second variable
			ts.nVar(2) = struct('name', 'angle', 'values', [-45 45], ...
				'stimulus', [1], 'offsetstimulus', [], 'offsetvalue', []);
			verifyEqual(testCase, ts.nVars, 2, 'should have 2 variables');
			verifyEqual(testCase, ts.minTrials, 6, 'minTrials = 3 * 2 = 6');
			verifyEqual(testCase, ts.nRuns, 12, 'nRuns = 6 * 2 blocks');
		end

		% ===================================================================
		%> @brief Test randomised task produces correct output sizes and
		%> balanced designs (each value appears equally).
		% ===================================================================
		function testRandomiseTaskBalancedDesign(testCase)
			ts = testCase.ts;
			ts.nVar(1) = struct('name', 'angle', 'values', [-90 -45 0 45 90], ...
				'stimulus', [1], 'offsetstimulus', [], 'offsetvalue', []);
			ts.randomiseTask;

			verifyEqual(testCase, size(ts.outValues, 1), 10, ...
				'should have 10 runs (5 values * 2 blocks)');
			verifyEqual(testCase, size(ts.outValues, 2), 1, '1 variable');
			verifyEqual(testCase, length(ts.outIndex), 10, 'outIndex length');
			verifyEqual(testCase, length(ts.outBlock), 2, 'outBlock length = nBlocks');
			verifyNotEmpty(testCase, ts.outMap, 'outMap should be populated');
			verifyFalse(testCase, ts.taskFinished, 'should not be finished after randomise');

			% Each value should appear exactly nBlocks times (balanced)
			allVals = [ts.outValues{:, 1}];
			for v = [-90 -45 0 45 90]
				verifyEqual(testCase, sum(allVals == v), 2, ...
					sprintf('value %d should appear 2 times', v));
			end

			% outIndex should contain indices 1..minTrials, each appearing nBlocks times
			for idx = 1:5
				verifyEqual(testCase, sum(ts.outIndex == idx), 2, ...
					sprintf('index %d should appear 2 times (once per block)', idx));
			end
		end

		% ===================================================================
		%> @brief Test sequential (non-randomised) mode produces
		%> predictable ordering.
		% ===================================================================
		function testSequentialMode(testCase)
			ts = testCase.ts;
			ts.randomise = false;
			ts.nVar(1) = struct('name', 'orientation', 'values', [0 90 180 270], ...
				'stimulus', [1], 'offsetstimulus', [], 'offsetvalue', []);
			ts.randomiseTask;

			% In sequential mode, outIndex should be [1 2 3 4 1 2 3 4]
			verifyEqual(testCase, ts.outIndex', [1 2 3 4 1 2 3 4], ...
				'sequential mode should produce ordered indices');

			% Values should match the sequential order
			expectedVals = [0 90 180 270 0 90 180 270];
			actualVals = [ts.outValues{:, 1}];
			verifyEqual(testCase, actualVals, expectedVals, ...
				'sequential mode values should be in order');
		end

		% ===================================================================
		%> @brief Test block-level factors are assigned.
		% ===================================================================
		function testBlockVar(testCase)
			ts = testCase.ts;
			ts.nBlocks = 10;
			ts.nVar(1) = struct('name', 'contrast', 'values', [0.1 0.5], ...
				'stimulus', [1], 'offsetstimulus', [], 'offsetvalue', []);
			blockVar.values = {'A','B'}; blockVar.probability = [0.6 0.4];
			ts.blockVar = blockVar;
			ts.randomiseTask;

			verifyEqual(testCase, length(ts.outBlock), 10, 'outBlock should have 10 entries');
			verifyTrue(testCase, all(ismember(ts.outBlock, {'A', 'B'})), ...
				'all block values should be A or B');
		end

		% ===================================================================
		%> @brief Test trial-level factors are assigned.
		% ===================================================================
		function testTrialVar(testCase)
			ts = testCase.ts;
			ts.nVar(1) = struct('name', 'contrast', 'values', [0.1 0.5], ...
				'stimulus', [1], 'offsetstimulus', [], 'offsetvalue', []);
			trialVar.values = {'YES', 'NO'}; trialVar.probability = [0.5 0.5];
			ts.trialVar = trialVar;
			ts.randomiseTask;

			verifyEqual(testCase, length(ts.outTrial), ts.nRuns, ...
				'outTrial length should equal nRuns');
			verifyTrue(testCase, all(ismember(ts.outTrial, {'YES', 'NO'})), ...
				'all trial values should be YES or NO');
		end

		% ===================================================================
		%> @brief Test initialise creates dynamic properties and sets
		%> taskInitialised to true.
		% ===================================================================
		function testInitialise(testCase)
			ts = testCase.ts;
			ts.nVar(1) = struct('name', 'angle', 'values', [0 90 180], ...
				'stimulus', [1], 'offsetstimulus', [], 'offsetvalue', []);
			ts.initialise;

			verifyTrue(testCase, ts.taskInitialised, 'should be initialised');
			verifyFalse(testCase, ts.taskFinished, 'should not be finished');
			verifyEqual(testCase, ts.totalRuns, 1, 'totalRuns should start at 1');
			verifyEqual(testCase, ts.thisBlock, 1, 'thisBlock should start at 1');
			verifyEqual(testCase, ts.thisRun, 1, 'thisRun should start at 1');
			verifyTrue(testCase, isprop(ts, 'response'), 'response dynamic prop should exist');
			verifyTrue(testCase, isprop(ts, 'runTimeList'), 'runTimeList dynamic prop should exist');
		end

		% ===================================================================
		%> @brief Test updateTask tracks responses and sets taskFinished.
		% ===================================================================
		function testUpdateTask(testCase)
			ts = testCase.ts;
			ts.nVar(1) = struct('name', 'angle', 'values', [0 90], ...
				'stimulus', [1], 'offsetstimulus', [], 'offsetvalue', []);
			ts.initialise;

			nRuns = ts.nRuns; % 2 values * 2 blocks = 4
			verifyEqual(testCase, nRuns, 4, 'should have 4 runs');

			% Simulate responses for all runs
			for i = 1:nRuns
				verifyFalse(testCase, ts.taskFinished, ...
					sprintf('should not be finished at run %d', i));
				ts.updateTask(1, i * 1000, 'correct'); %#ok<NASGU>
			end

			verifyTrue(testCase, ts.taskFinished, 'should be finished after all runs');
			verifyEqual(testCase, length(ts.response), nRuns, 'response array length');
			verifyEqual(testCase, ts.response, ones(1, nRuns), 'all responses should be 1');
		end

		% ===================================================================
		%> @brief Test findRun returns correct block and run numbers.
		% ===================================================================
		function testFindRun(testCase)
			ts = testCase.ts;
			ts.nVar(1) = struct('name', 'angle', 'values', [0 45 90 135], ...
				'stimulus', [1], 'offsetstimulus', [], 'offsetvalue', []);
			ts.randomiseTask;
			% minTrials = 4, nBlocks = 2, nRuns = 8

			% findRun(index) — pass index explicitly
			% Trial 1 -> block 1, run 1
			[b, r] = ts.findRun(1);
			verifyEqual(testCase, b, 1, 'trial 1 should be block 1');
			verifyEqual(testCase, r, 1, 'trial 1 should be run 1');

			% Trial 4 -> block 1, run 4
			[b, r] = ts.findRun(4);
			verifyEqual(testCase, b, 1, 'trial 4 should be block 1');
			verifyEqual(testCase, r, 4, 'trial 4 should be run 4');

			% Trial 5 -> block 2, run 1
			[b, r] = ts.findRun(5);
			verifyEqual(testCase, b, 2, 'trial 5 should be block 2');
			verifyEqual(testCase, r, 1, 'trial 5 should be run 1');

			% Trial 8 -> block 2, run 4
			[b, r] = ts.findRun(8);
			verifyEqual(testCase, b, 2, 'trial 8 should be block 2');
			verifyEqual(testCase, r, 4, 'trial 8 should be run 4');
		end

		% ===================================================================
		%> @brief Test rewindTask steps back one run.
		% ===================================================================
		function testRewindTask(testCase)
			ts = testCase.ts;
			ts.nVar(1) = struct('name', 'angle', 'values', [0 90 180], ...
				'stimulus', [1], 'offsetstimulus', [], 'offsetvalue', []);
			ts.initialise;

			% Advance a few runs
			ts.updateTask(1, 100, 'ok');
			ts.updateTask(0, 200, 'no');
			verifyEqual(testCase, ts.totalRuns, 3, 'should be at run 3');

			% Rewind
			ts.rewindTask;
			verifyEqual(testCase, ts.totalRuns, 2, 'should be back at run 2');
		end

		% ===================================================================
		%> @brief Test validate removes nVar entries with empty name/values.
		% ===================================================================
		function testValidate(testCase)
			ts = testCase.ts;
			% Set two variables, one with empty name
			ts.nVar(1) = struct('name', 'contrast', 'values', [0.1 0.5], ...
				'stimulus', [1], 'offsetstimulus', [], 'offsetvalue', []);
			ts.nVar(2) = struct('name', '', 'values', [], ...
				'stimulus', [], 'offsetstimulus', [], 'offsetvalue', []);
			verifyEqual(testCase, ts.nVars, 2, 'should have 2 variables before validate');

			ts.validate;
			verifyEqual(testCase, ts.nVars, 1, 'validate should remove empty nVar');
		end

		% ===================================================================
		%> @brief Test randomSeed reproducibility — same seed should
		%> produce same outIndex.
		% ===================================================================
		function testRandomSeedReproducibility(testCase)
			ts1 = taskSequence('nBlocks', 1, 'randomSeed', 123, 'verbose', false, 'realTime', false);
			ts1.nVar(1) = struct('name', 'angle', 'values', [0 30 60 90 120 150], ...
				'stimulus', [1], 'offsetstimulus', [], 'offsetvalue', []);
			ts1.randomiseTask;
			idx1 = ts1.outIndex;

			ts2 = taskSequence('nBlocks', 1, 'randomSeed', 123, 'verbose', false, 'realTime', false);
			ts2.nVar(1) = struct('name', 'angle', 'values', [0 30 60 90 120 150], ...
				'stimulus', [1], 'offsetstimulus', [], 'offsetvalue', []);
			ts2.randomiseTask;
			idx2 = ts2.outIndex;

			verifyEqual(testCase, idx1, idx2, ...
				'same seed should produce same randomisation');
		end

		% ===================================================================
		%> @brief Test nFrames dependent property returns a positive
		%> estimate.
		% ===================================================================
		function testNFrames(testCase)
			ts = testCase.ts;
			ts.nVar(1) = struct('name', 'angle', 'values', [0 90], ...
				'stimulus', [1], 'offsetstimulus', [], 'offsetvalue', []);
			% nRuns = 4, trialTime = 2, isTime = 1, ibTime = 2, fps = 60
			nf = ts.nFrames;
			verifyGreaterThan(testCase, nf, 0, 'nFrames should be positive');
		end

		% ===================================================================
		%> @brief Test getLabels returns labels after randomisation.
		% ===================================================================
		function testGetLabels(testCase)
			ts = testCase.ts;
			ts.nVar(1) = struct('name', 'angle', 'values', [0 90], ...
				'stimulus', [1], 'offsetstimulus', [], 'offsetvalue', []);
			ts.randomiseTask;
			[labels, list] = ts.getLabels;
			verifyNotEmpty(testCase, labels, 'labels should not be empty');
			verifyNotEmpty(testCase, list, 'list should not be empty');
			verifyEqual(testCase, length(labels), 2, 'should have 2 labels (2 values)');
		end

		% ===================================================================
		%> @brief Test addBlank increases minTrials by 1 per block.
		% ===================================================================
		function testAddBlank(testCase)
			ts = testCase.ts;
			ts.addBlank = true;
			ts.nVar(1) = struct('name', 'angle', 'values', [0 45 90], ...
				'stimulus', [1], 'offsetstimulus', [], 'offsetvalue', []);
			% minTrials = 3 + 1 (blank) = 4, nRuns = 4 * 2 = 8
			verifyEqual(testCase, ts.minTrials, 4, 'minTrials should include blank');
			verifyEqual(testCase, ts.nRuns, 8, 'nRuns should include blanks');
		end

		% ===================================================================
		%> @brief Test cellStruct static method converts cell array to
		%> matrix.
		% ===================================================================
		function testCellStruct(testCase)
			input = {1; 2; 3};
			out = taskSequence.cellStruct(input);
			verifyEqual(testCase, out, [1; 2; 3], 'cellStruct should convert cell to array');

			input = {1 2; 3 4};
			out = taskSequence.cellStruct(input);
			verifyEqual(testCase, out, [1 2; 3 4], 'cellStruct 2D');
		end
	end
end
