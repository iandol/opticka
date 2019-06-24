path = fileparts(mfilename('fullpath'));
paths = genpath(path); 
paths=strsplit(paths,pathsep);
newpaths = {};
for i=1:length(paths)
	if isempty(strfind(paths{i},[filesep '.git']))
		newpaths{end+1}=paths{i};
	end
end

newpaths = strjoin(newpaths,pathsep);
addpath(newpaths);