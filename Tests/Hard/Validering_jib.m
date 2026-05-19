%% Jib Validation Plotting Script
%
% Sammenligner målt data (JibHard.csv) med simulering (valideringstest_jib2.mat)
%
% Denne versjonen:
%   - finner bunnpunktene i X_ref
%   - velger én hel sinuskurve: bunn -> topp -> bunn
%   - bruker helst sinuskurve nr. 2
%   - hvis MAT-filen ikke har nok kurver, brukes siste tilgjengelige hele kurve
%   - nullstiller tid til 0 ved valgt bunnpunkt for både målt og simulert data
%
% Figure 1 — 6 subplot (3x2): Målt (venstre) | Simulering (høyre)
% Figure 2 — 3 subplot (3x1): Målt + Simulering overlaid

clear;
clc;
close all;

%% -------------------------------------------------------------------------
%  KONFIGURASJON
% --------------------------------------------------------------------------

csvFile = 'JibHard.csv';
matFile = 'valideringstest_jib2.mat';

% Ønsket sinuskurve:
% 1 = første bunn -> topp -> bunn
% 2 = andre bunn -> topp -> bunn
%
% Scriptet bruker 2 hvis tilgjengelig.
% Hvis MAT-filen bare har én hel kurve, brukes kurve 1 for MAT automatisk.
cycleNumberWanted = 2;

% Hvor nær bunnen signalet må være for å regnes som bunnregion.
% 0.05 betyr nederste 5 % av signalområdet.
troughThresholdFrac = 0.05;

%% -------------------------------------------------------------------------
%  1. LAST MÅLT DATA (CSV)
% --------------------------------------------------------------------------

fprintf('Laster CSV: %s\n', csvFile);

allData = readTwinCATNumericAuto(csvFile);
allData = allData(~any(isnan(allData), 2), :);

% Kolonneoppsett JibHard.csv:
%  1  t_ms
%  2  fXRef_mm
%  4  fXReal_mm
% 10  fU_FF
% 12  fU_PID
% 14  fPs_bar
% 16  fJib_Pa_bar
% 18  fJib_Pb_bar
% 20  fJib_Pa_Cyl_bar
% 22  fJib_Pb_Cyl_bar

t_csv_raw          = allData(:,  1) ./ 1000;
fXRef_mm_raw       = allData(:,  2);
fXReal_mm_raw      = allData(:,  4);
fU_FF_raw          = allData(:, 10);
fU_PID_raw         = allData(:, 12);
fU_total_raw       = fU_FF_raw + fU_PID_raw;
fPs_bar_raw        = allData(:, 14);
fJib_Pa_bar_raw    = allData(:, 16);
fJib_Pb_bar_raw    = allData(:, 18);
fJib_Pa_Cyl_raw    = allData(:, 20);
fJib_Pb_Cyl_raw    = allData(:, 22);

% Nullstill rå CSV-tid først.
t_csv_raw = t_csv_raw - t_csv_raw(1);

fprintf('  CSV rådata: %d samples, %.1f–%.1f s\n', ...
    numel(t_csv_raw), t_csv_raw(1), t_csv_raw(end));

%% -------------------------------------------------------------------------
%  2. LAST SIMULERINGSDATA
% --------------------------------------------------------------------------

fprintf('Laster MAT: %s\n', matFile);

% Mapping fra valideringstest_jib2.mat:
% 0  = PA_Jib_dcv
% 1  = tid
% 2  = PB_Jib_dcv
% 4  = jib_pos
% 6  = referanseposisjon
% 8  = PID
% 10 = SumUfiltrert / Utotal
% 12 = Transfer Fcn
% 14 = Uff Jib
% 16 = Psupply

t_mat_raw         = readSignal(matFile,  1);
sim_Pa_raw        = readSignal(matFile,  0);
sim_Pb_raw        = readSignal(matFile,  2);
sim_XReal_raw     = readSignal(matFile,  4) .* 1000;   % m -> mm
sim_XRef_raw      = readSignal(matFile,  6) .* 1000;   % m -> mm
sim_UPID_raw      = readSignal(matFile,  8);
sim_Utotal_raw    = readSignal(matFile, 10);
sim_Utransfer_raw = readSignal(matFile, 12);
sim_UFF_raw       = readSignal(matFile, 14);
sim_Ps_raw        = readSignal(matFile, 16);

% Nullstill rå MAT-tid først.
t_mat_raw = t_mat_raw - t_mat_raw(1);

