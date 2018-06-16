function [] = analyzeQCmetrics(theProject,targetProjectField,varargin)
% Script to create plots of quality control metrics and identify outlier data for a flywheel project
%
% Syntax:
%  analyzeQCMetrics(theProject,targetProjectField)
%
% Description:
%   This routine connects to a Flywheel server and pulls quality assessment
%   metrics for a selected project. The identity of the flywheel server and
%   your login credentials are specified by the api_key environment
%   preference variable. This is set in the localhook file for the
%   flywheelMRSupport toolbox.
%
% Inputs:
%   theProject              - Define the project. This is the project you
%                             are interested in performing a QC metric
%                             analysis on. This must be a String value.
%   targetProjectField      - Define the target location of the output
%                             files for this analysis. You may specify
%                             either "analyses" or "files".
%                            
% Outputs:
%   none
%
% Optional key/value pairs:
%   'verbose'                - Logical, default false
%   'stdThreshForOutlier'    - How many standard deviations away from the
%                              mean a value may go to not be considered an
%                              outlier. Numeric, default 3
%   'jitterFactor'           - The amount of x-axis jitter in the column
%                              plots. Numeric (between 0 and 1), default
%                              0.25
%
% Examples:
%{
    getQCMetrics
%}


%% Parse vargin for options passed here
p = inputParser; p.KeepUnmatched = false;
p.addRequired('theProject', @ischar);
p.addRequired('targetProjectField', @ischar);
p.addParameter('verbose',false, @islogical);
p.addParameter('stdThreshForOutlier',3, @isnumeric);
p.addParameter('jitterFactor',0.25, @isnumeric);
p.parse(theProject, targetProjectField, varargin{:})

% Distribute the parameters into variables
theProject = p.Results.theProject;
targetProjectField = p.Results.targetProjectField;
verbose = p.Results.verbose;
stdThreshForOutlier = p.Results.stdThreshForOutlier;
jitterFactor = p.Results.jitterFactor;


%% Init SDK and Scratch Directory
api_key = getpref('flywheelMRSupport','flywheelAPIKey');
fw = flywheel.Flywheel(api_key);

outputDirectory = getpref('flywheelMRSupport','flywheelScratchDir');


%% Get the Project we're interested in

% Find a specific Flywheel Project among them all
all_projects = fw.getAllProjects;

project = all_projects{contains(cellfun(@(p) {p.label}, all_projects), theProject)};


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
        % Iterator to identify duplicate QC files
        iterator = 1;
        files = session_acquisitions{ii}.files;
        acq_id = session_acquisitions{ii}.id;
        acq_label = session_acquisitions{ii}.label;
        
        % For each file, if that file is 'qa' get its info metadata
        for ff = 1:length(files)
            if strcmpi(files{ff}.type, 'qa')
                iterator = iterator + 1;
                end
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
                    if iterator == 3
                        message = strcat('Acquisition',32,acq_label,32,'in ',32,session.label,32,'for Subject',32,project_sessions{ss}.subject.code,32,'has duplicate QC files.');
                    warning(message);
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
    0,0,0,0,1,0,0,0};

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
        sbplt = subplot(3,3,iter,axis);
        if range == 0 
            xDim = [sbplt.Position(1)+sbplt.Position(3) sbplt.Position(1)+sbplt.Position(3)];
            yDim = [sbplt.Position(2) sbplt.Position(2)+sbplt.Position(4)];
            annotation('textarrow',xDim,yDim,'String','Bad')
        else
            if range == 1
                xDim = [sbplt.Position(1)+sbplt.Position(3) sbplt.Position(1)+sbplt.Position(3)];
                yDim = [sbplt.Position(2)+sbplt.Position(4) sbplt.Position(2)];
                annotation('textarrow',xDim,yDim,'String','Bad')
            else
                xDim = [sbplt.Position(1)+sbplt.Position(3) sbplt.Position(1)+sbplt.Position(3)];
                yDim = [sbplt.Position(2) sbplt.Position(2)+sbplt.Position(4)];
                annotation('doublearrow',xDim,yDim)
            end
        end
        
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
        final = 1;
        
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
                                outliers.(mods{i}).(mets{j}).subject{final} = QA{NumQA}.subject;
                                outliers.(mods{i}).(mets{j}).label{final} = QA{NumQA}.label;
                                outliers.(mods{i}).(mets{j}).acquisition{final} = QA{NumQA}.acquisitions{NumAcq}.label;
                                outliers.(mods{i}).(mets{j}).scores{final} = values(badNums);
                                outliers.(mods{i}).(mets{j}).stdsaway{final} = abs(values(badNums)-nanmean(values))/nanstd(values);
                                final = final+1;
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
    close(hFigure);
end

%% Write outlier information to a file (and display, if desired)
% Create the information that you want in table
subject = {};
session = {};
acquisition = {};
metric = {};
score = {};
stdsaway = {};
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
            stdsaway{end+1} = outliers.(modalities{modalityIdx}).(metricNames{metricIdx}).stdsaway{finalIdx};
        end
    end
end
outliersInfo = [subject;session;acquisition;metric;score;stdsaway].';
T = cell2table(outliersInfo,'VariableNames',{'Subject','Session','Acquisition','Metric','Score','StandardDeviations'});
OutliersFilename = fullfile(outputDirectory,'outliers.csv');
writetable(T,OutliersFilename,'Delimiter',',','QuoteStrings',false);
if verbose
    T;
end

%% Write the output files to the project on Flywheel
switch targetProjectField
    case 'analyses'
        file_ref = {};
        for NumFiles = 1:length(FilesAnalyzed)
            file_ref{end+1} = struct('id', FilesAnalyzedId{NumFiles}, 'type', 'acquisition', 'name', FilesAnalyzed{NumFiles});
        end
        analysis = struct('label', 'testAnalysis', 'inputs', {file_ref});
        analysisId = fw.addProjectAnalysis(project.id, analysis);
        fw.uploadOutputToAnalysis(analysisId, '/private/tmp/flywheel/T1w.pdf');
        fw.uploadOutputToAnalysis(analysisId, '/private/tmp/flywheel/T2w.pdf');
        fw.uploadOutputToAnalysis(analysisId, '/private/tmp/flywheel/bold.pdf');
        fw.uploadOutputToAnalysis(analysisId, '/private/tmp/flywheel/outliers.csv');
        delete T1w.pdf T2w.pdf bold.pdf outliers.csv;
    case 'files'
        cd(outputDirectory);
        outputs = {'./T1w.pdf', './T2w.pdf', './bold.pdf', './outliers.csv'};
        for ff = 1:length(outputs)
            fw.uploadFileToProject(project.id, outputs{ff});
        end
        delete T1w.pdf T2w.pdf bold.pdf outliers.csv;
    otherwise
        error('Error. Target project field must be either "analyses" or "files".');
end
