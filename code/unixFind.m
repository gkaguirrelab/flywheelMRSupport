function [status,cmdout] = unixFind(searchString, topLevelSearchDir, varargin) 
% unixFind
%
% Description:
%   Performs a recursive search for a string within files and folders using
%   the unix find command.
%
% Inputs:
%  searchString      = The string you want to search for
%  topLevelSearchDir = The top level starting point for the recursive
%                      search
%
% Outputs:
%   status           = The exit status of the command.
%
%   cmdout           = The output of the seearch. Will either be empty if 
%                      nothing is found or contain a string of the matches 
% Optional key/value pairs:
%   seachCase        = "wildcard" = willd do a wildcardseach for the string
%                    = "exact"    = search for exact string (default) 
%                       Mainly here for if we want to get fancy with the search
%                       in the future...
%
% Examples are provided in the source code.
%
% See also:
%    find command in the unix shell (type "help find" in a unix terminal)

% History
%  2/16/18  mab  Created.

% Examples:
%{
    uniqueAnalusisID = '5a7dcf58b21836001c755ba4';
    topLevelSearchDir = tempdir;
    [status,cmdout] = unixFind(uniqueAnalusisID, topLevelSearchDir, 'searchCase', 'wildcard')
%}

p = inputParser;
p.addParameter('searchCase','exact',@isstr);
p.parse(varargin{:});

% recursive search starting at topLevelSearchDir for the search tree.
% Uses grep to remove the permission denied cases

switch p.Results.searchCase
    case 'wildcard' 
        searchString = ['*' searchString '*'];   
    % add additional searchcases here such as file size of date...
end

command = ['find ' topLevelSearchDir ' -name "' searchString '" 2> >(grep -v ''Permission denied'' >&2)'];
% Execute command
[status,cmdout] = system(command);

end