fprintf('  MAT rådata: %d samples, %.1f–%.1f s\n', ...
    numel(t_mat_raw), t_mat_raw(1), t_mat_raw(end));

%% -------------------------------------------------------------------------
%  3. VELG ÉN HEL SINUSKURVE: BUNN -> TOPP -> BUNN
% --------------------------------------------------------------------------

[csv_start_idx, csv_end_idx, csv_cycleUsed, csv_troughTimes] = selectBottomToBottomCycleFlexible( ...
    t_csv_raw, fXRef_mm_raw, cycleNumberWanted, troughThresholdFrac, 'CSV');

[mat_start_idx, mat_end_idx, mat_cycleUsed, mat_troughTimes] = selectBottomToBottomCycleFlexible( ...
    t_mat_raw, sim_XRef_raw, cycleNumberWanted, troughThresholdFrac, 'MAT');

fprintf('\nValgt sinuskurve:\n');
fprintf('  CSV: ønsket kurve %d, brukt kurve %d, t = %.3f s til %.3f s\n', ...
    cycleNumberWanted, csv_cycleUsed, t_csv_raw(csv_start_idx), t_csv_raw(csv_end_idx));
fprintf('  MAT: ønsket kurve %d, brukt kurve %d, t = %.3f s til %.3f s\n', ...
    cycleNumberWanted, mat_cycleUsed, t_mat_raw(mat_start_idx), t_mat_raw(mat_end_idx));

% Trim CSV-signaler fra valgt bunn til neste bunn.
t_csv          = t_csv_raw(csv_start_idx:csv_end_idx) - t_csv_raw(csv_start_idx);
fXRef_mm       = fXRef_mm_raw(csv_start_idx:csv_end_idx);
fXReal_mm      = fXReal_mm_raw(csv_start_idx:csv_end_idx);
fU_FF          = fU_FF_raw(csv_start_idx:csv_end_idx);
fU_PID         = fU_PID_raw(csv_start_idx:csv_end_idx);
fU_total       = fU_total_raw(csv_start_idx:csv_end_idx);
fPs_bar        = fPs_bar_raw(csv_start_idx:csv_end_idx);
fJib_Pa_bar    = fJib_Pa_bar_raw(csv_start_idx:csv_end_idx);
fJib_Pb_bar    = fJib_Pb_bar_raw(csv_start_idx:csv_end_idx);
fJib_Pa_Cyl    = fJib_Pa_Cyl_raw(csv_start_idx:csv_end_idx);
fJib_Pb_Cyl    = fJib_Pb_Cyl_raw(csv_start_idx:csv_end_idx);

% Trim MAT-signaler fra valgt bunn til neste bunn.
t_mat          = t_mat_raw(mat_start_idx:mat_end_idx) - t_mat_raw(mat_start_idx);
sim_XRef       = sim_XRef_raw(mat_start_idx:mat_end_idx);
sim_XReal      = sim_XReal_raw(mat_start_idx:mat_end_idx);
sim_UFF        = sim_UFF_raw(mat_start_idx:mat_end_idx);
sim_UPID       = sim_UPID_raw(mat_start_idx:mat_end_idx);
sim_Utotal     = sim_Utotal_raw(mat_start_idx:mat_end_idx);
sim_Utransfer  = sim_Utransfer_raw(mat_start_idx:mat_end_idx);
sim_Pa         = sim_Pa_raw(mat_start_idx:mat_end_idx);
sim_Pb         = sim_Pb_raw(mat_start_idx:mat_end_idx);
sim_Ps         = sim_Ps_raw(mat_start_idx:mat_end_idx);

fprintf('\nEtter trim:\n');
fprintf('  CSV: %d samples, %.1f–%.1f s\n', ...
    numel(t_csv), t_csv(1), t_csv(end));

fprintf('  MAT: %d samples, %.1f–%.1f s\n', ...
    numel(t_mat), t_mat(1), t_mat(end));

% Felles sluttid for plot.
t_end_plot = min(t_csv(end), t_mat(end));

%% -------------------------------------------------------------------------
%  4. FEILMÅL
% --------------------------------------------------------------------------

err_csv = fXRef_mm - fXReal_mm;
err_sim = sim_XRef - sim_XReal;

fprintf('\n============================================================\n');
fprintf('JIB VALIDATION SUMMARY - ÉN HEL SINUSKURVE\n');
fprintf('============================================================\n');

