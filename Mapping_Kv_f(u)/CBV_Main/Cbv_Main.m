%% ========================================================================
%  MAIN CBV IDENTIFICATION - CRACK PRESSURE AND OPENING RANGE
%
%  This script identifies effective CBV parameters for the main cylinder:
%
%       pCr_Main
%       dpOpen_Main
%
%  The opening pressure is calculated as:
%
%       p_open = pB - pA
%
%  where:
%
%       pA = fPres2A_bar
%       pB = fPres2B_bar
%
%  The script uses:
%
%       Crack1.csv, Crack2.csv, Crack3.csv
%       to estimate pCr_Main
%
%  and:
%
%       pOpen-40.csv, pOpen-70.csv, pOpen-90.csv
%       to estimate dpOpen_Main
%
% ========================================================================

clc;
clear;
close all;

%% ===================== USER SETTINGS =====================

% Folder containing all CBV test CSV files.
folderPath = 'C:\Users\hakon\OneDrive - Universitetet i Agder\Skrivebord\BACHELOR_PROSJEKT\Bachelor-Oppgave---Elektrisk-Kompansering\Mapping_Kv_f(u)\CBV_Main';

% Crack pressure test files.
crackFiles = {
    'Crack1.csv'
    'Crack2.csv'
    'Crack3.csv'
};

% Labels for crack pressure tests.
crackLabels = {
    'Crack 1'
    'Crack 2'
    'Crack 3'
};

% Opening range test files.
pOpenFiles = {
    'pOpen-40.csv'
    'pOpen-70.csv'
    'pOpen-90.csv'
};

% Labels for opening range tests.
pOpenLabels = {
    'pOpen 40%'
    'pOpen 70%'
    'pOpen 90%'
};

% Nominal PDCV openings for opening range tests.
uNominal_percent = [40; 70; 90];

% Main down means the measured cylinder position decreases.
motionDirection = "decreasing";

% Motion threshold used to define clear start of cylinder motion.
% This should be stated in the report.
motionThreshold_mm = 0.5;

% Position smoothing before differentiating.
smoothWindow = 25;

% Short time window around motion start for crack pressure estimate.
% Keep this short because p_open rises during ramp-up.
pCrWindowBefore_s = 0.03;
pCrWindowAfter_s  = 0.05;

% Manually selected steady-state windows for pOpen tests.
% Adjust these if the marked intervals do not lie on the flat parts.
steadyWindows = [
    8.0   18.0;    % pOpen-40
    8.0   12.5;    % pOpen-70
    8.0    11    % pOpen-90
];

% Show optional full time-series control figure.
showTimeSeriesFigure = true;

% Save figures as PNG?
saveFigures = false;

% Figure save folder.
figureFolder = fullfile(folderPath, 'CBV_Main_Final_Figures');

%% ===================== CHECK FILES =====================

% Check that all crack files exist.
for k = 1:numel(crackFiles)

    filePath = fullfile(folderPath, crackFiles{k});

    if ~isfile(filePath)
        error('File not found: %s', filePath);
    end

end

% Check that all pOpen files exist.
for k = 1:numel(pOpenFiles)

    filePath = fullfile(folderPath, pOpenFiles{k});

    if ~isfile(filePath)
        error('File not found: %s', filePath);
    end

end

% Create figure folder if needed.
if saveFigures && ~exist(figureFolder, 'dir')
    mkdir(figureFolder);
end

%% ========================================================================
%  PART 1: CRACK PRESSURE IDENTIFICATION
% ========================================================================

% Number of crack tests.
nCrack = numel(crackFiles);

% Preallocate arrays for crack test results.
pCr_est_bar = nan(nCrack, 1);
tMotion_crack_s = nan(nCrack, 1);
uMotion_crack_percent = nan(nCrack, 1);
pA_motion_bar = nan(nCrack, 1);
pB_motion_bar = nan(nCrack, 1);
xMotion_mm = nan(nCrack, 1);

% Store processed crack data for plotting.
crackData = cell(nCrack, 1);

