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

%% Set where we will download data to stage analysis
sysInfo = GetComputerInfo();
switch (sysInfo.localHostName)
    case 'eagleray'
        % DHB's desktop
        baseDir = fullfile(filesep,'Volumes','Users1','Dropbox (Aguirre-Brainard Lab)');
        
    otherwise
        % Some unspecified machine, try user specific customization
        switch(sysInfo.userShortName)
            % Could put user specific things in, but at the moment generic
            % is good enough.
            otherwise
                baseDir = fullfile('/Users',sysInfo.userShortName,'Dropbox (Aguirre-Brainard Lab)');
        end
end