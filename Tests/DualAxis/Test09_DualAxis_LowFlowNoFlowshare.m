%% ============================================================
%  DUAL-AXIS TEST PLOT
%
%  This script plots one complete reference cycle for both cylinders:
%      1) Combined Jib and Main position tracking
%      2) Jib control signal
%      3) Main control signal
%
%  The selected interval is chosen automatically from the reference signal
%  as one complete low -> high -> low cycle.
%
%  Time is reset to 0 s at the beginning of the selected cycle.
%
%  Place this script in the same folder as the CSV file, or keep the
%  original folder structure from the Tests.zip file.
%% ============================================================

clc;
clear;
close all;

%% ===================== USER SETTINGS =====================

csvFileName  = 'LowFlowNoFlowshare.csv';
testTitle    = 'Test 9 - Dual-axis low flow, no flow-sharing';

% Search start for the selected cycle:
%   Test 9:  40 s, to skip the first sinus period.
%   Test 10: 0 s, to use the first complete high-flow sinus curve.
%   Test 11: 0 s, to use the first complete high-flow sinus curve.
tSearchStart = 40;   % [s]

% Set to true if you want figures to be saved as PNG files in the script folder.
saveFigures = false;

% Line width used in plots.
lw = 1.6;

%% ===================== FIND AND READ CSV =====================

scriptDir = fileparts(mfilename('fullpath'));
if isempty(scriptDir)
    scriptDir = pwd;
end

candidateFiles = {
    fullfile(scriptDir, csvFileName)
    fullfile(scriptDir, 'Tests', 'DualAxis', csvFileName)
    fullfile(scriptDir, '..', 'Tests', 'DualAxis', csvFileName)
    fullfile(scriptDir, '..', '..', 'Tests', 'DualAxis', csvFileName)
    fullfile(pwd, csvFileName)
    fullfile(pwd, 'Tests', 'DualAxis', csvFileName)
};

csvFile = '';
for k = 1:numel(candidateFiles)
    if isfile(candidateFiles{k})
        csvFile = candidateFiles{k};
        break;
    end
end

if isempty(csvFile)
    msg = sprintf('Could not find the CSV file "%s". Tried these paths:\n', csvFileName);
    for k = 1:numel(candidateFiles)
        msg = sprintf('%s%d) %s\n', msg, k, candidateFiles{k});
    end
    error(msg);
end

D = readTwinCATScopeCsv(csvFile);

%% ===================== EXTRACT SIGNALS =====================

t = D.time_s;

jib.xRef  = D.fJib_XRef_mm;
jib.xReal = D.fJib_XReal_mm;
jib.uTot  = D.fJib_U_total;
jib.uFF   = D.fJib_U_FF;
jib.uPID  = D.fJib_U_PID;

main.xRef  = D.fMain_XRef_mm;
main.xReal = D.fMain_XReal_mm;
main.uTot  = D.fMain_U_total;
main.uFF   = D.fMain_U_FF;
main.uPID  = D.fMain_U_PID;

%% ===================== SELECT ONE FULL SINUS CYCLE =====================

% Jib and Main references use the same timing in the dual-axis tests.
% The Jib reference is used only to identify the plotting interval.
[idxStart, idxPeak, idxStop] = findOneReferenceCycleLowHighLow(t, jib.xRef, tSearchStart);

idx = idxStart:idxStop;
tPlot = t(idx) - t(idxStart);   % reset time axis to zero

fprintf('\n============================================================\n');
fprintf('%s\n', testTitle);
fprintf('CSV file: %s\n', csvFile);
fprintf('Selected interval: %.3f s to %.3f s\n', t(idxStart), t(idxStop));
fprintf('Cycle duration: %.3f s\n', t(idxStop) - t(idxStart));
fprintf('Peak occurs at: %.3f s in original time, %.3f s in plot time\n', ...
    t(idxPeak), t(idxPeak) - t(idxStart));
fprintf('============================================================\n');

printMetrics('Jib',  jib,  idx);
printMetrics('Main', main, idx);

%% ===================== PLOT COMBINED POSITION TRACKING =====================