for i = 1:nCrack

    %% ---------- Read crack test ----------

    % Build full file path.
    filePath = fullfile(folderPath, crackFiles{i});

    % Read TwinCAT Scope CSV.
    T = readTwinCatScopeCsv(filePath);

    %% ---------- Extract signals ----------

    % Extract time in seconds.
    t = T.time_s;

    % Extract pressures in bar.
    pA = T.fPres2A_bar;
    pB = T.fPres2B_bar;

    % Extract main cylinder position in millimetres.
    x = T.fCylinder2_mm;

    % Extract valve reference voltage.
    uValve_V = T.fValve2_V;

    %% ---------- Remove invalid rows ----------

    % Keep only rows where key signals are finite.
    validRows = isfinite(t) & isfinite(pA) & isfinite(pB) & ...
                isfinite(x) & isfinite(uValve_V);

    % Apply valid row filter.
    t = t(validRows);
    pA = pA(validRows);
    pB = pB(validRows);
    x = x(validRows);
    uValve_V = uValve_V(validRows);

    % Remove duplicate time samples.
    [t, uniqueIdx] = unique(t, 'stable');

    % Apply unique time filter to all signals.
    pA = pA(uniqueIdx);
    pB = pB(uniqueIdx);
    x = x(uniqueIdx);
    uValve_V = uValve_V(uniqueIdx);

    %% ---------- Calculate derived signals ----------

    % Convert valve voltage to opening percent.
    % Convention: 5 V = 0%, 0 V = 100%.
    uValve_percent = (5 - uValve_V) / 5 * 100;

    % Calculate main CBV opening pressure.
    pOpen = pB - pA;

    % Smooth position before motion detection.
    xFilt = smoothdata(x, 'movmean', smoothWindow);

    % Calculate velocity for plotting/checking.
    v = gradient(xFilt, t);

    %% ---------- Detect start of motion ----------

    % Initial filtered position.
    x0 = xFilt(1);

    if motionDirection == "decreasing"

        % Main down: position decreases.
        motionIdx = find((x0 - xFilt) >= motionThreshold_mm, 1, 'first');

    elseif motionDirection == "increasing"

        % Increasing motion alternative.
        motionIdx = find((xFilt - x0) >= motionThreshold_mm, 1, 'first');

    else

        % Stop if direction setting is invalid.
        error('motionDirection must be "decreasing" or "increasing".');

    end

    % Stop if no movement is detected.
    if isempty(motionIdx)
        error('No clear motion detected in file: %s', crackFiles{i});
    end

    % Store motion start time.
    tMotion_crack_s(i) = t(motionIdx);

    % Store opening percentage at motion start.
    uMotion_crack_percent(i) = uValve_percent(motionIdx);

    % Store pressures at closest motion sample.
    pA_motion_bar(i) = pA(motionIdx);
    pB_motion_bar(i) = pB(motionIdx);

    % Store position at motion start.
    xMotion_mm(i) = xFilt(motionIdx);

    %% ---------- Estimate crack pressure ----------

    % Select short window around detected motion start.
    pCrIdx = t >= (tMotion_crack_s(i) - pCrWindowBefore_s) & ...
             t <= (tMotion_crack_s(i) + pCrWindowAfter_s);

    % Use median pOpen in short window if possible.
    if any(pCrIdx)

        pCr_est_bar(i) = median(pOpen(pCrIdx), 'omitnan');

    else

        pCr_est_bar(i) = pOpen(motionIdx);

    end

    %% ---------- Store crack data ----------

    crackData{i}.label = crackLabels{i};
    crackData{i}.t = t;
    crackData{i}.pA = pA;
    crackData{i}.pB = pB;
    crackData{i}.pOpen = pOpen;
    crackData{i}.x = x;
    crackData{i}.xFilt = xFilt;
    crackData{i}.v = v;
    crackData{i}.uValve_percent = uValve_percent;
    crackData{i}.motionIdx = motionIdx;
    crackData{i}.tMotion = tMotion_crack_s(i);
    crackData{i}.pCrEstimate = pCr_est_bar(i);

end

%% ---------- Final crack pressure value ----------

% Calculate mean crack pressure.
pCr_mean_bar = mean(pCr_est_bar, 'omitnan');

% Calculate median crack pressure as a robustness check.
pCr_median_bar = median(pCr_est_bar, 'omitnan');

% Use mean as final value because the three tests should be repetitions.
pCr_Main_bar = pCr_mean_bar;

% Convert crack pressure to Pascal.
pCr_Main_Pa = pCr_Main_bar * 1e5;

%% ========================================================================
%  PART 2: OPENING RANGE IDENTIFICATION
% ========================================================================

