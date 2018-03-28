function [confoundRegressors] = getConfoundRegressors(filename, varargin)
% Creates confound matrix for TFE
%
% Syntax:
%   confoundRegressors = getConfoundRegressors(filename, varargin)
%
% Description:
%   Creates a timepoint by confound matrix from the fmriprep confounds .tsv
%   file. Confounds are added to the output matrix my setting the key/value
%   pair to true. 
%
% Inputs:
%   filename                - Full file name to the confounds .tsv file that
%                             fmriprep returns in the func folder.
%
% Outputs:
%   confoundRegressors      -  timepoint by confound matrix. 
%
% Optional key/value pairs:
%   'CSF'                   - 1 column
%   'WhiteMatter'           - 1 column
%   'GlobalSignal'          - 1 column
%   'stdDVARS'              - 1 column
%   'non0x2DstdDVARS'       - 1 column
%   'vx0x2DwisestdDVARS'    - 1 column
%   'FramewiseDisplacement' - 1 column
%   'tCompCor'              - 6 columns
%   'aCompCor'              - 6 columns
%   'Cosine'                - 3 columns
%   'NonSteadyStateOutlier' - 3 columns
%   'Translations'          - 3 columns X Y Z
%   'Rotations'             - 3 columns X Y Z
%
% Examples are provided in the source code.
%

% History
%  3/28/18  mab  Created from previous example script.

% Examples:
%{
    % Downloads an analysis into tempdir
    theProject      = 'LFContrast';
    analysisLabel   = 'fmriprep 02/09/2018 11:40:55';
    dataDownloadDir =  fullfile(getpref('LFContrastAnalysis','projectRootDir'),'fmriprep');
    getAnalysisFromFlywheel(theProject,analysisLabel,dataDownloadDir);
%}
p = inputParser; p.KeepUnmatched = false;
p.addRequired('filename', @ischar);
p.addParameter('CSF',true, @islogical);
p.addParameter('WhiteMatter',true, @islogical);
p.addParameter('GlobalSignal',true, @islogical);
p.addParameter('stdDVARS',false, @islogical);
p.addParameter('non0x2DstdDVARS',false, @islogical);
p.addParameter('FramewiseDisplacement',true, @islogical);
p.addParameter('tCompCor',false, @islogical);
p.addParameter('aCompCor',false, @islogical);
p.addParameter('Cosine',false, @islogical);
p.addParameter('NonSteadyStateOutlier',true, @islogical);
p.addParameter('Translations',false, @islogical);
p.addParameter('Rotations',false, @islogical);
p.parse(filename, varargin{:})

fullConfounds = tdfread('sub-HEROgka1_ses-201709191435_task-tfMRILFContrastAP_run-1_bold_confounds.tsv','\t');
