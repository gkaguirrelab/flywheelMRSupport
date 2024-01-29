function submitGears(paramsFileName,varargin)
% Submits jobs to a flywheel instance based upon a table of parameters
%
% Syntax
%  result = submitGears(paramsFileName)
%
% Description:
%   This routine implements calls to the Flywheel API to submit analysis
%   gear jobs. The behavior of the routine is determined by a parameter
%   file, that itself is a .csv file with a standard format. The first six
%   rows of the parameter table contain header information. The first row
%   is treated as a set of key-value pairs which are submitted to the input
%   parser. The remaining header rows define the type of inputs provided to
%   the gear. The subsequent rows of the table each define an analysis to
%   be submitted.
%
%   The routine will decline to re-run a job if a job with the same
%   analysis label appears on the instance.
%
%   key-value pairs may be passed as input to the routine or read from the
%   params table of the file.
%
% Format of the params table:
%
%   ROW 1 contains key-value pairs, running left-to-right. This row is
%   loaded as a cell array and parsed using the input parser. Some of the
%   keys call for logical values. Because a csv file saves only text, these
%   are parsed as char vectors and later converted to logical. The meaning
%   of the key values are:
%
%  'projectLabel'         - Char or empty. Defines the project that
%                           contains the sessions to be analyzed. If left
%                           empty, the gear expects that the individual
%                           entries in the table will specify the project
%                           name before the subject and session.
%  'gearName'             - The name of the gear to be run. This string may
%                           be found on Flywheel within the list of
%                           available gears and examining the URL source of
%                           the gear code. The gearName is the final
%                           portion of the URL after the last slash.
%  'rootSession'          - The value is the name of one of the inputs
%                           types to the gear. The session that is the
%                           source of this inout type is then the session
%                           in which the analysis will be placed.
%  'tags'                 - Cell array of char vectors. These are tags that
%                           are passed to the Flywheel job scheduler. A
%                           common usage is to pass the identity of a
%                           better-equipped virtual machine. E.g.:
%                               {'extra-large'}
%  'verbose'              - Char vector of the form "true" or "false".
%  'configKeys'           - A cell array that contans the char vectors of
%                           the configuration labels for the gear.
%  'configValues'         - A cell array of values to be provided along
%                           with the configKeys.
%
%   ROW 2 defines the input labels to the gear. The first column contains
%   the strng "Inputs". The subsequent columns contain the input labels for
%   the gear, in any order.
%
%   ROW 3 defines the default file label for the input. Subsequent rows
%   direct the routine to look in a particular session for an input. If not
%   otherwise specified, the acquisition label that matches this input will
%   be used.
%
%   ROW 4 defines the acquisition file suffix. An entry is only required
%   for those inputs that are acquisition files, and if the full path to
%   the file is not provided. Valid values here include "nifit", "bval",
%   "bvec".
%
%   ROW 5 specifies the container type that holds the target file. Valid
%   values are from the set:
%       {'acquisition','analysis','session','project'}
%
%   ROW 6 indicates if the file name is to be an exact match to a file on
%   the Flywheel server. If set to false, the routine will trim white space
%   off the start and end of the file name and be case insensitive in its
%   match.
%
%   The subsequent rows of the table each specify a job. The first column
%   is the subject ID; this value is used only to label the analysis. The
%   subsequent columns specify the input to the gear, using the format of:
%
%       (projectLabel/)subjectID/sessionLabel/acquisitionLabel/acquisitionfileName
%       (projectLabel/)subjectID/sessionLabel/gearName/analysisfileName
%       (projectLabel/)subjectID/sessionLabel/sessionFileName
%       (projectLabel/)projectFileName
%
%   where the projectLabel is optional if it was specified in the header
%
% Inputs:
%   paramsFileName        - String. Full path to a csv file that contains
%                           the analysis specifications
%
% Outputs:
%   none
%
% Examples:
%{
    submitGears('myFlywheelParams.csv','overwriteExisting','failed')
%}



%% Load and parse the params table
% This identifies the subjects and inputs to be processed
paramsTable = readtable(paramsFileName,'ReadVariableNames',false,'FileType','text','Delimiter','comma','Format','auto');

