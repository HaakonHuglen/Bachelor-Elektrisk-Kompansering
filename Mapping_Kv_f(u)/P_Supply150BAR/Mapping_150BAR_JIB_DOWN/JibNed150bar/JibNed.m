%% ===================== USER SETTINGS =====================
clc; clear; close all;
folderPath = 'C:\Users\hakon\OneDrive - Universitetet i Agder\Skrivebord\BACHELOR_PROSJEKT\Bachelor-Oppgave---Elektrisk-Kompansering\Mapping_Kv_f(u)\P_Supply150BAR\Mapping_150Bar_JIB_DOWN\JibNed150bar';

% Sylinderdata
dc   = 0.150;   % [m]
drod = 0.100;   % [m]

A_piston  = pi*dc^2/4;
A_annulus = A_piston - pi*drod^2/4;

% Velg aktiv side
% 'A' dersom Q = A_piston * x_dot
% 'B' dersom Q = A_annulus * abs(x_dot)
activeSide = 'B';

Cd  = 0.64;
rho = 850;      % [kg/m^3]

velThreshold = 1e-5;   % [m/s]

%% ===================== FIND FILES =====================

files = dir(fullfile(folderPath, '*prosent*.csv'));
files = files(~contains({files.name}, 'results'));

if isempty(files)
    error('Fant ingen CSV-filer i valgt mappe.');
end

%% ===================== PREALLOCATE =====================

nFiles = numel(files);

u_percent = nan(nFiles,1);
uV_mean   = nan(nFiles,1);   % measured = fSensor1_V
uV_exp    = nan(nFiles,1);   % reference = fValve1_V

ps_mean   = nan(nFiles,1);
pa_mean   = nan(nFiles,1);
pb_mean   = nan(nFiles,1);
dp_mean   = nan(nFiles,1);

x_mean    = nan(nFiles,1);
xdot_mean = nan(nFiles,1);
Q_mean    = nan(nFiles,1);
Ad_mean   = nan(nFiles,1);

file_names = strings(nFiles,1);

%% ===================== LOOP THROUGH FILES =====================

for k = 1:nFiles

    file_names(k) = string(files(k).name);
    filePath = fullfile(files(k).folder, files(k).name);

    % Les alle linjer
    rawLines = readlines(filePath);

    % I denne filtypen ligger header på rad 7 og data starter på rad 9
    if numel(rawLines) < 9
        warning('Fil %s har færre enn 9 linjer. Hopper over.', files(k).name);
        continue;
    end

    dataLines = rawLines(9:end);

    % Finn prosent fra filnavn, f.eks. -75prosent.csv
    token = regexp(files(k).name, '(-?\d+)', 'tokens', 'once');
    if isempty(token)
        warning('Kunne ikke lese prosent fra filnavn: %s', files(k).name);
        continue;
    end
    u_percent(k) = str2double(token{1});

    % Parse numeriske rader
    t_ms = [];
    ps   = [];
    pa   = [];
    pb   = [];
    x    = [];
    uV   = [];   % measured sensor signal
    uRef = [];   % commanded valve signal

    for i = 1:numel(dataLines)
        line = strtrim(dataLines(i));

        if line == "" || startsWith(line, "EOF")
            continue;
        end

        % Bytt komma til punktum dersom nødvendig
        line = replace(line, ',', '.');

        % Split på semikolon
        parts = split(line, ';');

        % Forventer format:
        % t ; ps ; t ; pa ; t ; pb ; t ; x ; t ; u_sensor ; t ; u_valve
        if numel(parts) < 12
            continue;
        end

        vals = str2double(parts(1:12));

        if any(isnan(vals))
            continue;
        end

        t_ms(end+1,1) = vals(1);
        ps(end+1,1)   = vals(2);

        % Samme mapping som du brukte tidligere, med pa/pb byttet
        pa(end+1,1)   = vals(6);
        pb(end+1,1)   = vals(4);

        x(end+1,1)    = vals(8);
        uV(end+1,1)   = vals(10);   % fSensor1_V
        uRef(end+1,1) = vals(12);   % fValve1_V
    end

    if numel(t_ms) < 5
        warning('For få gyldige datapunkter i %s', files(k).name);
        continue;
    end

    % Tid i sekunder
    t = t_ms / 1000;

    % Smooth x litt før derivert
    win = min(15, numel(x));
    x_filt = smoothdata(x, 'movmean', win);

    % Hastighet
    xdot = gradient(x_filt, t);

    % Middelverdier
    uV_mean(k)   = mean(uV, 'omitnan');    % measured
    uV_exp(k)    = mean(uRef, 'omitnan');  % reference

    ps_mean(k)   = mean(ps, 'omitnan');
    pa_mean(k)   = mean(pa, 'omitnan');
    pb_mean(k)   = mean(pb, 'omitnan');
    dp_mean(k)   = mean(ps - pa, 'omitnan');

    x_mean(k)    = mean(x, 'omitnan');
    xdot_mean(k) = median(xdot, 'omitnan');

    % Flow
    switch upper(activeSide)
        case 'A'
            Q = A_piston * xdot_mean(k);
        case 'B'
            Q = A_annulus * abs(xdot_mean(k));
        otherwise
            error('activeSide må være ''A'' eller ''B''.');
    end

    % Ad
    if abs(xdot_mean(k)) < velThreshold || dp_mean(k) <= 0
        Q_mean(k)  = 0;
        Ad_mean(k) = 0;
    else
        dp_Pa = dp_mean(k) * 1e5;
        Q_mean(k)  = Q;
        Ad_mean(k) = abs(Q) / (Cd * sqrt(2*dp_Pa/rho));
    end
