%% ============================================================
%  DRIFTING ANALYSIS - TEST WITHOUT TC3 PID
%
%  This script is intended for the long-run drift test:
%
%      MainHardUtenTC3PIDLongrun.csv
%
%  The purpose is to show whether the actual cylinder position
%  gradually drifts away from the position reference when the
%  outer TC3 PID controller is disabled.
%
%  The script plots:
%      1) Position reference vs measured position
%      2) Position error over time
%      3) Smoothed position error / drift trend
%      4) Feedforward, PID and total control signal
%
%  The full test is used by default.
%% ============================================================

clc;
clear;
close all;

%% ===================== USER SETTINGS =====================

csvFileName = 'MainHardUtenTC3PIDLongrun.csv';

testTitle = 'Main hard position - without TC3 PID, long-run drift test';

% Use 0 to include the whole test.
% Increase this if you want to remove startup transient.
tAnalysisStart = 2.3;     % [s]

% Use inf to include the whole remaining file.
tAnalysisStop = inf;    % [s]

% Moving average window used to show slow drift trend.
% Increase this if the sinusoidal error dominates the drift plot.
driftWindow_s = 10;     % [s]

% Set true if figures should be saved.
saveFigures = false;

% Line width.
lw = 1.6;

%% ===================== FIND AND READ CSV =====================

scriptDir = fileparts(mfilename('fullpath'));

if isempty(scriptDir)
    scriptDir = pwd;
end

csvFile = findCsvFile(scriptDir, csvFileName);

D = readTwinCATScopeCsv(csvFile);

S = extractSingleAxisSignals(D);

%% ===================== SELECT ANALYSIS INTERVAL =====================

idx = S.t >= tAnalysisStart & S.t <= tAnalysisStop;

if sum(idx) < 10
    error('Too few samples selected. Check tAnalysisStart and tAnalysisStop.');
end

tPlot = S.t(idx) - S.t(find(idx, 1, 'first'));

xRef  = S.xRef(idx);
xReal = S.xReal(idx);

% Position error.
% Positive error means reference is higher than measured position.
e = xRef - xReal;

% Sampling time estimate.
dt = median(diff(S.t), 'omitnan');

% Moving-average window in samples.
driftWindow_N = max(1, round(driftWindow_s / dt));

% Smoothed error used as drift trend.
eSmooth = movmean(e, driftWindow_N, 'omitnan');

%% ===================== DRIFT METRICS =====================

meanAbsError = mean(abs(e), 'omitnan');
rmseError    = sqrt(mean(e.^2, 'omitnan'));
maxAbsError  = max(abs(e));

initialError = eSmooth(1);
finalError   = eSmooth(end);
totalDrift   = finalError - initialError;

testDuration_min = (tPlot(end) - tPlot(1)) / 60;

if testDuration_min > 0
    driftRate_mm_per_min = totalDrift / testDuration_min;
else
    driftRate_mm_per_min = NaN;
end

meanAbsUFF  = mean(abs(S.uFF(idx)), 'omitnan');
meanAbsUPID = mean(abs(S.uPID(idx)), 'omitnan');
meanAbsUtot = mean(abs(S.uTotal(idx)), 'omitnan');

denom = meanAbsUFF + meanAbsUPID;

if denom > 0
    ffContributionPct  = 100 * meanAbsUFF / denom;
    pidContributionPct = 100 * meanAbsUPID / denom;
else
    ffContributionPct  = NaN;
    pidContributionPct = NaN;
end

fprintf('\n============================================================\n');
fprintf('%s\n', testTitle);
fprintf('CSV file: %s\n', csvFile);
fprintf('Selected interval: %.3f s to %.3f s\n', S.t(find(idx, 1, 'first')), S.t(find(idx, 1, 'last')));
fprintf('Duration: %.2f min\n', testDuration_min);
fprintf('============================================================\n');

fprintf('\nPosition error:\n');
fprintf('  Mean absolute position error: %.3f mm\n', meanAbsError);
fprintf('  RMSE:                         %.3f mm\n', rmseError);
fprintf('  Max absolute position error:  %.3f mm\n', maxAbsError);

