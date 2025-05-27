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
addpath(opaths{~qAdd}); 

% Define the parent folder and the string array of folder names
parentFolder = fileparts(opath); % Adjust this to your actual parent folder
folderNames = ["CageLab/software" "matlab-jzmq", "matmoteGO", "PTBSimia"]; % Example folder names

% Loop through each folder name
for i = 1:length(folderNames)
    % Construct the full path for each folder
    folderPath = fullfile(parentFolder, folderNames(i));

    % Check if the folder exists
    if isfolder(folderPath)
        % Add the folder to the MATLAB path
        addpath(folderPath);
        fprintf('Additionally added to path: %s\n', folderPath);
    else
        fprintf('Folder does not exist: %s\n', folderPath);
    end
end

% Save the changes to the path for future sessions
savepath;

fprintf('--->>> Added opticka to the MATLAB path in %.1f ms...\n',toc(tt)*1000);