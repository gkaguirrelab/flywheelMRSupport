function [ ciftiMask ] = makeMaskFromRetinoCIFTI(areaNum, eccenRange, anglesRange, hemisphere, varargin)
% Make binary mask from Benson's retinotopy project.
%
% Syntax:
%  [ maskMatrix ] = makeMaskFromRetinoCIFTI(areaNum, eccenRange, anglesRange, hemisphere
%
% Description:
%  This routine makes binary retinotopy masks from Noah's project to be
%  used with CIFTI files processed through HPC's standard pipeline. We
%  can make masks on the basis of several different retinotopy
%  parameters, including visual area number, eccentricity, polar angle,
%  and hemisphere. The routine first makes a mask for each desired
%  retinotopic property, then multiplies these masks together. Any
%  surviving grayordinate was therefore included in each individual mask.
%
% Inputs:
%  areaNum:					- a number that defines which visual area we're looking for.
% 					          Options include 1 (for V1), 2 or 3.
%  eccenRange:		        - the range in eccentricity to be included, ranging from 0 to 90.
%  anglesRange:	            - the range in polar angle to be included, ranging from 0 to 180.
% 						      Dorsal regions would include values between 90 and 180,
%							  while ventral regions would include values between 0 and 90.
%  hemisphere:              - which hemisphere to be analyzed. Options include 'lh' for
% 							  left hemisphere, 'rh' for right, or 'combined' for both.
%
% Optional key-value pairs:
%  saveName					- a string which defines the full path for where to save the
%						      resulting mask. If no value is passed (the default), no mask
%							  is saved.
%  pathToBensonMasks        - a string which defines the full path to where the previously
%							  made Benson masks in CIFTI format are located.
%
% Output:
%  maskMatrix:				- a 92812 x 1 binary vector that defines the retinotopic mask.
%
%
% Example:
%{
% make a V1 mask for the left hemisphere
areaNum = 1;
eccenRange = [0 90];
anglesRange = [0 180];
hemisphere = 'lh';
threshold = 0.9;

[~, userID] = system('whoami');
userID = strtrim(userID);

saveName = fullfile('/Users', userID, 'Desktop/lh.V1.dscalar.nii');
pathToBensonMasks = fullfile('/Users', userID, 'Dropbox-Aguirre-Brainard-Lab/MELA_analysis/mriTOMEAnalysis/flywheelOutput/benson/');
pathToBensonMappingFile = fullfile('/Users', userID, 'Dropbox-Aguirre-Brainard-Lab/MELA_analysis/mriTOMEAnalysis/flywheelOutput/benson/indexMapping.mat');
pathToTemplateFile = fullfile('/Users', userID, 'Dropbox-Aguirre-Brainard-Lab/MELA_analysis/mriTOMEAnalysis/flywheelOutput/benson/template.dscalar.nii');

[ maskMatrix ] = makeMaskFromRetinoCIFTI(areaNum, eccenRange, anglesRange, hemisphere, 'saveName', saveName, 'pathToBensonMasks', pathToBensonMasks, 'pathToTemplateFile', pathToTemplateFile, 'pathToBensonMappingFile', pathToBensonMappingFile, 'threshold', threshold);


% make a V1 mask for the combined right-left hemisphere
areaNum = 1;
eccenRange = [0 90];
anglesRange = [0 180];
hemisphere = 'combined';
saveName = fullfile('/Users', userID, 'Desktop/combined.V1.dscalar.nii');
pathToBensonMasks = fullfile('/Users', userID, 'Dropbox-Aguirre-Brainard-Lab/MELA_analysis/mriTOMEAnalysis/flywheelOutput/benson/');
pathToBensonMappingFile = fullfile('/Users', userID, 'Dropbox-Aguirre-Brainard-Lab/MELA_analysis/mriTOMEAnalysis/flywheelOutput/benson/indexMapping.mat');
pathToTemplateFile = fullfile('/Users', userID, 'Dropbox-Aguirre-Brainard-Lab/MELA_analysis/mriTOMEAnalysis/flywheelOutput/benson/template.dscalar.nii');

[ maskMatrix ] = makeMaskFromRetinoCIFTI(areaNum, eccenRange, anglesRange, hemisphere, 'saveName', saveName, 'pathToBensonMasks', pathToBensonMasks, 'pathToTemplateFile', pathToTemplateFile, 'pathToBensonMappingFile', pathToBensonMappingFile, 'threshold', threshold);

%}

p = inputParser; p.KeepUnmatched = true;
p.addParameter('saveName', [], @ischar)
p.addParameter('threshold', [], @isnumeric)
p.addParameter('pathToBensonMasks', [], @ischar)
p.addParameter('pathToBensonMappingFile', [], @ischar)
p.addParameter('pathToTemplateFile', [], @ischar)
p.parse(varargin{:});


%% Locate the template files
% describe the different templates we want to produce
mapTypes = {'angle', 'eccen', 'varea'};
hemispheres  = {'lh', 'rh'};
pathToBensonMasks = p.Results.pathToBensonMasks;

%% Restrict area

areaMask = zeros(327684,1);


if strcmp(hemisphere, 'lh') || strcmp(hemisphere, 'combined')
    rhAreaMask = zeros(163842,1);
    lhAreaMask = zeros(163842,1);
    lhAreaMap = MRIread(fullfile(p.Results.pathToBensonMasks, 'lh.benson14_varea.v4_0.mgz'));
    lhAreaMap = lhAreaMap.vol;
    
    
    
    lhAreaMask(lhAreaMap == areaNum) = 1;
    
    lhAreaMask = [lhAreaMask; rhAreaMask];
    
    areaMask = areaMask + lhAreaMask;
    
    
end
if strcmp(hemisphere, 'rh') || strcmp(hemisphere, 'combined')
    rhAreaMask = zeros(163842,1);
    lhAreaMask = zeros(163842,1);
    rhAreaMap = MRIread(fullfile(p.Results.pathToBensonMasks, 'rh.benson14_varea.v4_0.mgz'));
    rhAreaMap = rhAreaMap.vol;
    
    rhAreaMask(rhAreaMap == areaNum) = 1;
    
    rhAreaMask = [lhAreaMask; rhAreaMask];
    
    areaMask = areaMask + rhAreaMask;
    
    
    
    
end


%% Restrict eccen
eccenMask = zeros(327684,1);


if strcmp(hemisphere, 'lh') || strcmp(hemisphere, 'combined')
    rhEccenMask = zeros(163842,1);
    lhEccenMask = zeros(163842,1);
    lhEccenMap = MRIread(fullfile(p.Results.pathToBensonMasks, 'lh.benson14_eccen.v4_0.mgz'));
    lhEccenMap = lhEccenMap.vol;
    
    lhEccenMask(lhEccenMap >= eccenRange(1) & lhEccenMap <= eccenRange(2)) = 1;
    
    lhEccenMask = [lhEccenMask; rhEccenMask];
    
    eccenMask = eccenMask + lhEccenMask;
    
end
if strcmp(hemisphere, 'rh') || strcmp(hemisphere, 'combined')
    rhEccenMask = zeros(163842,1);
    lhEccenMask = zeros(163842,1);
    rhEccenMap = MRIread(fullfile(p.Results.pathToBensonMasks, 'rh.benson14_eccen.v4_0.mgz'));
    rhEccenMap = rhEccenMap.vol;
    
    
    rhEccenMask(rhEccenMap >= eccenRange(1) & rhEccenMap <= eccenRange(2)) = 1;
    
    rhEccenMask = [lhEccenMask; rhEccenMask];
    
    eccenMask = eccenMask + rhEccenMask;
    
    
end


%% Restrict polar angles
anglesMask = zeros(327684,1);


if strcmp(hemisphere, 'lh') || strcmp(hemisphere, 'combined')
    rhAnglesMask = zeros(163842,1);
    lhAnglesMask = zeros(163842,1);
    lhAnglesMap = MRIread(fullfile(p.Results.pathToBensonMasks, 'lh.benson14_angle.v4_0.mgz'));
    lhAnglesMap = lhAnglesMap.vol;
    
    lhAnglesMask(lhAnglesMap >= anglesRange(1) & lhAnglesMap <= anglesRange(2)) = 1;
    
    lhAnglesMask = [lhAnglesMask; rhAnglesMask];
    
    anglesMask = anglesMask + lhAnglesMask;
    
end
if strcmp(hemisphere, 'rh') || strcmp(hemisphere, 'combined')
    rhAnglesMask = zeros(163842,1);
    lhAnglesMask = zeros(163842,1);
    rhAnglesMap = MRIread(fullfile(p.Results.pathToBensonMasks, 'rh.benson14_angle.v4_0.mgz'));
    rhAnglesMap = rhAnglesMap.vol;
    
    
    rhAnglesMask(rhAnglesMap >= anglesRange(1) & rhAnglesMap <= anglesRange(2)) = 1;
    
    rhAnglesMask = [lhAnglesMask; rhAnglesMask];
    
    anglesMask = anglesMask + rhAnglesMask;
    
    
end


%% Combine maps
combinedMask = zeros(327684,1);
combinedMask(areaMask == 1 & eccenMask == 1 & anglesMask == 1) = 1;

%% Convert FreeSurfer mask to HCP
matrix = sparse(91282, 327684);
load(p.Results.pathToBensonMappingFile);
for ii = 1:length(ciftifsaverageix)
    matrix(ciftifsaverageix(ii), ii) = 1;
end

sumPerRow = sum(matrix,2);

nonZeroIndices = find(matrix);
for ii = 1:length(nonZeroIndices)
    [row,column] = ind2sub(size(matrix), nonZeroIndices(ii));
    matrix(row,column) = matrix(row,column)/sumPerRow(row);
end

ciftiMask = matrix * combinedMask;

if ~isempty(p.Results.threshold)
    ciftiMask(ciftiMask < p.Results.threshold) = 0;
    ciftiMask(ciftiMask >= p.Results.threshold) = 1;
end


% save out mask, if desired
if ~isempty(p.Results.saveName)
    makeWholeBrainMap(ciftiMask', [], fullfile(p.Results.pathToTemplateFile), p.Results.saveName)
end




end