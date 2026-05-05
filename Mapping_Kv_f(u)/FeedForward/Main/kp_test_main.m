%% compare_main_pid_tests.m
% Compares Main cylinder PID/feedforward tests for different Kp values.
% Expected TwinCAT Scope signals:
% fXRef, fPistonPosition, fFF, fU, fXDotRef, fError, fPID

clc; clear; close all;

%% ===================== USER SETTINGS =====================
% Put this script in the same folder as the CSV files, or use full paths.
baseFolder = pwd;

% Main files: edit file names here if needed.
tests = struct([]);
tests(1).label = 'Main Kp = 10'; tests(1).Kp = 10; tests(1).file = fullfile(baseFolder, 'P10.csv');
tests(2).label = 'Main Kp = 15'; tests(2).Kp = 15; tests(2).file = fullfile(baseFolder, 'P15.csv');
tests(3).label = 'Main Kp = 20'; tests(3).Kp = 20; tests(3).file = fullfile(baseFolder, 'P20.csv');

% Use last N seconds for numerical comparison. For f = 0.05 Hz, 20 s = one full sine period.
analysisWindow_s = 20;

% Defines when the test is considered active. This removes the initial zero-output delay.
activeVelocityThreshold = 1e-4;   % [m/s]
activeSignalThreshold   = 1e-4;   % [-]

% Save figures as PNG files.
saveFigures = true;
outputFolder = fullfile(baseFolder, 'Main_PID_Comparison_Figures');

%% ===================== RUN ANALYSIS =====================
results = analyzePidTests(tests, analysisWindow_s, activeVelocityThreshold, activeSignalThreshold, outputFolder, saveFigures, 'Main');

disp(' ');
disp('===================== MAIN RESULTS, LAST WINDOW =====================');
disp(results.summaryTable);

