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


%% Hard-coded variables
verbose = false; % By default, nothing reported to the console.
stdThreshForOutlier = 3;
jitterFactor = .25; % The amount of x-axis jitter in the column plots
outputDirectory = './';
closeFigures = true;


%% Init SDK
api_key = getpref('flywheelMRSupport','flywheelAPIKey');
fw = flywheel.Flywheel(api_key);


%% Get the Project we're interested in

% Find a specific Flywheel Project among them all
all_projects = fw.getAllProjects;
project_label = 'tome';

project = all_projects{contains(cellfun(@(p) {p.label}, all_projects), project_label)};


%% For each session/acquisition/file find the QA reports and add them to QA

QA = {};
FilesAnalyzed = {};
FilesAnalyzedId = {};

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
                % This file will be analyzed
                if isfield(acq, 'modality')
                    session.acquisitions{end+1} = acq;
                    FilesAnalyzed{end+1} = files{ff}.name;
                    FilesAnalyzedId{end+1} = acq_id;
                    break;
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
% What values are generally bad for the corresponding metric from
% metricLabels (0 means high values are bad, 1 means low values are bad,
% 2 means any extreme values are bad)
metricRanges = {0,1,0,1,2,1,1,1;
    0,1,0,1,2,1,1,1;
    0,0,0,1,1,0,0,0};

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
                        metrics.(modalityLabels{mm}).(metricLabels{mm,kk}).vals = [];
                        metrics.(modalityLabels{mm}).(metricLabels{mm,kk}).range = [];
                    end
                    metrics.(modalityLabels{mm}).(metricLabels{mm,kk}).vals = ...
                        [ metrics.(modalityLabels{mm}).(metricLabels{mm,kk}).vals ...
                        QA{qq}.acquisitions{aa}.info.(metricLabels{mm,kk}) ];
                    metrics.(modalityLabels{mm}).(metricLabels{mm,kk}).range = ...
                        [metricRanges{mm,kk}];
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
    
    % Create a figure to hold the plots for this modality
    hFigure = figure('NumberTitle', 'off', 'Name', mods{i});
    
    %Get all the metrics in the modality
    mets = fieldnames(metrics.(mods{i}));
    
    % Iterator used to create subplots
    iter = 1;
    
    % Loop through the metrics to begin creating the plots
    for j = 1:length(mets)
        
        % Store the metric's values and range
        values = metrics.(mods{i}).(mets{j}).vals;
        range = metrics.(mods{i}).(mets{j}).range;
        
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
        
        % x is used to plot points on the scatter diagram
        x = zeros(1,size(values,2));
        
        % xMin and xMax are values that are used to scale the x-axis in
        % relation to the y-axis to make the data easier to view
        xMin = -(maxVal-minVal)/2;
        xMax = (maxVal-minVal)/2;
        
        % Create the axis for each subplot using the dimensions of xMin,
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
        
        % Identify the bounds for outlier values for this metric
        if range == 0
            withinThreshMin = -Inf;
            withinThreshMax = nanmean(values) + stdThreshForOutlier * nanstd(values);
        else
            if range == 1
                withinThreshMin = (nanmean(values) - stdThreshForOutlier * nanstd(values));
                withinThreshMax = Inf;
            else
                withinThreshMin = (nanmean(values) - stdThreshForOutlier * nanstd(values));
                withinThreshMax = nanmean(values) + stdThreshForOutlier * nanstd(values);
            end
        end
        
        % Plot the within bounds points in blue
        withinThreshIdx = logical((values > withinThreshMin) .* (values < withinThreshMax));
        scatter(axis,x(withinThreshIdx),values(withinThreshIdx), 'jitter','on', 'jitterAmount',xMax*jitterFactor,'MarkerFaceColor','b','MarkerEdgeColor','b','MarkerFaceAlpha',.2,'MarkerEdgeAlpha',.2);
        
        % Plot the outside bounds points in red
        outsideThreshIdx = ~withinThreshIdx;
        scatter(axis,x(outsideThreshIdx),values(outsideThreshIdx), 'jitter','on', 'jitterAmount',xMax*jitterFactor,'MarkerFaceColor','r','MarkerEdgeColor','r','MarkerFaceAlpha',.2,'MarkerEdgeAlpha',.2);
        
        % Used for making the outlier structure
        iterator = 1;
        
        % Iterate through the outlier values, identify their properties, and organize them
        % into an 'outlier' structure
        for badNums = 1:length(outsideThreshIdx)
            if outsideThreshIdx(badNums)
                
                % Loop through QA to get all sessions and acquisitions
                for NumQA = 1:length(QA)
                    for NumAcq = 1:length(QA{NumQA}.acquisitions)
                        
                        % Make sure the acquisition has the desired
                        % modality
                        if strcmpi(mods{i},QA{NumQA}.acquisitions{NumAcq}.modality)
                            
                            % Find the acquisition with the same metric
                            % quantity as the outlier
                            if values(badNums) == QA{NumQA}.acquisitions{NumAcq}.info.(mets{j})
                                outliers.(mods{i}).(mets{j}).subject{iterator} = QA{NumQA}.subject;
                                outliers.(mods{i}).(mets{j}).label{iterator} = QA{NumQA}.label;
                                outliers.(mods{i}).(mets{j}).acquisition{iterator} = QA{NumQA}.acquisitions{NumAcq}.label;
                                outliers.(mods{i}).(mets{j}).scores{iterator} = values(badNums);
                                iterator = iterator + 1;
                            end
                        end
                    end
                end
            end
        end
        iter=iter+1;
    end
    
    % Save the figure as a PDF within the output directory
    filenameOut = fullfile(outputDirectory,[mods{i} '.pdf']);
    saveas(hFigure,filenameOut);
    
    % Close figure handle
    if closeFigures
        close(hFigure);
    end
