%% Main Validation Plotting Script
%
% Sammenligner målt data (MainHard.csv / MainHard(1).csv)
% med simulering (valideringstest_main2.mat)
%
% Denne versjonen:
%   - finner bunnpunktene i X_ref
%   - velger én hel sinuskurve: bunn -> topp -> bunn
%   - bruker helst sinuskurve nr. 2
%   - hvis MAT-filen ikke har nok kurver, brukes siste tilgjengelige hele kurve
%   - nullstiller tid til 0 ved valgt bunnpunkt for både målt og simulert data
%   - plotter Pa, Pb, Psupply, posisjon, UFF, UPID og Utotal
%   - lager 1 side-om-side figur + 3 store overlay-figurer
%   - alle linjer er heltrukne
%
% Figure 1 — 6 subplot (3x2): Målt (venstre) | Simulering (høyre)
% Figure 2 — stor overlay: Trykk
% Figure 3 — stor overlay: Posisjon
% Figure 4 — stor overlay: Kontrollsignal

clear;
clc;
close all;

%% -------------------------------------------------------------------------
%  KONFIGURASJON
% --------------------------------------------------------------------------

csvFile = 'MainHard.csv';
matFile = 'valideringstest_main2.mat';

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

if size(allData, 2) < 20
    error('CSV-filen har bare %d kolonner. Forventet minst 20 kolonner for MainHard.', size(allData, 2));
end

% Kolonneoppsett MainHard.csv:
%  1  t_ms
%  2  fXRef_mm
%  4  fXReal_mm
% 10  fU_FF
% 12  fU_PID
% 14  fPs_bar
% 16  fMain_Pa_bar
% 18  fMain_Pb_bar
% 20  fMain_Pa_Cyl_bar

t_csv_raw            = allData(:,  1) ./ 1000;
fXRef_mm_raw         = allData(:,  2);
fXReal_mm_raw        = allData(:,  4);
fU_FF_raw            = allData(:, 10);
fU_PID_raw           = allData(:, 12);
fU_total_raw         = fU_FF_raw + fU_PID_raw;
fPs_bar_raw          = allData(:, 14);
fMain_Pa_bar_raw     = allData(:, 16);
fMain_Pb_bar_raw     = allData(:, 18);
fMain_Pa_Cyl_raw     = allData(:, 20);

% Nullstill rå CSV-tid først.
t_csv_raw = t_csv_raw - t_csv_raw(1);

fprintf('  CSV rådata: %d samples, %.1f–%.1f s\n', ...
    numel(t_csv_raw), t_csv_raw(1), t_csv_raw(end));

%% -------------------------------------------------------------------------
%  2. LAST SIMULERINGSDATA
% --------------------------------------------------------------------------

fprintf('Laster MAT: %s\n', matFile);

% Mapping fra valideringstest_main2.mat:
%
%  1  = tid
% 30  = referanseposisjon
% 34  = Psupply
% 36  = PID / UPID
% 38  = Utotal
% 44  = PA_main_dcv
% 46  = PB_main_dcv
% 48  = UFF
% 86  = main_pos
%
% Merk:
% Utotal = UFF + UPID er verifisert med:
%   index 38 = index 48 + index 36

t_mat_raw       = readSignal(matFile,  1);
sim_XRef_raw    = readSignal(matFile, 30) .* 1000;   % m -> mm
sim_Ps_raw      = readSignal(matFile, 34);
sim_UPID_raw    = readSignal(matFile, 36);
sim_Utotal_raw  = readSignal(matFile, 38);
sim_Pa_raw      = readSignal(matFile, 44);
sim_Pb_raw      = readSignal(matFile, 46);
sim_UFF_raw     = readSignal(matFile, 48);
sim_XReal_raw   = readSignal(matFile, 86) .* 1000;   % m -> mm

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
t_csv            = t_csv_raw(csv_start_idx:csv_end_idx) - t_csv_raw(csv_start_idx);
fXRef_mm         = fXRef_mm_raw(csv_start_idx:csv_end_idx);
fXReal_mm        = fXReal_mm_raw(csv_start_idx:csv_end_idx);
fU_FF            = fU_FF_raw(csv_start_idx:csv_end_idx);
fU_PID           = fU_PID_raw(csv_start_idx:csv_end_idx);
fU_total         = fU_total_raw(csv_start_idx:csv_end_idx);
fPs_bar          = fPs_bar_raw(csv_start_idx:csv_end_idx);
fMain_Pa_bar     = fMain_Pa_bar_raw(csv_start_idx:csv_end_idx);
fMain_Pb_bar     = fMain_Pb_bar_raw(csv_start_idx:csv_end_idx);
fMain_Pa_Cyl     = fMain_Pa_Cyl_raw(csv_start_idx:csv_end_idx);

