%% ========================================================================
%  JIB NED CBV IDENTIFICATION - P TO B, A-SIDE CBV
%
%  Purpose:
%  Identify effective CBV parameters for Jib ned.
%
%  For Jib ned, the PDCV is assumed to connect:
%
%       P -> B
%       A -> T
%
%  Therefore, the A-side CBV is assumed to be active.
%
%  Opening pressure:
%
%       p_open,Jib,A = alpha*pB + pA_cyl - (alpha + 1)*pA
%
%  where:
%
%       pA     = fPres1A_bar
%       pB     = fPres1B_bar
%       pA_cyl = fPresCyl1A_bar
%
% ========================================================================

clc;
clear;
close all;

%% ===================== USER SETTINGS =====================

% Folder containing the Jib ned CBV test files.
folderPath = 'C:\Users\hakon\OneDrive - Universitetet i Agder\Skrivebord\BACHELOR_PROSJEKT\Bachelor-Oppgave---Elektrisk-Kompansering\Mapping_Kv_f(u)\CBV_JibNed';

% Pilot ratio for the Jib CBV.
alpha = 2.7;

% Crack pressure test files.
crackFiles = {
    'NedCrack1.csv'
    'NedCrack2.csv'
    'NedCrack3.csv'
};

crackLabels = {
    'Jib Ned Crack 1'
    'Jib Ned Crack 2'
    'Jib Ned Crack 3'
};

% Opening range test files.
pOpenFiles = {
    'NedPOPEN-40.csv'
    'NedPOPEN-70.csv'
    'NedPOPEN-90.csv'
};

pOpenLabels = {
    'Jib Ned 40%'
    'Jib Ned 70%'
    'Jib Ned 90%'
};

uNominal_percent = [40; 70; 90];

% Jib ned in these files gives decreasing cylinder position.
motionDirection = "decreasing";

% Motion threshold for detecting start of motion.
motionThreshold_mm = 0.5;

% Position smoothing before velocity calculation.
smoothWindow = 25;

% Short window around motion start for pCr estimate.
pCrWindowBefore_s = 0.03;
pCrWindowAfter_s  = 0.05;

% Manually selected steady-state windows for pOpen tests.
% Adjust these after checking Figure 3.
steadyWindows = [
    4.0   21.0;    % NedPOPEN-40
    4.0   21.0;    % NedPOPEN-70
    4.0   21.0     % NedPOPEN-90
];

% Show optional time-series figure.
showTimeSeriesFigure = true;

% Save figures?
saveFigures = false;

figureFolder = fullfile(folderPath, 'CBV_Jib_Ned_Final_Figures');

%% ===================== CHECK FILES =====================

for k = 1:numel(crackFiles)

    filePath = fullfile(folderPath, crackFiles{k});

    if ~isfile(filePath)
        error('File not found: %s', filePath);
    end

end

for k = 1:numel(pOpenFiles)

    filePath = fullfile(folderPath, pOpenFiles{k});

    if ~isfile(filePath)
        error('File not found: %s', filePath);
    end

end

if saveFigures && ~exist(figureFolder, 'dir')
    mkdir(figureFolder);
end

%% ========================================================================
%  PART 1: CRACK PRESSURE IDENTIFICATION
% ========================================================================

nCrack = numel(crackFiles);

pCr_est_bar = nan(nCrack, 1);
tMotion_crack_s = nan(nCrack, 1);
uMotion_crack_percent = nan(nCrack, 1);

pA_motion_bar = nan(nCrack, 1);
pB_motion_bar = nan(nCrack, 1);
pA_cyl_motion_bar = nan(nCrack, 1);
pB_cyl_motion_bar = nan(nCrack, 1);

crackData = cell(nCrack, 1);

