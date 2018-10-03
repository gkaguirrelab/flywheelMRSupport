function uploadAllCoeffGrad(projectName, coeffGradLocation,varargin)
% Script that uploads all coeff.grad files to Flywheel

% Syntax:
%  uploadAllCoeffGrad(projectName,coeffGradLocation)
%
% Description:
%   This routine identifies all the sessions for a given project, and then
%   locates and uploads the coeff.grad files from the DropBox repository.
%
% Inputs:
%   projectName             - Define the project.
%   pulseOxLocation         - This is the location of the PulseOx files you
%                             want to upload. These files must be organized
%                             into separate directories for
%                             session1_restAndStructure and
%                             session2_spatialStimuli.
%
% Outputs:
%   none
%
% Optional key/value pairs:
%   'verbose'                - Logical, default false
%
%   'availableSessionNames'  - Cell array with possible session names
%
%   'sessionPaths'           - Cell array that corresponds to
%                              availableSessionNames and is the filePath to
%                              the location of the coeff.grad data.
%
% Examples:
%{
    uploadAllCoeffGrad('tome','~/Dropbox (Aguirre-Brainard Lab)/TOME_data','verbose',true)
%}


%% Convenience variables
p = inputParser; p.KeepUnmatched = false;
p.addRequired('projectName', @ischar);
p.addRequired('coeffGradLocation', @ischar);

p.addParameter('coeffGradFileName','coeff.grad', @ischar);
p.addParameter('sessionPaths',{'/session1_restAndStructure/','/session2_spatialStimuli/'}, @iscell);
p.addParameter('verbose',false, @islogical);

p.parse(projectName, coeffGradLocation, varargin{:})

verbose = p.Results.verbose;
sessionPaths = p.Results.sessionPaths;


%% Instantiate Flywheel object
fw = flywheel.Flywheel(getpref('flywheelMRSupport','flywheelAPIKey'));


%% Get project ID and sessions
allProjects = fw.getAllProjects;
for proj = 1:numel(allProjects)
    if strcmp(allProjects{proj}.label,projectName)
        projID = allProjects{proj}.id;
    end
end

if verbose
    disp(['Uploading coeff.grad from project ' projectName ' to Flywheel.']);
    fprintf(['Start time: ' char(datetime('now')) ' \n\n']);
end

allSessions = fw.getProjectSessions(projID);

% Loop through the sessions
for session = 1:numel(allSessions)
    
    % Get the subject ID
    subID = allSessions{session}.subject.code;
    
    % Get the session date in standard format
    sesDate = allSessions{session}.timestamp;
    sesDate = erase(sesDate,extractAfter(sesDate,16));
    sesDate = strcat(sesDate,'+00:00');
    sesDate = datetime(sesDate,'InputFormat','yyyy-MM-dd''T''HH:mmXXX','TimeZone','America/New_York');
    formatOut = 'mmddyy';
    sesDate = datestr(sesDate,formatOut);
    
    % Check in the available session paths to see if there is a
    % coeff.grad file that matches this session
    stillLooking = true;
    sessionPathIdx = 1;
    while stillLooking
        subjDir = fullfile(coeffGradLocation,sessionPaths{sessionPathIdx},subID,sesDate,'**',p.Results.coeffGradFileName);
        candidateFileToUpload = dir(subjDir);
        if ~isempty(candidateFileToUpload)
            % There should only be one candidate file
            if length(candidateFileToUpload)>1
                % Report what happened
                if verbose
                    fprintf([subID ', ' sesDate ': MORE THAN ONE coeff.grad FILE FOUND; skipping\n']);
                end
                stillLooking=false;
            end
            % Check if there is already a coeff.grad file, and if so
            % decline to upload another
            sessionFiles = allSessions{session}.files;
            if ~isempty(sessionFiles) && stillLooking
                if any(strcmp(cellfun(@(x) x.name,sessionFiles,'UniformOutput',false),p.Results.coeffGradFileName))
                    % Report what happened
                    if verbose
                        %fprintf([subID ', ' sesDate ': coeff.grad file all ready present; skipping\n']);
                    end
                    stillLooking=false;
                end
            end
            if stillLooking
                % Define the path to the file
                fileToUpload = fullfile(candidateFileToUpload.folder,candidateFileToUpload.name);
                % Get the session ID
                sesID = allSessions{session}.id;
                % Upload the coeff.grad file to the session attachments
                fw.uploadFileToSession(sesID,fileToUpload);
                % No longer looking
                stillLooking=false;
                % Report what we've done
                if verbose
                    fprintf([subID ', ' sesDate ': coeff.grad file uploaded\n']);
                end
            end
        else
            sessionPathIdx=sessionPathIdx+1;
            if sessionPathIdx>length(sessionPaths)
                stillLooking=false;
                % Report what happened
                if verbose
                    fprintf([subID ', ' sesDate ': No coeff.grad file found\n']);
                end
            end
        end
    end
end
disp(['End time: ' char(datetime('now'))]);