fileConstiningPath = 'defaultParRecFolder.txt';
% this file contains the path to the default folder containing the PAR/REC files
% if the file does not exist, there will be no default path
% initialFolder.txt should be included in the gitignore file
%
pathPAR = '~';
% pathPAR = directory containing the PAR/REC files
if exist(fileConstiningPath) == 2
	pathPAR = fileread(fileConstiningPath);
	% set the default PAR/REC directory contents of the file
end
%
viewMultipleScansGUI(pathPAR);
% start the GUI with the default path