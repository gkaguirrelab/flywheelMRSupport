function [ LGNMask ] = makeLGNMaskCIFTI(varargin)
%


%% Input parser
p = inputParser; p.KeepUnmatched = true;
p.addParameter('workbenchPath', '/Applications/workbench/bin_macosx64/', @ischar);
p.addParameter('templateFile', [], @ischar);
p.addParameter('maskPath', [], @ischar);
p.addParameter('pathToJuelichAtlas', [], @ischar);
p.parse(varargin{:});

% set the path-related parameters if nothing was inputted
if isempty(p.Results.pathToJuelichAtlas)
    pathToJuelichAtlas = '/usr/local/fsl/data/atlases/Juelich';
else
    pathToJuelichAtlas = p.Results.pathToJuelichAtlas;
end

if isempty(p.Results.maskPath)
    [~, userID] = system('whoami');
    userID = strtrim(userID);
    maskPath = fullfile('/Users', userID, 'Desktop');
else
    maskPath = p.Results.maskPath;
end

if isempty(p.Results.templateFile)
    [~, userID] = system('whoami');
    userID = strtrim(userID);
    templateFile = fullfile('/Users', userID, 'Dropbox-Aguirre-Brainard-Lab/MELA_analysis/mriTOMEAnalysis/flywheelOutput/benson/template.dscalar.nii');
else
    templateFile = p.Results.templateFile;
end


%% Create left-right combined LGN mask in MNI space
% We will do so using FSL command-line

% Right LGN
system(['FSLDIR=/usr/local/fsl; PATH=${FSLDIR}/bin:${PATH}; export FSLDIR PATH; . ${FSLDIR}/etc/fslconf/fsl.sh; fslmaths "', fullfile(pathToJuelichAtlas, 'Juelich-maxprob-thr0-2mm.nii.gz'), '" -thr 103 -uthr 103 -bin "', fullfile(maskPath, 'LGN-R'),'"']);
% Left LGN
system(['FSLDIR=/usr/local/fsl; PATH=${FSLDIR}/bin:${PATH}; export FSLDIR PATH; . ${FSLDIR}/etc/fslconf/fsl.sh; fslmaths "', fullfile(pathToJuelichAtlas, 'Juelich-maxprob-thr0-2mm.nii.gz'), '" -thr 104 -uthr 104 -bin "', fullfile(maskPath, 'LGN-L'),'"']);
% Combined LGN
system(['FSLDIR=/usr/local/fsl; PATH=${FSLDIR}/bin:${PATH}; export FSLDIR PATH; . ${FSLDIR}/etc/fslconf/fsl.sh; fslmaths "', fullfile(maskPath, 'LGN-R'),'" -add "', fullfile(maskPath, 'LGN-L'), '" "', fullfile(maskPath, 'LGN-combined'), '"']);

%% Convert MNI volume to CIFTI
% We will do so using HCP's workbench commands
system(['bash ', p.Results.workbenchPath, 'wb_command -cifti-create-dense-from-template "', templateFile, '" "', fullfile(maskPath, 'LGN-combined.dscalar.nii'), '" -volume-all "', fullfile(maskPath, 'LGN-combined.nii.gz'), '"']);


end