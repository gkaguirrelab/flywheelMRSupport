function analyzeWholeBrain(subjectID, runName, covariateStruct, varargin)
% Complete analysis pipeline for analyzing resting state data, ultimately
% producing maps
%
% Syntax:
%  analyzeWholeBrain(subjectID, runName)
%
% Description:
%  This routine performs the analysis pipeline for functional BOLD data
%  from resting state runs. Basic analysis steps include to 1) download the
%  necessary data off of flywheel, 2) register the functional volume to the
%  structural volume in subject native space, 3) extract white matter and
%  ventricular signals to be used as nuisance regressors, 4) extract time
%  series from each gray matter voxel in the functional volume, 5) regress
%  out signals from physio, motion, white matter, and ventricles to yield
%  cleaned time series, and 6) regress out a series of eye signals
%  extracted from pupillometry and create maps out of these statistics.
%
%  This routien also requires several pieces of pre-installed software.
%  These include FSL, HCP Workbench, and AFNI.
%
%  Besides the explicit inputs listed below, the routine expects to be able
%  to find certain data files. If processing in the volume, these include:
%  the functional volume, anatomic volume (for registration), aparc+aseg
%  parcellation, physio files, and movement text files. Also note that this
%  analysis is intended to be performed in subject native space. For CIFTI
%  processing, these include: the functional grayordinates and mid-thickness
%  maps.
%
% Inputs:
%  subjectID:           - a string that identifies the relevant subject (i.e.
%                         'TOME_3040'
%  runName:             - a string that identifies the relevant run (i.e.
%                         'rfMRI_REST_AP_Run3')
%  covariateStruct      - a struct that defines our covariates of interest.
%                         One of the subfields must labeled 'timebase' and
%                         define the timebase for all other covariates
%
% Optional key-value pairs:
%  skipPhysioMotionWMVRegression  - a logical, with false set as the
%                         default. If true, regressors will be created out
%                         of motion parameters, physiology parameters, and
%                         mean white matter and ventricular signals. One
%                         reason to is when using output from ICAFix, which
%                         we believe will have already dealed with these
%                         nuisance signals.
%  fileType             - a string that controls which type of functional
%                         file is to be processed. Options include 'volume'
%                         and 'CIFTI'. Note that for now, 'volume' is
%                         intended to be analyzed in subject-native space,
%                         and 'CIFTI' in MNI volume, freeSurfer cortical
%                         surface space.
%  cleanedTimeSeriesSavePath - a string that defines a path to where we
%                         want to save the cleanedTimeSeries results
%  statsSavePath        - a string that defines a path to where we
%                         want to save the whole brain maps
%  rawPath              - a string that defines a path to where raw data
%                         lives
%  CIFTITEmplateName    - a string that defines the file name of the
%                         template file
%  CIFTISuffix          - a string that refers to the suffix applied
%                         functional files following processing that gets
%                         appended to the runName
%  TR                   - a number that defines the TR, in ms, of the
%                         functional scan
% Outputs:
%  None. Several maps are saved out to Dropbox, however.

%% Input parser
p = inputParser; p.KeepUnmatched = true;

p.addParameter('skipPhysioMotionWMVRegression', false, @islogical);
p.addParameter('fileType', 'volume', @ischar);
p.addParameter('cleanedTimeSeriesSavePath', [], @ischar);
p.addParameter('statsSavePath', [], @ischar);
p.addParameter('CIFTISuffix', '_Atlas_hp2000_clean.dtseries.nii', @ischar);
p.addParameter('rawPath', [], @ischar);
p.addParameter('TR', 800, @isnumeric);
p.addParameter('CIFTITemplateName', 'template.dscalar.nii', @ischar);



p.parse(varargin{:});

%% Register functional scan to anatomical scan

if strcmp(p.Results.fileType, 'volume')
    [ ~ ] = registerFunctionalToAnatomical(subjectID, runName);
    
    %% Smooth functional scan
    functionalFile = fullfile(p.Results.rawPath, [runName, '_native.nii.gz']);
    [ functionalScan ] = smoothVolume(functionalFile);
    %% Get white matter and ventricular signal
    % make white matter and ventricular masks
    targetFile = (fullfile(p.Results.rawPath, [runName, '_native.nii.gz']));
    
    aparcAsegFile = fullfile(p.Results.rawPath, [subjectID, '_aparc+aseg.nii.gz']);
    
    if ~(p.Results.skipPhysioMotionWMVRegression)
        [whiteMatterMask, ventriclesMask] = makeMaskOfWhiteMatterAndVentricles(aparcAsegFile, targetFile);
        
        
        % extract time series from white matter and ventricles to be used as
        % nuisance regressors
        [ meanTimeSeries.whiteMatter ] = extractTimeSeriesFromMask( functionalScan, whiteMatterMask, 'whichCentralTendency', 'median');
        [ meanTimeSeries.ventricles ] = extractTimeSeriesFromMask( functionalScan, ventriclesMask, 'whichCentralTendency', 'median');
        clear whiteMatterMask ventriclesMask
    end
    %% Get gray matter mask
    makeGrayMatterMask(subjectID);
    structuralGrayMatterMaskFile = fullfile(anatDir, [subjectID '_GM.nii.gz']);
    grayMatterMaskFile = fullfile(anatDir, [subjectID '_GM_resampled.nii.gz']);
    [ grayMatterMask ] = resampleMRI(structuralGrayMatterMaskFile, targetFile, grayMatterMaskFile);
    
    %% Extract time series of each voxel from gray matter mask
    [ ~, rawTimeSeriesPerVoxel, voxelIndices ] = extractTimeSeriesFromMask( functionalScan, grayMatterMask);
    clear grayMatterMask
    
    %% Clean time series from physio regressors
    if ~(p.Results.skipPhysioMotionWMVRegression)
        
        physioRegressors = load(fullfile(p.Results.rawDir, [runName, '_puls.mat']));
        physioRegressors = physioRegressors.output;
        motionTable = readtable((fullfile(p.Results.rawDir, [runName, '_Movement_Regressors.txt'])));
        motionRegressors = table2array(motionTable(:,7:12));
        regressors = [physioRegressors.all, motionRegressors];
        
        % mean center these motion and physio regressors
        for rr = 1:size(regressors,2)
            regressor = regressors(:,rr);
            regressorMean = nanmean(regressor);
            regressor = regressor - regressorMean;
            regressor = regressor ./ regressorMean;
            nanIndices = find(isnan(regressor));
            regressor(nanIndices) = 0;
            regressors(:,rr) = regressor;
        end
        
        % also add the white matter and ventricular time series
        regressors(:,end+1) = meanTimeSeries.whiteMatter;
        regressors(:,end+1) = meanTimeSeries.ventricles;
        
        TR = functionalScan.tr; % in ms
        nFrames = functionalScan.nframes;
        
        
        regressorsTimebase = 0:TR:nFrames*TR-TR;
        
        % remove all regressors that are all 0
        emptyColumns = [];
        for column = 1:size(regressors,2)
            if ~any(regressors(:,column))
                emptyColumns = [emptyColumns, column];
            end
        end
        regressors(:,emptyColumns) = [];
        
        [ cleanedTimeSeriesMatrix, stats_physioMotionWMV ] = cleanTimeSeries( rawTimeSeriesPerVoxel, regressors, regressorsTimebase, 'meanCenterRegressors', false, 'totalTime', nFrames*TR, 'TR', TR);
        clear stats_physioMotionWMV rawTimeSeriesPerVoxel meanTimeSeries regressors functionalScan
    else
        cleanedTimeSeriesMatrix = rawTimeSeriesPerVoxel;
        clear rawTimeSeriesPerVoxel functionalScan
    end
end

if strcmp(p.Results.fileType, 'CIFTI')
    %% Smooth the functional file
    functionalFile = fullfile(p.Results.rawPath, [runName, p.Results.CIFTISuffix]);
    [ smoothedGrayordinates ] = smoothCIFTI(functionalFile);
    
    % mean center the time series of each grayordinate
    [ cleanedTimeSeriesMatrix ] = meanCenterTimeSeries(smoothedGrayordinates);
    
    % make dumnmy voxel indices. this doesn't really apply for grayordinate
    % based analysis, but the code is expecting the variable to at least
    % exist
    voxelIndices = [];
    
    clear smoothedGrayordinates
end

% save out cleaned time series
if ~isempty(p.Results.cleanedTimeSeriesSavePath)
    savePath = p.Results.cleanedTimeSeriesSavePath;
    if ~exist(savePath,'dir')
        mkdir(savePath);
    end
    save(fullfile(savePath, [runName, '_cleanedTimeSeries']), 'cleanedTimeSeriesMatrix', 'voxelIndices', '-v7.3');
end


%% Analyze regressors
if strcmp(p.Results.fileType, 'volume')
    templateFile = functionalFile;
elseif strcmp(p.Results.fileType, 'CIFTI')
    templateFile = fullfile(p.Results.rawPath, p.Results.CIFTITemplateName);
end


% assemble regressors
regressors = [];

covariateStructFieldNames = fieldnames(covariateStruct);

covariateNames = [];
for nn = 1:length(covariateStructFieldNames)
    if ~contains(covariateStructFieldNames{nn}, 'timebase')
        covariateNames{end+1} = covariateStructFieldNames{nn};
    end
end

for nn = 1:length(covariateNames)
    regressors = [regressors; covariateStruct.(covariateNames{nn})];
end


% perform the regression
TR = p.Results.TR;
totalTime = size(cleanedTimeSeriesMatrix,2)*TR;
[ ~, stats ] = cleanTimeSeries( cleanedTimeSeriesMatrix, regressors, covariateStruct.timebase, 'meanCenterRegressors', true, 'totalTime', totalTime, 'TR', TR);

% determine output type
if strcmp(p.Results.fileType, 'volume')
    suffix = '.nii.gz';
elseif strcmp(p.Results.fileType, 'CIFTI')
    suffix = '.dscalar.nii';
end


% save our rSquared
if ~exist(p.Results.statsSavePath,'dir')
    mkdir(p.Results.statsSavePath);
end
saveName = fullfile(p.Results.statsSavePath, [runName, '_', 'rSquared', suffix]);
makeWholeBrainMap(stats.rSquared(1,:), voxelIndices, templateFile, saveName);

% save our beta maps
for cc = 1:length(covariateNames)
    
    saveName = fullfile(p.Results.statsSavePath, [runName, '_beta_', covariateNames{cc}, suffix]);
    makeWholeBrainMap(stats.beta(cc,:), voxelIndices, templateFile, saveName);
    
    
end



clearvars
end