end

%% ===================== SORT RESULTS =====================

% Sorter slik at 0 havner til venstre og mer negativ kommando til høyre
[u_percent, idx] = sort(u_percent, 'descend');

file_names = file_names(idx);
uV_mean    = uV_mean(idx);
uV_exp     = uV_exp(idx);

ps_mean    = ps_mean(idx);
pa_mean    = pa_mean(idx);
pb_mean    = pb_mean(idx);
dp_mean    = dp_mean(idx);

x_mean     = x_mean(idx);
xdot_mean  = xdot_mean(idx);
Q_mean     = Q_mean(idx);
Ad_mean    = Ad_mean(idx);

uV_error = uV_mean - uV_exp;

%% ===================== RESULTS TABLE =====================

results = table(file_names, u_percent, uV_exp, uV_mean, uV_error, ...
    ps_mean, pa_mean, pb_mean, dp_mean, ...
    x_mean, xdot_mean, Q_mean, Ad_mean, ...
    'VariableNames', {'file_name','u_percent','uV_expected','uV_mean','uV_error', ...
    'ps_bar','pa_bar','pb_bar','dp_bar','x_m','xdot_mps','Q_m3ps','Ad_m2'});

disp(results);

%% ===================== EXPORT =====================

outFile = fullfile(folderPath, 'results_manual_cleaned_from_row9.csv');
writetable(results, outFile);

%% ===================== PLOTS =====================

% 1) U_ref og U_målt
figure;
plot(u_percent, uV_exp, '-', 'LineWidth', 1.8); hold on;
plot(u_percent, uV_mean, 'o', 'MarkerSize', 7, 'LineWidth', 1.5);
grid on;
xlabel('u [%]');
ylabel('U [V]');
legend('U_{ref}','U_{målt}','Location','best');
title('U_{ref} og U_{målt}');
% 2) Pressure plot
figure;
plot(u_percent, ps_mean, '-o', 'LineWidth', 1.5); hold on;
plot(u_percent, pa_mean, '-o', 'LineWidth', 1.5);
plot(u_percent, pb_mean, '-o', 'LineWidth', 1.5);
grid on;
xlabel('u [%]');
ylabel('Pressure [bar]');
legend('p_s','p_A','p_B','Location','best');
title('Mean pressure values');

% 3) dp plot
figure;
plot(u_percent, dp_mean, '-o', 'LineWidth', 1.5);
grid on;
xlabel('u [%]');
ylabel('\Deltap [bar]');
title('\Deltap = p_s - p_A');

% 4) Flow mot U_målt
figure;
plot(uV_mean, Q_mean*60000, '-o', 'LineWidth', 1.5);
grid on;
xlabel('U_{målt} [V]');
ylabel('Q [L/min]');
title('Estimated flow vs U_{målt}');

% 5) Ad mot U_målt
figure;
plot(uV_mean, Ad_mean, 'o', 'MarkerSize', 7, 'LineWidth', 1.5); hold on;
grid on;
xlabel('U_{målt} [V]');
ylabel('A_d [m^2]');
title('Effective orifice area vs U_{målt}');

%% ===================== OPTIONAL FIT =====================

valid = ~isnan(uV_mean) & ~isnan(Ad_mean);

u_fit  = uV_mean(valid);
Ad_fit = Ad_mean(valid);

polyDegree = 3;

if numel(u_fit) >= polyDegree + 1
    pAd = polyfit(u_fit, Ad_fit, polyDegree);

    u_dense = linspace(min(u_fit), max(u_fit), 300);
    Ad_dense = polyval(pAd, u_dense);

    figure;
    plot(u_fit, Ad_fit, 'o', 'MarkerSize', 7, 'LineWidth', 1.5); hold on;
    plot(u_dense, Ad_dense, '-', 'LineWidth', 1.8);
    grid on;
    xlabel('U_{målt} [V]');
    ylabel('A_d [m^2]');
    title(sprintf('A_d(U_{målt}) fit, degree = %d', polyDegree));
    legend('Measured points','Polynomial fit','Location','best');

    disp('Polyfit coefficients for A_d(U_målt):');
    disp(pAd);
end

disp(['Ferdig. Resultatfil: ', outFile]);