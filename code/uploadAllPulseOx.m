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
% Examples:
%{
    uploadAllPulseOx('tome','~/Dropbox (Aguirre-Brainard Lab)/TOME_data')
%}


%% Convenience variables
p = inputParser; p.KeepUnmatched = false;
p.addRequired('projectName', @ischar);
p.addRequired('pulseOxLocation', @ischar);

p.addParameter('verbose',false, @islogical);

p.parse(projectName, pulseOxLocation, varargin{:})

projectName = p.Results.projectName;
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

% Get acquisitions for each session
session1Bad = {};
session2Bad = {};
for session = 1:numel(allSessions)
    if strcmp(allSessions{session}.label,'Session 1') || strcmp(allSessions{session}.label,'Session 2')
        sesID = allSessions{session}.id;
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
            if strcmp(allSessions{session}.label,'Session 1')
                % Find the Subject Directory
                subjDir = strcat(pulseOxLocation,'/session1_restAndStructure/',allSessions{session}.subject.code);
                folders = dir(subjDir);
            end
                
            % Check for Session 2
            if strcmp(allSessions{session}.label,'Session 2')
                % Find the Subject Directory
                subjDir = strcat(pulseOxLocation,'/session2_spatialStimuli/',allSessions{session}.subject.code);
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

            if length(pulseFiles) ~= length(acqTimes)
                warning(['Subject ' allSessions{session}.subject.code ' for ' allSessions{session}.label ' has an unequal number of puls.log files. ']);
                if strcmp(allSessions{session}.label,'Session 2')
                    session2Bad{end+1} = [allSessions{session}.subject.code ' -- ' dateString];
                else
                    session1Bad{end+1} = [allSessions{session}.subject.code ' -- ' dateString];
                end
            end
            
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
                    warning(['Subject ' allSessions{session}.subject.code ' for Session 2 for Acquisition ' acqToUpload.label ' already has PulseOx files on Flywheel.']);
                end
            end
            
            scratchDir = getpref('flywheelMRSupport','flywheelScratchDir');
            if ~exist(fullfile(scratchDir,'dicomFiles'))
                mkdir(fullfile(scratchDir,'dicomFiles'));
            end
            
            for file = 1:length(sortedIDs)
                acqToUpload = fw.getAcquisition(sortedIDs{file});
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
                        % fw.uploadFileToAcquisition(acqIDs{file},fullfile(pulseFiles(file).folder,pulseFiles(file).name));
                        break;
                    catch
                        if file == length(pulseFiles)
                            warning('This acquisition has no compatible PulseOx files');
                        end
                    end
                end
                
                allDcmFiles = fullfile(dcmDir,'/*');
                delete(allDcmFiles);
                rmdir(dcmDir);
                delete(dcmFile);
                
            end
        end
    end
end