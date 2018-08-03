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
%
%   subjectName             - Name of subject to upload PulseOx data to.
%
%   subjectName             - Subject's session to upload PulseOx data to.
%
%   pulseOxLocation         - This is the location of the PulseOx files you
%                             want to upload to Flywheel.

% Outputs:
%   pulseOxMatches          - This is 2 column array, with first column
%                             containing acquisition names and second
%                             column containing the matching compatible
%                             PulseOx file. If no matching PulseOx file was
%                             found, that value will be empty.
%
%   allMatched              - Logical, if all acquisitions were matched to
%                             a PulseOx file, this is true. Otherwise
%                             false.
%
% Optional key/value pairs:
%   'verbose'                - Logical, default false
%
%   'availableSessionNames'  - Cell array with possible session names with
%                              acquisitions that may have PulseOx data.
%
%   'sessionPaths'           - Cell array that corresponds to
%                              availableSessionNames and is the filePath to
%                              the location of the PulseOx data.
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

% Optional key/value pairs
p.addParameter('availableSessionNames',{'Session 1','Session 2'}, @iscell);
p.addParameter('sessionPaths',{'/session1_restAndStructure/','/session2_spatialStimuli/'}, @iscell);
p.addParameter('verbose',false, @islogical);

% parse
p.parse(projectName, subjectName, sessionName, pulseOxLocation, varargin{:})

% Unpack p.Results
verbose = p.Results.verbose;
availableSessionNames = p.Results.availableSessionNames;
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
    for ssn = 1:length(availableSessionNames)
        if strcmp(sessionName,availableSessionNames{ssn})
            % Find the Subject Directory
            subjDir = fullfile(pulseOxLocation,sessionPaths{ssn},session.subject.code);
            folders = dir(subjDir);
        end
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
                if verbose
                    disp(acqToUploadFiles{fff}.name);
                end
                dcmFile = strcat(scratchDir,'/dicomFiles/',acqToUploadFiles{fff}.name);
                if ~exist(dcmFile)
                    dcmFile = fw.downloadFileFromAcquisition(acqToUpload.id,acqToUploadFiles{fff}.name,dcmFile);
                end
                dcmDir = strcat(scratchDir,'/dicomFiles/dicomDir');
                unzip(dcmFile,dcmDir);
                if contains(dcmFile,'.dicom')
                    dirs = dir(dcmDir);
                    extraDirName = dirs(3).name;
                    extraDir = fullfile(dirs(3).folder,extraDirName);
                    movefile(fullfile(extraDir,'*'),dcmDir);
                    rmdir(extraDir);
                end
            end
        end
        
        for jj = 1:length(pulseFiles)
            pulseFile = strcat(pulseFiles(jj).folder,'/',pulseFiles(jj).name);
            try
                PulseResp(dcmDir,pulseFile,strcat(scratchDir,'/dicomFiles/pulseOutput'),'verbose',verbose);
                if verbose
                    disp('this works.');
                end
                fw.uploadFileToAcquisition(sortedIDs{file},pulseFile);
                pulseOxMatches(file,2) = pulseFiles(jj).name;
                break;
            catch ME
                if verbose
                    disp('this does not work.');
                end
                if jj == length(pulseFiles)
                    warning(['Aquisition ' acqToUpload.label ' has no compatible PulseOx files']);
                    allMatched = false;
                end
                rethrow(ME);
            end
        end
        
        testDir = dir(dcmDir);
        if ~testDir(3).isdir
            allDcmFiles = fullfile(dcmDir,'/*');
            delete(allDcmFiles);
        else
            allDcmFiles = strcat(dcmDir,'/',testDir(3).name,'/*');
            delete(allDcmFiles);
            rmdir(fullfile(dcmDir,testDir(3).name));
        end
        
        rmdir(dcmDir);
        delete(dcmFile);
        
    end
end