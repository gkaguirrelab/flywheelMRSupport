function [outSignal] = filter_signal(inSignal,filtType,sampT,cutoffHzlow,cutoffHzhigh,varargin)

% Filters and input signal based on the specified 'filtType'
%
%   Usage:
%   [outSignal] = filter_signal(inSignal,filtType,sampPeriod,cutoffHzlow,cutoffHzhigh)
%
%   inputs:
%   inSignal - signal to be filtered
%   filtType - can be 'high', 'low', or 'band'
%   sampT - sampling period (e.g. TR for MRI)
%   cutoffHzlow - low frequency cutoff (Hz)
%   cutoffHzhigh - high frequency cutoff (Hz)
%
%   Optional key/value pairs:
%   'verbose' - logical, default false
%
%   Written by Andrew S Bock Nov 2015

%% Parameter Parser (for varargin)

p = inputParser;
p.addParameter('verbose',false, @islogical);
p.parse(varargin{:})
verbose = p.Results.verbose;

%% Filter data
switch filtType
    case 'high'
        if verbose
            disp('FiltType = ''high''');
        end
        f_cutoff  = 1/(2*sampT);
        n = 5; %order
        Wn = cutoffHzlow/f_cutoff;
        FD = design(fdesign.highpass('N,F3dB',n,Wn),'butter');
        outSignal = filtfilt(FD.sosMatrix, FD.ScaleValues, inSignal);
    case 'low'
        if verbose
            disp('FiltType = ''low''');
        end
        f_cutoff  = 1/(2*sampT);
        n = 5; %order
        Wn = cutoffHzhigh/f_cutoff;
        FD = design(fdesign.lowpass('N,F3dB',n,Wn),'butter');
        outSignal = filtfilt(FD.sosMatrix, FD.ScaleValues, inSignal);
    case 'band'
        if verbose
            disp('FiltType = ''band''');
        end
        f_cutoff  = 1/(2*sampT);
        n = 4; %requires even order number
        Wn = [cutoffHzlow cutoffHzhigh]./f_cutoff;
        FD = design(fdesign.bandpass('N,F3dB1,F3dB2',n,Wn(1),Wn(2)),'butter');
        outSignal = filtfilt(FD.sosMatrix, FD.ScaleValues, inSignal);
    case 'notch'
        if verbose
            disp('FiltType = ''notch''');
        end
        f_cutoff  = 1/(2*sampT);
        n = 4; %requires even order number
        q = 30; % Quality factor. Higher = narrow
        f0 = cutoffHzhigh/f_cutoff;        
        FD = design(fdesign.notch(n,f0,q));
        outSignal = filtfilt(FD.sosMatrix, FD.ScaleValues, inSignal);
end