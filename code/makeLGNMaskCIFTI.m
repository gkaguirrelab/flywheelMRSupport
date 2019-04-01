function [ LGNMask ] = makeLGNMaskCIFTI(varargin)
% Routine to make a binary LGN mask.
%
% Syntax:
%  [ LGNMask ] = makeLGNMaskCIFTI
%
% Description:
%  This routine makes a binary mask in CIFTI format from Julich
%  histological atlas (https://fsl.fmrib.ox.ac.uk/fsl/fslwiki/Atlases).
%  First, command line tools that are part of the FSL package are used to
%  identify the left and right LGN from the Julich atlas, and then combine
%  them into a single mask. Next, this mask in the volume is converted to a
%  mask in the grayordinate space via wb_command.
%
% Note that both FSL and workbench command line tools are required.
%
% Optional key-value pairs:
%  workbenchPath         - a string that defines the full path to where
%                          workbench commands can be found.
%  templateFile          - a string which defines the full path to the
%                          template CIFTI file to be used. All that's
%                          needed is for the mapping between grayordinate
%                          value and location, which will be the same for
%                          basically anything created by the HCP
%                          preprocessing routines. The default is a
%                          template file stored with the Benson masks.
%  maskPath              - a string which defines the path to which we'd
%                          like to save out the created masks, including
%                          the intermediate masks
%  pathToJuelichAtlas    - a string which defines the full path to the
%                          folder that contains the Juelich nifti files.
%                          The default is where the standard FSL
%                          installation puts them.
%
% References:
%   - Eickhoff et al., A new SPM toolbox for combining probabilistic
%     cytoarchitectonic maps and functional imaging data. Neuroimage
%     25(4):1325-35 (2005); 
%   - Eickhoff et al. Testing anatomically specified hypotheses in 
%     functional imaging using cytoarchitectonic maps. NeuroImage 32(2): 
%     570-582 (2006); 
%   - Eickhoff et al., Assignment of functional activations to probabilistic 
%     cytoarchitectonic areas revisited. NeuroImage, 36(3): 511-521 (2007))

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


%% Load the mask
[ LGNMask ] = loadCIFTI(fullfile(maskPath, 'LGN-combined.dscalar.nii'));

end