% ========================================================================
classdef alyxManagerHarness < alyxManager
%> @class alyxManagerHarness
%> @brief Test-only subclass exposing protected alyxManager seams.
% ========================================================================

	properties
		nextStatusCode double = 200
		nextResponseBody = struct('token', 'mock-token')
		lastEndpoint char = ''
		lastJsonData char = ''
		lastRequestMethod char = ''
		lastGetEndpoint = ''
		lastGetArgs cell = {}
		lastPostEndpoint char = ''
		lastPostData struct = struct()
		lastPostMethod char = ''
		mockData struct = struct()
		mockPostResponse = []
		getDataCallCount double = 0
	end

	methods
		function forceToken(me, tokenValue)
		%> Set a token without performing an HTTP login.
			me.token = tokenValue;
			me.webOptions.HeaderFields = {'Authorization', ['Token ' tokenValue]};
		end

		function endpoint = exposeMakeEndpoint(me, endpoint)
		%> Public wrapper for protected endpoint normalization.
			endpoint = me.makeEndpoint(endpoint);
		end

		function [data, statusCode] = exposeFlushQueue(me, dontSend)
		%> Public wrapper for protected queue flushing.
			[data, statusCode] = me.flushQueue(dontSend);
		end

		function [data, statusCode] = getData(me, endpoint, varargin)
		%> Return deterministic mock data for public read methods.
			me.getDataCallCount = me.getDataCallCount + 1;
			me.lastGetEndpoint = endpoint;
			me.lastGetArgs = varargin;
			statusCode = 200;
			if startsWith(endpoint, 'subjects')
				data = me.mockData.subjects;
			elseif startsWith(endpoint, 'sessions')
				data = me.mockData.sessions;
			else
				data = me.mockData.session;
			end
		end

		function [data, statusCode] = postData(me, endpoint, data, requestMethod)
		%> Capture mutation requests without sending them.
			if nargin < 4
				requestMethod = 'post';
			end
			me.lastPostEndpoint = endpoint;
			me.lastPostData = data;
			me.lastPostMethod = requestMethod;
			if isempty(me.mockPostResponse)
				statusCode = 200;
			else
				data = me.mockPostResponse;
				statusCode = 200;
			end
		end
	end

	methods (Access = protected)
		function [statusCode, responseBody] = jsonPost(me, endpoint, jsonData, requestMethod)
		%> Capture protected HTTP writes without network access.
			if nargin < 4
				requestMethod = 'post';
			end
			me.lastEndpoint = endpoint;
			me.lastJsonData = jsonData;
			me.lastRequestMethod = requestMethod;
			statusCode = me.nextStatusCode;
			responseBody = me.nextResponseBody;
		end
	end
end
