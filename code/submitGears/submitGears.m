function submitGears(paramsFileName)
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
%   ROW 4 defines the acquisition file type. An entry is only required for
%   those inputs that are acquisition files. Valid values here include
%   "nifit", "bval", "bvec".
%
%   ROW 5 specifies the file type. Valid values are from the set:
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



%% Load and parse the params table
% This identifies the subjects and inputs to be processed
paramsTable = readtable(paramsFileName,'ReadVariableNames',false,'FileType','text','Delimiter','comma');

% Parse the table header
p = inputParser; p.KeepUnmatched = false;
p.addParameter('projectLabel','',@(x)(isempty(x) || ischar(x)));
p.addParameter('gearName','hcp-func',@ischar);
p.addParameter('rootSession','fMRITimeSeries',@ischar);
p.addParameter('verbose','true',@ischar);
p.addParameter('configKeys','',@(x)(isempty(x) || ischar(x)));
p.addParameter('configVals','',@(x)(isempty(x) || ischar(x)));
tableVarargin = paramsTable{1,1:end};
p.parse(tableVarargin{:});

% The parameters arrive as char variables from the csv file. We create
% logical variables out of some of these, and handle the possibility that
% the string is in upper case.
verbose = eval(lower(p.Results.verbose));

% Define the paramsTable dimensions
nParamRows = 9; % This is the number of rows that make up the header
nParamCols = 1; % This is for the first column that has header info

% Hard-coded identity of the header row information
InputsRow = 2;
DefaultLabelRow = 3;
FileSuffixRow = 4;
FileTypeRow = 5;
ExactStringMatchRow = 6;

% Determine the number of inputs to specify for this gear
nInputCols = sum(cellfun(@(x) ~isempty(x),paramsTable{InputsRow,:}));
nRows = size(paramsTable,1);

%% Instantiate the flywheel object
fw = flywheel.Flywheel(getpref('flywheelMRSupport','flywheelAPIKey'));


%% Get project IDs
allProjects = fw.getAllProjects;


%% Construct the gear configuration
% Get all the gears
allGears = fw.getAllGears();

% Find the particular gear we are going to use
theGearIdx=find(strcmp(cellfun(@(x) x.gear.name,allGears,'UniformOutput',false),p.Results.gearName));
theGearID = allGears{theGearIdx}.id;
theGearName = allGears{theGearIdx}.gear.name;
theGearVersion = allGears{theGearIdx}.gear.version;