% Parse the table header
p = inputParser; p.KeepUnmatched = false;
p.addParameter('projectLabel','',@(x)(isempty(x) || ischar(x)));
p.addParameter('gearName','hcp-func',@ischar);
p.addParameter('versionNum','',@(x)(isempty(x) || ischar(x)));
p.addParameter('rootSession','fMRITimeSeries',@ischar);
p.addParameter('rootSessionID',@(x)(isempty(x) || ischar(x)));
p.addParameter('tags',{},@(x)(isempty(x) || iscell(x)));
p.addParameter('verbose','true',@ischar);
p.addParameter('unsetDefaultValueWarning','false',@ischar);
p.addParameter('overwriteExisting','never',@ischar);
p.addParameter('configKeys','',@(x)(isempty(x) || ischar(x)));
p.addParameter('configVals','',@(x)(isempty(x) || ischar(x)));

% Grab the first row of the table
tableVarargin = paramsTable{1,1:end};
% Remove all trailing empty cells
tableVarargin=tableVarargin(1:find(cellfun(@(x) ~isempty(x),tableVarargin),1,'last'));
% Combine the tableVarargin with the passed varargin
comboVarargin = [tableVarargin varargin];
% Parse
p.parse(comboVarargin{:});

% The parameters arrive as char variables from the csv file. We create
% logical variables out of some of these, and handle the possibility that
% the string is in upper case.
verbose = eval(lower(p.Results.verbose));
unsetDefaultValueWarning = eval(lower(p.Results.unsetDefaultValueWarning));

% Pull out the overwriteExisting variable
overwriteExisting = p.Results.overwriteExisting;

% Define the paramsTable dimensions
nParamRows = 6; % This is the number of rows that make up the header
nParamCols = 1; % This is for the first column that has header info

% Hard-coded identity of the header row information
InputsRow = 2;
DefaultLabelRow = 3;
FileSuffixRow = 4;
ContainerTypeRow = 5;
ExactStringMatchRow = 6;

% Determine the number of inputs to specify for this gear
nInputCols = sum(cellfun(@(x) ~isempty(x),paramsTable{InputsRow,:}));
nRows = size(paramsTable,1);

%% Instantiate the flywheel object
fw = flywheel.Flywheel(getpref('flywheelMRSupport','flywheelAPIKey'));


%% Get project IDs
allProjects = fw.getAllProjects;


%% Construct the gear configuration
% Find the gear we are going to use
if ~isempty(p.Results.versionNum)
    gearFilterString = ['gears/' lower(p.Results.gearName) '/' lower(p.Results.versionNum)];
else
    gearFilterString = ['gears/' lower(p.Results.gearName)];
end
theGear = fw.lookup(gearFilterString);

if isempty(theGear)
    error(['Cannot find the gear "' p.Results.gearName '" in Flywheel'])
end
if length(theGear)>1
    error(['There is more than one gear named "' p.Results.gearName '" in Flywheel'])
end


% Get the info for the gear
theGearID = theGear.id;
theGearName = theGear.gear.name;
theGearVersion = theGear.gear.version;

% Build the config params. Read the config to set the defaults and edit
% required ones
gear = fw.getGear(theGearID);
gearCfg = struct(gear.gear.config);
configDefault = struct;
keys = fieldnames(gearCfg);
for ii = 1:numel(keys)
    val = gearCfg.(keys{ii});
    if isfield(val, 'default')
        configDefault.(keys{ii}) = val.default;
    else
        if unsetDefaultValueWarning
            fprintf('No default value for %s. It must be set prior to execution.\n', keys{ii});
        end
    end
end


% Create a variable that will hold a list of sessions in each project
allSessions = struct();