end

%% Write outlier information to a file (and display, if desired)
% Create the information that you want in table
subject = {};
session = {};
acquisition = {};
metric = {};
score = {};
modalities = fields(outliers);
for modalityIdx = 1:length(modalities)
    metricNames = fields(outliers.(modalities{modalityIdx}));
    for metricIdx = 1:length(metricNames)
        for finalIdx = 1:length(outliers.(modalities{modalityIdx}).(metricNames{metricIdx}).subject)
            subject{end+1} = outliers.(modalities{modalityIdx}).(metricNames{metricIdx}).subject{finalIdx};
            session{end+1} = outliers.(modalities{modalityIdx}).(metricNames{metricIdx}).label{finalIdx};
            acquisition{end+1} = outliers.(modalities{modalityIdx}).(metricNames{metricIdx}).acquisition{finalIdx};
            metric{end+1} = metricNames{metricIdx};
            score{end+1} = outliers.(modalities{modalityIdx}).(metricNames{metricIdx}).scores{finalIdx};
        end
    end
end
outliersInfo = [subject;session;acquisition;metric;score].';
T = cell2table(outliersInfo,'VariableNames',{'Subject','Session','Acquisition','Metric','Score'});
OutliersFilename = fullfile(outputDirectory,'outliers.csv');
writetable(T,OutliersFilename,'Delimiter',',','QuoteStrings',false);
if verbose
    T;
end

%% Write the output files to the project on Flywheel
acquisitionArray = repmat({'acquisition'},[1 length(FilesAnalyzed)]);
file_ref = struct('id', FilesAnalyzedId, 'type', 'acquisition', 'name', FilesAnalyzed);
analysis = struct('label', 'testAnalysis', 'inputs', {{file_ref}});
analysisId = fw.addProjectAnalysis(project.id, analysis);
outputs = {strcat(outputDirectory,'T1w.pdf'), strcat(outputDirectory,'T2w.pdf'), strcat(outputDirectory,'bold.pdf'), strcat(outputDirectory,'outliers.csv')};
fw.uploadOutputToAnalysis(analysisId, strcat(outputDirectory,outputs));
cd(outputDirectory);
delete T1w.pdf T2w.pdf bold.pdf outliers.csv;