figure('Name', [testTitle ' - position tracking'], 'Color', 'w');
plot(tPlot, jib.xRef(idx),   '',  'LineWidth', lw); hold on;
plot(tPlot, jib.xReal(idx),  '', 'LineWidth', lw);
plot(tPlot, main.xRef(idx),  '',  'LineWidth', lw);
plot(tPlot, main.xReal(idx), '', 'LineWidth', lw);
grid on;
xlabel('Time [s]');
ylabel('Position [mm]');
title([testTitle ' - position tracking']);
legend('$x_{ref,jib}$', '$x_{real,jib}$', ...
       '$x_{ref,main}$', '$x_{real,main}$', ...
       'Interpreter', 'latex', 'Location', 'best');
set(gca, 'FontSize', 12);

if saveFigures
    saveas(gcf, fullfile(scriptDir, [matlab.lang.makeValidName(testTitle) '_Position_Combined.png']));
end

%% ===================== PLOT JIB CONTROL SIGNAL =====================

figure('Name', [testTitle ' - Jib control signal'], 'Color', 'w');
plot(tPlot, jib.uTot(idx), '',  'LineWidth', lw); hold on;
plot(tPlot, jib.uFF(idx),  '', 'LineWidth', lw);
plot(tPlot, jib.uPID(idx), '',  'LineWidth', lw + 0.2);
grid on;
xlabel('Time [s]');
ylabel('Control signal [-]');
title([testTitle ' - Jib control signal']);
legend('$U$', '$U_{FF}$', '$U_{PID}$', 'Interpreter', 'latex', 'Location', 'best');
set(gca, 'FontSize', 12);

if saveFigures
    saveas(gcf, fullfile(scriptDir, [matlab.lang.makeValidName(testTitle) '_Jib_Control.png']));
end

%% ===================== PLOT MAIN CONTROL SIGNAL =====================

figure('Name', [testTitle ' - Main control signal'], 'Color', 'w');
plot(tPlot, main.uTot(idx), '',  'LineWidth', lw); hold on;
plot(tPlot, main.uFF(idx),  '', 'LineWidth', lw);
plot(tPlot, main.uPID(idx), '',  'LineWidth', lw + 0.2);
grid on;
xlabel('Time [s]');
ylabel('Control signal [-]');
title([testTitle ' - Main control signal']);
legend('$U$', '$U_{FF}$', '$U_{PID}$', 'Interpreter', 'latex', 'Location', 'best');
set(gca, 'FontSize', 12);

if saveFigures
    saveas(gcf, fullfile(scriptDir, [matlab.lang.makeValidName(testTitle) '_Main_Control.png']));
end

%% ============================================================
%  LOCAL FUNCTIONS
%% ============================================================

function D = readTwinCATScopeCsv(filename)
    % Reads TwinCAT Scope CSV files where each signal is exported as:
    % time; value; time; value; ...

    rawLines = readlines(filename, 'EmptyLineRule', 'read');

    headerLineIdx = find(contains(rawLines, 'Name;f'), 1, 'first');
    if isempty(headerLineIdx)
        error('Could not find the TwinCAT signal header line in the CSV file.');
    end

    headerParts = split(rawLines(headerLineIdx), ';');
    signalNames = strings(0);

    for i = 1:numel(headerParts)-1
        if strlength(headerParts(i)) > 0 && strcmp(strtrim(headerParts(i)), 'Name')
            signalNames(end+1) = strtrim(headerParts(i+1)); %#ok<AGROW>
        end
    end

    nSignals = numel(signalNames);
    dataStartIdx = headerLineIdx + 2;

    time_s = [];
    values = [];

    for r = dataStartIdx:numel(rawLines)
        line = strtrim(rawLines(r));

        if strlength(line) == 0 || startsWith(line, 'EOF')
            continue;
        end

        parts = split(line, ';');

        if numel(parts) < 2*nSignals
            continue;
        end

        rowTime_ms = str2double(strrep(parts(1), ',', '.'));
        if isnan(rowTime_ms)
            continue;
        end

        rowValues = nan(1, nSignals);
        for s = 1:nSignals
            valueCol = 2*s;
            rowValues(s) = str2double(strrep(parts(valueCol), ',', '.'));
        end

        time_s(end+1, 1) = rowTime_ms/1000; %#ok<AGROW>
        values(end+1, :) = rowValues; %#ok<AGROW>
    end

    D = array2table(values, 'VariableNames', cellstr(signalNames));
    D.time_s = time_s;
    D = movevars(D, 'time_s', 'Before', 1);
end

