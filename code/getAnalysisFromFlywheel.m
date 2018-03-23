function [fwInfo] = getAnalysisFromFlywheel(theProject,analysisLabel,dataDownloadDir, varargin)
% Downloads analysis outputs from flywheel
%
% Syntax:
%  [analysis_id] = GetAnalysisFromFlywheel(theProject,analysisLabel,analysisScratchDir)
%
% Description:
%	Use api to download data from flywheel based an a given
%   project name and analysis label.  Returns a structure (fwInfo)
%   that provides various useful information about the analysis.
%
%   If you just want the structure but don't want to download, set the
%   value for the 'nodownload' key to true.
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
%
% Outputs:
%   fwInfo                - Structure with various fields providing
%                           information about the analysis. 
%
% Optional key/value pairs:
%  'verbose'              - Logical, default false
%  'searchDir'            - Specify another location for the recursive file
%                           search to take place for skip download check:
%                           default is the dataDownloadDir location.
%  'nodownload'           - Logical, default false. Set this to true if you
%                           just want the fwInfo struct but do not want to
%                           download the data.
%
% Examples are provided in the source code.
%

% History
%  1/31/18  mab  Created from previous example script.

% Examples:
%{
    % Downloads an analysis into tempdir
    theProject      = 'LFContrast';
    analysisLabel   = 'fmriprep 02/09/2018 11:40:55';
    dataDownloadDir =  fullfile(getpref('LFContrastAnalysis','projectRootDir'),'fmriprep');
    getAnalysisFromFlywheel(theProject,analysisLabel,dataDownloadDir);
%}
%{
    % Just get analysis information
    theProject      = 'LFContrast';
    analysisLabel   = 'fmriprep 02/09/2018 11:40:55';
    dataDownloadDir =  fullfile(getpref('LFContrastAnalysis','projectRootDir'),'fmriprep');
    fwInfo = getAnalysisFromFlywheel(theProject,analysisLabel,dataDownloadDir,'nodownload',true)
%}

%% Parse vargin for options passed here
p = inputParser; p.KeepUnmatched = false;
p.addRequired('theProject', @ischar);
p.addRequired('analysisLabel', @ischar);
p.addRequired('analysisScratchDir', @ischar);
p.addParameter('verbose',false, @islogical);
p.addParameter('nodownload',false, @islogical);
p.addParameter('searchDir', dataDownloadDir, @ischar);
p.parse(theProject, analysisLabel, dataDownloadDir, varargin{:})


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
project_id = projects{ii}.id;


%% Check for the specified analysis
projectSessions = fw.getProjectSessions(project_id);
for ii = 1:length(projectSessions)
    % Get session ID
    if (length(projectSessions) == 1)
        session_id{ii} = projectSessions.id;
    else
        session_id{ii} = projectSessions{ii}.id;
    end
    
    % Get acquisitions for each session
    sessionAcqs{ii} = fw.getSessionAcquisitions(session_id{ii});
end


%% Download
% Given some analysis label, download the files that were generated.
% For this we use:
%   fw.downloadFileFromAnalysis(session_id, analysis_id, file_name, output_name)

% Where do we want the files stored?
if (~p.Results.nodownload)
    if (~exist(dataDownloadDir,'dir'))
        mkdir(dataDownloadDir);
    end
end

%% Set-up search structure and search
searchStruct = struct('return_type', 'file', ...
    'filters', {{struct('term', ...
    struct('analysis0x2elabel', analysisLabel))}});
results = fw.search(searchStruct);

% Grab ids from first result. 
analysis_id = results(1).analysis.x_id;
session_id = results(1).session.x_id;
subject = results(1).subject.code;

% This next
if (~p.Results.nodownload)
    [~,cmdout] = unixFind(analysis_id, p.Results.searchDir, 'searchCase', 'wildcard');
    if ~isempty(cmdout)
        warning('flywheelMRSupport:analysisAlreadyPresent','WARNING: File found in search containing the analysis id: %s \n',results(1).analysis.x_id);
    else
        % Iterate over results and download the files
        for ii = 1:numel(results)
            file_name = results(ii).file.name;
            output_name = fullfile(dataDownloadDir, file_name);
            
            % Check that our assumptions about what can change with
            % iteration are met.
            if (~strcmp(session_id,results(ii).session.x_id))
                error('Session number changed with iteration');
            end
            if (~strcmp(analysis_id,results(ii).analysis.x_id))
                error('Analysis id changed with iteration');
            end
            if (~strcnp(subject,results(ii).subject.code))
            	error('Subject code changed with iteration');
            end
            
            % Do the download
            if p.Results.verbose
                fprintf('Downloading %dMB file: %s ... \n', round(results(ii).file.size / 1000000), file_name);
                tic
            end
            fw.downloadFileFromAnalysis(session_id, analysis_id, file_name, output_name);
            if p.Results.verbose
                toc
            end
            
            % We don't know quite what happens if we unzip more than one file, but
            % sooner or later we will find out.
            [~,~,ext] = fileparts(file_name);
            unzipDir = fullfile(dataDownloadDir,[subject '_' analysis_id]);
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

%% Create flywheel info struct
fwInfo.session_id    = session_id;
fwInfo.analysis_id   = analysis_id;
fwInfo.subject       = subject;
fwInfo.label         = results(1).session.label;
fwInfo.timestamp     = results(1).session.timestamp;
fwInfo.project_id    = project_id;
fwInfo.theProject    = theProject;
fwInfo.analysisLabel = analysisLabel;

end
