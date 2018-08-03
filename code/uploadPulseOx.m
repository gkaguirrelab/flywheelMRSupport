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

%% Check to make sure this session is valid
    if ~contains(availableSessionNames,sessionName)
        error('This is not a valid session name.');
    end
%% Get project ID and sessions
allProjects = fw.getAllProjects;
for proj = 1:numel(allProjects)
    if strcmp(allProjects{proj}.label,projectName)
        projID = allProjects{proj}.id;
    end
end

% Get all the sessions for this project
allSessions = fw.getProjectSessions(projID);
for ss = 1:length(allSessions)
    % Find the session we are looking for
    if strcmp(allSessions{ss}.label,sessionName) && strcmp(allSessions{ss}.subject.code,subjectName)
        session = allSessions{ss};
        break;
    end
end

% Get the session ID
sesID = session.id;

% Get all acquisitions for this session
allAcqs = fw.getSessionAcquisitions(sesID);

% Instantiate arrays
acqTimes = NaT(1,'TimeZone','America/New_York');
acqIDs = {};
idx = 0;

% Get the desired acquisitions
for acq = 1:numel(allAcqs)
    
    % Only find tfMRI and rfMRI runs for PulseOx (no SBRefs)
    if (contains(allAcqs{acq}.label,'tfMRI') || contains(allAcqs{acq}.label,'rfMRI')) && ~contains(allAcqs{acq}.label,'SBRef')
        idx = idx+1;
        
        % Convert to a valid timestamp that MATLAB understands
        newAcqTime = allAcqs{acq}.timestamp;
        newAcqTime = erase(newAcqTime,extractAfter(newAcqTime,16));
        newAcqTime = strcat(newAcqTime,'+00:00');
        newAcqTime = datetime(newAcqTime,'InputFormat','yyyy-MM-dd''T''HH:mmXXX','TimeZone','America/New_York');
        
        % Add acquisition data to arrays
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
    
    % Find the right subject/session directory
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
    
    % Find all the PulseOx files for this session
    pulseDir = fullfile(subjDir, sesDir.name,'ScannerFiles','PulseOx');
    allPulseFiles = dir(fullfile(pulseDir));
    pulseFiles = allPulseFiles(3:end);
    
    % Get the current acquisition and check for existing PulseOx log files
    for file = 1:length(sortedIDs)
        acqToUpload = fw.getAcquisition(sortedIDs{file});
        acqToUploadFiles = acqToUpload.files;
        logExists = false;
        for fff = 1:length(acqToUploadFiles)
            if strcmp(acqToUploadFiles{fff}.type,'log')
                logExists = true;
            end
        end
        
        % Warning if log files already exist.
        if logExists
            warning('This session already has PulseOx files on Flywheel.');
        end
    end
    
    % Create the directory to store the dicom files.
    scratchDir = getpref('flywheelMRSupport','flywheelScratchDir');
    if ~exist(fullfile(scratchDir,'dicomFiles'))
        mkdir(fullfile(scratchDir,'dicomFiles'));
    end
    
    % Create a directory to store output of PulseResp (comparing dicoms and
    % PulseOx log files).
    if ~exist(fullfile(scratchDir,'dicomFiles/pulseOutput'))
        mkdir(fullfile(scratchDir,'dicomFiles/pulseOutput'));
    end
    
    % Instantiate outputs
    pulseOxMatches = strings(length(sortedIDs),2);
    allMatched = true;
    
    % Find the dicom files and download them to the dicom directory.
    for file = 1:length(sortedIDs)
        acqToUpload = fw.getAcquisition(sortedIDs{file});
        pulseOxMatches(file,1) = acqToUpload.label;
        acqToUploadFiles = acqToUpload.files;
        for fff = 1:length(acqToUploadFiles)
            
            % Finding the dicom file
            if strcmp(acqToUploadFiles{fff}.type,'dicom')
                if verbose
                    disp(acqToUploadFiles{fff}.name);
                end
                dcmFile = strcat(scratchDir,'/dicomFiles/',acqToUploadFiles{fff}.name);
                
                % Downloading the file
                if ~exist(dcmFile)
                    dcmFile = fw.downloadFileFromAcquisition(acqToUpload.id,acqToUploadFiles{fff}.name,dcmFile);
                end
                dcmDir = strcat(scratchDir,'/dicomFiles/dicomDir');
                
                % Unzip the file
                unzip(dcmFile,dcmDir);
                
                % Special case, some files are unzipped differently. This fixes that bug. 
                if contains(dcmFile,'.dicom')
                    dirs = dir(dcmDir);
                    extraDirName = dirs(3).name;
                    extraDir = fullfile(dirs(3).folder,extraDirName);
                    movefile(fullfile(extraDir,'*'),dcmDir);
                    rmdir(extraDir);
                end
            end
        end
        
        % Go through the PulseOx files and compare them to the dicoms.
        for jj = 1:length(pulseFiles)
            pulseFile = strcat(pulseFiles(jj).folder,'/',pulseFiles(jj).name);
            try
                % Compare the dicoms and the log file
                PulseResp(dcmDir,pulseFile,strcat(scratchDir,'/dicomFiles/pulseOutput'),'verbose',verbose);
                if verbose
                    disp('this works.');
                end
                % If they are matched, upload the log file to Flywheel
                fw.uploadFileToAcquisition(sortedIDs{file},pulseFile);
                
                % Matching the PulseOx file to the corresponding
                % acquisition
                pulseOxMatches(file,2) = pulseFiles(jj).name;
                break;
            catch 
                if verbose
                    disp('this does not work.');
                end
                
                % Warning if no log files match this acquisition
                if jj == length(pulseFiles)
                    warning(['Aquisition ' acqToUpload.label ' has no compatible PulseOx files']);
                    allMatched = false;
                end
            end
        end
        
        % Cleaning up the dicom directory by deleting all files inside it
        testDir = dir(dcmDir);
        if ~testDir(3).isdir
            allDcmFiles = fullfile(dcmDir,'/*');
            delete(allDcmFiles);
        else
            allDcmFiles = strcat(dcmDir,'/',testDir(3).name,'/*');
            delete(allDcmFiles);
            rmdir(fullfile(dcmDir,testDir(3).name));
        end
        
        % Delete the dicom directory.
        rmdir(dcmDir);
        
        % Delete the zipped dicom file.
        delete(dcmFile);
        
    end
end