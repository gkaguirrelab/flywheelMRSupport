function [analysis_id] = getAnalysisFromFlywheel(theProject,analysisLabel,analysisScratchDir, varargin)
% Downloads analysis outputs from flywheel
%
% Syntax:
%  GetAnalysisFromFlywheel(theProject,analysisLabel,analysisScratchDir)
%
% Description:
%	Use api to download data from flywheel from flywheel based an a given
%   project name and analysis label.
%
% Inputs:
%  theProject             - Define the project. This is the name of the
%                           project as it appears in the Flywheel projects
%                           tab: this can be found at
%                           (https://flywheel.sas.upenn.edu/#/projects)
%  analysisLabel          - Define the analysis. This is the name of the
%                           analysis as it appears on Flywheel in the
%                           projects directory under the analysis tab: the
%                           analysis name can be found after the "Session
%                           Analysis |" string on the analysis tab.
%  analysisScratchDir     - This is a string specifying the directory where
%                           this routine should put its files.
% Optional key/value pairs:
%  'verbose'              - Logical flag, default false
%
% Outputs:
%   analysis_id           - The unique analysis id set by flywheel
%
%
% Examples are provided in the source code.
%

% History
%  1/31/18  mab  Created from previous example script.
%
% Examples:
%{
    % Downloads an analysis into tempdir
    theProject = 'LFContrast';
    analysisLabel = 'fmriprep 02/09/2018 11:40:55';
    getAnalysisFromFlywheel(theProject,analysisLabel,tempdir);
%}


%% Parse vargin for options passed here
p = inputParser; p.KeepUnmatched = false;

% Required
p.addRequired('theProject', @ischar);
p.addRequired('analysisLabel', @ischar);
p.addRequired('analysisScratchDir', @ischar);

% Optional params
p.addParameter('verbose',false, @islogical);

% parse
p.parse(theProject, analysisLabel, analysisScratchDir, varargin{:})


%% Open flywheel object
fw = Flywheel(getpref('flywheelMRSupport','flywheelAPIKey'));


%% Find out who we are
me = fw.getCurrentUser();
if p.Results.verbose
    fprintf('I am %s %s\n', me.firstname, me.lastname);
end

%% Get a list of our projects
theProjectIndex = [];
projects = fw.getAllProjects();

% Handle the case of a single project. When the user has only one project
% on flywheel, the routine returns a struct intstead of a cell. We catch
% this case and return a cell.
if ~iscell(projects)
    tmpProject{1} = projects;
    projects = tmpProject;
end


%% Check for the specified project
if p.Results.verbose
    fprintf('Avaliable projects\n');
end
for ii = 1:length(projects)
    if p.Results.verbose
        fprintf('\t%s\n',projects{ii}.label)
    end
    if (strcmp(theProject,projects{ii}.label))
        theProjectIndex = ii;
        break;
    end
end
if (isempty(theProjectIndex))
    error('Could not find specified project %s\n',theProject);
end
if p.Results.verbose
    fprintf('Found project %s!\n',projects{theProjectIndex}.label);
end
projectId = projects{ii}.id;


%% Check for the specified analysis
projectSessions = fw.getProjectSessions(projectId);
for ii = 1:length(projectSessions)
    % Get session ID
    if (length(projectSessions) == 1)
        sessionId{ii} = projectSessions.id;
    else
        sessionId{ii} = projectSessions{ii}.id;
    end
    
    % Get acquisitions for each session
    sessionAcqs{ii} = fw.getSessionAcquisitions(sessionId{ii});
end


%% Download
% Given some analysis label, download the files that were generated.
% For this we use:
%   fw.downloadFileFromAnalysis(session_id, analysis_id, file_name, output_name)

% Where do we want the files stored?
if (~exist(analysisScratchDir,'dir'))
    mkdir(analysisScratchDir);
end


%% Set-up search structure and search
searchStruct = struct('return_type', 'file', ...
    'filters', {{struct('term', ...
    struct('analysis0x2elabel', analysisLabel))}});
results = fw.search(searchStruct);
analysis_id = results(1).analysis.x_id;
[~,cmdout] = unixFind(analysis_id, analysisScratchDir, 'searchCase', 'wildcard');
if ~isempty(cmdout)
    warning('flywheelMRSupport:analysisAlreadyPresent','WARNING: File found in search containing the analysis id: %s \n',results(1).analysis.x_id);
else
    % Iterate over results and download the files
    for ii = 1:numel(results)
        file_name = results(ii).file.name;
        output_name = fullfile(analysisScratchDir, file_name);
        
        session_id = results(ii).session.x_id;
        analysis_id = results(ii).analysis.x_id;
        subject = results(ii).subject.code;
        
        if p.Results.verbose
            fprintf('Downloading %dMB file: %s ... \n', round(results(ii).file.size / 1000000), file_name);
            tic
        end
        
        fw.downloadFileFromAnalysis(session_id, analysis_id, file_name, output_name);
        
        if p.Results.verbose
            toc
        end
        
        %
        % We don't know quite what happens if we unzip more than one file, but
        % sooner or later we will find out.
        [~,~,ext] = fileparts(file_name);
        unzipDir = fullfile(analysisScratchDir,[subject '_' analysis_id]);
        switch (ext)
            case '.zip'
                if p.Results.verbose
                    fprintf('Unzipping %s\n',output_name);
                end
                if (~exist(unzipDir,'dir'))
                    mkdir(unzipDir);
                end
                system(['unzip -o ' output_name ' -d ' unzipDir]);
                delete(output_name);
        end
    end
end

end