fprintf('CSV position error:\n');
fprintf('  Mean abs error = %.3f mm\n', nanMeanCompat(abs(err_csv)));
fprintf('  RMSE           = %.3f mm\n', rmsNoToolbox(err_csv));
fprintf('  Max abs error  = %.3f mm\n', nanMaxCompat(abs(err_csv)));

fprintf('\nSIM position error:\n');
fprintf('  Mean abs error = %.3f mm\n', nanMeanCompat(abs(err_sim)));
fprintf('  RMSE           = %.3f mm\n', rmsNoToolbox(err_sim));
fprintf('  Max abs error  = %.3f mm\n', nanMaxCompat(abs(err_sim)));

fprintf('============================================================\n');

%% -------------------------------------------------------------------------
%% -------------------------------------------------------------------------
%  5. COMMON COLORS
%
%  Principle:
%     - Same signal type = same color family
%     - Measured / TC3   = lighter variant
%     - Simulation       = darker variant
%
%  Pressure:
%     p_A      = green
%     p_B      = blue
%     p_supply = red
%
%  Control:
%     u_FF     = blue
%     u_PID    = red
%     u_total  = yellow
% --------------------------------------------------------------------------

% Pressure colors
C_PA_M = [0.45 0.75 0.35];   % p_A measured - light green
C_PA_S = [0.00 0.40 0.10];   % p_A simulation - dark green

C_PB_M = [0.35 0.65 0.95];   % p_B measured - light blue
C_PB_S = [0.00 0.20 0.65];   % p_B simulation - dark blue

C_PS_M = [0.95 0.45 0.40];   % p_s measured - light red
C_PS_S = [0.55 0.00 0.00];   % p_s simulation - dark red

% Position colors
C_REF_M  = [0.55 0.55 0.55]; % x_ref measured - light gray
C_REF_S  = [0.10 0.10 0.10]; % x_ref simulation - dark gray

C_REAL_M = [0.35 0.65 0.95]; % x measured - light blue
C_REAL_S = [0.00 0.20 0.65]; % x simulation - dark blue

% Control signal colors
C_UTOT_M = [0.95 0.78 0.25]; % u_total measured - light yellow
C_UTOT_S = [0.65 0.45 0.00]; % u_total simulation - dark yellow/gold

C_UFF_M  = [0.35 0.65 0.95]; % u_FF measured - light blue
C_UFF_S  = [0.00 0.20 0.65]; % u_FF simulation - dark blue

C_UPID_M = [0.95 0.45 0.40]; % u_PID measured - light red
C_UPID_S = [0.55 0.00 0.00]; % u_PID simulation - dark red


%% -------------------------------------------------------------------------
%  6. FIGURE 1 — SIDE-BY-SIDE PLOTS
% --------------------------------------------------------------------------

figure(1);
clf;

set(gcf, ...
    'Name', 'Jib validation — Side-by-side', ...
    'NumberTitle', 'off', ...
    'Position', [60 60 1400 900]);

subplot(3,2,1);
plot(t_csv, fJib_Pa_bar, '-', 'Color', C_PA_M, 'LineWidth', 1.3, 'DisplayName', 'p_A');
hold on;
plot(t_csv, fJib_Pb_bar, '-', 'Color', C_PB_M, 'LineWidth', 1.3, 'DisplayName', 'p_B');
plot(t_csv, fPs_bar,     '-', 'Color', C_PS_M, 'LineWidth', 1.3, 'DisplayName', 'p_s');
ylabel('Pressure [bar]');
title(sprintf('Measured — Pressure, cycle %d', csv_cycleUsed));
legend('Location','best');
grid on;
xlim([0 t_end_plot]);

subplot(3,2,2);
plot(t_mat, sim_Pa, '-', 'Color', C_PA_S, 'LineWidth', 1.3, 'DisplayName', 'p_A');
hold on;
plot(t_mat, sim_Pb, '-', 'Color', C_PB_S, 'LineWidth', 1.3, 'DisplayName', 'p_B');
plot(t_mat, sim_Ps, '-', 'Color', C_PS_S, 'LineWidth', 1.3, 'DisplayName', 'p_s');
ylabel('Pressure [bar]');
title(sprintf('Simulation — Pressure, cycle %d', mat_cycleUsed));
legend('Location','best');
grid on;
xlim([0 t_end_plot]);

