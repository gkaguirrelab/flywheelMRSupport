function [pulseOxMatches, allMatched] = uploadPulseOx(projectName, subjectName, sessionName, pulseOxLocation,varargin)
% Script that uploads all PulseOx files to the correct Flywheel acquisition

% Syntax:
%  uploadAllPulseOx(projectName,pulseOxLocation)
%
% Description:
%   This routine finds all the task and resting state acquisitions for a
%   given project and uploads their corresponding PulseOx files. These
%   PulseOx files must be located in a local directory.
%
% Inputs:
%   projectName             - Define the project. This is the project you
%                             are interested in uploading PulseOx files to
%                             its acquisitions.
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
% Examples:
%{
    uploadPulseOx('tome','TOME_3009','Session 2','~/Dropbox (Aguirre-Brainard Lab)/TOME_data')
%}


%% Convenience variables
p = inputParser; p.KeepUnmatched = false;
p.addRequired('projectName', @ischar);
p.addRequired('subjectName', @ischar);
p.addRequired('sessionName', @ischar);
p.addRequired('pulseOxLocation', @ischar);

p.addParameter('verbose',false, @islogical);

p.parse(projectName, subjectName, sessionName, pulseOxLocation, varargin{:})

projectName = p.Results.projectName;
subjectName = p.Results.subjectName;
sessionName = p.Results.sessionName;
pulseOxLocation = p.Results.pulseOxLocation;
verbose = p.Results.verbose;

%% Instantiate Flywheel object

fw = flywheel.Flywheel(getpref('flywheelMRSupport','flywheelAPIKey'));

%% Get project ID and sessions
allProjects = fw.getAllProjects;
for proj = 1:numel(allProjects)
    if strcmp(allProjects{proj}.label,projectName)
        projID = allProjects{proj}.id;
    end
end

allSessions = fw.getProjectSessions(projID);
for ss = 1:length(allSessions)
    if strcmp(allSessions{ss}.label,sessionName) && strcmp(allSessions{ss}.subject.code,subjectName)
        session = allSessions{ss};
        break;
    end
end

sesID = session.id;
allAcqs = fw.getSessionAcquisitions(sesID);
% Instantiate arrays
acqTimes = NaT(1,'TimeZone','America/New_York');
acqIDs = {};
idx = 0;
% Get the desired acquisitions
for acq = 1:numel(allAcqs)
    if (contains(allAcqs{acq}.label,'tfMRI') || contains(allAcqs{acq}.label,'rfMRI')) && ~contains(allAcqs{acq}.label,'SBRef')
        idx = idx+1;
        newAcqTime = allAcqs{acq}.timestamp;
        newAcqTime = erase(newAcqTime,extractAfter(newAcqTime,16));
        newAcqTime = strcat(newAcqTime,'+00:00');
        newAcqTime = datetime(newAcqTime,'InputFormat','yyyy-MM-dd''T''HH:mmXXX','TimeZone','America/New_York');
        acqTimes(idx) = newAcqTime;
        acqIDs{end+1} = allAcqs{acq}.id;
    end
end

% Sort the times and IDs
[acqTimes, ind] = sort(acqTimes);
sortedIDs = acqIDs;
if ~isempty(sortedIDs)
    for ii = 1:length(ind)
        sortedIDs{ii} = acqIDs{ind(ii)};
    end
    
    % Check for Session 1
    if strcmp(sessionName,'Session 1')
        % Find the Subject Directory
        subjDir = strcat(pulseOxLocation,'/session1_restAndStructure/',session.subject.code);
        folders = dir(subjDir);
    end
    
    % Check for Session 2
    if strcmp(sessionName,'Session 2')
        % Find the Subject Directory
        subjDir = strcat(pulseOxLocation,'/session2_spatialStimuli/',session.subject.code);
        folders = dir(subjDir);
    end
    
    % Match Session Folder to Flywheel Session
    formatOut = 'mmddyy';
    dateString = datestr(acqTimes(1),formatOut);
    for gg = 1:length(folders)
        if strcmp(folders(gg).name,dateString)
            sesDir = folders(gg);
            break;
        end
    end
    
    pulseDir = fullfile(subjDir, sesDir.name,'ScannerFiles','PulseOx');
    allPulseFiles = dir(fullfile(pulseDir));
    pulseFiles = allPulseFiles(3:end);
    
    for file = 1:length(sortedIDs)
        acqToUpload = fw.getAcquisition(sortedIDs{file});
        acqToUploadFiles = acqToUpload.files;
        logExists = false;
        for fff = 1:length(acqToUploadFiles)
            if strcmp(acqToUploadFiles{fff}.type,'log')
                logExists = true;
            end
        end
        
        if logExists
            warning('This session already has PulseOx files on Flywheel.');
        end
    end
    
    scratchDir = getpref('flywheelMRSupport','flywheelScratchDir');
    if ~exist(fullfile(scratchDir,'dicomFiles'))
        mkdir(fullfile(scratchDir,'dicomFiles'));
    end
    
    if ~exist(fullfile(scratchDir,'dicomFiles/pulseOutput'))
        mkdir(fullfile(scratchDir,'dicomFiles/pulseOutput'));
    end
    
    pulseOxMatches = strings(length(sortedIDs),2);
    allMatched = true;
    for file = 1:length(sortedIDs)
        acqToUpload = fw.getAcquisition(sortedIDs{file});
        pulseOxMatches(file,1) = acqToUpload.label;
        acqToUploadFiles = acqToUpload.files;
        for fff = 1:length(acqToUploadFiles)
            if strcmp(acqToUploadFiles{fff}.type,'dicom')
                disp(acqToUploadFiles{fff}.name);
                dcmFile = strcat(scratchDir,'/dicomFiles/',acqToUploadFiles{fff}.name);
                if ~exist(dcmFile)
                    dcmFile = fw.downloadFileFromAcquisition(acqToUpload.id,acqToUploadFiles{fff}.name,dcmFile);
                end
                dcmDir = strcat(scratchDir,'/dicomFiles/dicomDir');
                unzip(dcmFile,dcmDir);
            end
        end
        
        for jj = 1:length(pulseFiles)
            pulseFile = strcat(pulseFiles(jj).folder,'/',pulseFiles(jj).name);
            try
                PulseResp(dcmDir,pulseFile,strcat(scratchDir,'/dicomFiles/pulseOutput'),'verbose',verbose);
                disp('this works.');
                fw.uploadFileToAcquisition(sortedIDs{file},pulseFile);
                pulseOxMatches(file,2) = pulseFiles(jj).name;
                break;
            catch ME
                disp('this does not work.');
                if jj == length(pulseFiles)
                    warning(['Aquisition ' acqToUpload.label ' has no compatible PulseOx files']);
                    allMatched = false;
                end
                disp(ME);
            end
        end
        
        allDcmFiles = fullfile(dcmDir,'/*');
        delete(allDcmFiles);
        rmdir(dcmDir);
        delete(dcmFile);
        
    end
end