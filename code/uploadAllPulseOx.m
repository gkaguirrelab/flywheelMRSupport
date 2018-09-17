function uploadAllPulseOx(projectName, pulseOxLocation,varargin)
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
%   'availableSessionNames'  - Cell array with possible session names with
%                              acquisitions that may have PulseOx data.
%
%   'sessionPaths'           - Cell array that corresponds to
%                              availableSessionNames and is the filePath to
%                              the location of the PulseOx data.
%
% Examples:
%{
    uploadAllPulseOx('tome','~/Dropbox (Aguirre-Brainard Lab)/TOME_data','verbose',true)
%}


%% Convenience variables
p = inputParser; p.KeepUnmatched = false;
p.addRequired('projectName', @ischar);
p.addRequired('pulseOxLocation', @ischar);

p.addParameter('availableSessionNames',{'Session 1','Session 2'}, @iscell);
p.addParameter('sessionPaths',{'/session1_restAndStructure/','/session2_spatialStimuli/'}, @iscell);
p.addParameter('verbose',false, @islogical);

p.parse(projectName, pulseOxLocation, varargin{:})

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

if verbose
    disp(['Uploading pulse ox from project ' projectName ' to Flywheel.']);
    fprintf(['Start time: ' char(datetime('now')) ' \n\n']);
end

allSessions = fw.getProjectSessions(projID);
scratchDir = getpref('flywheelMRSupport','flywheelScratchDir');

% Get acquisitions for each session
for session = 1:numel(allSessions)
    if contains(allSessions{session}.label,availableSessionNames)
        sesID = allSessions{session}.id;
        allAcqs = fw.getSessionAcquisitions(sesID);
        % Instantiate arrays
        acqTimes = NaT(1,'TimeZone','America/New_York');
        acqIDs = {};
        idx = 0;
        % Get the desired acquisitions
        for acq = 1:numel(allAcqs)
            if contains(allAcqs{acq}.label,'fMRI') && ~contains(allAcqs{acq}.label,'SBRef')
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
            
            % Find the right subject/session directory
            for ssn = 1:length(availableSessionNames)
                if strcmp(allSessions{session}.label,availableSessionNames{ssn})
                    if verbose
                        fprintf('\n');
                        disp([allSessions{session}.subject.code ' - ' availableSessionNames{ssn}]);
                    end
                    % Find the Subject Directory
                    subjDir = fullfile(pulseOxLocation,sessionPaths{ssn},allSessions{session}.subject.code);
                    folders = dir(subjDir);
                end
            end
            
            % Match Session Folder to Flywheel Session
            formatOut = 'mmddyy';
            dateString = datestr(acqTimes(1),formatOut);
            sesDir = [];
            for gg = 1:length(folders)
                if strcmp(folders(gg).name,dateString)
                    sesDir = folders(gg);
                    break;
                end
            end
            if isempty(sesDir)
                fprintf('\t Cannot find a corresponding TOME_data session directory; skipping.\n');
                continue
            end
            
            % Find all the PulseOx files for this session
            pulseDir = fullfile(subjDir, sesDir.name,'ScannerFiles','PulseOx');
            allPulseFiles = dir(fullfile(pulseDir));
            pulseFiles = allPulseFiles(3:end);
            
            % Loop through the fMRI acquisitions in this session. For each
            % acquisition, we will identify the DICOM file and download
            % it, and then see if it can be used to generate a valid pulse
            % ox file.
            for file = 1:length(sortedIDs)
                acqToUpload = fw.getAcquisition(sortedIDs{file});
                acqToUploadFiles = acqToUpload.files;
                
                % Check for some conditions that would cause us to skip
                % processing this acquisition. First, check if there are
                % DICOM files available
                dicomFileIdx = find(cellfun(@(x) strcmp(x.type,'dicom'),acqToUploadFiles),1);
                if isempty(dicomFileIdx)
                    fprintf(['\t' acqToUpload.label '- DICOM file not found; skipping.\n']);
                    continue
                end
                
                % Check for the case in which there is already a pulse file
                % for this acquisition
                if any(cellfun(@(x) contains(x.name,'_puls.mat'),acqToUploadFiles))
                    fprintf(['\t' acqToUpload.label '- puls.mat file already present; skipping.\n']);
                    continue
                end
                
                % Create the directory to store the dicom files.
                fullDicomPath = fullfile(scratchDir,['dicomFiles-' allSessions{session}.subject.code '-' allSessions{session}.label]);
                if ~exist(fullfile(scratchDir,['dicomFiles-' allSessions{session}.subject.code '-' allSessions{session}.label]))
                    mkdir(fullfile(scratchDir,['dicomFiles-' allSessions{session}.subject.code '-' allSessions{session}.label]));
                end
                
                % Create a directory to store output of PulseResp (comparing dicoms and
                % PulseOx log files).
                pulsePath = fullfile(fullDicomPath,['pulseOutput-' acqToUpload.label]);
                if ~exist(fullfile(fullDicomPath,['pulseOutput-' acqToUpload.label]))
                    mkdir(fullfile(fullDicomPath,['pulseOutput-' acqToUpload.label]));
                end
                
                % Download the file
                dcmFile = strcat(fullDicomPath,'/',acqToUploadFiles{dicomFileIdx}.name);
                if ~exist(dcmFile)
                    fw.downloadFileFromAcquisition(acqToUpload.id,acqToUploadFiles{dicomFileIdx}.name,dcmFile);
                end
                dcmDir = strcat(fullDicomPath,['/dicomDir-' acqToUpload.label]);
                
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
                
                % Go through the PulseOx files and compare them to the dicoms.
                jj=1;
                notDoneFlag = true;
                while notDoneFlag
                    pulseFile = strcat(pulseFiles(jj).folder,'/',pulseFiles(jj).name);
                    % Compare the dicoms and the log file
                    pulseOutput = PulseResp(dcmDir,pulseFile,pulsePath,'verbose',false);
                    if isempty(pulseOutput)
                        jj=jj+1;
                        if jj>length(pulseFiles)
                            notDoneFlag = false;
                            if verbose
                                fprintf(['\t' acqToUpload.label '- Valid pulse ox file not found; skipping.\n']);
                            end
                        end
                    else
                        notDoneFlag = false;
                        % Upload the raw log file and the processed
                        % puls.mat file to matlab
                        fw.uploadFileToAcquisition(sortedIDs{file},pulseFile);
                        newMatFile = fullfile(pulsePath,[acqToUpload.label '_puls.mat']);
                        movefile(fullfile(pulsePath,'puls.mat'),newMatFile);
                        fw.uploadFileToAcquisition(sortedIDs{file},newMatFile);
                        if verbose
                            fprintf(['\t' acqToUpload.label '- cardiac: %4.1f, resp: %4.1f - ' pulseFile '\n'],pulseOutput.Highrate,pulseOutput.Lowrate);
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
    end
end
disp(['Start time: ' char(datetime('now'))]);