subplot(3,2,3);
plot(t_csv, fXRef_mm,  '-', 'Color', C_REF_M,  'LineWidth', 1.3, 'DisplayName', 'x_{ref}');
hold on;
plot(t_csv, fXReal_mm, '-', 'Color', C_REAL_M, 'LineWidth', 1.3, 'DisplayName', 'x');
ylabel('Position [mm]');
title('Measured — Position');
legend('Location','best');
grid on;
xlim([0 t_end_plot]);

subplot(3,2,4);
plot(t_mat, sim_XRef,  '-', 'Color', C_REF_S,  'LineWidth', 1.3, 'DisplayName', 'x_{ref}');
hold on;
plot(t_mat, sim_XReal, '-', 'Color', C_REAL_S, 'LineWidth', 1.3, 'DisplayName', 'x');
ylabel('Position [mm]');
title('Simulation — Position');
legend('Location','best');
grid on;
xlim([0 t_end_plot]);

subplot(3,2,5);
plot(t_csv, fU_total, '-', 'Color', C_UTOT_M, 'LineWidth', 1.4, 'DisplayName', 'u_{total}');
hold on;
plot(t_csv, fU_FF,    '-', 'Color', C_UFF_M,  'LineWidth', 1.3, 'DisplayName', 'u_{FF}');
plot(t_csv, fU_PID,   '-', 'Color', C_UPID_M, 'LineWidth', 1.3, 'DisplayName', 'u_{PID}');
xlabel('Time [s]');
ylabel('Control signal [-]');
title('Measured — Control signal');
legend('Location','best');
grid on;
xlim([0 t_end_plot]);

subplot(3,2,6);
plot(t_mat, sim_Utotal, '-', 'Color', C_UTOT_S, 'LineWidth', 1.4, 'DisplayName', 'u_{total}');
hold on;
plot(t_mat, sim_UFF,    '-', 'Color', C_UFF_S,  'LineWidth', 1.3, 'DisplayName', 'u_{FF}');
plot(t_mat, sim_UPID,   '-', 'Color', C_UPID_S, 'LineWidth', 1.3, 'DisplayName', 'u_{PID}');
xlabel('Time [s]');
ylabel('Control signal [-]');
title('Simulation — Control signal');
legend('Location','best');
grid on;
xlim([0 t_end_plot]);

sgtitle(sprintf('Jib validation — measured cycle %d vs simulation cycle %d', ...
    csv_cycleUsed, mat_cycleUsed), ...
    'FontSize', 13, 'FontWeight', 'bold');


%% -------------------------------------------------------------------------
%  7. FIGURE 2 — PRESSURE OVERLAY
% --------------------------------------------------------------------------

figure(2);
clf;

set(gcf, ...
    'Name', 'Jib validation — Pressure overlay', ...
    'NumberTitle', 'off', ...
    'Position', [100 100 1200 650]);

plot(t_csv, fJib_Pa_bar, '-', 'Color', C_PA_M, 'LineWidth', 1.8, ...
    'DisplayName', 'p_A measured');
hold on;
plot(t_csv, fJib_Pb_bar, '-', 'Color', C_PB_M, 'LineWidth', 1.8, ...
    'DisplayName', 'p_B measured');
plot(t_csv, fPs_bar, '-', 'Color', C_PS_M, 'LineWidth', 1.6, ...
    'DisplayName', 'p_s measured');

plot(t_mat, sim_Pa, '-', 'Color', C_PA_S, 'LineWidth', 1.8, ...
    'DisplayName', 'p_A simulation');
plot(t_mat, sim_Pb, '-', 'Color', C_PB_S, 'LineWidth', 1.8, ...
    'DisplayName', 'p_B simulation');
plot(t_mat, sim_Ps, '-', 'Color', C_PS_S, 'LineWidth', 1.6, ...
    'DisplayName', 'p_s simulation');

xlabel('Time [s]');
ylabel('Pressure [bar]');
title(sprintf('Jib — Pressure: measured vs simulation', ...
    csv_cycleUsed, mat_cycleUsed));

legend('Location', 'best', 'NumColumns', 2);
grid on;
box on;
xlim([0 t_end_plot]);


%% -------------------------------------------------------------------------
%  8. FIGURE 3 — POSITION OVERLAY
% --------------------------------------------------------------------------

figure(3);
clf;

set(gcf, ...
    'Name', 'Jib validation — Position overlay', ...
    'NumberTitle', 'off', ...
    'Position', [130 130 1200 650]);

plot(t_csv, fXRef_mm, '-', 'Color', C_REF_M, 'LineWidth', 2.0, ...
    'DisplayName', 'x_{ref} measured');