% Number of pOpen tests.
nPOpen = numel(pOpenFiles);

% Preallocate arrays.
pOpenStable_bar = nan(nPOpen, 1);
pAStable_bar = nan(nPOpen, 1);
pBStable_bar = nan(nPOpen, 1);
vStable_mmps = nan(nPOpen, 1);
steadyStart_s = nan(nPOpen, 1);
steadyEnd_s = nan(nPOpen, 1);

% Also calculate "crack pressure" from pOpen tests for curiosity.
pCr_from_pOpenTests_bar = nan(nPOpen, 1);
tMotion_pOpen_s = nan(nPOpen, 1);
uMotion_pOpen_percent = nan(nPOpen, 1);

% Store processed pOpen data.
pOpenData = cell(nPOpen, 1);

for i = 1:nPOpen

    %% ---------- Read pOpen test ----------

    % Build full file path.
    filePath = fullfile(folderPath, pOpenFiles{i});

    % Read TwinCAT CSV.
    T = readTwinCatScopeCsv(filePath);

    %% ---------- Extract signals ----------

    % Extract time.
    t = T.time_s;

    % Extract pressures.
    pA = T.fPres2A_bar;
    pB = T.fPres2B_bar;

    % Extract position.
    x = T.fCylinder2_mm;

    % Extract valve voltage.
    uValve_V = T.fValve2_V;

    %% ---------- Remove invalid rows ----------

    % Keep rows with finite key signals.
    validRows = isfinite(t) & isfinite(pA) & isfinite(pB) & ...
                isfinite(x) & isfinite(uValve_V);

    % Apply row filter.
    t = t(validRows);
    pA = pA(validRows);
    pB = pB(validRows);
    x = x(validRows);
    uValve_V = uValve_V(validRows);

    % Remove duplicate time values.
    [t, uniqueIdx] = unique(t, 'stable');

    % Apply unique filter.
    pA = pA(uniqueIdx);
    pB = pB(uniqueIdx);
    x = x(uniqueIdx);
    uValve_V = uValve_V(uniqueIdx);

    %% ---------- Calculate derived signals ----------

    % Convert valve voltage to opening percent.
    uValve_percent = (5 - uValve_V) / 5 * 100;

    % Calculate opening pressure.
    pOpen = pB - pA;

    % Smooth position.
    xFilt = smoothdata(x, 'movmean', smoothWindow);

    % Calculate velocity.
    v = gradient(xFilt, t);

    %% ---------- Calculate crack pressure from pOpen tests for curiosity ----------

    % Initial filtered position.
    x0 = xFilt(1);

    if motionDirection == "decreasing"

        % Detect motion for decreasing position.
        motionIdx = find((x0 - xFilt) >= motionThreshold_mm, 1, 'first');

    else

        % Detect motion for increasing position.
        motionIdx = find((xFilt - x0) >= motionThreshold_mm, 1, 'first');

    end

    % Store curious crack estimate if motion is detected.
    if ~isempty(motionIdx)

        % Store motion time.
        tMotion_pOpen_s(i) = t(motionIdx);

        % Store opening percent at motion start.
        uMotion_pOpen_percent(i) = uValve_percent(motionIdx);

        % Use short window around motion start.
        pCrIdx = t >= (tMotion_pOpen_s(i) - pCrWindowBefore_s) & ...
                 t <= (tMotion_pOpen_s(i) + pCrWindowAfter_s);

        % Estimate pCr from this pOpen test.
        if any(pCrIdx)
            pCr_from_pOpenTests_bar(i) = median(pOpen(pCrIdx), 'omitnan');
        else
            pCr_from_pOpenTests_bar(i) = pOpen(motionIdx);
        end

    end

    %% ---------- Select steady-state interval ----------

    % Get steady-state window from settings.
    tSteadyStart = steadyWindows(i, 1);
    tSteadyEnd   = steadyWindows(i, 2);

    % Create index for selected steady-state interval.
    steadyIdx = t >= tSteadyStart & t <= tSteadyEnd;

    % Stop if the selected interval contains no data.
    if ~any(steadyIdx)
        error('Steady-state window contains no data for file: %s', pOpenFiles{i});
    end

    % Store window times.
    steadyStart_s(i) = tSteadyStart;
    steadyEnd_s(i) = tSteadyEnd;

    %% ---------- Calculate steady-state values ----------

    % Calculate mean opening pressure in steady interval.
    pOpenStable_bar(i) = mean(pOpen(steadyIdx), 'omitnan');

    % Calculate mean A-pressure in steady interval.
    pAStable_bar(i) = mean(pA(steadyIdx), 'omitnan');

    % Calculate mean B-pressure in steady interval.
    pBStable_bar(i) = mean(pB(steadyIdx), 'omitnan');

    % Calculate mean cylinder velocity in steady interval.
    vStable_mmps(i) = mean(v(steadyIdx), 'omitnan');

    %% ---------- Store pOpen data ----------

    pOpenData{i}.label = pOpenLabels{i};
    pOpenData{i}.t = t;
    pOpenData{i}.pA = pA;
    pOpenData{i}.pB = pB;
    pOpenData{i}.pOpen = pOpen;
    pOpenData{i}.x = x;
    pOpenData{i}.xFilt = xFilt;
    pOpenData{i}.v = v;
    pOpenData{i}.uValve_percent = uValve_percent;
    pOpenData{i}.steadyIdx = steadyIdx;
    pOpenData{i}.tSteadyStart = tSteadyStart;
    pOpenData{i}.tSteadyEnd = tSteadyEnd;

