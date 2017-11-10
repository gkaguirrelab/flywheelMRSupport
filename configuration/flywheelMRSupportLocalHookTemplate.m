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