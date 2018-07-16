function [] = applyANTsWarpToData(inFile, outFile, warpFile, refFile, varargin)
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
%       inFiles                 = Full path and file name of the input file 
%       outFile                 = Full path and file name of the output file 
%       warpFile                = Full path and file name of the warp file (.h5) 
%       refFile                 = Full path and file name of the reference volume 
%                                  --The output volume will be resampled
%                                    to the resoultion of the reference
%       varargin:
%           verbose             = Print stuff to the screen for
%                                 antsApplyTransforms (default true)
%           dimensions          = Dimesionality of warp (default 3)
%   Output:
%       None
%
%   Call:
%       inFile             = '/home/user/myTemplates/data/subj_001_native.template_areas.nii.gz'
%       refFile            = '/home/user/experiments/func/subj_001_sesion_task_run-1_bold_space-MNI_brainmask.nii.gz';
%       warpFile           = '/home/user/experiments/anat/subj_001_sesion_T1w_target-MNI152NLin2009cAsym_warp.h5'
%       outFile            = '/home/user/myTemplates/data/subj_001_native.template_areas_MNI_funcRes.nii.gz'
%       
%       [] = applyANTsWarpToData(inFile,outFile,warpFile,refFile,varargin)

% History:
% 01/xx/18 mab  Created
% 01/28/18 dhb  Use pref for ANTS bin location

%% Parse inputs
p = inputParser;
p.addParameter('verbose',1,@isnumeric);
p.addParameter('dimensions',3,@isnumeric);
p.parse(varargin{:});

%% Generate antsApplyTransform command A
cmd = [fullfile(getpref('flywheelMRSupport','binANTS'),'antsApplyTransforms') ' -d ' num2str(p.Results.dimensions) ' -o ' outFile ' -v ' num2str(p.Results.verbose) ' -t ' ...
        warpFile ' -i ' inFile ' -r ' refFile];
    
%% Run antsApplyTramsforms command
%display(cmd)
system(cmd);