for i = 1:nCrack

    %% ---------- Read crack file ----------

    filePath = fullfile(folderPath, crackFiles{i});

    T = readTwinCatScopeCsv(filePath);

    %% ---------- Extract signals ----------

    t = T.time_s;

    pA = T.fPres1A_bar;
    pB = T.fPres1B_bar;

    pA_cyl = T.fPresCyl1A_bar;
    pB_cyl = T.fPresCyl1B_bar;

    x = T.fCylinder1_mm;

    uValve_V = T.fValve1_V;

    %% ---------- Remove invalid rows ----------

    validRows = isfinite(t) & ...
                isfinite(pA) & ...
                isfinite(pB) & ...
                isfinite(pA_cyl) & ...
                isfinite(pB_cyl) & ...
                isfinite(x) & ...
                isfinite(uValve_V);

    t = t(validRows);
    pA = pA(validRows);
    pB = pB(validRows);
    pA_cyl = pA_cyl(validRows);
    pB_cyl = pB_cyl(validRows);
    x = x(validRows);
    uValve_V = uValve_V(validRows);

    [t, uniqueIdx] = unique(t, 'stable');

    pA = pA(uniqueIdx);
    pB = pB(uniqueIdx);
    pA_cyl = pA_cyl(uniqueIdx);
    pB_cyl = pB_cyl(uniqueIdx);
    x = x(uniqueIdx);
    uValve_V = uValve_V(uniqueIdx);

    %% ---------- Derived signals ----------

    % 5 V = 0%, 0 V = 100%.
    uValve_percent = (5 - uValve_V) / 5 * 100;

    % Jib ned, A-side CBV opening pressure.
    pOpen = alpha .* pB + pA_cyl - (alpha + 1) .* pA;

    % Alternative B-side expression for checking only.
    pOpen_B_side_check = alpha .* pA + pB_cyl - (alpha + 1) .* pB;

    % Smooth position.
    xFilt = smoothdata(x, 'movmean', smoothWindow);

    % Velocity.
    v = gradient(xFilt, t);

    %% ---------- Detect motion start ----------

    x0 = xFilt(1);

    if motionDirection == "decreasing"

        motionIdx = find((x0 - xFilt) >= motionThreshold_mm, 1, 'first');

    elseif motionDirection == "increasing"

        motionIdx = find((xFilt - x0) >= motionThreshold_mm, 1, 'first');

    else

        error('motionDirection must be "decreasing" or "increasing".');

    end

    if isempty(motionIdx)
        error('No clear motion detected in file: %s', crackFiles{i});
    end

    tMotion_crack_s(i) = t(motionIdx);
    uMotion_crack_percent(i) = uValve_percent(motionIdx);

    pA_motion_bar(i) = pA(motionIdx);
    pB_motion_bar(i) = pB(motionIdx);
    pA_cyl_motion_bar(i) = pA_cyl(motionIdx);
    pB_cyl_motion_bar(i) = pB_cyl(motionIdx);

    %% ---------- Estimate crack pressure ----------

    pCrIdx = t >= (tMotion_crack_s(i) - pCrWindowBefore_s) & ...
             t <= (tMotion_crack_s(i) + pCrWindowAfter_s);

    if any(pCrIdx)

        pCr_est_bar(i) = median(pOpen(pCrIdx), 'omitnan');

    else

        pCr_est_bar(i) = pOpen(motionIdx);

    end

    %% ---------- Store data ----------

    crackData{i}.label = crackLabels{i};
    crackData{i}.t = t;
    crackData{i}.pOpen = pOpen;
    crackData{i}.pOpen_B_side_check = pOpen_B_side_check;
    crackData{i}.x = x;
    crackData{i}.xFilt = xFilt;
    crackData{i}.v = v;
    crackData{i}.uValve_percent = uValve_percent;
    crackData{i}.tMotion = tMotion_crack_s(i);
    crackData{i}.pCrEstimate = pCr_est_bar(i);

end

%% ---------- Final crack pressure ----------

pCr_mean_bar = mean(pCr_est_bar, 'omitnan');

pCr_median_bar = median(pCr_est_bar, 'omitnan');

% Use mean because these are repeated crack tests.
pCr_Jib_A_bar = pCr_mean_bar;

pCr_Jib_A_Pa = pCr_Jib_A_bar * 1e5;

%% ========================================================================
%  PART 2: OPENING RANGE IDENTIFICATION
% ========================================================================

nPOpen = numel(pOpenFiles);

pOpenStable_bar = nan(nPOpen, 1);
pAStable_bar = nan(nPOpen, 1);
pBStable_bar = nan(nPOpen, 1);
pA_cylStable_bar = nan(nPOpen, 1);
pB_cylStable_bar = nan(nPOpen, 1);
vStable_mmps = nan(nPOpen, 1);

steadyStart_s = nan(nPOpen, 1);
steadyEnd_s = nan(nPOpen, 1);

% Crack pressure from pOpen tests, only for curiosity/check.
pCr_from_pOpenTests_bar = nan(nPOpen, 1);
tMotion_pOpen_s = nan(nPOpen, 1);
uMotion_pOpen_percent = nan(nPOpen, 1);

pOpenData = cell(nPOpen, 1);