hold on;
plot(t_csv, fXReal_mm, '-', 'Color', C_REAL_M, 'LineWidth', 1.8, ...
    'DisplayName', 'x measured');

plot(t_mat, sim_XRef, '-', 'Color', C_REF_S, 'LineWidth', 2.0, ...
    'DisplayName', 'x_{ref} simulation');
plot(t_mat, sim_XReal, '-', 'Color', C_REAL_S, 'LineWidth', 1.8, ...
    'DisplayName', 'x simulation');

xlabel('Time [s]');
ylabel('Position [mm]');
title(sprintf('Jib — Position: measured vs simulation', ...
    csv_cycleUsed, mat_cycleUsed));

legend('Location', 'best', 'NumColumns', 2);
grid on;
box on;
xlim([0 t_end_plot]);


%% -------------------------------------------------------------------------
%  9. FIGURE 4 — CONTROL SIGNAL OVERLAY
% --------------------------------------------------------------------------

figure(4);
clf;

set(gcf, ...
    'Name', 'Jib validation — Control signal overlay', ...
    'NumberTitle', 'off', ...
    'Position', [160 160 1200 650]);

plot(t_csv, fU_total, '-', 'Color', C_UTOT_M, 'LineWidth', 2.0, ...
    'DisplayName', 'u_{total} measured');
hold on;
plot(t_csv, fU_FF, '-', 'Color', C_UFF_M, 'LineWidth', 1.8, ...
    'DisplayName', 'u_{FF} measured');
plot(t_csv, fU_PID, '-', 'Color', C_UPID_M, 'LineWidth', 1.8, ...
    'DisplayName', 'u_{PID} measured');

plot(t_mat, sim_Utotal, '-', 'Color', C_UTOT_S, 'LineWidth', 2.0, ...
    'DisplayName', 'u_{total} simulation');
plot(t_mat, sim_UFF, '-', 'Color', C_UFF_S, 'LineWidth', 1.8, ...
    'DisplayName', 'u_{FF} simulation');
plot(t_mat, sim_UPID, '-', 'Color', C_UPID_S, 'LineWidth', 1.8, ...
    'DisplayName', 'u_{PID} simulation');

xlabel('Time [s]');
ylabel('Control signal [-]');
title(sprintf('Jib — Control signal: measured vs simulation', ...
    csv_cycleUsed, mat_cycleUsed));

legend('Location', 'best', 'NumColumns', 2);
grid on;
box on;
xlim([0 t_end_plot]);

fprintf('\nDone. Figure 1 = side-by-side, Figure 2 = pressure, Figure 3 = position, Figure 4 = control.\n');
%% -------------------------------------------------------------------------
%  LOKALE FUNKSJONER
% -------------------------------------------------------------------------

function sig = readSignal(matFile, idx)
    base = sprintf('/#sigstream#/%d', idx);
    raw8 = h5read(matFile, [base '/#data#']);
    len  = double(h5read(matFile, [base '/#length#']));
    sig  = typecast(uint8(raw8(1:len*8)), 'double');
    sig  = sig(:);
end

function M = readTwinCATNumericAuto(filename)
    fid = fopen(filename, 'r');

    if fid == -1
        error('Kunne ikke åpne filen: %s', filename);
    end

    cleanupObj = onCleanup(@() fclose(fid)); %#ok<NASGU>

    rows = {};
    dataStarted = false;

    while ~feof(fid)
        line = fgetl(fid);

        if ~ischar(line)
            continue;
        end

        line = strtrim(line);

        if isempty(line)
            continue;
        end

        line = strrep(line, ',', '.');
        parts = strsplit(line, ';');

        values = nan(1, numel(parts));

        for k = 1:numel(parts)
            values(k) = str2double(parts{k});
        end

        if ~dataStarted
            if numel(values) >= 2 && ~isnan(values(1)) && ~isnan(values(2))
                dataStarted = true;
            else
                continue;
            end
        end

        rows{end+1, 1} = values; %#ok<AGROW>
    end

    if isempty(rows)
        error('Fant ingen numeriske datarader i CSV-filen.');
    end

    maxCols = 0;

    for r = 1:numel(rows)
        maxCols = max(maxCols, numel(rows{r}));
    end

    M = nan(numel(rows), maxCols);

    for r = 1:numel(rows)
        values = rows{r};
        M(r, 1:numel(values)) = values;
    end
end

