mpath			= path;
mpath			= strsplit(mpath, pathsep);
opath			= fileparts(mfilename('fullpath'));
for i = 1:length(mpath)
	if ~isempty(regexpi(mpath{i},opath))
		rmpath(mpath{i}); % remove any old path values
	end
end
opaths		= genpath(opath); 
opaths		= strsplit(opaths,pathsep);
newopaths	= {};
pathExceptions = [filesep '\.git|' filesep 'adio|' filesep 'photodiode'];
for i=1:length(opaths)
	if isempty(regexpi(opaths{i},pathExceptions))
		newopaths{end+1}=opaths{i};
	end
end
newopaths = strjoin(newopaths,pathsep);
addpath(newopaths); savepath;
disp('--->>> Added opticka to the path...')
clear mpath opath opaths newopaths pathExceptions i