for i = 1:nPOpen

    %% ---------- Read pOpen file ----------

    filePath = fullfile(folderPath, pOpenFiles{i});

    T = readTwinCatScopeCsv(filePath);

    %% ---------- Extract signals ----------

    t = T.time_s;

    pA = T.fPres1A_bar;
    pB = T.fPres1B_bar;

    pA_cyl = T.fPresCyl1A_bar;
    pB_cyl = T.fPresCyl1B_bar;

    x = T.fCylinder1_mm;

    uValve_V = T.fValve1_V;

    %% ---------- Remove invalid rows ----------

    validRows = isfinite(t) & ...
                isfinite(pA) & ...
                isfinite(pB) & ...
                isfinite(pA_cyl) & ...
                isfinite(pB_cyl) & ...
                isfinite(x) & ...
                isfinite(uValve_V);

    t = t(validRows);
    pA = pA(validRows);
    pB = pB(validRows);
    pA_cyl = pA_cyl(validRows);
    pB_cyl = pB_cyl(validRows);
    x = x(validRows);
    uValve_V = uValve_V(validRows);

    [t, uniqueIdx] = unique(t, 'stable');

    pA = pA(uniqueIdx);
    pB = pB(uniqueIdx);
    pA_cyl = pA_cyl(uniqueIdx);
    pB_cyl = pB_cyl(uniqueIdx);
    x = x(uniqueIdx);
    uValve_V = uValve_V(uniqueIdx);

    %% ---------- Derived signals ----------

    uValve_percent = (5 - uValve_V) / 5 * 100;

    % Jib ned, A-side CBV.
    pOpen = alpha .* pB + pA_cyl - (alpha + 1) .* pA;

    % B-side expression only for checking.
    pOpen_B_side_check = alpha .* pA + pB_cyl - (alpha + 1) .* pB;

    xFilt = smoothdata(x, 'movmean', smoothWindow);

    v = gradient(xFilt, t);

    %% ---------- Crack estimate from pOpen tests, for curiosity ----------

    x0 = xFilt(1);

    if motionDirection == "decreasing"

        motionIdx = find((x0 - xFilt) >= motionThreshold_mm, 1, 'first');

    else

        motionIdx = find((xFilt - x0) >= motionThreshold_mm, 1, 'first');

    end

    if ~isempty(motionIdx)

        tMotion_pOpen_s(i) = t(motionIdx);

        uMotion_pOpen_percent(i) = uValve_percent(motionIdx);

        pCrIdx = t >= (tMotion_pOpen_s(i) - pCrWindowBefore_s) & ...
                 t <= (tMotion_pOpen_s(i) + pCrWindowAfter_s);

        if any(pCrIdx)
            pCr_from_pOpenTests_bar(i) = median(pOpen(pCrIdx), 'omitnan');
        else
            pCr_from_pOpenTests_bar(i) = pOpen(motionIdx);
        end

    end

    %% ---------- Select steady-state interval ----------

    tSteadyStart = steadyWindows(i, 1);
    tSteadyEnd = steadyWindows(i, 2);

    steadyIdx = t >= tSteadyStart & t <= tSteadyEnd;

    if ~any(steadyIdx)
        error('Steady-state window contains no data for file: %s', pOpenFiles{i});
    end

    steadyStart_s(i) = tSteadyStart;
    steadyEnd_s(i) = tSteadyEnd;

    %% ---------- Steady-state values ----------

    pOpenStable_bar(i) = mean(pOpen(steadyIdx), 'omitnan');

    pAStable_bar(i) = mean(pA(steadyIdx), 'omitnan');
    pBStable_bar(i) = mean(pB(steadyIdx), 'omitnan');

    pA_cylStable_bar(i) = mean(pA_cyl(steadyIdx), 'omitnan');
    pB_cylStable_bar(i) = mean(pB_cyl(steadyIdx), 'omitnan');

    vStable_mmps(i) = mean(v(steadyIdx), 'omitnan');

    %% ---------- Store data ----------

    pOpenData{i}.label = pOpenLabels{i};
    pOpenData{i}.t = t;
    pOpenData{i}.pOpen = pOpen;
    pOpenData{i}.pOpen_B_side_check = pOpen_B_side_check;
    pOpenData{i}.x = x;
    pOpenData{i}.xFilt = xFilt;
    pOpenData{i}.v = v;
    pOpenData{i}.uValve_percent = uValve_percent;
    pOpenData{i}.steadyIdx = steadyIdx;
    pOpenData{i}.tSteadyStart = tSteadyStart;
    pOpenData{i}.tSteadyEnd = tSteadyEnd;

end

%% ---------- Final opening range ----------

pOpenHigh_bar = max(pOpenStable_bar);

