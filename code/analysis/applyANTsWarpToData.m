function [outputs] = applyANTsWarpToData(inFiles,params,varargin)
% applyANTsWarpToData -- Apply the ANTs registration file from frmiprep to the output of the benson atlas.
%
%   Details: This function uses the ANTS command line tools to call 
%            antsApplyTransforms which will warp/register a nifti volume 
%            (e.g. Benson atlas outputs) and resample voxel size to a 
%            reference volume  (e.g. my_functional_data_MNI_space.nii.gz) 
%            to generate an output volume. *Needs ANTs compiled binaries set 
%            in the system path: see github wiki page for flywheelMRSupport
%            (https://github.com/gkaguirrelab/flywheelMRSupport/wiki)*
%
%   Inputs:
%       inFiles                 = Input volume to be warped. Must be a cell
%       Required params subfields
%           params.path2input   = Path to iunput volume
%           params.path2ref     = Path to refernce file 
%           params.refFileName  = Reference file name. This will set the
%                                 resolution of the warp output volume
%           params.path2warp    = Path to the warp file
%           params.warpFileName = Warp file(.h5) that ANTs applies to the
%                                 input volume
%       varargin:
%           verbose             = Print stuff to the screen for
%                                 antsApplyTransforms (default true) 
%           dimensions          = Dimesionality of warp (default 3) 
%   Output:
%       outputs = a cell of the output filenames;
%
%   Call:
%       inFiles             = 'subj_001_native.template_areas.nii.gz'
%       params.path2input   = '/home/user/myTemplates/data/'
%       params.path2ref     = '/home/user/experiments/func/'
%       params.refFileName  = 'subj_001_sesion_task_run-1_bold_space-MNI_brainmask.nii.gz';
%       params.path2warp    = '/home/user/experiments/anat/'
%       params.warpFileName =   'subj_001_sesion_T1w_target-MNI152NLin2009cAsym_warp.h5'
%       
%       [] = applyANTsWarpToData(inFiles,params);
%

% mab 2018 -- created

p = inputParser;
p.addParameter('verbose',1,@isnumeric);
p.addParameter('dimensions',3,@isnumeric);
p.parse(varargin{:});

for ii = 1:length(inFiles)
    %% set up file names
    % input file
    inFile = fullfile(params.path2input,inFiles{ii});
    % output file
    [~,tempName,~] = fileparts(inFile);
    [~,outName,~] = fileparts(tempName);
    outFile = fullfile(params.path2ret,[outName '_MNI_resampled.nii.gz']);
    outputs{ii} = outFile;
    %reference file
    refFile = fullfile(params.path2ref,params.refFileName);
    
    %warp file
    warpFile = fullfile(params.path2warp,params.warpFileName);
    
    cmd = ['antsApplyTransforms -d ' num2str(p.Results.dimensions) ' -o ' outFile '-v ' num2str(p.Results.verbose) ' -t ' ...
            warpFile ' -i ' inFile ' -r ' refFile];
    system(cmd);
end


