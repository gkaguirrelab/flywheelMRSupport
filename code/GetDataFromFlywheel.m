function [] = GetDataFromFlywheel(theProject,analysisLabel,analysisScratchDir)
% GetDataFromFlywheel
%
% Description:
%   Use api to download data from flywheel from flywheel based an a given
%   project name and analysis label.
%
% Inputs:
%  theProject    = Define the project. This is the name of the project as
%                  it appears in the Flywheel projects tab: this can be
%                  found at (https://flywheel.sas.upenn.edu/#/projects)
%  analysisLabel = Define the analysis. This is the name of the analysis as
%                  it appears on Flywheel in the projects directory under
%                  the analysis tab: the analysis name can be found after the
%                  "Session Analysis |" string on the analysis tab.
%  analysisScratchDir = This is a string specifying the directory where
%                  this routine should put its files.
%
% Outputs:
%   None.
%
% Optional key/value pairs:
%    None.
%
% Examples are provided in the source code.
%
% See also:
%

% History
%  1/31/18  mab  Created from previous example script.

% Examples:
%{
    % Downloads an analysis into tempdir
    theProject = 'LFContrast';
    analysisLabel = 'fmriprep 02/09/2018 11:40:55';
    GetDataFromFlywheel(theProject,analysisLabel,tempdir);
%}

%% Open flywheel object
fw = Flywheel(getpref('flywheelMRSupport','flywheelAPIKey'));

%% Find out who we are
me = fw.getCurrentUser();
fprintf('I am %s %s\n', me.firstname, me.lastname);

%% Get a list of our projects
theProjectIndex = [];
projects = fw.getAllProjects();

%% In the case of a user only have one project on flywheel. Turns the struct
%  into a cell so that the indexing
if ~iscell(projects)
    tmpProject{1} = projects;
    projects = tmpProject;
end

%fprintf('Avaliable projects\n');
for ii = 1:length(projects)
    %fprintf('\t%s\n',projects{ii}.label)
    if (strcmp(theProject,projects{ii}.label))
        theProjectIndex = ii;
        break;
    end
end
if (isempty(theProjectIndex))
    error('Could not find specified project %s\n',theProject);
end
fprintf('Found project %s!\n',projects{theProjectIndex}.label);
projectId = projects{ii}.id;

%% Try to get output from fmriPrep for each session
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

%% Try to download the output of an analysis
%
% Given some analysis label, download the files that were generated.
%
% For this we use:
%   fw.downloadFileFromAnalysis(session_id, analysis_id, file_name, output_name)


% Where do you want the files stored?
if (~exist(analysisScratchDir,'dir'))
    mkdir(analysisScratchDir);
end

%% Set-up search structure and search
searchStruct = struct('return_type', 'file', ...
    'filters', {{struct('term', ...
    struct('analysis0x2elabel', analysisLabel))}});
results = fw.search(searchStruct);
[~,cmdout] = unixFind(results(1).analysis.x_id, analysisScratchDir, 'searchCase', 'wildcard');
if ~isempty(cmdout)
    fprintf('WARNING: File found in search contianing the analysis id: %s \n',results(1).analysis.x_id);
else
    % Iterate over results and download the files
    for ii = 1:numel(results)
        file_name = results(ii).file.name;
        output_name = fullfile(analysisScratchDir, file_name);
        
        session_id = results(ii).session.x_id;
        analysis_id = results(ii).analysis.x_id;
        subject = results(ii).subject.code;
        
        % Could add logic right here that looks for a log file
        % GetDataFromFlywheel.log and if it finds a line with the analysis_id
        % in it, doesn't bother with the long download because we already have
        % the file (or prompts and asks, or ...)
        
        
        fprintf('Downloading %dMB file: %s ... \n', round(results(ii).file.size / 1000000), file_name);
        tic; fw.downloadFileFromAnalysis(session_id, analysis_id, file_name, output_name); toc
        
        %
        % We don't know quite what happens if we unzip more than one file, but
        % sooner or later we will find out.
        [~,body,ext] = fileparts(file_name);
        unzipDir = fullfile(analysisScratchDir,[subject '_' analysis_id]);
        switch (ext)
            case '.zip'
                fprintf('Unzipping %s\n',output_name);
                if (~exist(unzipDir,'dir'))
                    mkdir(unzipDir);
                end
                system(['unzip -o ' output_name ' -d ' unzipDir]);
                %delete(output_name);
        end
    end
end  
    
end