% Trim MAT-signaler fra valgt bunn til neste bunn.
t_mat       = t_mat_raw(mat_start_idx:mat_end_idx) - t_mat_raw(mat_start_idx);
sim_XRef    = sim_XRef_raw(mat_start_idx:mat_end_idx);
sim_XReal   = sim_XReal_raw(mat_start_idx:mat_end_idx);
sim_UFF     = sim_UFF_raw(mat_start_idx:mat_end_idx);
sim_UPID    = sim_UPID_raw(mat_start_idx:mat_end_idx);
sim_Utotal  = sim_Utotal_raw(mat_start_idx:mat_end_idx);
sim_Pa      = sim_Pa_raw(mat_start_idx:mat_end_idx);
sim_Pb      = sim_Pb_raw(mat_start_idx:mat_end_idx);
sim_Ps      = sim_Ps_raw(mat_start_idx:mat_end_idx);

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
fprintf('MAIN VALIDATION SUMMARY - ÉN HEL SINUSKURVE\n');
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
%  5. FELLES FARGER
% --------------------------------------------------------------------------

%% -------------------------------------------------------------------------
%  FELLES FARGER
%
%  Prinsipp:
%     - Samme signaltype = samme fargefamilie
%     - Målt / TC3       = lysere variant
%     - Simulering       = mørkere variant
%
%  Trykk:
%     P_A      = grønn
%     P_B      = blå
%     P_supply = rød
%
%  Kontroll:
%     U_FF     = blå
%     U_FB/PID = rød
%     U_total  = gul
% --------------------------------------------------------------------------

% -------------------------------------------------------------------------
%  TRYKKFARGER
% -------------------------------------------------------------------------

% P_A = grønn
C_PA_M = [0.45 0.75 0.35];   % P_A målt / TC3 - lys grønn
C_PA_S = [0.00 0.40 0.10];   % P_A simulering - mørk grønn

% P_B = blå
C_PB_M = [0.35 0.65 0.95];   % P_B målt / TC3 - lys blå
C_PB_S = [0.00 0.20 0.65];   % P_B simulering - mørk blå

% P_supply = rød
C_PS_M = [0.95 0.45 0.40];   % P_s målt / TC3 - lys rød
C_PS_S = [0.55 0.00 0.00];   % P_s simulering - mørk rød


% -------------------------------------------------------------------------
%  POSISJONSFARGER
%  Ikke like kritisk siden kurvene ligger nesten oppå hverandre.
% -------------------------------------------------------------------------

C_REF_M  = [0.55 0.55 0.55]; % X_ref målt / TC3 - lys grå
C_REF_S  = [0.10 0.10 0.10]; % X_ref simulering - mørk grå

C_REAL_M = [0.35 0.65 0.95]; % X_real målt / TC3 - lys blå
C_REAL_S = [0.00 0.20 0.65]; % X_real simulering - mørk blå


% -------------------------------------------------------------------------
%  KONTROLLFARGER
% -------------------------------------------------------------------------

% U_total = gul
C_UTOT_M = [0.95 0.78 0.25]; % U_total målt / TC3 - lys gul
C_UTOT_S = [0.65 0.45 0.00]; % U_total simulering - mørk gul/gull

% U_FF = blå
C_UFF_M  = [0.35 0.65 0.95]; % U_FF målt / TC3 - lys blå
C_UFF_S  = [0.00 0.20 0.65]; % U_FF simulering - mørk blå

% U_FB / U_PID = rød
C_UPID_M = [0.95 0.45 0.40]; % U_PID målt / TC3 - lys rød
C_UPID_S = [0.55 0.00 0.00]; % U_PID simulering - mørk rød

%% -------------------------------------------------------------------------
%  6. FIGURE 1 — SIDE-BY-SIDE PLOTS
% --------------------------------------------------------------------------

figure(1);
clf;

set(gcf, ...
    'Name', 'Main validation — Side-by-side', ...
    'NumberTitle', 'off', ...
    'Position', [60 60 1400 900]);

subplot(3,2,1);
plot(t_csv, fMain_Pa_bar, '-', 'Color', C_PA_M, 'LineWidth', 1.3, 'DisplayName', 'p_A');
hold on;
plot(t_csv, fMain_Pb_bar, '-', 'Color', C_PB_M, 'LineWidth', 1.3, 'DisplayName', 'p_B');
plot(t_csv, fPs_bar,      '-', 'Color', C_PS_M, 'LineWidth', 1.3, 'DisplayName', 'p_s');
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

sgtitle(sprintf('Main validation — measured cycle %d vs simulation cycle %d', ...
    csv_cycleUsed, mat_cycleUsed), ...
    'FontSize', 13, 'FontWeight', 'bold');

%% -------------------------------------------------------------------------
%  7. FIGURE 2 — PRESSURE OVERLAY
% --------------------------------------------------------------------------

figure(2);
clf;

set(gcf, ...
    'Name', 'Main validation — Pressure overlay', ...
    'NumberTitle', 'off', ...
    'Position', [100 100 1200 650]);

plot(t_csv, fMain_Pa_bar, '-', 'Color', C_PA_M, 'LineWidth', 1.8, ...
    'DisplayName', 'p_A measured');
hold on;
plot(t_csv, fMain_Pb_bar, '-', 'Color', C_PB_M, 'LineWidth', 1.8, ...
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
title(sprintf('Main — Pressure: measured vs simulation', ...
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
    'Name', 'Main validation — Position overlay', ...
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
title(sprintf('Main — Position: measured vs simulation', ...
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
    'Name', 'Main validation — Control signal overlay', ...
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
title(sprintf('Main — Control signal: measured vs simulation', ...
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