% Build the config params. Read the config to set the defaults and edit
% required ones
gear = fw.getGear(theGearID);
gearCfg = struct(gear.gear.config);
configDefault = struct;
keys = fieldnames(gearCfg);
for i = 1:numel(keys)
    val = gearCfg.(keys{i});
    if isfield(val, 'default')
        configDefault.(keys{i}) = val.default;
    else
        if verbose
            fprintf('No default value for %s\n. It must be set prior to execution.', keys{i});
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
    
    % Get the subject name
    subjectName = char(paramsTable{ii,1});
    
    %% Assemble Inputs
    % Create an empty inputs struct
    inputs = struct();
    
    % Loop through the inputs specified in the paramsTable
    for jj=nParamCols+1:nInputCols
        
        % If the entry is empty, skip this input
        if isempty(char(paramsTable{ii,jj}))
            continue
        end
        
        % Define the input label
        theInputLabel=char(paramsTable{InputsRow,jj});
        
        % Check if the theInputLabel is "rootSessionTag", in which case use
        % the entry to define the rootSessionTag
        if strcmp('analysisLabel',theInputLabel)
            analysisLabel = char(paramsTable{ii,jj});
        end
        
        % Get the entry for this job and input from the params table
        entry = strsplit(char(paramsTable{ii,jj}),'/');
        
        % Determine the project and get the session list
        if ~isempty(p.results.projectLabel)
            % The project label is defined for all jobs
            projIdx = find(strcmp(cellfun(@(x) x.label,allProjects,'UniformOutput',false),p.Results.projectLabel),1);
            thisProjID = allProjects{projIdx}.id;
            thisProjLabel = p.results.projectLabel;
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
        
        % If this is not a project input, find the matching subject and
        % session
        if ~strcmp('project',char(paramsTable{FileTypeRow,jj}))
            sessionIdx = find(cellfun(@(x) all([strcmp(x.subject.code,entry{1}) strcmp(x.label,entry{2})]),allSessions.(thisProjLabel)));
            if isempty(sessionIdx)
                error('No matching session and subject for this input entry')
            end
            if length(sessionIdx)>1
                error('More than one matching session and subject for this input entry')
            end
        end
        
        % Switch on the type of input we are looking for
        switch char(paramsTable{FileTypeRow,jj})
            case 'acquisition'
                % Obtain the set of acquisitions for the matching session
                allAcqs = fw.getSessionAcquisitions(allSessions.(thisProjLabel){sessionIdx}.id);
                
                % Check to see if the acquisition name is specified. If not,
                % use the default
                if length(entry)>=3
                    targetLabel = strjoin(entry(3:end),'/');
                else
                    targetLabel = char(paramsTable{DefaultLabelRow,jj});
                end
                
                % If a file entry was specified, go
                % find that.
                if length(entry)==4
                    % We are given the name of the file
                    theName = entry{4};
                    % Find the acquisition ID
                    acqIdx = find(cellfun(@(x) sum(cellfun(@(y) strcmp(y.name,theName),x.files)),allAcqs));
                    theID = allAcqs{acqIdx}.id;
                    theInputLabel = allAcqs{acqIdx}.label;
                else
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
                    isFileTypeMatchIdx = cellfun(@(x) any(cellfun(@(y) strcmp(y.type,paramsTable{FileSuffixRow,jj}),x.files)),allAcqs);
                    acqIdx = logical(labelMatchIdx .* isFileTypeMatchIdx);
                    if ~any(acqIdx)
                        error('No matching acquisition for this input entry')
                    end
                    if sum(acqIdx)>1
                        error('More than one matching acquisition for this input entry')
                    end
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
                    theID = allAcqs{acqIdx}.id;
                    theName = allAcqs{acqIdx}.files{theFileTypeMatchIdx}.name;
                    theInputLabel = allAcqs{acqIdx}.label;
                end
                theType = 'acquisition';
                
            case 'analysis'
                
                % Get the set of analyses for this session
                allAnalyses=fw.getSessionAnalyses(allSessions.(char(thisProjID)){sessionIdx}.id);
                targetLabelParts = strsplit(targetLabel,'/');
                analysisIdx = find(strcmp(cellfun(@(x) x.gearInfo.name,allAnalyses,'UniformOutput',false),targetLabelParts{1}));
                
                % Check to see if the analysis name was specified. If not,
                % use the default
                if length(entry)>=3
                    targetLabel = strjoin(entry(3:end),'/');
                else
                    targetLabel = char(paramsTable{DefaultLabelRow,jj});
                end
                
                % Find which of the analyses contains the target file
                whichAnalysis = find(cellfun(@(y) ~isempty(find(cellfun(@(x) (endsWith(x.name,targetLabelParts{2})),y.files))),allAnalyses(analysisIdx)));

                % Get this file
                fileIdx = find(cellfun(@(x) (endsWith(x.name,targetLabelParts{2})),allAnalyses{analysisIdx(whichAnalysis)}.files));
                theID = allAnalyses{analysisIdx(whichAnalysis)}.id;
                theName = allAnalyses{analysisIdx(whichAnalysis)}.files{fileIdx}.name;
                theType = 'analysis';
                theInputLabel = 'analysis_file';
                                
            case 'session'

                theID = allSessions{sessionIdx}.id;
                if isempty(allSessions{sessionIdx}.files)
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
                fileIdx = find(strcmp(cellfun(@(x) x.name,allSessions{sessionIdx}.files,'UniformOutput',false),targetLabel));
                if isempty(fileIdx)
                    error('No matching session file for this entry')
                end
                theName = allSessions{sessionIdx}.files{fileIdx}.name;
                theType = 'session';
                theInputLabel = targetLabel;
                
            case 'project'

                % Only one entry should be present, and it is the identity
                % of the project file
                targetLabel = entry{1};

                projFileIdx = find(strcmp(cellfun(@(x) x.name,allProjects{projIdx}.files,'UniformOutput',false),targetLabel);
                projFileName = allProjects{projIdx}.files{projFileIdx}.name;
                projFileID = allProjects{projIdx}.id;
                theType = 'project';
                theInputLabel = targetLabel;
                
            otherwise
                error('That is not a file type I know')
        end
        
        % Check if theInputLabel is the rootSession
        if strcmp(p.Results.rootSession,theInputLabel)
            % Get the root session information. This is the session to
            % which the analysis product will be assigned
            rootSessionID = allSessions{sessionIdx}.id;
            % The root session tag is used to label the outputs of the
            % gear. Sometimes there is leading or trailing white space
            % in the acquisition label. We trim that off here as it can
            % cause troubles in gear execution.
            analysisLabel = strtrim(theName);
        end
        
        % Add this input information to the structure
        inputStem = struct('type', theType,...
            'id', theID, ...
            'name', theName);
        inputs.(theInputLabel) = inputStem;
        inputNotes.(theInputLabel) = theInputLabel;
    end
    
end


%% Customize gear configuration
configKeys = eval(p.Results.configKeys);
configVals = eval(p.Results.configVals);
config = configDefault;
if ~isempty(configKeys)
    for kk=1:length(configKeys)
        config.(configKeys{kk})=configVals{kk};
    end
end


%% Assemble Job
% Create the job body with all the involved files in a struct
thisJob = struct('gear_id', theGearID, ...
    'inputs', inputs, ...
    'config', config);


%% Assemble analysis label
jobLabel = [theGearName ' v' theGearVersion ' [' analysisLabel '] - ' char(datetime('now','TimeZone','local','Format','yyyy-MM-dd HH:mm'))];


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
                end
            end
        end
    end
end
if skipFlag
    if verbose
        fprintf(['The analysis ' theGearName ' is already present for ' subjectName ', ' jobLabel '; skipping.\n']);
        % This command may be used to delete the prior analysis
        %{
                fw.deleteSessionAnalysis(allSessions{sessionIdx}.id,priorAnalysisID);
        %}
    end
    continue
end

%% Run
body = struct('label', jobLabel, 'job', thisJob);
[newAnalysisID, ~] = fw.addSessionAnalysis(rootSessionID, body);


%% Add a notes entry to the analysis object
note = ['InputLabel  -+-  AcquisitionLabel  -+-  FileName\n' ...
    '-------------|----------------------|-----------\n'];
inputFieldNames = fieldnames(inputs);
for nn = 1:numel(inputFieldNames)
    newLine = [inputFieldNames{nn} '  -+-  ' inputNotes.(inputFieldNames{nn}) '  -+-  ' inputs.(inputFieldNames{nn}).name '\n'];
    note = [note newLine];
end
fw.addAnalysisNote(newAnalysisID,sprintf(note));

%% Report the event
if verbose
    fprintf(['Submitted ' subjectName ' [' newAnalysisID '] - ' jobLabel '\n']);
end
end