end

%% ---------- Final opening range value ----------

% Highest steady-state opening pressure.
pOpenHigh_bar = max(pOpenStable_bar);

% Effective opening range.
dpOpen_Main_bar = pOpenHigh_bar - pCr_Main_bar;

% Convert to Pascal.
dpOpen_Main_Pa = dpOpen_Main_bar * 1e5;

%% ========================================================================
%  PRINT RESULTS
% ========================================================================

% Table for crack tests.
crackResults = table( ...
    crackLabels(:), ...
    tMotion_crack_s, ...
    uMotion_crack_percent, ...
    pA_motion_bar, ...
    pB_motion_bar, ...
    pCr_est_bar, ...
    'VariableNames', { ...
        'Test', ...
        't_motion_start_s', ...
        'u_at_motion_start_percent', ...
        'pA_at_motion_bar', ...
        'pB_at_motion_bar', ...
        'pCr_estimate_bar' ...
    } ...
);

% Table for pOpen tests.
pOpenResults = table( ...
    pOpenLabels(:), ...
    uNominal_percent(:), ...
    steadyStart_s, ...
    steadyEnd_s, ...
    pAStable_bar, ...
    pBStable_bar, ...
    pOpenStable_bar, ...
    vStable_mmps, ...
    pOpenStable_bar - pCr_Main_bar, ...
    tMotion_pOpen_s, ...
    uMotion_pOpen_percent, ...
    pCr_from_pOpenTests_bar, ...
    'VariableNames', { ...
        'Test', ...
        'u_nominal_percent', ...
        'steady_start_s', ...
        'steady_end_s', ...
        'pA_steady_bar', ...
        'pB_steady_bar', ...
        'pOpen_steady_bar', ...
        'v_steady_mmps', ...
        'Delta_p_from_test_bar', ...
        't_motion_start_s_for_fun', ...
        'u_at_motion_start_percent_for_fun', ...
        'pCr_from_pOpen_test_for_fun_bar' ...
    } ...
);

% Display crack results.
disp(' ');
disp('============================================================');
disp('MAIN CBV CRACK PRESSURE RESULTS');
disp('============================================================');
disp(crackResults);

% Display pOpen results.
disp(' ');
disp('============================================================');
disp('MAIN CBV OPENING RANGE RESULTS');
disp('============================================================');
disp(pOpenResults);

% Display final values.
fprintf('\nFinal Main CBV parameters:\n');
fprintf('pCr_Main mean      = %.2f bar\n', pCr_mean_bar);
fprintf('pCr_Main median    = %.2f bar\n', pCr_median_bar);
fprintf('pCr_Main used      = %.2f bar = %.3e Pa\n', pCr_Main_bar, pCr_Main_Pa);
fprintf('pOpen_high used    = %.2f bar\n', pOpenHigh_bar);
fprintf('dpOpen_Main        = %.2f bar = %.3e Pa\n', dpOpen_Main_bar, dpOpen_Main_Pa);