function [idxStart, idxPeak, idxStop] = findOneReferenceCycleLowHighLow(t, xRef, tSearchStart)
    % Finds one full reference cycle of the type low -> high -> low.
    % This version is more robust than a pure local-minimum detector because
    % some of the logged references start with a short flat section close to
    % the lower turning point.

    t = t(:);
    xRef = xRef(:);

    valid = isfinite(t) & isfinite(xRef) & t >= tSearchStart;
    idxValidOriginal = find(valid);

    if numel(idxValidOriginal) < 10
        error('Not enough valid reference data after tSearchStart = %.2f s.', tSearchStart);
    end

    tSeg = t(idxValidOriginal);
    xSeg = xRef(idxValidOriginal);

    % Remove initialization zeros if the real reference range is much higher.
    xMax = max(xSeg);
    if xMax > 50
        keep = xSeg > 0.25*xMax;
        if sum(keep) > 10
            idxValidOriginal = idxValidOriginal(keep);
            tSeg = t(idxValidOriginal);
            xSeg = xRef(idxValidOriginal);
        end
    end

    xMin = min(xSeg);
    xMax = max(xSeg);
    xRange = xMax - xMin;

    if xRange <= 0
        error('Reference signal has no usable variation after tSearchStart = %.2f s.', tSearchStart);
    end

    % Thresholds relative to the local reference range.
    lowLeaveLevel = xMin + 0.025*xRange;  % e.g. 5 mm for a 200 mm range
    lowNearLevel  = xMin + 0.005*xRange;  % e.g. 1 mm for a 200 mm range
    highLevel     = xMax - 0.025*xRange;

    % First time the reference leaves the lower turning region upwards.
    upCrossLocal = find(xSeg(1:end-1) <= lowLeaveLevel & xSeg(2:end) > lowLeaveLevel, 1, 'first') + 1;

    if isempty(upCrossLocal)
        error('Could not find where the reference leaves the lower turning point after %.2f s.', tSearchStart);
    end

    % Backtrack to the last point that is very close to the lower reference.
    lowBefore = find(xSeg(1:upCrossLocal) <= lowNearLevel, 1, 'last');
    if isempty(lowBefore)
        lowBefore = upCrossLocal;
    end
    idxStart = idxValidOriginal(lowBefore);

    % Find the first high region after the start, then select the actual peak
    % before the signal returns to the lower region.
    highAfterStartLocal = find(xSeg(upCrossLocal:end) >= highLevel, 1, 'first') + upCrossLocal - 1;
    if isempty(highAfterStartLocal)
        error('Could not find the upper part of the selected reference cycle.');
    end

    % Find when the reference returns close to the lower turning point.
    lowAfterHighLocal = find(xSeg(highAfterStartLocal:end) <= lowNearLevel, 1, 'first') + highAfterStartLocal - 1;

    if isempty(lowAfterHighLocal)
        % Fallback: use a less strict return threshold.
        lowAfterHighLocal = find(xSeg(highAfterStartLocal:end) <= lowLeaveLevel, 1, 'first') + highAfterStartLocal - 1;
    end

    if isempty(lowAfterHighLocal)
        error('Could not find where the selected reference cycle returns to the lower turning point.');
    end

    idxStop = idxValidOriginal(lowAfterHighLocal);

    % Peak is the maximum inside the selected interval.
    intervalOriginal = idxStart:idxStop;
    [~, peakLocal] = max(xRef(intervalOriginal));
    idxPeak = intervalOriginal(peakLocal);
end

function printMetrics(name, S, idx)
    e = S.xRef(idx) - S.xReal(idx);

    mae = mean(abs(e), 'omitnan');
    rmse = sqrt(mean(e.^2, 'omitnan'));
    maxAbs = max(abs(e));

    meanFF  = mean(abs(S.uFF(idx)), 'omitnan');
    meanPID = mean(abs(S.uPID(idx)), 'omitnan');

    denom = meanFF + meanPID;
    if denom > 0
        ffPct  = 100*meanFF/denom;
        pidPct = 100*meanPID/denom;
    else
        ffPct = NaN;
        pidPct = NaN;
    end

    fprintf('\n%s cylinder:\n', name);
    fprintf('  Mean absolute position error: %.3f mm\n', mae);
    fprintf('  RMSE:                         %.3f mm\n', rmse);
    fprintf('  Max absolute position error:  %.3f mm\n', maxAbs);
    fprintf('  Feedforward contribution:     %.2f %%\n', ffPct);
    fprintf('  Feedback/PID contribution:    %.2f %%\n', pidPct);
end
