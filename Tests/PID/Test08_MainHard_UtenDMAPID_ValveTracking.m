%% ============================================================
%  TEST 08 - VALVE TRACKING WITHOUT DMA PID
%
%  Plots one complete sinusoidal reference cycle:
%       u_ref  = fU
%       u_meas = fMain_Spool
%
%  The selected cycle is the same type as the position/control scripts:
%       reference trough -> reference peak -> reference trough
%
%  Time is reset so that the selected cycle starts at t = 0 s.
%
%  Expected CSV file:
%       MainHardUtenDMAPID2.csv
%
%  Place this script in the same folder as the CSV file.
%% ============================================================

clc;
clear;
close all;

%% ===================== USER SETTINGS =====================

csvFileName = 'MainHardUtenDMAPID2.csv';
tSearchStart = 0;        % [s] use same cycle as the other PID scripts
saveFigures  = false;     % true = save figure as PNG

%% ===================== READ CSV FILE =====================

scriptFolder = fileparts(mfilename('fullpath'));
csvFile = fullfile(scriptFolder, csvFileName);

if ~isfile(csvFile)
    csvFile = fullfile(pwd, csvFileName);
end

if ~isfile(csvFile)
    error(['Could not find CSV file: ', csvFileName, newline, ...
           'Place this script in the same folder as the CSV file, or edit csvFileName.']);
end

D = readTwinCATScopeCsv(csvFile);

%% ===================== CHECK REQUIRED SIGNALS =====================

requiredSignals = {'fXRef_mm', 'fU', 'fMain_Spool'};
for k = 1:numel(requiredSignals)
    if ~any(strcmp(D.Properties.VariableNames, requiredSignals{k}))
        error('Missing required signal: %s', requiredSignals{k});
    end
end

%% ===================== EXTRACT SIGNALS =====================

t     = D.t_s;
xRef  = D.fXRef_mm;
uRef  = D.fU;
uMeas = D.fMain_Spool;

%% ===================== SELECT ONE FULL SINUS CYCLE =====================

[idxStart, idxPeak, idxStop] = findReferenceCycleTroughPeakTrough(t, xRef, tSearchStart);
idx = idxStart:idxStop;

tPlot = t(idx) - t(idxStart);
uRefPlot  = uRef(idx);
uMeasPlot = uMeas(idx);

fprintf('\n============================================================\n');
fprintf('TEST 08 - VALVE TRACKING WITHOUT DMA PID\n');
fprintf('Selected cycle: %.2f s to %.2f s, reset to 0 s to %.2f s\n', ...
    t(idxStart), t(idxStop), tPlot(end));
fprintf('Reference trough: %.2f mm, peak: %.2f mm, trough: %.2f mm\n', ...
    xRef(idxStart), xRef(idxPeak), xRef(idxStop));
fprintf('============================================================\n\n');

%% ===================== FIGURE: VALVE TRACKING =====================

figure('Name','Test 08 - Valve Tracking','Color','w');
plot(tPlot, uRefPlot, 'LineWidth', 1.8); hold on;
plot(tPlot, uMeasPlot, '', 'LineWidth', 1.8);
grid on;
box on;
xlabel('Time [s]');
ylabel('Valve signal [-]');
title('Test 8 - Valve tracking without DMA PID');
legend('$u_{ref}$', '$u_{meas}$', 'Interpreter','latex', 'Location','best');

if saveFigures
    exportgraphics(gcf, fullfile(scriptFolder, 'Test08_ValveTracking.png'), 'Resolution', 300);
end

%% ===================== LOCAL FUNCTIONS =====================

function D = readTwinCATScopeCsv(filePath)
    lines = readlines(filePath, 'Encoding','UTF-8');

    headerIdx = find(contains(lines, 'fXRef_mm'), 1, 'first');
    if isempty(headerIdx)
        error('Could not find the signal header line containing fXRef_mm.');
    end

    headerParts = split(lines(headerIdx), ';');
    headerParts = string(headerParts);

    signalNames = strings(0,1);
    for k = 2:2:numel(headerParts)
        name = strtrim(headerParts(k));
        if strlength(name) > 0
            signalNames(end+1,1) = name; %#ok<AGROW>
        end
    end

    nSignals = numel(signalNames);
    rawData = [];
    rawTime = [];

    for i = headerIdx+2:numel(lines)
        line = strtrim(lines(i));
        if strlength(line) == 0 || contains(line, 'EOF')
            continue;
        end

        parts = split(line, ';');
        if numel(parts) < 2*nSignals
            continue;
        end

        tValue = str2double(strrep(parts(1), ',', '.')) / 1000;
        if isnan(tValue)
            continue;
        end

        values = nan(1,nSignals);
        ok = true;
        for s = 1:nSignals
            valueIndex = 2*s;
            values(s) = str2double(strrep(parts(valueIndex), ',', '.'));
            if isnan(values(s))
                ok = false;
                break;
            end
        end

        if ok
            rawTime(end+1,1) = tValue; %#ok<AGROW>
            rawData(end+1,:) = values; %#ok<AGROW>
        end
    end

    D = table(rawTime, 'VariableNames', {'t_s'});
    for s = 1:nSignals
        D.(signalNames(s)) = rawData(:,s);
    end
end

function [idxStart, idxPeak, idxStop] = findReferenceCycleTroughPeakTrough(t, xRef, tSearchStart)
    % Finds one complete reference cycle without using findpeaks.
    % No Signal Processing Toolbox is required.
    %
    % The reference used in these tests is sinusoidal with a period of about
    % 40 s. The function searches for:
    %       trough -> peak -> trough
    % after tSearchStart.

    expectedPeriod = 40;   % [s]

    t = t(:);
    xRef = xRef(:);

    if numel(t) < 10
        error('Not enough samples to detect a reference cycle.');
    end

    % Smooth only for selecting the cycle. The plotted data is unchanged.
    dt = median(diff(t));
    smoothWindow = max(5, round(0.25/dt));
    xSmooth = movmean(xRef, smoothWindow);

    % -------- First trough --------
    % Search over approximately one period after tSearchStart.
    firstWindow = find(t >= tSearchStart & t <= tSearchStart + expectedPeriod);
    if isempty(firstWindow)
        error('Could not find samples after tSearchStart = %.2f s.', tSearchStart);
    end

    [~, localMinIndex] = min(xSmooth(firstWindow));
    idxStart = firstWindow(localMinIndex);

    % -------- Peak between the two troughs --------
    peakWindow = find(t >= t(idxStart) + 0.25*expectedPeriod & ...
                      t <= t(idxStart) + 0.75*expectedPeriod);
    if isempty(peakWindow)
        error('Could not find a peak search window after the selected trough.');
    end

    [~, localPeakIndex] = max(xSmooth(peakWindow));
    idxPeak = peakWindow(localPeakIndex);

    % -------- Next trough --------
    stopWindow = find(t >= t(idxStart) + 0.75*expectedPeriod & ...
                      t <= t(idxStart) + 1.25*expectedPeriod);
    if isempty(stopWindow)
        error('Could not find a stop trough search window after the selected trough.');
    end

    [~, localStopIndex] = min(xSmooth(stopWindow));
    idxStop = stopWindow(localStopIndex);

    if idxStop <= idxPeak || idxPeak <= idxStart
        error('Could not identify a valid trough -> peak -> trough reference cycle.');
    end
end
