%% ============================================================
%  Test 1 - Main easy load, polynomial feedforward
%
%  This script plots only the two most important result figures:
%       1) Position tracking: x_ref and x_real
%       2) Control signal: U_total, U_FF and U_PID
%
%  The plotted interval is one complete sinus period, selected from
%  trough -> peak -> trough. The time axis is reset so the selected
%  interval starts at t = 0 s.
%
%  Recommended placement:
%       Put this script in the same folder as: MainEasy.csv
%       If not, the fallback path below is also checked.
%% ============================================================

clc;
clear;
close all;

%% ===================== USER SETTINGS =====================

csvFileName = 'MainEasy.csv';
fallbackRelativeCsvFile = fullfile('Tests','Easy','MainEasy.csv');

% The tests use f = 0.025 Hz, so one period is approximately 40 s.
expectedPeriod_s = 40;

% The script searches for the first stable trough after this time.
% For Test 1-6 this removes the first sinus curve/transient region.
cycleSearchStart_s = 35;

% Search window around the expected cycle end. Increase slightly if needed.
cycleEndSearchWindow_s = 4;

% Save figures automatically?
saveFigures = false;

%% ===================== FIND AND READ CSV =====================

scriptDir = fileparts(mfilename('fullpath'));
csvPath = findCsvFile(scriptDir, csvFileName, fallbackRelativeCsvFile);

[t_s, S] = readTwinCATScopeCsv(csvPath);

xRef  = getSignal(S, 'fXRef_mm');
xReal = getSignal(S, 'fXReal_mm');
uFF   = getSignal(S, 'fU_FF');
uPID  = getSignal(S, 'fU_PID');
uTot  = uFF + uPID;

%% ===================== SELECT ONE SINUS PERIOD =====================

idx = selectOneTroughToTroughCycle(t_s, xRef, cycleSearchStart_s, expectedPeriod_s, cycleEndSearchWindow_s);

tPlot = t_s(idx) - t_s(idx(1));
xRefPlot  = xRef(idx);
xRealPlot = xReal(idx);
uFFPlot   = uFF(idx);
uPIDPlot  = uPID(idx);
uTotPlot  = uTot(idx);

%% ===================== PRINT SUMMARY =====================

posError = xRefPlot - xRealPlot;
MAE_mm   = mean(abs(posError), 'omitnan');
RMSE_mm  = sqrt(mean(posError.^2, 'omitnan'));
MaxE_mm  = max(abs(posError));

denominator = mean(abs(uFFPlot), 'omitnan') + mean(abs(uPIDPlot), 'omitnan');
if denominator > 0
    ffContribution_pct  = mean(abs(uFFPlot), 'omitnan') / denominator * 100;
    pidContribution_pct = mean(abs(uPIDPlot), 'omitnan') / denominator * 100;
else
    ffContribution_pct  = NaN;
    pidContribution_pct = NaN;
end

fprintf('\n============================================================\n');
fprintf('Test 1 - Main easy load, polynomial feedforward\n');
fprintf('CSV file: %s\n', csvPath);
fprintf('Selected original time interval: %.2f s to %.2f s\n', t_s(idx(1)), t_s(idx(end)));
fprintf('Mean absolute position error: %.3f mm\n', MAE_mm);
fprintf('RMSE position error: %.3f mm\n', RMSE_mm);
fprintf('Max absolute position error: %.3f mm\n', MaxE_mm);
fprintf('Feedforward contribution: %.2f %%\n', ffContribution_pct);
fprintf('Feedback/PID contribution: %.2f %%\n', pidContribution_pct);
fprintf('============================================================\n\n');

%% ===================== FIGURE 1: POSITION TRACKING =====================

fig1 = figure('Name', 'Position tracking', 'Color', 'w');
plot(tPlot, xRefPlot, 'LineWidth', 1.8);
hold on;
plot(tPlot, xRealPlot, '', 'LineWidth', 1.8);
grid on;
box on;
xlabel('Time [s]');
ylabel('Position [mm]');
title('Test 1 - Main easy load, polynomial feedforward');
legend('$x_{ref}$', '$x_{real}$', 'Interpreter', 'latex', 'Location', 'best');
xlim([0, tPlot(end)]);
set(gca, 'FontSize', 12);

yAll = [xRefPlot; xRealPlot];
yMargin = 0.08 * max(max(yAll) - min(yAll), 1);
ylim([450,750]);

%% ===================== FIGURE 2: CONTROL SIGNAL =====================

fig2 = figure('Name', 'Control signal', 'Color', 'w');
plot(tPlot, uTotPlot,'' ,'LineWidth', 1.8);
hold on;
plot(tPlot, uFFPlot, '', 'LineWidth', 1.8);
plot(tPlot, uPIDPlot, '', 'LineWidth', 2.0);
grid on;
box on;
xlabel('Time [s]');
ylabel('Control signal [-]');
title('Test 1 - Main easy load, polynomial feedforward - control signal');
legend('$U$', '$U_{FF}$', '$U_{PID}$', 'Interpreter', 'latex', 'Location', 'best');
xlim([0, tPlot(end)]);
set(gca, 'FontSize', 12);

