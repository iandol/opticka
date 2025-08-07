classdef awsManager < handle
	% Use aws CLI command from MATLAB
	% Can install cross-platform with pixi:
	%  > pixi global install awscli
	%
	% Secrets can be kept locally using setSecret('AWS_ID') 
	% and setSecret('AWS_KEY'), then passed with getSecret
	% e.g.
	% aws=awsManager(getSecret("AWS_ID"),getSecret("AWS_KEY"), "http://172.16.102.77:9000")
	
	properties
		AWS_DEFAULT_REGION = 'cn-north-1'
		ENDPOINT
	end

	properties (Transient = true, Hidden = true)
		AWS_ACCESS_KEY_ID
		AWS_SECRET_ACCESS_KEY
	end

	methods
		% ===================================================================
		function me = awsManager(id,key,url)
			[r, out] = system('which aws');
			assert(~logical(r),"--->>> awsManager: AWS CLI tool is not installed or available on path!!! %s",out)

			if nargin < 3; error("--->>> awsManager: must enter ID and key"); end

			me.AWS_ACCESS_KEY_ID = id;
			me.AWS_SECRET_ACCESS_KEY = key;
			me.ENDPOINT = url;
			me.AWS_DEFAULT_REGION = 'cn-north-1';

			updateENV(me);
		end

		% ===================================================================
		function updateENV(me)
			setenv("AWS_ACCESS_KEY_ID", me.AWS_ACCESS_KEY_ID)
			setenv("AWS_SECRET_ACCESS_KEY", me.AWS_SECRET_ACCESS_KEY)
			setenv("AWS_DEFAULT_REGION", me.AWS_DEFAULT_REGION)
		end

		% ===================================================================
		function out = list(me)
			cmdin = strjoin(["aws --endpoint-url " me.ENDPOINT " s3 ls"],"");
			[~, out] = system(cmdin);
			out = strtrim(out);
		end

		% ===================================================================
		function checkBucket(me, bucket)
			buckets = list(me);
			if ~contains(buckets,lower(bucket))
				createBucket(me, lower(bucket));
			end
		end

		% ===================================================================
		function success = createBucket(me, bucket)
			if nargin < 2; error("--->>> awsManager: you must enter a bucket name"); end
			cmdin = strjoin(["aws --endpoint-url " me.ENDPOINT " s3 mb s3://" bucket],"");
			[r, out] = system(cmdin);
			success = ~logical(r);
			if ~success
				warning("Problem making bucket: %s", out);
			end
		end

		% ===================================================================
		function success = copyFiles(me, file, bucket, key)
			if ~exist('file','var') || isempty(file); return; end
			if ~exist('bucket','var') || isempty(bucket); return; end
			if ~exist('key','var') || isempty(key); return; end

			if exist(file) == 7
				rec = "--recursive ";
			else
				rec = "";
			end

			cmdin = strjoin(["aws --no-progress " rec "--endpoint-url " me.ENDPOINT " s3 cp '" file "' s3://" bucket "/" key],"");
			[r, out] = system(cmdin);
			success = ~logical(r);
			if ~success
				warning("!!! Problem making bucket: %s - %s", cmdin, out);
			else
				fprintf('--->>> awsManager: Copy Details using %s\n',cmdin)
				disp(out)
			end
		end
	end
end