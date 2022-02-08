function runDeployed(scriptname)
% Works around a problem with app deployment and using `run`, this is a
% simplified version of the official MATLAB function. Basically `run` will
% fail if there is a shadowed script in the app bundle, which is not an
% issue for opticka.

if isstring(scriptname)
	scriptname = char(scriptname);
end

if isempty(scriptname)
	error('No script passed!!!');
end

if ispc
	scriptname = strrep(scriptname,'/','\');
end

startDir = pwd;
[fileDir,script,~] = fileparts(scriptname);

% If the input had a path, CD to that path if it exists
if ~isempty(fileDir)
	if ~exist(fileDir,'dir')
		error(message('runner:FolderNotFound',scriptname));
	end
	cd(fileDir);
end

% Finally, evaluate the script if it exists and isn't a shadowed script.
script = [script ';'];
evalin('caller', script);
cd(startDir);
end