%% ===================== SAVE FIGURES IF ENABLED =====================

if saveFigures
    [~, scriptName, ~] = fileparts(mfilename('fullpath'));
    exportgraphics(fig1, fullfile(scriptDir, scriptName + "_PositionTracking.png"), 'Resolution', 300);
    exportgraphics(fig2, fullfile(scriptDir, scriptName + "_ControlSignal.png"), 'Resolution', 300);
end

%% ============================================================
%  LOCAL FUNCTIONS
%% ============================================================

function csvPath = findCsvFile(scriptDir, csvFileName, fallbackRelativeCsvFile)
    candidatePaths = {
        fullfile(scriptDir, csvFileName)
        fullfile(scriptDir, fallbackRelativeCsvFile)
        fullfile(scriptDir, '..', fallbackRelativeCsvFile)
        fullfile(scriptDir, '..', '..', fallbackRelativeCsvFile)
    };

    for k = 1:numel(candidatePaths)
        candidate = char(candidatePaths{k});
        if isfile(candidate)
            csvPath = candidate;
            return;
        end
    end

    msg = sprintf('Could not find the CSV file. Expected one of these paths:\n');
    for k = 1:numel(candidatePaths)
        msg = sprintf('%s%d) %s\n', msg, k, char(candidatePaths{k}));
    end
    error(msg);
end

function [t_s, S] = readTwinCATScopeCsv(csvPath)
    raw = readcell(csvPath, 'Delimiter', ';');

    headerRow = [];
    for r = 1:size(raw, 1)
        rowAsText = string(raw(r, :));
        nName = sum(rowAsText == "Name");
        if nName >= 2
            headerRow = r;
            break;
        end
    end

    if isempty(headerRow)
        error('Could not find the TwinCAT signal header row in the CSV file.');
    end

    signalNames = {};
    valueCols = [];
    timeCols = [];

    for c = 1:2:size(raw, 2)-1
        if isTextEqual(raw{headerRow, c}, 'Name') && ~isMissingCell(raw{headerRow, c+1})
            signalNames{end+1} = char(string(raw{headerRow, c+1})); %#ok<AGROW>
            timeCols(end+1) = c; %#ok<AGROW>
            valueCols(end+1) = c + 1; %#ok<AGROW>
        end
    end

    dataStartRow = headerRow + 2;
    nRows = size(raw, 1) - dataStartRow + 1;
    nSignals = numel(signalNames);

    t_ms = nan(nRows, 1);
    data = nan(nRows, nSignals);

    for r = dataStartRow:size(raw, 1)
        outRow = r - dataStartRow + 1;
        t_ms(outRow) = cellToDouble(raw{r, timeCols(1)});
        for k = 1:nSignals
            data(outRow, k) = cellToDouble(raw{r, valueCols(k)});
        end
    end

    valid = ~isnan(t_ms);
    t_s = t_ms(valid) / 1000;
    data = data(valid, :);

    S = struct();
    for k = 1:nSignals
        cleanName = matlab.lang.makeValidName(signalNames{k});
        S.(cleanName) = data(:, k);
    end
end

function idx = selectOneTroughToTroughCycle(t_s, xRef, searchStart_s, expectedPeriod_s, endSearchWindow_s)
    startWindow = t_s >= searchStart_s & t_s <= searchStart_s + expectedPeriod_s;
    if ~any(startWindow)
        error('No samples found in the cycle start search window.');
    end

    startCandidates = find(startWindow);
    [~, localStart] = min(xRef(startCandidates));
    idxStart = startCandidates(localStart);

    expectedEnd_s = t_s(idxStart) + expectedPeriod_s;
    endWindow = t_s >= expectedEnd_s - endSearchWindow_s & t_s <= expectedEnd_s + endSearchWindow_s;

    if any(endWindow)
        endCandidates = find(endWindow);
        [~, localEnd] = min(xRef(endCandidates));
        idxEnd = endCandidates(localEnd);
    else
        [~, idxEnd] = min(abs(t_s - expectedEnd_s));
    end

    if idxEnd <= idxStart
        error('The selected cycle end occurs before the selected cycle start. Adjust cycleSearchStart_s.');
    end

    idx = idxStart:idxEnd;
end

function x = getSignal(S, signalName)
    fieldName = matlab.lang.makeValidName(signalName);
    if ~isfield(S, fieldName)
        available = strjoin(fieldnames(S), ', ');
        error('Missing signal "%s". Available signals: %s', signalName, available);
    end
    x = S.(fieldName);
end

function tf = isTextEqual(value, wantedText)
    txt = string(value);
    if any(ismissing(txt))
        tf = false;
    else
        tf = strcmp(strtrim(txt), wantedText);
    end
end

function tf = isMissingCell(value)
    txt = string(value);
    if isempty(value) || any(ismissing(txt))
        tf = true;
    else
        tf = strlength(strtrim(txt)) == 0;
    end
end

function x = cellToDouble(value)
    if isnumeric(value)
        x = double(value);
    else
        txt = string(value);
        if any(ismissing(txt))
            x = NaN;
        else
            txt = strrep(strtrim(char(txt)), ',', '.');
            x = str2double(txt);
        end
    end
end
