function addOptickaToPath(addPTB)
% adds opticka to path, ignoring unneeded folders. Also ensures other
% related code folders are present.

% in general we do not want to add PTB paths as this is done by
% SetupPsychToolbox, but for CI tasks it may be necessary to at least have
% PTB functions available even when not "fully" setup.
if ~exist('addPTB','var'); addPTB = false; end

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
pathExceptions	= ["/.git" "/.github" "/.vscode" ...
	"/adio" "/arduino" "photodiode" "/+uix" ...
	"/+zmq" "/+uiextras" "/tests" "/images" "/resources" ...
	"/media" "/legacy" "/html" "/doc"];
qAdd 			= contains(opaths,pathExceptions); % true where exceptions match
addpath(opaths{~qAdd}); 

% Define the parent folder and the string array of optional project folder names
% If they exist in the same folder that opticka is stored, add them to
% path.
parentFolder = fileparts(opath); % Adjust this to your actual parent folder
folderNames = ["Palamedes", "CageLab-Code", "matlab-jzmq", "matmoteGO", "PTBSimia"];
if addPTB; folderNames = [folderNames "Psychtoolbox"]; end

% Loop through each folder name
for i = 1:length(folderNames)
	% Construct the full path for each folder
	folderPath = fullfile(parentFolder, folderNames(i));

	% Check if the folder exists
	if isfolder(folderPath)
		if strcmp(folderNames(i), "Psychtoolbox")
			ptbPaths = strsplit(genpath(folderPath),pathsep);
			qAdd 	 = contains(ptbPaths,pathExceptions); % true where exceptions match
			addpath(ptbPaths{~qAdd});
			fprintf('Additionally added to path with subfolders: %s\n', folderPath);
		else
			% Add the folder to the MATLAB path
			addpath(folderPath);
			fprintf('Additionally added to path: %s\n', folderPath);
		end
	else
		fprintf('Optional folder does not exist: %s\n', folderPath);
	end
end

% Save the changes to the path for future sessions
savepath;

fprintf('--->>> Added opticka to the MATLAB path in %.1f ms...\n',toc(tt)*1000);