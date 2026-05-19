%% ============================================================
%  CLASSIC FEEDFORWARD TESTS - ONE STABLE SINUS CYCLE
%
%  This script plots one complete and stable sinus cycle for the
%  classical feedforward tests:
%
%      1) MainHardClassic2.csv
%      2) JibHardClassic2.csv
%
%  For each test, the script plots:
%      - Position reference vs measured position
%      - Feedforward, PID and total control signal
%
%  The selected interval is found automatically as one complete
%  low -> high -> low sinus cycle after tSearchStart.
%% ============================================================

clc;
clear;
close all;

%% ===================== USER SETTINGS =====================

tests = struct([]);

tests(1).fileName     = 'MainHardClassic2.csv';
tests(1).title        = 'Main hard position - classical feedforward';
tests(1).cylinder     = 'Main';
tests(1).tSearchStart = 20;     % [s] skip startup/transient

tests(2).fileName     = 'JibHardClassic2.csv';
tests(2).title        = 'Jib hard position - classical feedforward';
tests(2).cylinder     = 'Jib';
tests(2).tSearchStart = 20;     % [s] skip startup/transient

% Set true if figures should be saved as PNG files.
saveFigures = false;

% Line width for plots.
lw = 1.6;

% Saturation limit for control signal.
uSatLimit = 0.98;

%% ===================== SCRIPT FOLDER =====================

scriptDir = fileparts(mfilename('fullpath'));

if isempty(scriptDir)
    scriptDir = pwd;
end

%% ===================== RUN ANALYSIS =====================

summaryRows = [];

for k = 1:numel(tests)

    fprintf('\n============================================================\n');
    fprintf('Reading test %d of %d:\n', k, numel(tests));
    fprintf('%s\n', tests(k).title);
    fprintf('============================================================\n');

    csvFile = findCsvFile(scriptDir, tests(k).fileName);

    D = readTwinCATScopeCsv(csvFile);

    S = extractSingleAxisSignals(D, tests(k).cylinder);

    %% ===================== SELECT ONE STABLE SINUS CYCLE =====================

    [idxStart, idxPeak, idxStop] = findOneReferenceCycleLowHighLow( ...
        S.t, S.xRef, tests(k).tSearchStart);

    idx = idxStart:idxStop;

    tPlot = S.t(idx) - S.t(idxStart);

    fprintf('\nSelected stable sinus cycle:\n');
    fprintf('  Original time interval: %.3f s to %.3f s\n', S.t(idxStart), S.t(idxStop));
    fprintf('  Cycle duration:         %.3f s\n', S.t(idxStop) - S.t(idxStart));
    fprintf('  Peak occurs at:         %.3f s original time\n', S.t(idxPeak));

    %% ===================== METRICS =====================

    metrics = calculateMetrics(S, idx, uSatLimit);

    printMetrics(tests(k).title, tests(k).cylinder, metrics);

    summaryRows = [summaryRows; createSummaryRow(tests(k), metrics)]; %#ok<AGROW>

    %% ===================== POSITION PLOT =====================

    figure('Name', [tests(k).title ' - one stable sinus cycle - position'], 'Color', 'w');

    plot(tPlot, S.xRef(idx),  '',  'LineWidth', lw); hold on;
    plot(tPlot, S.xReal(idx), '', 'LineWidth', lw);

    grid on;
    xlabel('Time [s]');
    ylabel('Position [mm]');
    title([tests(k).title ' - position tracking']);

    legend('$x_{ref}$', '$x_{real}$', ...
        'Interpreter', 'latex', ...
        'Location', 'best');

    set(gca, 'FontSize', 12);
    ylim ([150, 450])

    if saveFigures
        saveas(gcf, fullfile(scriptDir, ...
            [matlab.lang.makeValidName(tests(k).title) '_OneStableSinus_Position.png']));
   
    end

    %% ===================== CONTROL SIGNAL PLOT =====================

    figure('Name', [tests(k).title ' - one stable sinus cycle - control'], 'Color', 'w');

    plot(tPlot, S.uTotal(idx), '',  'LineWidth', lw); hold on;
    plot(tPlot, S.uFF(idx),    '', 'LineWidth', lw);
    plot(tPlot, S.uPID(idx),   '',  'LineWidth', lw + 0.2);


    grid on;
    xlabel('Time [s]');
    ylabel('Control signal [-]');
    title([tests(k).title ' - control signal']);

    legend('$U_{total}$', '$U_{FF}$', '$U_{PID}$', ...
        'Interpreter', 'latex', ...
        'Location', 'best');

    set(gca, 'FontSize', 12);
    ylim([-1.1, 1.1]);

    if saveFigures
        saveas(gcf, fullfile(scriptDir, ...
            [matlab.lang.makeValidName(tests(k).title) '_OneStableSinus_Control.png']));
    end

