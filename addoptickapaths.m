opath			= fileparts(mfilename('fullpath'));
opaths		= genpath(opath); 
opaths		= strsplit(opaths,pathsep);
newopaths	= {};
for i=1:length(opaths)
	if isempty(strfind(opaths{i},[filesep '.git']))
		newopaths{end+1}=opaths{i};
	end
end
newopaths = strjoin(newopaths,pathsep);
addpath(newopaths);savepath;
clear opath opaths newopaths