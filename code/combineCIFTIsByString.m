function combineCIFTIsByString(fileNameString, saveName, varargin)
% Average CIFTIs together according to a common file name string that
% supports wild cards.
%
% Syntax:
%  combineCIFTIsByString(fileNameString, saveName)
%
% Description:
%  Rather than manually specifying every file to be averaged together, this
%  folder will perform a search for all relevant files according to a
%  fileNameString, which can include wild cards. The routine first searches
%  for files within the directory of the fileNameString that match the
%  wildcard syntax found in the fileNameString file name. Then all of these
%  files are packaged up to be combined through the function combineCIFTIs.
%
% Input:
%  fileNameString           - a string which defines the full path, as well
%                             as file name pattern for the relevant maps to
%                             be combined. For example, a fileNameString of
%                             '~/Desktop/*AP*' will identify all maps
%                             within the Desktop directory that contain AP
%                             and combine them together.
%  saveName                 - a string which defines the full path for the
%                             name of the output combined map.
%
% Optional key-value pairs:
%  exclude                  - a string which defines parts of the file name
%                             to be excluded from averaging if encountered.

p = inputParser; p.KeepUnmatched = true;
p.addParameter('exclude', [], @ischar);
p.parse(varargin{:});


mapFiles = dir(fileNameString);
mapDir = fileparts(fileNameString);
mapsCellArray = [];
fprintf('Combining the following maps:\n');

for ii = 1:length(mapFiles)
    if isempty(p.Results.exclude)
        
        fprintf('\t %s\n', mapFiles(ii).name);
        mapsCellArray{end+1} = fullfile(mapDir, mapFiles(ii).name);
    else
        if ~contains(mapFiles(ii).name, p.Results.exclude)
            fprintf('\t %s\n', mapFiles(ii).name);
            mapsCellArray{end+1} = fullfile(mapDir, mapFiles(ii).name);
        end
    end
end

[savePath, saveFileName, extension] = fileparts(saveName);
combineCIFTIs(mapsCellArray, 'savePath', savePath, 'saveName', [saveFileName, extension]);


end