fprintf('\nRounded values I would test first in Simscape:\n');
fprintf('pCr_Main = %.0fe5;        %% [Pa] = %.0f bar\n', round(pCr_Main_bar), round(pCr_Main_bar));
fprintf('dpOpen_Main = %.0fe5;     %% [Pa] = %.0f bar\n', round(dpOpen_Main_bar), round(dpOpen_Main_bar));

fprintf('\nExact copy to Simscape/MATLAB parameter file:\n');
fprintf('pCr_Main = %.6g;        %% [Pa]\n', pCr_Main_Pa);
fprintf('dpOpen_Main = %.6g;     %% [Pa]\n', dpOpen_Main_Pa);

%% ========================================================================
%  FIGURE 1: CRACK PRESSURE IDENTIFICATION
% ========================================================================

figure('Name', 'Figure 1 - Main CBV Crack Pressure Identification');
hold on;
grid on;
box on;

% Plot pOpen for all crack tests.
for i = 1:nCrack

    % Plot pOpen curve.
    plot(crackData{i}.t, crackData{i}.pOpen, ...
        'LineWidth', 1.5);

    % Mark motion start.
    plot(tMotion_crack_s(i), pCr_est_bar(i), 'o', ...
        'MarkerSize', 8, ...
        'LineWidth', 1.7);

end

% Add final mean crack pressure line.
yline(pCr_Main_bar, '--', ...
    sprintf('Mean p_{cr,Main} = %.1f bar', pCr_Main_bar), ...
    'LineWidth', 1.4);

xlabel('Time [s]');
ylabel('Opening pressure, p_{open} = p_B - p_A [bar]');
title('Main CBV Crack Pressure Identification');

legend( ...
    'Crack 1 p_{open}', ...
    'Crack 1 motion start', ...
    'Crack 2 p_{open}', ...
    'Crack 2 motion start', ...
    'Crack 3 p_{open}', ...
    'Crack 3 motion start', ...
    'Mean crack pressure', ...
    'Location', 'best' ...
);

%% ========================================================================
%  FIGURE 2: OPENING RANGE SUMMARY
% ========================================================================

figure('Name', 'Figure 2 - Main CBV Opening Range Identification');
hold on;
grid on;
box on;

% Plot steady-state pOpen for 40, 70, and 90%.
plot(uNominal_percent, pOpenStable_bar, 'o-', ...
    'LineWidth', 1.8, ...
    'MarkerSize', 8);

% Plot crack pressure.
yline(pCr_Main_bar, '--', ...
    sprintf('p_{cr,Main} = %.1f bar', pCr_Main_bar), ...
    'LineWidth', 1.4);

% Plot highest pOpen.
yline(pOpenHigh_bar, ':', ...
    sprintf('p_{open,high} = %.1f bar', pOpenHigh_bar), ...
    'LineWidth', 1.4);

% Add point labels.
for i = 1:nPOpen

    text(uNominal_percent(i), pOpenStable_bar(i) + 2, ...
        sprintf('%.1f bar', pOpenStable_bar(i)), ...
        'HorizontalAlignment', 'center');

end

% Add opening range text.
text(65, (pCr_Main_bar + pOpenHigh_bar)/2, ...
    sprintf('\\Delta p_{open,Main} = %.1f bar', dpOpen_Main_bar), ...
    'FontSize', 11, ...
    'FontWeight', 'bold', ...
    'HorizontalAlignment', 'center');

xlabel('Nominal PDCV opening [%]');
ylabel('Steady-state opening pressure, p_{open} [bar]');
title('Main CBV Opening Range Identification');

xlim([30 100]);
ylim([0 max(pOpenStable_bar) + 15]);

legend( ...
    'Steady-state p_{open}', ...
    'Mean crack pressure', ...
    'Highest steady-state p_{open}', ...
    'Location', 'best' ...
);

%% ========================================================================
%  FIGURE 3: OPTIONAL pOpen TIME SERIES WITH SELECTED INTERVALS
% ========================================================================

