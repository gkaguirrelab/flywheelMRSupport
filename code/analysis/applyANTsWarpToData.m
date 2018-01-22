function [] = applyANTsWarpToData(inFiles,params,varargin)
% applyANTsWarpToData -- Apply the ANTs registration file from frmiprep to the output of the benson atlas.
%
%   Details: This function uses the ANTS command line tools to
%            warp/register a nifti volume (e.g. Benson atlas
%            outputs) and resamples to a reference volume to match the functional data space. *Needs Freesurfer*
%
%   Inputs:
%       inFiles                 = Input volume to be warped
%       Required params subfields
%           params.path2input   = 
%           params.path2ref     = 
%           params.refFileName  = 
%           params.path2warp    =
%           params.warpFileName =
%       varargin:
%           verbose             =
%           dimensions          = 
%   Output:
%       NONE
%
%   Call:
%       inFiles             = 'subj_001_native.template_areas.nii.gz'
%       params.path2input   = '/home/user/myTemplates/data/'
%       params.path2ref     = '/home/user/experiments/func/'
%       params.refFileName  = 'subj_001_sesion_task_run-1_bold_space-MNI_brainmask.nii.gz';
%       params.path2warp    = 
%       params.warpFileName =
%       applyRetAtlas2Functional(inFiles,params,varargin)
%

% mab 2017 -- created

p = inputParser;
p.addParameter('verbose',1,@isnumeric);
p.addParameter('dimensions',3,@isnumeric);
p.parse(varargin{:});


for ii = 1:length(inFiles)
    % set up file names
    
    %input file
    inFile = fullfile(params.path2ret,inFiles{ii});
    
    %output file
    [~,tempName,~] = fileparts(inFile);
    [~,outName,~] = fileparts(tempName);
    outFile = fullfile(params.path2ret,[outName '_MNI_resampled.nii.gz']);
    
    %reference file
    refFile = fullfile(params.path2ref,params.refFileName);
    
    %warp file
    warpFile = fullfile(params.path2warp,params.warpFileName);
    
    cmd = ['antsApplyTransforms -d ' p.dimensions ' -o ' outfile '-v ' p.verbose ' -t ' ...
            warpFile ' -i ' inFile ' -r ' refFile];




end


