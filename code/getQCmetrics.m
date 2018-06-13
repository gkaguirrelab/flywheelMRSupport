% getQCMetrics
% Script to create plots of quality control metrics for a flywheel project
%
% Syntax:
%  getQCMetrics
%
% Description:
%   This routine connects to a Flywheel server and pulls quality assessment
%   metrics for a selected project. The identity of the flywheel server and
%   your login credentials are specified by the api_key environment
%   preference variable. This is set in the localhook file for the
%   flywheelMRSupport toolbox.
%
% Inputs:
%   none
%
% Outputs:
%   none
%
% Examples:
%{
    getQCMetrics
%}


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
    % If there are any sessions with qa files, they are added to QA
    if ~isempty(session.acquisitions)
        QA{end+1} = session;
    end
end


%% Create plots for the modalities
% Metrics are placed within respective modality arrays
modalityLabels = {'T1w','T2w','bold'};
% Metrics of interest are placed here
metricLabels = {'cjv','cnr','efc','fber','wm2max','snr_csf','snr_gm','snr_wm';
                'cjv','cnr','efc','fber','wm2max','snr_csf','snr_gm','snr_wm';
                'fd_mean','dvars_std','fd_perc','gcor','tsnr','aor','gsr_x','gsr_y'};

metrics = [];
dataLabels = [];

% Loop through modalities and metrics to organize the metrics
for mm = 1:length(modalityLabels)
    metrics.(modalityLabels{mm}) = [];
    % Loop through the files in QA
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

%% Create the Plots
% Get all the modalities that we want to make plots for
mods = fieldnames(metrics);
% Loop through modalities and metrics to create individual plots 
for i = 1:length(mods)
    
    % Get all the metrics in the modality
    mod = metrics.(mods{i});
    disp(mod);
    
    % Get the individual metrics from each modality
    mets = fieldnames(metrics.(mods{i}));
    
    % Create a figure with for each modality
    figure('NumberTitle', 'off', 'Name', mods{i});
    
    % Iterator to be used to make subplots
    iter = 1;
    
    % Loop through the metrics to begin creating the plots
    for j = 1:length(mets)
        values = metrics.(mods{i}).(mets{j});
        disp(values);
        
        % minVal and maxVal are used to scale the y-axis accurately
        
        % If there are no negative values in that metric, the y-axis scale
        % begins from 0 and goes to the maximum
        if all(values>=0)
                minVal = 0;
                maxVal = max(values);
                
        % If there are any negative values in the metric, the y-axis
        % scale takes the absolute largest quantity from the metric and
        % makes it the maximum and its corresponding negative value the
        % minimum (If absolute maximum value is 10, scale goes from -10 to 10)
        else
                minTemp = min(values);
                maxTemp = max(values);
                if maxTemp > minTemp
                    minVal = -maxVal;
                else
                    maxVal = -minVal; 
                end
        end 
        
        % xMin and xMax are values that are used to scale the x-axis in
        % relation to the y-axis to make the data easier to view
        xMin = -(maxVal-minVal)/2;
        xMax = (maxVal-minVal)/2;
        
        % Crate the axis for each subplot using the dimensions of xMin,
        % xMax, minVal, and maxVal
        axis = axes('NextPlot','add','DataAspectRatio',[1,1,1],'XLim',[xMin xMax],'YLim',[minVal maxVal],'Color','w');
        
        % Remove the x-axis labels; these are not useful in the context of
        % what is being created
        set(gca,'XTick',[]);
        
        % Set the title of each subplot to the metric that it represents
        title(mets(j),'Interpreter','none');
        
        % Place the created axis in the correct position in the figure;
        % each iteration (different metric) gets a different plot in the figure 
        subplot(3,3,iter,axis);
        
        % Loop through the individual values of the metric to begin
        % plotting them onto the created axis
        for index = 1:length(values)
            
            % Label the values of the metric with different colors on the
            % plot to identify outliers
            
            % If the value is greater than 3 standard deviations from the
            % mean of the metric values, it is considered an outlier and is
            % represented with a red circle
            if values(index) < mean(values) - 3*std(values) || values(index) > mean(values) + 3*std(values)
                scatter(axis,0,values(index), 'jitter','on', 'jitterAmount',xMax/7,'MarkerFaceColor','r','MarkerEdgeColor','r','MarkerFaceAlpha',.2,'MarkerEdgeAlpha',.2);
                iterator = 1;
                for NumQA = 1:length(QA)
                    for NumAcq = 1:length(QA{NumQA}.acquisitions)
                        if strcmpi(mods{i},QA{NumQA}.acquisitions{NumAcq}.modality)
                            if values(index) == QA{NumQA}.acquisitions{NumAcq}.info.(mets{j})
                                outliers.modality.(mods{i}).(mets{j}).subject{iterator} = QA{NumQA}.subject;
                                outliers.modality.(mods{i}).(mets{j}).label{iterator} = QA{NumQA}.label;
                                outliers.modality.(mods{i}).(mets{j}).acquisition{iterator} = QA{NumQA}.acquisitions{NumAcq}.label;
                                iterator = iterator + 1;
                            end
                        end
                    end
                end 
                
            else
                    scatter(axis,0,values(index), 'jitter','on', 'jitterAmount',xMax/7,'MarkerFaceColor','b','MarkerEdgeColor','b','MarkerFaceAlpha',.2,'MarkerEdgeAlpha',.2);
            end
        end
        iter=iter+1;
    end
    print(mods{i},'-dpdf','-fillpage');
end
    
    