%% ===================== LOCAL FUNCTIONS =====================
function results = analyzePidTests(tests, analysisWindow_s, velThr, sigThr, outputFolder, saveFigures, systemName)
    if saveFigures && ~exist(outputFolder, 'dir')
        mkdir(outputFolder);
    end

    n = numel(tests);
    data = cell(n,1);

    meanErr_mm    = zeros(n,1);
    meanAbsErr_mm = zeros(n,1);
    rmsErr_mm     = zeros(n,1);
    maxAbsErr_mm  = zeros(n,1);
    ffShare_pct   = zeros(n,1);
    fbShare_pct   = zeros(n,1);
    pidMax_pct    = zeros(n,1);
    uMax_pct      = zeros(n,1);
    kpEstimated   = zeros(n,1);

    for i = 1:n
        if ~isfile(tests(i).file)
            error('File not found: %s', tests(i).file);
        end

        T = readTwinCatScopeCsv(tests(i).file);

        % Find active part of the test.
        activeIdx = abs(T.fXDotRef) > velThr | abs(T.fFF) > sigThr | abs(T.fU) > sigThr;
        if any(activeIdx)
            tActiveStart = T.time_s(find(activeIdx, 1, 'first'));
            tActiveEnd   = T.time_s(find(activeIdx, 1, 'last'));
        else
            tActiveStart = T.time_s(1);
            tActiveEnd   = T.time_s(end);
        end

        T.t_rel_s = T.time_s - tActiveStart;

        % Last analysis window, measured from the end of active operation.
        idxWindow = T.time_s >= (tActiveEnd - analysisWindow_s) & T.time_s <= tActiveEnd;

        % Error definition: positive error means reference is above measured position.
        err_m  = T.fXRef - T.fPistonPosition;
        err_mm = 1000 * err_m;

        % Use the logged error if it exists, but recompute for consistency.
        T.fError_calc = err_m;
        T.fError_mm   = err_mm;

        ffAbs  = abs(T.fFF(idxWindow));
        pidAbs = abs(T.fPID(idxWindow));
        denom  = sum(ffAbs) + sum(pidAbs);

        if denom > 0
            ffShare_pct(i) = 100 * sum(ffAbs)  / denom;
            fbShare_pct(i) = 100 * sum(pidAbs) / denom;
        else
            ffShare_pct(i) = NaN;
            fbShare_pct(i) = NaN;
        end

        meanErr_mm(i)    = mean(err_mm(idxWindow), 'omitnan');
        meanAbsErr_mm(i) = mean(abs(err_mm(idxWindow)), 'omitnan');
        rmsErr_mm(i)     = sqrt(mean(err_mm(idxWindow).^2, 'omitnan'));
        maxAbsErr_mm(i)  = max(abs(err_mm(idxWindow)), [], 'omitnan');
        pidMax_pct(i)    = 100 * max(abs(T.fPID(idxWindow)), [], 'omitnan');
        uMax_pct(i)      = 100 * max(abs(T.fU(idxWindow)), [], 'omitnan');

        % Estimate Kp from fPID/fError where error is large enough to avoid division noise.
        idxKp = idxWindow & abs(T.fError_calc) > 1e-5 & abs(T.fPID) > 1e-6;
        if any(idxKp)
            kpEstimated(i) = median(T.fPID(idxKp) ./ T.fError_calc(idxKp), 'omitnan');
        else
            kpEstimated(i) = NaN;
        end

        data{i} = T;
    end

    summaryTable = table(...
    string({tests.label})', [tests.Kp]', kpEstimated, ...
    meanErr_mm, meanAbsErr_mm, rmsErr_mm, maxAbsErr_mm, ...
    ffShare_pct, fbShare_pct, pidMax_pct, uMax_pct, ...
    'VariableNames', {'Test','Kp_Set','Kp_Estimated','MeanError_mm','MeanAbsError_mm','RMSError_mm','MaxAbsError_mm','FFShare_pct','FBShare_pct','MaxPID_pct','MaxU_pct'});

    %% Figure 1: Position reference vs measured position
    fig1 = figure('Name', [systemName ' - Position Tracking']);
    tiledlayout(n,1, 'TileSpacing','compact');
    for i = 1:n
        T = data{i};
        nexttile;
        plot(T.t_rel_s, T.fXRef, 'LineWidth', 1.3); hold on;
        plot(T.t_rel_s, T.fPistonPosition, '--', 'LineWidth', 1.3);
        grid on;
        ylabel('Position [m]');
        title(tests(i).label);
        legend('x_{ref}', 'x_{measured}', 'Location','best');
        if i == n
            xlabel('Time after active start [s]');
        end
    end

    %% Figure 2: Position error comparison  
    fig2 = figure('Name', [systemName ' - Position Error']);
    hold on; grid on;
    for i = 1:n
        T = data{i};
        plot(T.t_rel_s, T.fError_mm, 'LineWidth', 1.2);
    end
    yline(0, 'k--');
    xlabel('Time after active start [s]');
    ylabel('Error x_{ref} - x [mm]');
    title([systemName ' position error comparison']);
    legend({tests.label}, 'Location','best');

    %% Figure 3: FF/FB contribution share
    fig3 = figure('Name', [systemName ' - FF FB Share']);
    bar(categorical({tests.label}), [ffShare_pct fbShare_pct], 'stacked');
    grid on;
    ylabel('Contribution share [%]');
    title([systemName ' feedforward / feedback contribution, last ' num2str(analysisWindow_s) ' s']);
    legend('Feedforward |fFF|', 'Feedback |fPID|', 'Location','best');

    %% Figure 4: Error metrics
    fig4 = figure('Name', [systemName ' - Error Metrics']);
    bar(categorical({tests.label}), [meanAbsErr_mm rmsErr_mm maxAbsErr_mm]);
    grid on;
    ylabel('Error [mm]');
    title([systemName ' error metrics, last ' num2str(analysisWindow_s) ' s']);
    legend('Mean abs. error', 'RMS error', 'Max abs. error', 'Location','best');

    %% Figure 5: FF, PID and total signal
    fig5 = figure('Name', [systemName ' - Control Signals']);
    tiledlayout(n,1, 'TileSpacing','compact');
    for i = 1:n
        T = data{i};
        nexttile;
        plot(T.t_rel_s, T.fFF, 'LineWidth', 1.1); hold on;
        plot(T.t_rel_s, T.fPID, 'LineWidth', 1.1);
        plot(T.t_rel_s, T.fU, '--', 'LineWidth', 1.1);
        grid on;
        ylabel('Signal [-]');
        title(tests(i).label);
        legend('fFF', 'fPID', 'fU', 'Location','best');
        if i == n
            xlabel('Time after active start [s]');
        end
    end

    if saveFigures
        saveas(fig1, fullfile(outputFolder, [systemName '_position_tracking.png']));
        saveas(fig2, fullfile(outputFolder, [systemName '_position_error.png']));
        saveas(fig3, fullfile(outputFolder, [systemName '_ff_fb_share.png']));
        saveas(fig4, fullfile(outputFolder, [systemName '_error_metrics.png']));
        saveas(fig5, fullfile(outputFolder, [systemName '_control_signals.png']));
    end

    results.summaryTable = summaryTable;
    results.data = data;
end

function T = readTwinCatScopeCsv(filePath)
    % Reads TwinCAT Scope CSV exports with repeated Name/value column pairs.
    rawLines = readlines(filePath);

    headerIdx = find(contains(rawLines, 'fXRef') & contains(rawLines, 'fPistonPosition'), 1, 'first');
    if isempty(headerIdx)
        error('Could not find signal header in file: %s', filePath);
    end

    lines = rawLines(headerIdx+1:end);
    lines = strtrim(lines);
    lines = lines(lines ~= "");

    % Keep only numeric data lines.
    isNumericLine = ~cellfun(@isempty, regexp(cellstr(lines), '^[-+]?[0-9]', 'once'));
    lines = lines(isNumericLine);

    M = nan(numel(lines), 14);
    for r = 1:numel(lines)
        parts = split(lines(r), ';');
        parts = erase(parts, '"');
        parts = replace(parts, ',', '.');
        vals = str2double(parts);
        nVals = min(numel(vals), 14);
        M(r,1:nVals) = vals(1:nVals);
    end

    % TwinCAT exports each signal as time/value pairs:
    % col 1/2: fXRef time/value, 3/4: fPistonPosition, 5/6: fFF,
    % 7/8: fU, 9/10: fXDotRef, 11/12: fError, 13/14: fPID.
    T = table;
    T.time_s          = M(:,1) / 1000;   % Scope time is normally in ms.
    T.fXRef           = M(:,2);
    T.fPistonPosition = M(:,4);
    T.fFF             = M(:,6);
    T.fU              = M(:,8);
    T.fXDotRef        = M(:,10);
    T.fError_logged   = M(:,12);
    T.fPID            = M(:,14);
end