function [startIdx, endIdx, cycleUsed, troughTimes] = selectBottomToBottomCycleFlexible(t, xRef, cycleNumberWanted, thresholdFrac, label)
    % Velger én hel sinuskurve fra bunn -> topp -> bunn.
    %
    % Hvis ønsket cycleNumber ikke finnes, brukes siste tilgjengelige hele
    % sinuskurve i stedet for å krasje.

    t = t(:);
    xRef = xRef(:);

    valid = ~isnan(t) & ~isnan(xRef);
    t = t(valid);
    xRef = xRef(valid);

    if numel(t) < 10
        error('%s: For få datapunkter til å finne sinuskurve.', label);
    end

    amp = max(xRef) - min(xRef);

    if amp <= 0
        error('%s: Referansesignalet har ingen amplitude.', label);
    end

    window = max(5, round(0.005 * numel(xRef)));

    if mod(window, 2) == 0
        window = window + 1;
    end

    xSmooth = movingAverageCompat(xRef, window);

    idxCandidates = [];

    for i = 2:numel(xSmooth)-1
        isLocalMin = xSmooth(i) <= xSmooth(i-1) && xSmooth(i) < xSmooth(i+1);

        if isLocalMin
            idxCandidates(end+1, 1) = i; %#ok<AGROW>
        end
    end

    if isempty(idxCandidates)
        error('%s: Fant ingen lokale minima i X_ref.', label);
    end

    lowerLimit = min(xSmooth) + thresholdFrac * amp;
    idxCandidates = idxCandidates(xSmooth(idxCandidates) <= lowerLimit);

    if isempty(idxCandidates)
        error('%s: Fant ingen tydelige bunnpunkter etter terskelfiltrering.', label);
    end

    totalDuration = t(end) - t(1);
    minTimeDistance = max(2.0, 0.10 * totalDuration);

    troughIdx = [];
    currentGroup = idxCandidates(1);

    for k = 2:numel(idxCandidates)
        idxNow  = idxCandidates(k);
        idxPrev = idxCandidates(k-1);

        if t(idxNow) - t(idxPrev) <= minTimeDistance
            currentGroup(end+1, 1) = idxNow; %#ok<AGROW>
        else
            [~, localMinIdx] = min(xSmooth(currentGroup));
            troughIdx(end+1, 1) = currentGroup(localMinIdx); %#ok<AGROW>

            currentGroup = idxNow;
        end
    end

    [~, localMinIdx] = min(xSmooth(currentGroup));
    troughIdx(end+1, 1) = currentGroup(localMinIdx);

    troughTimes = t(troughIdx);

    fprintf('\n%s: Fant bunnpunkter ved tider:\n', label);
    disp(troughTimes(:).');

    if numel(troughIdx) < 2
        error('%s: Fant ikke nok bunnpunkter til én hel sinuskurve.', label);
    end

    maxAvailableCycle = numel(troughIdx) - 1;

    if cycleNumberWanted > maxAvailableCycle
        fprintf('%s: Ønsket kurve %d finnes ikke. Bruker siste tilgjengelige hele kurve: %d.\n', ...
            label, cycleNumberWanted, maxAvailableCycle);

        cycleUsed = maxAvailableCycle;
    else
        cycleUsed = cycleNumberWanted;
    end

    startIdx = troughIdx(cycleUsed);
    endIdx   = troughIdx(cycleUsed + 1);

    if endIdx <= startIdx
        error('%s: Ugyldig valgt sinusperiode.', label);
    end
end

function ySmooth = movingAverageCompat(y, window)
    y = y(:);
    n = numel(y);
    ySmooth = nan(size(y));

    halfWindow = floor(window / 2);

    for i = 1:n
        i1 = max(1, i - halfWindow);
        i2 = min(n, i + halfWindow);

        segment = y(i1:i2);
        segment = segment(~isnan(segment));

        if isempty(segment)
            ySmooth(i) = NaN;
        else
            ySmooth(i) = mean(segment);
        end
    end
end

function r = rmsNoToolbox(x)
    x = x(:);
    x = x(~isnan(x));

    if isempty(x)
        r = NaN;
    else
        r = sqrt(mean(x.^2));
    end
end

function m = nanMeanCompat(x)
    x = x(:);
    x = x(~isnan(x));

    if isempty(x)
        m = NaN;
    else
        m = mean(x);
    end
end

function m = nanMaxCompat(x)
    x = x(:);
    x = x(~isnan(x));

    if isempty(x)
        m = NaN;
    else
        m = max(x);
    end
end