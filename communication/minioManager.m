% ========================================================================
classdef minioManager < handle
%> @class minioManager
%> @brief use MinIO mc CLI command from MATLAB (mc alias-based auth)
%>
%> @section intro Introduction
%>
%> minioManager provides an S3-compatible file transfer interface using
%> the MinIO mc CLI tool instead of the AWS CLI. Authentication uses
%> `mc alias set` to register an endpoint alias, and subsequent commands
%> use the alias name to address buckets and objects.
%>
%> @section install Installation
%>
%> Install the mc CLI cross-platform:
%> @code
%> curl https://dl.min.io/client/mc/release/linux-amd64/mc -o ~/bin/mc && chmod +x ~/bin/mc
%> @endcode
%>
%> Or with pixi:
%> @code
%> pixi global install minio-mc
%> @endcode
%>
%> @section usage Usage
%>
%> Secrets can be kept locally using setSecret('MINIO_ID') and
%> setSecret('MINIO_KEY'), then passed with getSecret.
%> @code
%> m = minioManager(getSecret("MINIO_ID"), getSecret("MINIO_KEY"), "http://1.1.1.1:9000")
%> m.list()
%> m.checkBucket("mybucket")
%> m.get("mybucket","path/to/file.mat")
%> m.copyFiles("localfile.mat","mybucket","remote/path/file.mat")
%> @endcode
%>
%> Copyright ©2014-2026 Ian Max Andolina — released: LGPL3, see LICENCE.md
% ========================================================================

	%--------------------PUBLIC PROPERTIES----------%
	properties
		%> the S3 endpoint URL
		ENDPOINT char
		%> alias name for mc commands
		ALIAS char = 'minio-local'
		%> local dir
		LOCAL char = './'
	end

	%--------------------TRANSIENT HIDDEN PROPERTIES----------%
	properties (Transient = true, Hidden = true)
		%> access key for S3-compatible store
		ACCESS_KEY char
		%> secret key for S3-compatible store
		SECRET_KEY char
	end

	%=======================================================================
	methods
	%=======================================================================

		% ===================================================================
		function me = minioManager(id, key, url, alias)
		%> @brief minioManager constructor
		%>
		%> @param id   access key for the S3 store
		%> @param key  secret key for the S3 store
		%> @param url  endpoint URL (e.g. 'http://192.168.1.1:9000')
		%> @param alias optional alias name (default 'minio')

			[r, out] = system('mc --version 2>&1');
			assert(~logical(r) && contains(out,'MinIO'), ...
				'--->>> minioManager: MinIO mc CLI not found on path (got Midnight Commander?). Install: https://min.io/download');

			if nargin < 3 || isempty(id) || isempty(key) || isempty(url); error('--->>> minioManager: must enter ID, key and URL'); end

			me.ACCESS_KEY = id;
			me.SECRET_KEY  = key;
			me.ENDPOINT    = url;
			if nargin >= 4 && ~isempty(alias)
				me.ALIAS = alias;
			end
			setupAlias(me);
		end

		% ===================================================================
		function delete(me)
		%> @brief clean up mc alias on object deletion
			cmdin = ['mc alias remove ' me.ALIAS ' 2>/dev/null'];
			system(cmdin);
		end

		% ===================================================================
		function setupAlias(me)
		%> @brief set up the mc alias for authentication
		%>
		%> Registers the endpoint URL, access key and secret key under the
		%> configured alias name. Keys are shell-quoted to handle special
		%> characters safely. Subsequent mc commands use the alias directly.

			id  = strrep(me.ACCESS_KEY, '''', '''''');
			key = strrep(me.SECRET_KEY,  '''', '''''');
			cmdin = ['mc alias set ' me.ALIAS ' ' me.ENDPOINT ' ''' id ''' ''' key ''''];
			[r, out] = system(cmdin);
			if logical(r)
				warning('--->>> minioManager: problem setting alias: %s',out);
			end
		end

		% ===================================================================
		function out = list(me)
		%> @brief list buckets (mc ls <alias>)
		%>
		%> @param  none
		%> @return out character vector of bucket listing

			cmdin = ['mc ls ' me.ALIAS];
			[~, out] = system(cmdin);
			out = strtrim(out);
		end

		% ===================================================================
		function checkBucket(me, bucket)
		%> @brief check bucket exists and create it if missing
		%>
		%> Lists buckets, and if the named bucket is not found,
		%> creates it automatically.
		%>
		%> @param bucket name of the bucket to check

			buckets = list(me);
			if contains(buckets,'[ERROR]')
				buckets = '';
				warning('Couldn''t get buckets list, problem with mc!!!');
			end
			if ~isempty(buckets) && ~contains(buckets,lower(bucket))
				createBucket(me, lower(bucket));
			end
		end

		% ===================================================================
		function success = createBucket(me, bucket)
		%> @brief create a bucket (mc mb <alias>/<bucket>)
		%>
		%> @param  bucket  name of the bucket to create
		%> @return success logical true if bucket was created

			if nargin < 2; error('--->>> minioManager: you must enter a bucket name'); end
			cmdin = ['mc mb ' me.ALIAS '/' bucket];
			[r, out] = system(cmdin);
			success = ~logical(r);
			if ~success
				warning('Problem making bucket: %s', out);
			else
				fprintf('--->>> minioManager: Create Bucket: %s\n',bucket)
				disp(out);
			end
		end

		% ===================================================================
		function [out, success] = find(me, pattern, target)
		%> @brief find objects matching a regex pattern
		%>
		%> Uses `mc find --regex --json` to search the store,
		%> then jsondecode to parse the JSON-lines output into
		%> a MATLAB struct array.
		%>
		%> @param  pattern regex pattern (RE2 syntax)
		%> @param  target  optional target path under alias
		%>                 (default: alias root, all buckets)
		%> @return out     struct array of matching objects
		%> @return success logical true if search succeeded

			if ~exist('pattern','var')||isempty(pattern)
				error('--->>> minioManager: you must enter a regex pattern');
			end
			if ~exist('target','var')||isempty(target)
				tgt = me.ALIAS;
			else
				tgt = [me.ALIAS '/' target];
			end

			p = strrep(pattern, '''', '''''');
			cmdin = ['mc find ' tgt ' --regex ''' p ''' --json'];
			[r, out] = system(cmdin);
			success = ~logical(r);

			if ~success
				warning('!!! Problem with find: %s - %s', cmdin, out);
				out = struct([]);
				return;
			end

			out = regexprep(out,"}\n{","},\n{");
			out = strtrim(out);
			if isempty(out)
				out = struct([]);
				return;
			end

			try
				out = jsondecode("[" + out + "]");
			catch ME
				warning('!!! Problem decoding JSON from find: %s', ...
					ME.message);
				out = struct([]);
				success = false;
			end
		end

		% ===================================================================
		function success = get(me, bucket, key)
		%> @brief get/download file from bucket
		%>
		%> Downloads an object from the store to the current working
		%> directory (mc cp <alias>/<bucket>/<key> ./).
		%>
		%> @param  bucket  bucket name
		%> @param  key     object key (path within the bucket)
		%> @return success logical true if download succeeded

			if ~exist('bucket','var') || isempty(bucket); return; end
			if ~exist('key','var') || isempty(key); return; end

			cmdin = ['mc cp ' me.ALIAS '/' bucket '/' key ' ' me.LOCAL];
			[r, out] = system(cmdin);
			success = ~logical(r);
			if ~success
				warning('!!! Problem getting file: %s - %s', cmdin, out);
			else
				fprintf('--->>> minioManager: Get File: %s\n',cmdin)
				disp(out)
			end
		end

		% ===================================================================
		function success = copyFiles(me, file, bucket, key)
		%> @brief copy/upload files to bucket
		%>
		%> Uploads a local file or directory to the S3 store.
		%> Directories are handled with the --recursive flag.
		%> (mc cp --quiet [--recursive] 'file' <alias>/<bucket>/<key>).
		%>
		%> @param  file    local file or directory path to upload
		%> @param  bucket  bucket name
		%> @param  key     destination object key (path within the bucket)
		%> @return success logical true if upload succeeded

			if ~exist('file','var') || isempty(file); return; end
			if ~exist('bucket','var') || isempty(bucket); return; end
			if ~exist('key','var') || isempty(key); return; end

			if exist(file) == 7
				rec = '--recursive ';
			else
				rec = '';
			end
			cmdin = ['mc cp --quiet ' rec '''' file ''' ' me.ALIAS '/' bucket '/' key];
			[r, out] = system(cmdin);
			success = ~logical(r);
			if ~success
				warning('!!! Problem copying: %s - %s', cmdin, out);
			else
				fprintf('--->>> minioManager: Copy Details using %s\n',cmdin)
				disp(out)
			end
		end

	end
end