end

%% ===================== COMPACT SUMMARY TABLE =====================

summaryTable = struct2table(summaryRows);

fprintf('\n============================================================\n');
fprintf('COMPACT SUMMARY: ONE STABLE SINUS CYCLE\n');
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
        fullfile(scriptDir, 'Tests', 'Classic', csvFileName)
        fullfile(scriptDir, '..', 'Tests', csvFileName)
        fullfile(scriptDir, '..', 'Tests', 'Hard', csvFileName)
        fullfile(scriptDir, '..', 'Tests', 'Classic', csvFileName)
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

function S = extractSingleAxisSignals(D, cylinder)
    % Extracts the required signals from a single-axis test.
    %
    % Expected signal names:
    %   fXRef_mm
    %   fXReal_mm
    %   fU_FF
    %   fU_PID
    %
    % If fU_total is not available:
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

    S.cylinder = cylinder;
    S.t        = D.time_s;
    S.xRef     = D.fXRef_mm;
    S.xReal    = D.fXReal_mm;
    S.uFF      = D.fU_FF;
    S.uPID     = D.fU_PID;

    if ismember('fU_total', D.Properties.VariableNames)
        S.uTotal = D.fU_total;
    elseif ismember('fU_Total', D.Properties.VariableNames)
        S.uTotal = D.fU_Total;
    else
        S.uTotal = S.uFF + S.uPID;
    end

    if ismember('fError_mm', D.Properties.VariableNames)
        S.errorLogged = D.fError_mm;
    else
        S.errorLogged = S.xRef - S.xReal;
    end

    if ismember('fXDotRef', D.Properties.VariableNames)
        S.xDotRef = D.fXDotRef;
    else
        S.xDotRef = nan(size(S.t));
    end
end

function [idxStart, idxPeak, idxStop] = findOneReferenceCycleLowHighLow(t, xRef, tSearchStart)
    % Finds one complete reference cycle of the type:
    %
    %     low -> high -> low
    %
    % after tSearchStart.
    %
    % This is useful for selecting one stable sinus period after startup.

    t = t(:);
    xRef = xRef(:);

    valid = isfinite(t) & isfinite(xRef) & t >= tSearchStart;
    idxValidOriginal = find(valid);

    if numel(idxValidOriginal) < 10
        error('Not enough valid reference data after tSearchStart = %.2f s.', tSearchStart);
    end

    xSeg = xRef(idxValidOriginal);

    % Remove initialization zeros if the reference range is much higher.
    xMaxInitial = max(xSeg);

    if xMaxInitial > 50
        keep = xSeg > 0.25*xMaxInitial;

        if sum(keep) > 10
            idxValidOriginal = idxValidOriginal(keep);
            xSeg = xRef(idxValidOriginal);
        end
    end

    xMin = min(xSeg);
    xMax = max(xSeg);
    xRange = xMax - xMin;

    if xRange <= 0
        error('Reference signal has no usable variation after tSearchStart = %.2f s.', tSearchStart);
    end

    lowLeaveLevel = xMin + 0.025*xRange;
    lowNearLevel  = xMin + 0.005*xRange;
    highLevel     = xMax - 0.025*xRange;

    % Find first point where reference leaves the lower turning point.
    upCrossLocal = find( ...
        xSeg(1:end-1) <= lowLeaveLevel & ...
        xSeg(2:end)   >  lowLeaveLevel, ...
        1, 'first') + 1;

    if isempty(upCrossLocal)
        error('Could not find where the reference leaves the lower turning point after %.2f s.', tSearchStart);
    end

    % Backtrack to a point close to the lower turning point.
    lowBefore = find(xSeg(1:upCrossLocal) <= lowNearLevel, 1, 'last');

    if isempty(lowBefore)
        lowBefore = upCrossLocal;
    end

    idxStart = idxValidOriginal(lowBefore);

    % Find upper part of the same cycle.
    highAfterStartLocal = find(xSeg(upCrossLocal:end) >= highLevel, 1, 'first') + upCrossLocal - 1;

    if isempty(highAfterStartLocal)
        error('Could not find the upper part of the selected reference cycle.');
    end

    % Find return to lower turning point.
    lowAfterHighLocal = find(xSeg(highAfterStartLocal:end) <= lowNearLevel, 1, 'first') + highAfterStartLocal - 1;

    if isempty(lowAfterHighLocal)
        lowAfterHighLocal = find(xSeg(highAfterStartLocal:end) <= lowLeaveLevel, 1, 'first') + highAfterStartLocal - 1;
    end

    if isempty(lowAfterHighLocal)
        error('Could not find where the selected reference cycle returns to the lower turning point.');
    end

    idxStop = idxValidOriginal(lowAfterHighLocal);

    intervalOriginal = idxStart:idxStop;
    [~, peakLocal] = max(xRef(intervalOriginal));
    idxPeak = intervalOriginal(peakLocal);
