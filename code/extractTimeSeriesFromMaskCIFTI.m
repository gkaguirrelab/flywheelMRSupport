function [ meanTimeSeries, timeSeriesPerRow] = extractTimeSeriesFromMaskCIFTI(mask, grayordinates, varargin)
% Extract time series from binary mask.
%
% Syntax: 
%  [ meanTimeSeries, timeSeriesPerRow] = extractTimeSeriesFromMaskCIFTI(mask, grayordinates)
%
% Description:
%  This routine extracts the time series from each grayordinate defined in
%  the mask. The mask defines which voxels of interest, giving voxels to
%  be included in the mask a value of 1 and all other grayordinates a value
%  of 0. By point wise multiplication and removal of resulting empty rows,
%  only the relevant time series are saved out. The routine also provides a
%  measure of the central tendency across all included time series, with an
%  option for median, mean, or PCA (although I don't think PCA is working
%  properly).
%
% Inputs:
%  mask:                - a 92812 x 1 vector that defines which
%                         grayordiantes are of interest.
%  grayordinates:       - a 92812 x TR matrix that defines the time series
%                         of each grayordinate. Grayordinates can also
%                         include scalar values (like R2 values) rather
%                         than time series data.
%
% Optional key-value pairs:
%  whichCentralTendency - a string which controls which measure of central
%                         tendency of all incldued grayordinates to save
%                         out. Options inlcude 'mean', 'median', and 'PCA'
%                         (but 'PCA likely isn't working as intended).
%  threshold            - a number that defines the acceptable upper limit
%                         of time series data. If not empty (the default),
%                         a time series that contains values greater than
%                         this threshold will be censored. This is intended
%                         as being a means of removing outlier time series.
%                         Note that mean centering happens prior to this.
%
% Outputs:
%  meanTimeSeries       - a 1 x TR vector which contains the central
%                         tendency across all grayordinates included in the
%                         functional mask
%  timeSeriesPerRow     - a m x TR matrix which contains the value at each
%                         TR for all grayordinates included in the mask.


%% Input Parser
p = inputParser; p.KeepUnmatched = true;
p.addParameter('whichCentralTendency', 'mean', @ischar);
p.addParameter('meanCenter', true, @islogical);
p.addParameter('threshold', [], @isnumeric);
p.parse(varargin{:});

% expand mask to be of the same dimension as the grayordinates
expandedMask = repmat(mask, 1, size(grayordinates,2));

timeSeriesPerRow = grayordinates .* expandedMask;
timeSeriesPerRow = timeSeriesPerRow(any(timeSeriesPerRow,2),:);

if p.Results.meanCenter
    timeSeriesPerRow = meanCenterTimeSeries(timeSeriesPerRow);
end

% identify time series that have extreme values, and discard, if desired
if ~isempty(p.Results.threshold)
   for rr = size(timeSeriesPerRow,1)
       if any(abs(timeSeriesPerRow(rr,:))>p.Results.threshold)
           timeSeriesPerRow(rr,:) = zeros(1,size(timeSeriesPerRow,2));
           timeSeriesPerRow = timeSeriesPerRow(any(timeSeriesPerRow,2),:);
       end
   end
end




if strcmp(p.Results.whichCentralTendency, 'mean')    
    meanTimeSeries = mean(timeSeriesPerRow,1);
elseif strcmp(p.Results.whichCentralTendency, 'median')
    meanTimeSeries = median(timeSeriesPerRow,1);
elseif strcmp(p.Results.whichCentralTendency, 'PCA')
    [coeffs] = pca(timeSeriesPerRow);
    meanTimeSeries = coeffs(:,1);
end

end