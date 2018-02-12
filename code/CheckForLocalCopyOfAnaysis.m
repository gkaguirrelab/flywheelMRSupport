function [analysisExists] = CheckForLocalCopyOfAnaysis(analysis_id,analysisScratchDir)
% Check whether we already have a local copy of an analysis
%
% Description:
%  


% History
%  02/12/18  mab, dhb  Wrote it

% Examples:
%{
    % Downloads an analysis into tempdir
    analysis_id = 5a7dcf58b21836001c755ba4;
    CheckForLocalCopyOfAnaysis(theProject,tempdir);
%}

% Get everyting in the directory
theContents = dir(fullfile(analysisScratchDir,'*'));
 
% Here we go
nRunFunctions = 0;
functionNames = {};
functionStatus = [];
for ii = 1:length(theContents)
    %theContents(ii)
    
    % Desend into directory?
    if (theContents(ii).isdir & ...
            ~strcmp(theContents(ii).name,'.') ...
            & ~strcmp(theContents(ii).name,'..') ...
            & isempty(strfind(theContents(ii).name,'underDevelopment')))
        if (p.Results.verbose)
            fprintf('Descending into %s\n',theContents(ii).name)
        end
        
        % Recurse!
        [tempFunctionNames,tempFunctionStatus] = ...
            ExecuteExamplesInDirectory(fullfile(parentDir,theContents(ii).name),...
            'printreport',false, ...
            'verbose',p.Results.verbose);
        tempNRunFunctions = length(tempFunctionNames);
        functionNames = {functionNames{:} tempFunctionNames{:}};
        functionStatus = [functionStatus(:) ; tempFunctionStatus(:)];
        nRunFunctions = nRunFunctions + tempNRunFunctions;
        
        % Run on a .m file? But don't run on self.
    elseif (length(theContents(ii).name) > 2)
        if (strcmp(theContents(ii).name(end-1:end),'.m') & ...
                ~strcmp(theContents(ii).name,[mfilename '.m']))
            
            % Check examples and report status
            status = ExecuteExamplesInFunction(theContents(ii).name,'verbose',p.Results.verbose);
            nRunFunctions = nRunFunctions+1;
            functionNames{nRunFunctions} = theContents(ii).name(1:end-2);
            functionStatus(nRunFunctions) = status;
        else
            if (p.Results.verbose)
                fprintf('%s: Ignoring\n',theContents(ii).name);
            end
        end
    else
        if (p.Results.verbose)
            fprintf('%s: Ignoring\n',theContents(ii).name);
        end
    end
end
 