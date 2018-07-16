%% Make median volume from functional run

% Set up paths to nifti and .h5 files
functionalPath = fullfile(sessionDir, 'fmriprep', subjID, session, 'func');

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