fprintf('\nDrift trend, based on %.1f s moving average:\n', driftWindow_s);
fprintf('  Initial smoothed error:        %.3f mm\n', initialError);
fprintf('  Final smoothed error:          %.3f mm\n', finalError);
fprintf('  Total drift:                   %.3f mm\n', totalDrift);
fprintf('  Drift rate:                    %.3f mm/min\n', driftRate_mm_per_min);

fprintf('\nControl contribution:\n');
fprintf('  Mean absolute U_total:         %.3f\n', meanAbsUtot);
fprintf('  Feedforward contribution:      %.2f %%\n', ffContributionPct);
fprintf('  PID contribution:              %.2f %%\n', pidContributionPct);
fprintf('============================================================\n');

%% ===================== PLOT 1: POSITION TRACKING =====================

figure('Name', [testTitle ' - position tracking'], 'Color', 'w');

plot(tPlot, xRef,  '',  'LineWidth', lw); hold on;
plot(tPlot, xReal, '', 'LineWidth', lw);

grid on;
xlabel('Time [s]');
ylabel('Position [mm]');
title([testTitle ' - position tracking']);

legend('$x_{ref}$', '$x_{real}$', ...
    'Interpreter', 'latex', ...
    'Location', 'best');

set(gca, 'FontSize', 12);

if saveFigures
    saveas(gcf, fullfile(scriptDir, 'DriftTest_PositionTracking.png'));
end

%% ===================== PLOT 2: POSITION ERROR =====================

figure('Name', [testTitle ' - position error'], 'Color', 'w');

plot(tPlot, e, '-', 'LineWidth', lw);

grid on;
xlabel('Time [s]');
ylabel('Position error [mm]');
title([testTitle ' - position error']);

set(gca, 'FontSize', 12);

if saveFigures
    saveas(gcf, fullfile(scriptDir, 'DriftTest_PositionError.png'));
end

%% ===================== PLOT 3: DRIFT TREND =====================

figure('Name', [testTitle ' - drift trend'], 'Color', 'w');

plot(tPlot, e, '-', 'LineWidth', 0.8); hold on;
plot(tPlot, eSmooth, '-', 'LineWidth', lw + 0.4);

grid on;
xlabel('Time [s]');
ylabel('Position error [mm]');
title([testTitle ' - drift trend']);

legend('$e = x_{ref} - x_{real}$', ...
       '$e$ moving average / drift trend', ...
       'Interpreter', 'latex', ...
       'Location', 'best');

set(gca, 'FontSize', 12);

if saveFigures
    saveas(gcf, fullfile(scriptDir, 'DriftTest_DriftTrend.png'));
end

%% ===================== PLOT 4: CONTROL SIGNALS =====================

figure('Name', [testTitle ' - control signals'], 'Color', 'w');

plot(tPlot, S.uTotal(idx), '-',  'LineWidth', lw); hold on;
plot(tPlot, S.uFF(idx),    '--', 'LineWidth', lw);
plot(tPlot, S.uPID(idx),   ':',  'LineWidth', lw + 0.2);

yline(1,  '--', 'Saturation +1');
yline(-1, '--', 'Saturation -1');

grid on;
xlabel('Time [s]');
ylabel('Control signal [-]');
title([testTitle ' - control signals']);

legend('$U_{total}$', '$U_{FF}$', '$U_{PID}$', ...
    'Interpreter', 'latex', ...
    'Location', 'best');

set(gca, 'FontSize', 12);
ylim([-1.1, 1.1]);

if saveFigures
    saveas(gcf, fullfile(scriptDir, 'DriftTest_ControlSignals.png'));
end

%% ===================== SUMMARY TABLE =====================

summaryTable = table( ...
    meanAbsError, ...
    rmseError, ...
    maxAbsError, ...
    initialError, ...
    finalError, ...
    totalDrift, ...
    driftRate_mm_per_min, ...
    meanAbsUtot, ...
    ffContributionPct, ...
    pidContributionPct, ...
    'VariableNames', { ...
        'MeanAbsError_mm', ...
        'RMSE_mm', ...
        'MaxAbsError_mm', ...
        'InitialSmoothedError_mm', ...
        'FinalSmoothedError_mm', ...
        'TotalDrift_mm', ...
        'DriftRate_mm_per_min', ...
        'MeanAbsUtotal', ...
        'MeanFFContributionPct', ...
        'MeanPIDContributionPct' ...
    });