end

function metrics = calculateMetrics(S, idx, uSatLimit)
    % Calculates position tracking and control contribution metrics.

    e = S.xRef(idx) - S.xReal(idx);

    metrics.meanAbsError_mm = mean(abs(e), 'omitnan');
    metrics.rmse_mm         = sqrt(mean(e.^2, 'omitnan'));
    metrics.maxAbsError_mm  = max(abs(e));

    metrics.meanAbsUtotal = mean(abs(S.uTotal(idx)), 'omitnan');
    metrics.maxAbsUtotal  = max(abs(S.uTotal(idx)));

    metrics.meanAbsUFF  = mean(abs(S.uFF(idx)), 'omitnan');
    metrics.meanAbsUPID = mean(abs(S.uPID(idx)), 'omitnan');

    denom = metrics.meanAbsUFF + metrics.meanAbsUPID;

    if denom > 0
        metrics.ffContributionPct  = 100*metrics.meanAbsUFF/denom;
        metrics.pidContributionPct = 100*metrics.meanAbsUPID/denom;
    else
        metrics.ffContributionPct  = NaN;
        metrics.pidContributionPct = NaN;
    end

    metrics.saturationPct = 100*mean(abs(S.uTotal(idx)) >= uSatLimit, 'omitnan');
end

function printMetrics(testTitle, cylinder, metrics)
    % Prints metrics to the command window.

    fprintf('\n%s\n', testTitle);
    fprintf('%s cylinder:\n', cylinder);
    fprintf('  Mean absolute position error: %.3f mm\n', metrics.meanAbsError_mm);
    fprintf('  RMSE:                         %.3f mm\n', metrics.rmse_mm);
    fprintf('  Max absolute position error:  %.3f mm\n', metrics.maxAbsError_mm);
    fprintf('  Mean absolute U_total:         %.3f\n', metrics.meanAbsUtotal);
    fprintf('  Max absolute U_total:          %.3f\n', metrics.maxAbsUtotal);
    fprintf('  Samples near saturation:       %.2f %%\n', metrics.saturationPct);
    fprintf('  Feedforward contribution:      %.2f %%\n', metrics.ffContributionPct);
    fprintf('  Feedback/PID contribution:     %.2f %%\n', metrics.pidContributionPct);
end

function row = createSummaryRow(test, metrics)
    % Creates one row for the final compact summary table.

    row = struct();

    row.TestName = string(test.title);
    row.Cylinder = string(test.cylinder);

    row.MeanAbsError_mm = metrics.meanAbsError_mm;
    row.RMSE_mm = metrics.rmse_mm;
    row.MaxAbsError_mm = metrics.maxAbsError_mm;

    row.MeanAbsUtotal = metrics.meanAbsUtotal;
    row.MaxAbsUtotal = metrics.maxAbsUtotal;
    row.SaturationPct = metrics.saturationPct;

    row.MeanAbsUFF = metrics.meanAbsUFF;
    row.MeanAbsUPID = metrics.meanAbsUPID;

    row.MeanFFContributionPct = metrics.ffContributionPct;
    row.MeanPIDContributionPct = metrics.pidContributionPct;
end