%% Loop through jobs
for ii=nParamRows+1:nRows

    % Check if this row is empty. If so, continue
    if isempty(char(paramsTable{ii,1}))
        continue
    end

    % Check if this is a stop row. If so, stop
    if strcmp(char(paramsTable{ii,1}),'stop')
        return
    end

    % Set the analysisSubmissionTag to empty
    analysisSubmissionTag = [];

    % Set the rootSessionID to empty
    rootSessionID = [];

    % Get the subject name
    subjectName = char(paramsTable{ii,1});

    % Create an empty inputs struct
    inputs = {};

    % Set the input notes to empty
    inputNotes = [];

    %% Loop through the inputs
    for jj=nParamCols+1:nInputCols

        % If the entry is empty, skip this input
        if isempty(char(paramsTable{ii,jj}))
            continue
        end

        % Get the input label
        theInputLabel=char(paramsTable{InputsRow,jj});

        % Get the container type
        theContainerType=char(paramsTable{ContainerTypeRow,jj});

        % Get the entry in the table for this row
        entry = strsplit(char(paramsTable{ii,jj}),'/');

        % Check if the theInputLabel is "analysisSubmissionTag", in which
        % case use the entry to define a variable that is used to label the
        % submitted analysis
        if strcmp('analysisSubmissionTag',theInputLabel)
            analysisSubmissionTag = entry{1};
            continue
        end

        % Check if the theInputLabel is "rootSessionID", in which case use
        % the entry to define a variable that is used to label the
        % submitted analysis
        if strcmp('rootSessionID',theInputLabel)
            rootSessionID = entry{1};
            continue
        end

        % Determine the project and get the session list
        if ~isempty(p.Results.projectLabel)
            % The project label is defined for all jobs
            projIdx = find(strcmp(cellfun(@(x) x.label,allProjects,'UniformOutput',false),p.Results.projectLabel),1);
            thisProjID = allProjects{projIdx}.id;
            thisProjLabel = p.Results.projectLabel;
        else
            % The project name is the first component of the entry
            projIdx = find(strcmp(cellfun(@(x) x.label,allProjects,'UniformOutput',false),entry{1}),1);
            thisProjID = allProjects{projIdx}.id;
            thisProjLabel = allProjects{projIdx}.label;
            entry = entry(2:end);
        end

        % Get the list of sessions associated with this project label
        if ~isfield(allSessions,thisProjLabel)
            allSessions.(thisProjLabel) = fw.getProjectSessions(thisProjID);
        end

        % If this is not a project or config input, find the matching
        % subject and session
        if ~strcmp('project',char(paramsTable{ContainerTypeRow,jj})) && ...
                ~strcmp('config',char(paramsTable{ContainerTypeRow,jj}))
            sessionIdx = find(cellfun(@(x) all([strcmp(x.subject.code,entry{1}) strcmp(x.label,entry{2})]),allSessions.(thisProjLabel)));
            if isempty(sessionIdx)
                error('No matching session and subject for this input entry')
            end
            if length(sessionIdx)>1
                error('More than one matching session and subject for this input entry')
            end
        end

        % Switch on the container type that holds the target file
        switch theContainerType
            case 'acquisition'
                % Obtain the set of acquisitions for the matching session
                allAcqs = fw.getSessionAcquisitions(allSessions.(thisProjLabel){sessionIdx}.id);

                % Check to see if the acquisition name is specified. If not,
                % use the default
                if length(entry)>=3
                    targetLabel = entry(3);
                else
                    targetLabel = char(paramsTable{DefaultLabelRow,jj});
                end

                % Try to find an acquisition that matches the input
                % label and contains the specified AcqFileType. Unless
                % told to use exact matching, trim off leading and
                % trailing whitespace, as the stored label in flywheel
                % sometimes has a trailing space. Also, use a case
                % insensitive match.
                if logical(str2double(char(paramsTable{ExactStringMatchRow,jj})))
                    labelMatchIdx = cellfun(@(x) strcmp(x.label,targetLabel),allAcqs);
                else
                    labelMatchIdx = cellfun(@(x) strcmpi(strtrim(x.label),strtrim(targetLabel)),allAcqs);
                end

                % If a file entry was specified, go
                % find that.
                if length(entry)==4
                    % We are given the name of the file
                    theFileName = entry{4};
                    % Find the acquisition ID
                    isFileNameMatchIdx = cellfun(@(x) sum(cellfun(@(y) strcmp(y.name,theFileName),x.files)),allAcqs);
                    acqIdx = logical(labelMatchIdx .* isFileNameMatchIdx);
                else
                    % Filter any acquitions with no files
                    notEmptyIdx = cellfun(@(x) ~isempty(x.files),allAcqs);
                    allAcqs = allAcqs(notEmptyIdx);
                    isFileTypeMatchIdx = cellfun(@(x) any(cellfun(@(y) strcmp(y.type,paramsTable{FileSuffixRow,jj}),x.files)),allAcqs);
                    acqIdx = logical(labelMatchIdx .* isFileTypeMatchIdx);
                end

                % Check if we have found a file
                if ~any(acqIdx)
                    error('No matching acquisition for this input entry')
                end
                if sum(acqIdx)>1
                    error('More than one matching acquisition for this input entry')
                end

                if length(entry)==4
                    theContainerID = allAcqs{acqIdx}.id;
                    theContainerLabel = allAcqs{acqIdx}.label;
                else
                    % We have a match. Re-find the specified file
                    theFileTypeMatchIdx = find(cellfun(@(y) strcmp(y.type,paramsTable{FileSuffixRow,jj}),allAcqs{acqIdx}.files));
                    % Check for an error condition
                    if isempty(theFileTypeMatchIdx)
                        error('No matching file type for this acquisition');
                    end
                    if length(theFileTypeMatchIdx)>1
                        warning('More than one matching file type for this acquisition; using the most recent');
                        [~,mostRecentIdx]=max(cellfun(@(x) datetime(x.created),allAcqs{acqIdx}.files(theFileTypeMatchIdx)));
                        theFileTypeMatchIdx=theFileTypeMatchIdx(mostRecentIdx);
                    end
                    % Get the file name, ID, and acquisition label
                    theContainerID = allAcqs{acqIdx}.id;
                    theFileName = allAcqs{acqIdx}.files{theFileTypeMatchIdx}.name;
                    theContainerLabel = allAcqs{acqIdx}.label;
                end

                theType = 'acquisition';

            case 'analysis'

                % Get the set of analyses for this session
                allAnalyses=fw.getSessionAnalyses(allSessions.(thisProjLabel){sessionIdx}.id);

                % Check to see if the analysis name was specified. If not,
                % use the default
                if length(entry)>=3
                    targetLabel = strjoin(entry(3:end),'/');
                else
                    targetLabel = char(paramsTable{DefaultLabelRow,jj});
                end

                % Find which of the analyses contains the target file
                targetLabelParts = strsplit(targetLabel,'/');

                gearName = targetLabelParts{1};
                gearModel = '';
                if length(strsplit(gearName,'.'))>1
                    gearNameParts = strsplit(gearName,'.');
                    gearName = gearNameParts{1};
                    gearModel = gearNameParts{2};
                end
                fileName = targetLabelParts{2};

                analysisIdx = find(strcmp(cellfun(@(x) x.gearInfo.name,allAnalyses,'UniformOutput',false),gearName));
                if ~isempty(gearModel)
                    modelIdx = cellfun(@(x) strcmp(fw.getJobDetail(x.job).config.config.modelClass,gearModel),allAnalyses(analysisIdx));
                    analysisIdx = analysisIdx(modelIdx);
                end

                % Remove from the list of analyses any which do not have
                % any output files
                hasOutputFiles = cellfun(@(x) ~isempty(x.files),allAnalyses(analysisIdx));
                analysisIdx = analysisIdx(hasOutputFiles);

                % Which analysis has the files we want?
                whichAnalysis = find(cellfun(@(y) ~isempty(find(cellfun(@(x) (endsWith(x.name,targetLabelParts{2})),y.files))),allAnalyses(analysisIdx)));

                % If there is more than one analysis, figure out which one
                % is the most recent
                if length(whichAnalysis)>1
                    [~,idx]=max(cellfun(@(x) x.created,allAnalyses(analysisIdx(whichAnalysis))));
                    whichAnalysis = whichAnalysis(idx);
                    warning('Using the most recent analysis');
                end

                % Get this file
                fileIdx = find(cellfun(@(x) (endsWith(x.name,targetLabelParts{2})),allAnalyses{analysisIdx(whichAnalysis)}.files));
                theContainerID = allAnalyses{analysisIdx(whichAnalysis)}.id;
                theFileName = allAnalyses{analysisIdx(whichAnalysis)}.files{fileIdx}.name;
                theType = 'analysis';
                theContainerLabel = 'analysis_file';

            case 'config'
                % Create a variable in memory that is theInputLabel, and
                % set this variable equal to the entry. First, however,
                % check to make sure that this new variable won't colide
                % with a variable name already in memory
                if exist(theInputLabel,'var')
                    error('The input label for a config value matches a variable that exists within submitGears');
                end

                % Assmeble a set of commands that will be used to clear
                % these created variables after this job has been submitted
                if ~exist('clearSet','var')
                    clearSet = {};
                    clearSet{1} = '';
                end
                clearSet{end+1}=['clear ' theInputLabel];

                % Now create the variable
                command = [theInputLabel ' = ' entry{1} ';'];
                eval(command);

            case 'session'

                theContainerID = allSessions.(thisProjLabel){sessionIdx}.id;
                theContainerLabel = allSessions.(thisProjLabel){sessionIdx}.label;
                if isempty(allSessions.(thisProjLabel){sessionIdx}.files)
                    error('No session file for this entry')
                end

                % Check to see if the session file name is specified. If
                % not, use the default
                if length(entry)>=3
                    targetLabel = strjoin(entry(3:end),'/');
                else
                    targetLabel = char(paramsTable{DefaultLabelRow,jj});
                end

                % Find the file
                fileIdx = find(strcmp(cellfun(@(x) x.name,allSessions.(thisProjLabel){sessionIdx}.files,'UniformOutput',false),targetLabel));
                if isempty(fileIdx)
                    error('No matching session file for this entry')
                end
                theFileName = allSessions.(thisProjLabel){sessionIdx}.files{fileIdx}.name;
                theType = 'session';

            case 'project'

                % Only one entry should be present, and it is the identity
                % of the project file
                targetLabel = entry{1};

                projFileIdx = find(strcmp(cellfun(@(x) x.name,allProjects{projIdx}.files,'UniformOutput',false),targetLabel));
                theFileName = allProjects{projIdx}.files{projFileIdx}.name;
                theContainerID = allProjects{projIdx}.id;
                theContainerLabel = allProjects{projIdx}.label;
                theType = 'project';

            otherwise
                error('That is not a file type I know')
        end

        % Check if theInputLabel is the rootSession
        if ~isempty(p.Results.rootSession)
            if strcmp(p.Results.rootSession,theInputLabel)
                % Get the root session information if not already defined. This
                % is the session to which the analysis product will be assigned
                if isempty(rootSessionID)
                    rootSessionID = allSessions.(thisProjLabel){sessionIdx}.id;
                end
                % The analysisSubmissionTag is used to label the outputs of the
                % gear. If not yet defined for this job, we use the container
                % label for the rootSession for this label. Sometimes there is
                % leading or trailing white space in the container label. We
                % trim that off here as it can cause troubles in gear
                % execution.
                if isempty(analysisSubmissionTag)
                    analysisSubmissionTag = strtrim(theContainerLabel);
                end
            end
        end

        % If it is not a config container, then it is an input, so add this
        % input information to the structure
        if ~strcmp(theContainerType,'config')
            theContainerWithInput = fw.get(theContainerID);
            theInputFileObject = theContainerWithInput.getFile(theFileName);
            inputs{end+1} = {theInputLabel,theInputFileObject};
            inputNotes.(theInputLabel).theContainerLabel = theContainerLabel;
            inputNotes.(theInputLabel).theContainerType = theContainerType;
        end
    end


    %% Customize gear configuration
    charConfigKeys = p.Results.configKeys;

    % Sanitize the config keys for forbiden characters
    charConfigKeys = strrep(charConfigKeys,'-','0x2D');

    % Obtain the cell array
    configKeys = eval(charConfigKeys);

    configVals = eval(p.Results.configVals);
    config = configDefault;
    if ~isempty(configKeys)
        for kk=1:length(configKeys)
            config.(configKeys{kk})=configVals{kk};
        end
    end

    % Replace entries that are text booleans with logical values. There are
    % some gears that text a text boolean of {'true' || 'false'}. So, we
    % only convert those text fields that are all upper case true or false.
    fn = fieldnames(config);
    for k=1:numel(fn)
        if isstring(config.(fn{k})) || ischar(config.(fn{k}))
            switch config.(fn{k})
                case 'TRUE'
                    config.(fn{k}) = true;
                case 'FALSE'
                    config.(fn{k}) = false;
            end
        end
    end

    % Clear from memory any variables that were created to hold custom key
    % values
    if exist('clearSet','var')
        for cc=1:length(clearSet)
            eval(clearSet{cc});
        end
        clear clearSet
    end

    % Grab the tags.
    tags = p.Results.tags;


    %% Assemble Job

    %% Assemble analysis label
    jobLabel = [theGearName ' v' theGearVersion ' [' analysisSubmissionTag '] - ' char(datetime('now','TimeZone','local','Format','yyyy-MM-dd HH:mm'))];


    %% Check if the analysis has already been performed
    skipFlag = false;
    allAnalyses=fw.getSessionAnalyses(rootSessionID);
    if ~isempty(allAnalyses)
        % Check if this gear has been run
        priorAnalysesMatchIdx = cellfun(@(x) strcmp(x.gearInfo.name,theGearName),allAnalyses);
        if any(priorAnalysesMatchIdx)
            priorAnalysesMatchIdx = find(priorAnalysesMatchIdx);
            % See if the data tag in any of the prior analyses is a match
            % Ignore white space in the label parts
            jobLabelParts = strsplit(jobLabel,{'[',']'});
            for mm=1:length(priorAnalysesMatchIdx)
                analysisLabelParts = strsplit(allAnalyses{priorAnalysesMatchIdx(mm)}.label,{'[',']'});
                if length(analysisLabelParts)>1
                    if strcmp(strtrim(analysisLabelParts{2}),strtrim(jobLabelParts{2}))
                        skipFlag = true;
                        priorAnalysisID = allAnalyses{priorAnalysesMatchIdx(mm)}.id;
                        priorJobID = allAnalyses{priorAnalysesMatchIdx(mm)}.job;
                        priorJobState = fw.getJobDetail(priorJobID).state;
                    end
                end
            end
        end
    end
    if skipFlag

        % Determine if the previous job failed
        failedFlag = false;
        if strcmp(priorJobState,'failed')
            failedFlag = true;
        end

        % Handle the overwriteExisting choices
        switch overwriteExisting
            case 'never'
                if verbose
                    if failedFlag
                        fprintf(['A failed ' theGearName ' analysis is already present for ' subjectName ', ' jobLabel '; skipping. If you wish to delete and re-run, set the overwriteExisting key to ''failed''.\n']);
                    else
                        fprintf(['The analysis ' theGearName ' is already present for ' subjectName ', ' jobLabel '; skipping.\n']);
                    end
                end
                continue

            case 'failed'
                if failedFlag
                    fw.deleteSessionAnalysis(allSessions.(thisProjLabel){sessionIdx}.id,priorAnalysisID);
                    if verbose
                        fprintf(['A failed ' theGearName ' analysis was found and deleted for ' subjectName ', ' jobLabel '; re-running.\n']);
                    end
                else
                    fprintf(['The analysis ' theGearName ' is already present for ' subjectName ', ' jobLabel '; skipping.\n']);
                    continue
                end

            case 'all'
                fw.deleteSessionAnalysis(allSessions.(thisProjLabel){sessionIdx}.id,priorAnalysisID);
                if verbose
                    if failedFlag
                        fprintf(['A failed ' theGearName ' analysis was found and deleted for ' subjectName ', ' jobLabel '; re-running.\n']);
                    else
                        fprintf(['The analysis ' theGearName ' is already present for ' subjectName ', ' jobLabel '; deleting and re-running.\n']);
                    end
                end

            otherwise
                error('Not a valid value for the overwriteExisting key');
        end
    end

    %% Run
    theSessionDestination = fw.get(rootSessionID);
    newJobID = theGear.run('analysisLabel',jobLabel,'inputs',inputs,'config',config,'destination',theSessionDestination,'tags',tags);

    %% Add the analysis ID as a notes entry
    theJob = fw.getJob(newJobID);
    theAnalysis = fw.getAnalysis(theJob.destination.id);
    successNote = ['Submitted ' subjectName ' [' theAnalysis.id '] - ' jobLabel ];
    theAnalysis.addNote(successNote);

    %% Add a table of inputs as a note
    note = ['InputLabel  -+-  ContainerType -+- ContainerLabel  -+-  FileName\n' ...
        '----------------------------------------------------------------\n'];
    inputFieldNames = fieldnames(inputNotes);
    for nn = 1:numel(inputFieldNames)
        newLine = [inputFieldNames{nn} '  -+-  ' inputNotes.(inputFieldNames{nn}).theContainerType '  -+-  ' inputNotes.(inputFieldNames{nn}).theContainerLabel '  -+-  ' inputs{nn}{2}.name '\n'];
        note = [note newLine];
    end
    theAnalysis.addNote(sprintf(note));

    %% Report the event
    if verbose
        fprintf([successNote '\n']);
    end
end % loop over rows of the table

end % main function