dpOpen_Jib_A_bar = pOpenHigh_bar - pCr_Jib_A_bar;

dpOpen_Jib_A_Pa = dpOpen_Jib_A_bar * 1e5;

%% ========================================================================
%  PRINT RESULTS
% ========================================================================

crackResults = table( ...
    crackLabels(:), ...
    tMotion_crack_s, ...
    uMotion_crack_percent, ...
    pA_motion_bar, ...
    pB_motion_bar, ...
    pA_cyl_motion_bar, ...
    pB_cyl_motion_bar, ...
    pCr_est_bar, ...
    'VariableNames', { ...
        'Test', ...
        't_motion_start_s', ...
        'u_at_motion_start_percent', ...
        'pA_at_motion_bar', ...
        'pB_at_motion_bar', ...
        'pA_cyl_at_motion_bar', ...
        'pB_cyl_at_motion_bar', ...
        'pCr_estimate_bar' ...
    } ...
);

pOpenResults = table( ...
    pOpenLabels(:), ...
    uNominal_percent(:), ...
    steadyStart_s, ...
    steadyEnd_s, ...
    pAStable_bar, ...
    pBStable_bar, ...
    pA_cylStable_bar, ...
    pB_cylStable_bar, ...
    pOpenStable_bar, ...
    vStable_mmps, ...
    pOpenStable_bar - pCr_Jib_A_bar, ...
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
        'pA_cyl_steady_bar', ...
        'pB_cyl_steady_bar', ...
        'pOpen_steady_bar', ...
        'v_steady_mmps', ...
        'Delta_p_from_test_bar', ...
        't_motion_start_s_for_fun', ...
        'u_at_motion_start_percent_for_fun', ...
        'pCr_from_pOpen_test_for_fun_bar' ...
    } ...
);

disp(' ');
disp('============================================================');
disp('JIB NED A-SIDE CBV CRACK PRESSURE RESULTS');
disp('============================================================');
disp(crackResults);

disp(' ');
disp('============================================================');
disp('JIB NED A-SIDE CBV OPENING RANGE RESULTS');
disp('============================================================');
disp(pOpenResults);

fprintf('\nFinal Jib Ned A-side CBV parameters, alpha = %.2f:\n', alpha);
fprintf('pCr_Jib_A mean      = %.2f bar\n', pCr_mean_bar);
fprintf('pCr_Jib_A median    = %.2f bar\n', pCr_median_bar);
fprintf('pCr_Jib_A used      = %.2f bar = %.3e Pa\n', pCr_Jib_A_bar, pCr_Jib_A_Pa);
fprintf('pOpen_high used     = %.2f bar\n', pOpenHigh_bar);
fprintf('dpOpen_Jib_A        = %.2f bar = %.3e Pa\n', dpOpen_Jib_A_bar, dpOpen_Jib_A_Pa);

fprintf('\nRounded values I would test first in Simscape:\n');
fprintf('pCr_Jib_A = %.0fe5;        %% [Pa] = %.0f bar\n', round(pCr_Jib_A_bar), round(pCr_Jib_A_bar));
fprintf('dpOpen_Jib_A = %.0fe5;     %% [Pa] = %.0f bar\n', round(dpOpen_Jib_A_bar), round(dpOpen_Jib_A_bar));

fprintf('\nExact copy to Simscape/MATLAB parameter file:\n');
fprintf('pCr_Jib_A = %.6g;        %% [Pa]\n', pCr_Jib_A_Pa);
fprintf('dpOpen_Jib_A = %.6g;     %% [Pa]\n', dpOpen_Jib_A_Pa);

%% ========================================================================
%  FIGURE 1: CRACK PRESSURE IDENTIFICATION
% ========================================================================

figure('Name', 'Figure 1 - Jib Ned A-side CBV Crack Pressure');
hold on;
grid on;
box on;

for i = 1:nCrack

    plot(crackData{i}.t, crackData{i}.pOpen, ...
        'LineWidth', 1.5);

    plot(tMotion_crack_s(i), pCr_est_bar(i), 'o', ...
        'MarkerSize', 8, ...
        'LineWidth', 1.7);

end

yline(pCr_Jib_A_bar, '--', ...
    sprintf('Mean p_{cr,Jib,A} = %.1f bar', pCr_Jib_A_bar), ...
    'LineWidth', 1.4);

xlabel('Time [s]');
ylabel('Opening pressure, p_{open,Jib,A} [bar]');
title('Jib Ned A-side CBV Crack Pressure Identification');

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
%  FIGURE 2: OPENING RANGE IDENTIFICATION
% ========================================================================

