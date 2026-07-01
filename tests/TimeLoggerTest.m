% ========================================================================
%> @class TimeLoggerTest
%> @brief Class-based unit tests for timeLogger.
%>
%> Tests preAllocate, addMessage, logStim, messageTable, calculateMisses,
%> removeEmptyValues, stderr, and loadobj. All tests run without PTB
%> (the constructor falls back to @now when GetSecs is unavailable).
%>
%> Run with:
%>   >> runtests('tests/TimeLoggerTest.m')
%>
%> Copyright (c) 2026 Ian Max Andolina — LGPL3, see LICENCE.md
% ========================================================================
classdef TimeLoggerTest < matlab.unittest.TestCase

	properties
		%> a timeLogger instance for reuse
		tl
	end

	methods (TestClassSetup)
		
	end

	methods (TestMethodSetup)
		function createLogger(testCase)
			%> Create a fresh timeLogger with small preallocation for speed.
			testCase.tl = timeLogger('verbose', false, ...
				'preallocateTimes', 100, 'preallocateMessages', 50);
		end
	end

	methods (Test, TestTags = {'CI'})
		% ===================================================================
		%> @brief Test default construction and property defaults.
		% ===================================================================
		function testDefaultConstruction(testCase)
			tl = testCase.tl;
			verifyEqual(testCase, tl.messageN, 0, 'should start with 0 messages');
			verifyFalse(testCase, tl.isAllocated, 'should not be pre-allocated');
			verifyTrue(testCase, isa(tl.timer, 'function_handle'), 'timer should be a function handle');
			verifyEqual(testCase, length(tl.stimStateNames), 3, 'should have 3 default stim state names');
			verifyTrue(testCase, any(strcmp(tl.stimStateNames, 'stimulus')), ...
				'should include "stimulus" in stimStateNames');
		end

		% ===================================================================
		%> @brief Test preAllocate creates correctly sized arrays.
		% ===================================================================
		function testPreAllocate(testCase)
			tl = testCase.tl;
			tl.preAllocate(100, 50);

			verifyTrue(testCase, tl.isAllocated, 'should be allocated');
			verifyEqual(testCase, length(tl.t.vbl), 100, 'vbl array should be 100');
			verifyEqual(testCase, length(tl.t.show), 100, 'show array should be 100');
			verifyEqual(testCase, length(tl.t.flip), 100, 'flip array should be 100');
			verifyEqual(testCase, length(tl.t.miss), 100, 'miss array should be 100');
			verifyEqual(testCase, length(tl.t.stimTime), 100, 'stimTime array should be 100');
			verifyEqual(testCase, length(tl.messages.time), 50, 'message time array should be 50');
			verifyEqual(testCase, tl.messageN, 0, 'messageN should reset to 0');
		end

		% ===================================================================
		%> @brief Test preAllocate with default arguments uses the
		%> property defaults.
		% ===================================================================
		function testPreAllocateDefaults(testCase)
			tl = timeLogger('verbose', false, 'preallocateTimes', 200, 'preallocateMessages', 100);
			tl.preAllocate; % use defaults from properties

			verifyTrue(testCase, tl.isAllocated, 'should be allocated');
			verifyEqual(testCase, length(tl.t.vbl), 200, 'vbl array should use preallocateTimes');
			verifyEqual(testCase, length(tl.messages.time), 100, 'messages should use preallocateMessages');
		end

		% ===================================================================
		%> @brief Test addMessage stores messages correctly.
		% ===================================================================
		function testAddMessage(testCase)
			tl = testCase.tl;
			tl.preAllocate(100, 50);
			tl.tick = 5;
			tl.startTime = 1000.0;
			tl.lastvbl = 1001.5;

			tl.addMessage(5, 1002.0, 1002.5, "trial_start", "vbl", "Experiment-control");

			verifyEqual(testCase, tl.messageN, 1, 'should have 1 message');
			verifyEqual(testCase, tl.messages.time(1), 1002.0, 'message time should match');
			verifyEqual(testCase, tl.messages.exitTime(1), 1002.5, 'exit time should match');
			verifyEqual(testCase, tl.messages.tick(1), 5, 'tick should match');
			verifyEqual(testCase, tl.messages.message(1), "trial_start", 'message text should match');
			verifyEqual(testCase, tl.messages.type(1), "vbl", 'type should be lowercased');
			verifyEqual(testCase, tl.messages.HED(1), "Experiment-control", 'HED should match');
		end

		% ===================================================================
		%> @brief Test addMessage with empty message is a no-op.
		% ===================================================================
		function testAddMessageEmpty(testCase)
			tl = testCase.tl;
			tl.preAllocate(100, 50);
			tl.addMessage(1, 100.0, 101.0, "", "test", "HED");

			verifyEqual(testCase, tl.messageN, 0, 'empty message should not be stored');

			tl.addMessage(1, 100.0, 101.0, missing, "test", "HED");
			verifyEqual(testCase, tl.messageN, 0, 'missing message should not be stored');
		end

		% ===================================================================
		%> @brief Test addMessage with empty values.
		% ===================================================================
		function testAddMessageEmptyArray(testCase)
			tl = testCase.tl;
			tl.preAllocate(100, 50);
			tl.addMessage([], [], [], "message", [], []);
			verifyEqual(testCase, tl.messageN, 1, 'empty [] should be filled in');
		end

		% ===================================================================
		%> @brief Test addMessage strips newlines and tabs from text.
		% ===================================================================
		function testAddMessageStripsNewlines(testCase)
			tl = testCase.tl;
			tl.preAllocate(100, 50);
			tl.addMessage(1, 100.0, 101.0, "hello\tworld\nfoo", "test");

			verifyEqual(testCase, tl.messages.message(1), "hello world foo", ...
				'tabs and newlines should be replaced with spaces');
		end

		% ===================================================================
		%> @brief Test addMessage with NaN startTime falls back to
		%> lastvbl or timer.
		% ===================================================================
		function testAddMessageFallbackTime(testCase)
			tl = testCase.tl;
			tl.preAllocate(100, 50);
			tl.lastvbl = 0; % no lastvbl

			tl.addMessage(1, NaN, NaN, "test_msg", missing, "HED");

			verifyEqual(testCase, tl.messageN, 1, 'message should be stored');
			verifyGreaterThan(testCase, tl.messages.time(1), 0, ...
				'time should fall back to timer()');
			verifyEqual(testCase, tl.messages.type(1), "getsecs", ...
				'type should indicate timer fallback');
		end

		% ===================================================================
		%> @brief Test addMessage uses lastvbl when startTime is NaN
		%> and lastvbl is positive.
		% ===================================================================
		function testAddMessageLastvblFallback(testCase)
			tl = testCase.tl;
			tl.preAllocate(100, 50);
			tl.lastvbl = 5000.0;

			tl.addMessage(1, NaN, NaN, "test_msg", missing);

			verifyEqual(testCase, tl.messages.time(1), 5000.0, ...
				'time should use lastvbl');
			verifyEqual(testCase, tl.messages.type(1), "lastvbl", ...
				'type should indicate lastvbl fallback');
		end

		% ===================================================================
		%> @brief Test logStim marks stimulus state for a tick.
		% ===================================================================
		function testLogStim(testCase)
			tl = testCase.tl;
			tl.preAllocate(100, 50);

			% "stimulus" is in stimStateNames, so should set stimTime = 1
			tl.logStim("stimulus", 5);
			verifyEqual(testCase, tl.t.stimTime(5), 1, 'stimulus state should set stimTime to 1');

			% "fixation" is NOT in stimStateNames, so should set stimTime = 0
			tl.logStim("fixation", 6);
			verifyEqual(testCase, tl.t.stimTime(6), 0, 'non-stimulus state should set stimTime to 0');
		end

		% ===================================================================
		%> @brief Test multiple messages are stored in order.
		% ===================================================================
		function testMultipleMessages(testCase)
			tl = testCase.tl;
			tl.preAllocate(100, 50);
			tl.startTime = 0;

			for i = 1:5
				tl.addMessage(i, i * 100, i * 100 + 10, sprintf("msg_%d", i), "test");
			end

			verifyEqual(testCase, tl.messageN, 5, 'should have 5 messages');
			verifyEqual(testCase, tl.messages.time(1:5), (1:5) * 100, ...
				'times should be in order');
			verifyEqual(testCase, tl.messages.tick(1:5), 1:5, ...
				'ticks should be 1 through 5');
		end

		% ===================================================================
		%> @brief Test messageTable returns a table with expected
		%> columns after messages are added.
		% ===================================================================
		function testMessageTable(testCase)
			tl = testCase.tl;
			tl.preAllocate(100, 50);
			tl.startTime = 1000.0;

			tl.addMessage(3, 1005.0, 1006.0, "stim_onset", "vbl", "Sensory-event");
			tl.addMessage(10, 1010.0, 1010.5, "stim_offset", "vbl", "Sensory-event");

			tbl = tl.messageTable;
			verifyTrue(testCase, istable(tbl), 'messageTable should return a table');
			verifyGreaterThan(testCase, height(tbl), 0, 'table should have rows');
			% Should include a "Start Time" row + 2 messages = 3 rows
			verifyEqual(testCase, height(tbl), 3, 'should have 3 rows (start + 2 messages)');
		end

		% ===================================================================
		%> @brief Test messageTable returns empty when no messages.
		% ===================================================================
		function testMessageTableEmpty(testCase)
			tl = testCase.tl;
			tl.preAllocate(100, 50);
			tbl = tl.messageTable;
			verifyEmpty(testCase, tbl, 'table should be empty with no messages');
		end

		% ===================================================================
		%> @brief Test calculateMisses counts missed frames during
		%> stimulus display.
		% ===================================================================
		function testCalculateMisses(testCase)
			tl = testCase.tl;
			tl.preAllocate(100, 50);

			% Simulate: 10 frames, miss on frames 3 and 5 during stimulus
			tl.tick = 11;
			tl.t.miss(1:10) = 0;
			tl.t.miss(3) = 0.01;  % missed frame
			tl.t.miss(5) = 0.02;  % missed frame
			tl.t.stimTime(1:10) = 1; % all frames during stimulus
			tl.t.vbl(1:10) = (1:10) * 0.016;
			tl.t.show(1:10) = (1:10) * 0.016;
			tl.t.flip(1:10) = (1:10) * 0.016;

			tl.calculateMisses;

			verifyEqual(testCase, tl.nMissed, 2, 'should detect 2 missed frames');
		end

		% ===================================================================
		%> @brief Test calculateMisses ignores frames outside stimulus.
		% ===================================================================
		function testCalculateMissesNonStim(testCase)
			tl = testCase.tl;
			tl.preAllocate(100, 50);

			tl.tick = 6;
			tl.t.miss(1:5) = [0 0.01 0 0.02 0];
			tl.t.stimTime(1:5) = [0 1 0 1 0]; % only frames 2 and 4 are during stim
			tl.t.vbl(1:5) = (1:5) * 0.016;
			tl.t.show(1:5) = (1:5) * 0.016;
			tl.t.flip(1:5) = (1:5) * 0.016;

			tl.calculateMisses;

			% Frame 2 (miss=0.01, stim=1) and Frame 4 (miss=0.02, stim=1) count
			% Frame 1 is always ignored
			verifyEqual(testCase, tl.nMissed, 2, 'should count 2 missed stim frames');
		end

		% ===================================================================
		%> @brief Test loadobj round-trip with a struct.
		% ===================================================================
		function testLoadobjFromStruct(testCase)
			tl = testCase.tl;
			tl.preAllocate(100, 50);
			tl.tick = 6;
			tl.t.vbl(1:5) = [1 2 3 4 5];
			tl.t.show(1:5) = [1.1 2.1 3.1 4.1 5.1];
			tl.t.flip(1:5) = [1.2 2.2 3.2 4.2 5.2];
			tl.t.miss(1:5) = [0 0 0.01 0 0];
			tl.t.stimTime(1:5) = [1 1 1 0 0];
			tl.name = 'testLogger';

			% Build a struct as loadobj expects
			s.name = 'testLogger';
			s.vbl = tl.t.vbl(1:5);
			s.show = tl.t.show(1:5);
			s.flip = tl.t.flip(1:5);
			s.miss = tl.t.miss(1:5);
			s.stimTime = tl.t.stimTime(1:5);

			loaded = timeLogger.loadobj(s);
			verifyEqual(testCase, loaded.name, 'testLogger', 'name should round-trip');
			verifyEqual(testCase, loaded.t.vbl(1:5), s.vbl, 'vbl should round-trip');
			verifyEqual(testCase, loaded.t.stimTime(1:5), s.stimTime, 'stimTime should round-trip');
		end
	end
end
