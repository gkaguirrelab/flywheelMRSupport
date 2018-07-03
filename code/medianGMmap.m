function medianGMmap(project,
%
%
% This script calculates the median values in the gray matter of a given 4D timeseries.

%% Convenience variables

projectName  = 'LFContrastAnalysis';
flywheelName = 'LFContrast';
subjID       = 'sub-HEROgka1';
session      = 'ses-0411181853PM';
sessionLabel = '04/11/18 18:53 PM';

%% %% Analysis labels that we are going to go and get
fmriprepLabel   = 'fmriprep 04/12/2018 15:16:06';
neuropythyLabel = 'retinotopy-templates 04/13/2018 16:46:22';
fwInfo          = getAnalysisFromFlywheel(flywheelName,fmriprepLabel,fullfile(getpref('LFContrastAnalysis','projectRootDir'),'fmriprep'),'nodownload',true);
sessionDir      = fullfile(getpref('LFContrastAnalysis','projectRootDir'),[fwInfo.subject,'_', fwInfo.timestamp(1:10)]);
if ~isfolder(sessionDir)
    mkdir(sessionDir);
end
if ~isfolder(fullfile(sessionDir,'fmriprep'))
    fwInfo          = getAnalysisFromFlywheel(flywheelName,fmriprepLabel,fullfile(sessionDir,'fmriprep'));
    fwInfoRetino    = getAnalysisFromFlywheel(flywheelName,neuropythyLabel,fullfile(sessionDir,'neuropythy'));
end

%% Relevant Nifti names for ANTS warp

% Native GM brainmask to warp to MNI EPI space
inFileName = 'sub-HEROgka1_ses-0411181853PM_T1w_class-GM_probtissue.nii.gz';

% Brain mask of function run for the reference volume in ANTs step
refFileName  =  'sub-HEROgka1_ses-0411181853PM_task-tfMRIFLASHAP_run-1_bold_space-MNI152NLin2009cAsym_brainmask.nii.gz';

% Warp file name (product of running fmriprep)
warpFileName = 'sub-HEROgka1_ses-0411181853PM_T1w_space-MNI152NLin2009cAsym_target-T1w_warp.h5';

% Set up paths to nifti and .h5 files
functionalPath = fullfile(sessionDir, 'fmriprep', subjID, session, 'func');
warpFilePath   = fullfile(sessionDir, 'fmriprep', subjID, session, 'anat');

%% Apply the warp to the T1 file using ANTs

inFile = fullfile(warpFilePath,inFileName);
outFile = fullfile(warpFilePath,'GM_brainmask_MNI_EPI.nii.gz');
warpFile = fullfile(warpFilePath,warpFileName);
refFile = fullfile(functionalPath,refFileName);

% Apply the ANTS transform
applyANTsWarpToData(inFile,outFile,warpFile,refFile);

%% Make median volume from functional run

% Get the file you want to take median of
fileToMedianName = 'sub-HEROgka1_ses-0411181853PM_task-tfMRIFLASHAP_run-1_bold_space-MNI152NLin2009cAsym_preproc.nii.gz';
fileToMedian = fullfile(functionalPath,fileToMedianName);

%  Load the file
nii = MRIread(fileToMedian);
timeSeries = nii.vol;

% Load donor
donorFileName = 'sub-HEROgka1_ses-0411181853PM_task-tfMRIFLASHAP_run-1_bold_space-MNI152NLin2009cAsym_brainmask.nii.gz';
donor = MRIread(fullfile(functionalPath,donorFileName));

% File to write median volume to
writeFileName = strcat(erase(fileToMedianName,'.nii.gz'),'_3D_GM.nii.gz');
writeFile = fullfile(functionalPath,writeFileName);

% Load GM Brainmask
niiBrainmask = MRIread(outFile);
niiBrainmaskVol = niiBrainmask.vol;

% Take the median (while removing non-GM values) and write to the writeFile

newVol = nan(size(timeSeries,1),size(timeSeries,2),size(timeSeries,3));
for index1 = 1:size(timeSeries,1)
    for index2 = 1:size(timeSeries,2)
        for index3 = 1:size(timeSeries,3)
            if niiBrainmaskVol(index1,index2,index3) > 0.1
                newVol(index1,index2,index3) = median(timeSeries(index1,index2,index3,:));
            end
        end
    end    
end
% medianTimeSeries = median(timeSeries,4);
donor.vol = newVol;
donor.fspec = writeFile;
MRIwrite(donor,writeFile);

% %% Remove non-GM values from median volume 
% 
% % The GM-only file
% GMFileName = strcat(erase(writeFileName,'.nii.gz'),'_GM.nii.gz');
% GMFile = fullfile(functionalPath,GMFileName);
% 
% % Remove non-GM values
% niiMedian = MRIread(writeFile);
% niiBrainmask = MRIread(outFile);
% niiMedianVol = niiMedian.vol;
% niiBrainmaskVol = niiBrainmask.vol;
% 
% for idx = 1:length(niiBrainmaskVol(:))
%     if niiBrainmaskVol(idx) < 0.1
%         niiMedianVol(idx) = Nan;
%     end
% end
% 
% donor.vol = niiMedianVol;
% donor.fspec = GMFile;
% MRIwrite(donor,GMFile);
% 
% disp('Done.');