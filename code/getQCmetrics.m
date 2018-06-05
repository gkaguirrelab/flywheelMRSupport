%% Uses the next-gen Alpha SDK


%% Init SDK

api_key = getpref('flywheelMRSupport','flywheelAPIKey'); % <<<< Add your key here
fw = flywheel.Flywheel(api_key);


%% Get the Project we're interested in

% Find a specific Flywheel Project among them all
all_projects = fw.getAllProjects;
project_label = 'tome';

project = all_projects{contains(cellfun(@(p) {p.label}, all_projects), project_label)};


%% For each session/acquisition/file find the QA reports and add them to QA

QA = {};

% Get all of the sessions in the project
project_sessions = fw.getProjectSessions(project.id);

% Loop over the sessions and examine acquisition files for qa metadata
for ss = 1:numel(project_sessions)
    session = [];
    session.label = project_sessions{ss}.label;
    session.subject = project_sessions{ss}.subject.code;
    session.acquisitions = {};
    session_acquisitions = fw.getSessionAcquisitions(project_sessions{ss}.id);
    
    % For each acquisition, look at all files, if a given file is qa, then
    % add that files info to 'qa'. 
    for ii = 1:numel(session_acquisitions)
        files = session_acquisitions{ii}.files;
        acq_id = session_acquisitions{ii}.id;
        acq_label = session_acquisitions{ii}.label;
        
        % For each file, if that file is 'qa' get its info metadata 
        for ff = 1:length(files)
            if strcmpi(files{ff}.type, 'qa')
                acq = [];
                acq.label = acq_label;
                acq.info = fw.getAcquisitionFileInfo(acq_id, files{ff}.name).info.struct;
                
                % Get the acquisition modality
                if isfield(acq.info, 'metadata')
                    acq.modality = acq.info.metadata.modality;                    
                end
                if isfield(acq.info, 'bids_meta')
                    acq.modality = acq.info.bids_meta.modality;
                end
                
                % Only if we have the modality do we add the acquisition
                if isfield(acq, 'modality')
                    session.acquisitions{end+1} = acq;
                end
            end
        end
    end
    if ~isempty(session.acquisitions)
        QA{end+1} = session;
    end
end

% Create plots for the modalities
modalityLabels = {'T1w','T2w','bold'};
metricLabels = {'cjv','cnr','efc';'cjv','cnr','efc';'fd_mean','dvars_std','fd_perc'};

metrics = [];
dataLabels = [];

for mm = 1:length(modalityLabels)
    metrics.(modalityLabels{mm}) = [];
    for qq = 1:length(QA)
        for aa = 1:length(QA{qq}.acquisitions)
            if strcmp(QA{qq}.acquisitions{aa}.modality,modalityLabels{mm})
                for kk = 1:length(metricLabels(mm,:))
                    if ~isfield(metrics.(modalityLabels{mm}),(metricLabels{mm,kk}))
                        metrics.(modalityLabels{mm}).(metricLabels{mm,kk}) = [];
                    end
                    metrics.(modalityLabels{mm}).(metricLabels{mm,kk})= ...
                        [ metrics.(modalityLabels{mm}).(metricLabels{mm,kk}) ...
                        QA{qq}.acquisitions{aa}.info.(metricLabels{mm,kk}) ];
                    %dataLabels{mm,kk,end+1}=[QA{2}.label QA{2}.subject];
                end
            end
        end
    end
end
