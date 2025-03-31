function addOptickaToPath()
% adds opticka to path, ignoring at least some of the unneeded folders

tt				= tic;
mpath			= path;
mpath			= strsplit(mpath, pathsep);
opath			= fileparts(mfilename('fullpath'));

%remove any old paths
opathesc		= regexptranslate('escape',opath);
oldPath			= ~cellfun(@isempty,regexpi(mpath,opathesc));
if any(oldPath)
	rmpath(mpath{oldPath});
end

% add new paths
opaths			= genpath(opath); 
opaths			= strsplit(opaths,pathsep);
sep 			= regexptranslate('escape',filesep);
pathExceptions	= [".git" "adio" "arduino" "photodiode" "+uix" ...
	"+zmq" "+uiextras" "legacy" "html" "doc" ".vscode"];
qAdd 			= contains(opaths,pathExceptions); % true where regexp _didn't_ match
addpath(opaths{~qAdd}); savepath;

fprintf('--->>> Added opticka to the MATLAB path in %.1f ms...\n',toc(tt)*1000);