if showTimeSeriesFigure

    figure('Name', 'Figure 3 - Main CBV pOpen Time Series');
    hold on;
    grid on;
    box on;

    for i = 1:nPOpen

        % Plot full pOpen signal.
        plot(pOpenData{i}.t, pOpenData{i}.pOpen, ...
            'LineWidth', 1.2);

        % Plot selected steady-state interval with thicker line.
        idx = pOpenData{i}.steadyIdx;

        plot(pOpenData{i}.t(idx), pOpenData{i}.pOpen(idx), ...
            'LineWidth', 3.0);

    end

    % Plot crack pressure.
    yline(pCr_Main_bar, '--', ...
        sprintf('p_{cr,Main} = %.1f bar', pCr_Main_bar), ...
        'LineWidth', 1.4);

    % Plot high pOpen value.
    yline(pOpenHigh_bar, ':', ...
        sprintf('p_{open,high} = %.1f bar', pOpenHigh_bar), ...
        'LineWidth', 1.4);

    xlabel('Time [s]');
    ylabel('Opening pressure, p_{open} = p_B - p_A [bar]');
    title('Main CBV Opening Pressure with Selected Steady-State Intervals');

    legend( ...
        '40% p_{open}', ...
        '40% selected interval', ...
        '70% p_{open}', ...
        '70% selected interval', ...
        '90% p_{open}', ...
        '90% selected interval', ...
        'Mean crack pressure', ...
        'Highest steady-state p_{open}', ...
        'Location', 'best' ...
    );

end

%% ===================== SAVE FIGURES IF ENABLED =====================

if saveFigures

    figs = findall(0, 'Type', 'figure');

    for k = 1:numel(figs)

        figName = get(figs(k), 'Name');

        figName = regexprep(figName, '[^\w\d-]', '_');

        exportgraphics(figs(k), ...
            fullfile(figureFolder, [figName '.png']), ...
            'Resolution', 300);

    end

    fprintf('\nFigures saved to:\n%s\n', figureFolder);

end

%% ========================================================================
%  LOCAL FUNCTION: READ TWINCAT SCOPE CSV
% ========================================================================

function T = readTwinCatScopeCsv(filePath)

    % Check if file exists.
    if ~isfile(filePath)
        error('File not found: %s', filePath);
    end

    % Read all file lines.
    lines = readlines(filePath);

    % Find the signal header line.
    headerLineIdx = find( ...
        contains(lines, 'fPres') | ...
        contains(lines, 'fCylinder') | ...
        contains(lines, 'fValve'), ...
        1, ...
        'first');

    % Stop if no signal header is found.
    if isempty(headerLineIdx)
        error('Could not find signal header in file: %s', filePath);
    end

    % Extract header line.
    headerLine = char(lines(headerLineIdx));

    % Split header by semicolon.
    headerParts = split(string(headerLine), ';');

    % Remove empty header parts.
    headerParts = headerParts(headerParts ~= "");

    % Initialize signal name list.
    signalNames = strings(0);

    % Extract signal names from TwinCAT header format.
    for k = 1:numel(headerParts)

        if headerParts(k) ~= "Name"
            signalNames(end+1, 1) = headerParts(k); %#ok<AGROW>
        end

    end

    % Numeric data starts two lines after signal header.
    dataStartIdx = headerLineIdx + 2;

    % Extract numeric data lines.
    dataLines = lines(dataStartIdx:end);

    % Remove empty lines.
    dataLines = dataLines(strlength(dataLines) > 0);

    % Replace comma decimals with dot decimals.
    dataLines = replace(dataLines, ',', '.');

    % Join numeric lines.
    dataText = join(dataLines, newline);

    % Temporary CSV file for readmatrix.
    tempFile = [tempname '.csv'];

    % Write temporary file.
    writelines(dataText, tempFile);

    % Read numeric matrix.
    M = readmatrix(tempFile, 'Delimiter', ';');

    % Delete temporary file.
    delete(tempFile);

    % Remove columns that are completely NaN.
    M = M(:, ~all(isnan(M), 1));

    % Number of signals.
    nSignals = numel(signalNames);

    % Check expected number of columns.
    if size(M, 2) < 2*nSignals
        error('Unexpected number of columns in file: %s', filePath);
    end

    % Use first time column as common time vector.
    time_ms = M(:, 1);

    % Convert milliseconds to seconds.
    time_s = time_ms / 1000;

    % Create output table.
    T = table();

    % Store time.
    T.time_s = time_s;

    % Extract each value column.
    for s = 1:nSignals

        % TwinCAT format:
        % column 2*s - 1 = time
        % column 2*s     = value
        valueCol = 2*s;

        % Make signal name valid for MATLAB table.
        cleanName = matlab.lang.makeValidName(signalNames(s));

        % Store signal.
        T.(cleanName) = M(:, valueCol);

    end

end