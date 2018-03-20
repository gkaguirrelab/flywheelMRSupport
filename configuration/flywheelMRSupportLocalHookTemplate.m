function flywheelMRSupportLocalHook
% flywheelMRSupportLocalHook
%
% For use with the ToolboxToolbox.  Copy this into your
% ToolboxToolbox localToolboxHooks directory (by defalut,
% ~/localToolboxHooks) and delete "Template" from the filename
%
% The thing that this does is add subfolders of the project to the path as
% well as define Matlab preferences that specify input and output
% directories.
%
% You will need to edit the project location and i/o directory locations
% to match what is true on your computer.

%% Say hello
fprintf('* Running flywheelMRSupportLocalHook\n');
toolboxName = 'flywheelMRSupport';

%% Clear out stray prefs
if (ispref(toolboxName))
    rmpref(toolboxName);
end

%% Set flywheel API key as a preference
flywheelAPIKey='Copy this value from flywheel and paste here';
setpref(toolboxName,'flywheelAPIKey',flywheelAPIKey);

%% Specify base paths for materials and data
[~, userID] = system('whoami');
userID = strtrim(userID);
switch userID
    case 'dhb'
        baseDir = fullfile(filesep,'Volumes','Users1','Dropbox (Aguirre-Brainard Lab)');
        
        % Could put user specific things in, but at the moment generic
        % is good enough.
    otherwise
        baseDir = fullfile('/Users',userID,'Dropbox (Aguirre-Brainard Lab)');
end

%% Paths to local applications needed to run this file
if ismac
    % Code to run on Mac plaform
    setpref(toolboxName,'binANTS',fullfile(baseDir,'FLYW_admin/MRI processing apps/ANTs/OSX_10.13.2/ANTs/bin/bin'));
elseif isunix
    % Code to run on Linux plaform
    setpref(toolboxName,'binANTS',fullfile(baseDir,'FLYW_admin/MRI processing apps/ANTs/Ubuntu_16.04/ANTs/bin/bin'));
elseif ispc
    % Code to run on Windows platform
    warning('No binaries for ANTs on PC')
else
    disp('Platform not supported')
end