fprintf('\n============================================================\n');
fprintf('COMPACT SUMMARY: DRIFT TEST\n');
fprintf('============================================================\n');
disp(summaryTable);

%% ============================================================
%  LOCAL FUNCTIONS
%% ============================================================

function csvFile = findCsvFile(scriptDir, csvFileName)
    % Finds the CSV file in common locations.

    candidateFiles = {
        fullfile(scriptDir, csvFileName)
        fullfile(pwd, csvFileName)
        fullfile(scriptDir, 'Tests', csvFileName)
        fullfile(scriptDir, 'Tests', 'Hard', csvFileName)
        fullfile(scriptDir, 'Tests', 'PID', csvFileName)
        fullfile(scriptDir, '..', 'Tests', csvFileName)
        fullfile(scriptDir, '..', 'Tests', 'Hard', csvFileName)
        fullfile(scriptDir, '..', 'Tests', 'PID', csvFileName)
    };

    csvFile = '';

    for i = 1:numel(candidateFiles)
        if isfile(candidateFiles{i})
            csvFile = candidateFiles{i};
            break;
        end
    end

    if isempty(csvFile)
        msg = sprintf('Could not find CSV file "%s". Tried these paths:\n', csvFileName);

        for i = 1:numel(candidateFiles)
            msg = sprintf('%s%d) %s\n', msg, i, candidateFiles{i});
        end

        error(msg);
    end
end

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
            signalName = strtrim(headerParts(i+1));
            signalName = matlab.lang.makeValidName(signalName);
            signalNames(end+1) = signalName; %#ok<AGROW>
        end
    end

    nSignals = numel(signalNames);

    if nSignals == 0
        error('No signal names were found in the CSV header.');
    end

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

function S = extractSingleAxisSignals(D)
    % Extracts signals from the single-axis long-run test.
    %
    % Expected names:
    %   fXRef_mm
    %   fXReal_mm
    %   fU_FF
    %   fU_PID
    %
    % If fU_total is missing:
    %   U_total = U_FF + U_PID

    requiredSignals = {
        'time_s'
        'fXRef_mm'
        'fXReal_mm'
        'fU_FF'
        'fU_PID'
    };

    for i = 1:numel(requiredSignals)
        if ~ismember(requiredSignals{i}, D.Properties.VariableNames)
            error('Missing required signal in CSV file: %s', requiredSignals{i});
        end
    end

    S = struct();

    S.t     = D.time_s;
    S.xRef  = D.fXRef_mm;
    S.xReal = D.fXReal_mm;
    S.uFF   = D.fU_FF;
    S.uPID  = D.fU_PID;

    if ismember('fU_total', D.Properties.VariableNames)
        S.uTotal = D.fU_total;
    elseif ismember('fU_Total', D.Properties.VariableNames)
        S.uTotal = D.fU_Total;
    else
        S.uTotal = S.uFF + S.uPID;
    end
end
%% 

%% ===================== CHECK MAX ERROR LOCATION =====================

[MaxAbsError_mm, idxMax] = max(abs(error_mm));

fprintf('\nMAX ERROR CHECK\n');
fprintf('Max absolute error: %.3f mm\n', MaxAbsError_mm);
fprintf('Time of max error: %.3f s\n', time(idxMax));
fprintf('Reference position: %.3f mm\n', xref_mm(idxMax));
fprintf('Measured position:  %.3f mm\n', xreal_mm(idxMax));
fprintf('Signed error:       %.3f mm\n', error_mm(idxMax));

figure;
plot(time, error_mm, 'LineWidth', 1.2);
hold on;
plot(time(idxMax), error_mm(idxMax), 'ro', 'MarkerSize', 8, 'LineWidth', 2);
grid on;
xlabel('Time [s]');
ylabel('Position error [mm]');
title('Position error with maximum error marked');
legend('Position error', 'Maximum absolute error', 'Location', 'best');