figure('Name', 'Figure 2 - Jib Ned A-side CBV Opening Range');
hold on;
grid on;
box on;

plot(uNominal_percent, pOpenStable_bar, 'o-', ...
    'LineWidth', 1.8, ...
    'MarkerSize', 8);

yline(pCr_Jib_A_bar, '--', ...
    sprintf('p_{cr,Jib,A} = %.1f bar', pCr_Jib_A_bar), ...
    'LineWidth', 1.4);

yline(pOpenHigh_bar, ':', ...
    sprintf('p_{open,high} = %.1f bar', pOpenHigh_bar), ...
    'LineWidth', 1.4);

for i = 1:nPOpen

    text(uNominal_percent(i), pOpenStable_bar(i) + 2, ...
        sprintf('%.1f bar', pOpenStable_bar(i)), ...
        'HorizontalAlignment', 'center');

end

text(65, (pCr_Jib_A_bar + pOpenHigh_bar)/2, ...
    sprintf('\\Delta p_{open,Jib,A} = %.1f bar', dpOpen_Jib_A_bar), ...
    'FontSize', 11, ...
    'FontWeight', 'bold', ...
    'HorizontalAlignment', 'center');

xlabel('Nominal PDCV opening [%]');
ylabel('Steady-state opening pressure, p_{open,Jib,A} [bar]');
title('Jib Ned A-side CBV Opening Range Identification');

xlim([30 100]);
ylim([0 max(pOpenStable_bar) + 20]);

legend( ...
    'Steady-state p_{open}', ...
    'Mean crack pressure', ...
    'Highest steady-state p_{open}', ...
    'Location', 'best' ...
);

%% ========================================================================
%  FIGURE 3: OPTIONAL pOpen TIME SERIES
% ========================================================================

if showTimeSeriesFigure

    figure('Name', 'Figure 3 - Jib Ned A-side CBV pOpen Time Series');
    hold on;
    grid on;
    box on;

    for i = 1:nPOpen

        plot(pOpenData{i}.t, pOpenData{i}.pOpen, ...
            'LineWidth', 1.2);

        idx = pOpenData{i}.steadyIdx;

        plot(pOpenData{i}.t(idx), pOpenData{i}.pOpen(idx), ...
            'LineWidth', 3.0);

    end

    yline(pCr_Jib_A_bar, '--', ...
        sprintf('p_{cr,Jib,A} = %.1f bar', pCr_Jib_A_bar), ...
        'LineWidth', 1.4);

    yline(pOpenHigh_bar, ':', ...
        sprintf('p_{open,high} = %.1f bar', pOpenHigh_bar), ...
        'LineWidth', 1.4);

    xlabel('Time [s]');
    ylabel('Opening pressure, p_{open,Jib,A} [bar]');
    title('Jib Ned A-side CBV Opening Pressure with Selected Intervals');

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

    if ~isfile(filePath)
        error('File not found: %s', filePath);
    end

    lines = readlines(filePath);

    headerLineIdx = find( ...
        contains(lines, 'fPres') | ...
        contains(lines, 'fCylinder') | ...
        contains(lines, 'fValve'), ...
        1, ...
        'first');

    if isempty(headerLineIdx)
        error('Could not find signal header in file: %s', filePath);
    end

    headerLine = char(lines(headerLineIdx));

    headerParts = split(string(headerLine), ';');

    headerParts = headerParts(headerParts ~= "");

    signalNames = strings(0);

    for k = 1:numel(headerParts)

        if headerParts(k) ~= "Name"
            signalNames(end+1, 1) = headerParts(k); %#ok<AGROW>
        end

    end

    dataStartIdx = headerLineIdx + 2;

    dataLines = lines(dataStartIdx:end);

    dataLines = dataLines(strlength(dataLines) > 0);

    dataLines = replace(dataLines, ',', '.');

    dataText = join(dataLines, newline);

    tempFile = [tempname '.csv'];

    writelines(dataText, tempFile);

    M = readmatrix(tempFile, 'Delimiter', ';');

    delete(tempFile);

    M = M(:, ~all(isnan(M), 1));

    nSignals = numel(signalNames);

    if size(M, 2) < 2*nSignals
        error('Unexpected number of columns in file: %s', filePath);
    end

    time_ms = M(:, 1);

    time_s = time_ms / 1000;

    T = table();

    T.time_s = time_s;

    for s = 1:nSignals

        valueCol = 2*s;

        cleanName = matlab.lang.makeValidName(signalNames(s));

        T.(cleanName) = M(:, valueCol);

    end

end