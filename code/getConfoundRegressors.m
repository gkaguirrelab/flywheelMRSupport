function [confoundRegressors, confoundLabels] = getConfoundRegressors(filename, varargin)
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
%   filename              - Full file name to the confounds .tsv file that
%                           fmriprep returns in the func folder.
%
% Outputs:
%   confoundRegressors    - timepoint by confound matrix.
%   confoundLabels        - cell array of names of the confounds
%
% Optional key/value pairs:
%   'CSF'                 - 1 column 
%   'WhiteMatter'         - 1 column
%   'GlobalSignal'        - 1 column
%   'stdDVARS'            - 1 column
%   'non0x2DstdDVARS'     - 1 column
%   'vx0x2DwisestdDVARS'  - 1 column
%   'FramewiseDisplacement' - 1 column
%   'tCompCor'            - 6 columns
%   'aCompCor'            - 6 columns
%   'Cosine'              - 3 columns
%   'NonSteadyStateOutlier' - 3 columns
%   'Translations'        - 3 columns X Y Z
%   'Rotations'           - 3 columns X Y Z
%
% Examples are provided in the source code.
%

% History
%  3/28/18  mab  created function.

% Examples:
%{
    filename = 'sub-HEROgka1_ses-201709191435_task-tfMRILFContrastAP_run-2_bold_confounds.tsv';
    confoundRegressors = getConfoundRegressors(filename,'CSF',true,'WhiteMatter',true,'GlobalSignal',false,','NonSteadyStateOutlier',false);
%}
p = inputParser; p.KeepUnmatched = false;
p.addRequired('filename', @ischar);
p.addParameter('CSF',true, @islogical);
p.addParameter('WhiteMatter',true, @islogical);
p.addParameter('GlobalSignal',false, @islogical);
p.addParameter('stdDVARS',false, @islogical);
p.addParameter('non0x2DstdDVARS',false, @islogical);
p.addParameter('FramewiseDisplacement',true, @islogical);
p.addParameter('tCompCor',false, @islogical);
p.addParameter('aCompCor',false, @islogical);
p.addParameter('Cosine',false, @islogical);
p.addParameter('NonSteadyStateOutlier',false, @islogical);
p.addParameter('Translations',false, @islogical);
p.addParameter('Rotations',false, @islogical);
p.parse(filename, varargin{:})

fullConfounds = tdfread(filename,'\t');

confoundRegressors = [];
for ii = 1:length(p.UsingDefaults)
    switch p.UsingDefaults{ii}
        case 'CSF'
            if p.Results.CSF
                confoundRegressors = [confoundRegressors, fullConfounds.CSF];
            end
        case 'WhiteMatter'
            if p.Results.WhiteMatter
                confoundRegressors = [confoundRegressors, fullConfounds.WhiteMatter];
            end
        case 'GlobalSignal'
            if p.Results.GlobalSignal
                confoundRegressors = [confoundRegressors, fullConfounds.GlobalSignal];
            end
        case 'stdDVARS'
            if p.Results.stdDVARS
                if  ischar(fullConfounds.stdDVARS)
                    for jj = 1:size(fullConfounds.stdDVARS,1)            
                        stdDVARS(jj,1) = str2double(fullConfounds.stdDVARS(jj,:));
                    end
                else
                    stdDVARS = fullConfounds.stdDVARS;
                end
                
                confoundRegressors = [confoundRegressors, stdDVARS];
            end
        case 'non0x2DstdDVARS'
            if p.Results.non0x2DstdDVARS
                if  ischar(fullConfounds.non0x2DstdDVARS)
                    for jj = 1:size(fullConfounds.non0x2DstdDVARS,1)            
                        non0x2DstdDVARS(jj,1) = str2double(fullConfounds.non0x2DstdDVARS(jj,:));
                    end
                else
                    non0x2DstdDVARS = fullConfounds.non0x2DstdDVARS;
                end
              
                confoundRegressors = [confoundRegressors, non0x2DstdDVARS];
            end
        case 'FramewiseDisplacement'
            if p.Results.FramewiseDisplacement
                if  ischar(fullConfounds.FramewiseDisplacement)
                    for jj = 1:size(fullConfounds.FramewiseDisplacement,1)            
                        FramewiseDisplacement(jj,1) = str2double(fullConfounds.FramewiseDisplacement(jj,:));
                    end
                else
                    FramewiseDisplacement = fullConfounds.FramewiseDisplacement;
                end
              
                confoundRegressors = [confoundRegressors, FramewiseDisplacement];
            end
        case 'tCompCor'
            if p.Results.tCompCor
                confoundRegressors = [confoundRegressors, fullConfounds.tCompCor00,fullConfounds.tCompCor01,fullConfounds.tCompCor02, ...
                    fullConfounds.tCompCor03, fullConfounds.tCompCor04,fullConfounds.tCompCor05];
            end
        case 'aCompCor'
            if p.Results.aCompCor
                confoundRegressors = [confoundRegressors, fullConfounds.aCompCor00,fullConfounds.aCompCor01,fullConfounds.aCompCor02, ...
                    fullConfounds.aCompCor03, fullConfounds.aCompCor04,fullConfounds.aCompCor05];
            end
        case 'Cosine'
            if p.Results.Cosine
                confoundRegressors = [confoundRegressors, fullConfounds.Cosine00, fullConfounds.Cosine01, fullConfounds.Cosine02];
            end
        case 'NonSteadyStateOutlier'
            if p.Results.NonSteadyStateOutlier
                confoundRegressors = [confoundRegressors, fullConfounds.NonSteadyStateOutlier00, fullConfounds.NonSteadyStateOutlier01, ...
                    fullConfounds.NonSteadyStateOutlier02];
            end
        case 'Translations'
            if p.Results.Translations
                confoundRegressors = [confoundRegressors, fullConfounds.X, fullConfounds.Y, fullConfounds.Z];
            end
        case 'Rotations'
            if p.Results.Rotations
                confoundRegressors = [confoundRegressors, fullConfounds.RotX, fullConfounds.RotY, fullConfounds.RotZ];
            end
    end
end



%% SANITY CHECK
% Add code to examine the confounds, and remove those that have no
% variation (i.e., are all zeros)


end











