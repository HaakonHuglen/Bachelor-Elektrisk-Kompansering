clc;
clear;
close all;

folderPath = 'C:\Users\hakon\OneDrive - Universitetet i Agder\Skrivebord\BACHELOR_PROSJEKT\Bachelor-Oppgave---Elektrisk-Kompansering\Mapping_Kv_f(u)\P_Supply150BAR\Mapping_150Bar_MAIN_DOWN\MainNed150bar';



% Sylinderdata
dc   = 0.160;   % [m]
drod = 0.100;   % [m]

A_piston  = pi*dc^2/4;
A_annulus = A_piston - pi*drod^2/4;

% Main ned, P->B
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

u_percent   = nan(nFiles,1);
uV_mean     = nan(nFiles,1);   % målt spolesensor
uV_exp      = nan(nFiles,1);   % forventet signal fra prosent
uValve_mean = nan(nFiles,1);   % faktisk ventilreferanse

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

    % Finn prosent fra filnavn
    token = regexp(files(k).name, '(-?\d+)', 'tokens', 'once');
    if isempty(token)
        warning('Kunne ikke lese prosent fra filnavn: %s', files(k).name);
        continue;
    end
    u_percent(k) = str2double(token{1});

    % Forventet volt fra prosent:
    % -100% -> 0V, 0% -> 5V, 100% -> 10V
    uV_exp(k) = 5 + 5*(u_percent(k)/100);

    % Finn første rad med faktisk data
    dataStart = 0;
    for i = 1:numel(rawLines)
        line = strtrim(rawLines(i));
        if line == ""
            continue;
        end

        lineTest = replace(line, ',', '.');
        parts = split(lineTest, ';');

        if numel(parts) >= 12
            vals = str2double(parts(1:12));
            if all(~isnan(vals))
                dataStart = i;
                break;
            end
        end
    end

    if dataStart == 0
        warning('Fant ingen gyldige datarader i %s', files(k).name);
        continue;
    end

    dataLines = rawLines(dataStart:end);

    % Init arrays
    t_ms   = [];
    ps     = [];
    pa     = [];
    pb     = [];
    x      = [];
    uSense = [];
    uValve = [];

    % Parse numeriske rader
    for i = 1:numel(dataLines)

        line = strtrim(dataLines(i));
        if line == ""
            continue;
        end

        line = replace(line, ',', '.');
        parts = split(line, ';');

        % Format:
        % t ; ps ; t ; pa ; t ; pb ; t ; x ; t ; sensor ; t ; valve
        if numel(parts) < 12
            continue;
        end

        vals = str2double(parts(1:12));
        if any(isnan(vals))
            continue;
        end

        t_ms(end+1,1)   = vals(1);
        ps(end+1,1)     = vals(2);
        pa(end+1,1)     = vals(4);
        pb(end+1,1)     = vals(6);
        x(end+1,1)      = vals(8);
        uSense(end+1,1) = vals(10);
        uValve(end+1,1) = vals(12);
    end

    if numel(t_ms) < 5
        warning('For få gyldige datapunkter i %s', files(k).name);
        continue;
    end

    %% Tid i sekunder
    t = t_ms / 1000;

    %% Smooth posisjon før derivasjon
    win = min(15, numel(x));
    x_filt = smoothdata(x, 'movmean', win);

    %% Hastighet
    xdot = gradient(x_filt, t);

    %% Middelverdier
    uV_mean(k)     = mean(uSense, 'omitnan');
    uValve_mean(k) = mean(uValve, 'omitnan');

    ps_mean(k) = mean(ps, 'omitnan');
    pa_mean(k) = mean(pa, 'omitnan');
    pb_mean(k) = mean(pb, 'omitnan');

    % Main ned, P->B: trykkfall over aktiv orifice
    dp_mean(k) = mean(ps - pb, 'omitnan');

    x_mean(k)    = mean(x, 'omitnan');
    xdot_mean(k) = median(xdot, 'omitnan');

    %% Flow
    switch upper(activeSide)
        case 'A'
            Q = A_piston * xdot_mean(k);
        case 'B'
            Q = A_annulus * abs(xdot_mean(k));
        otherwise
            error('activeSide må være ''A'' eller ''B''.');
    end

    %% Effektivt areal
    if abs(xdot_mean(k)) < velThreshold || dp_mean(k) <= 0
        Q_mean(k)  = 0;
        Ad_mean(k) = 0;
    else
        dp_Pa = dp_mean(k) * 1e5;
        Q_mean(k)  = Q;
        Ad_mean(k) = abs(Q) / (Cd * sqrt(2 * dp_Pa / rho));
    end
end

%% ===================== SORT RESULTS =====================
[u_percent, idx] = sort(u_percent);

file_names   = file_names(idx);
uV_mean      = uV_mean(idx);
uV_exp       = uV_exp(idx);
uValve_mean  = uValve_mean(idx);

ps_mean      = ps_mean(idx);
pa_mean      = pa_mean(idx);
pb_mean      = pb_mean(idx);
dp_mean      = dp_mean(idx);

x_mean       = x_mean(idx);
xdot_mean    = xdot_mean(idx);
Q_mean       = Q_mean(idx);
Ad_mean      = Ad_mean(idx);

uV_error = uV_mean - uV_exp;

%% ===================== RESULTS TABLE =====================
results = table( ...
    file_names, u_percent, uV_exp, uV_mean, uValve_mean, uV_error, ...
    ps_mean, pa_mean, pb_mean, dp_mean, ...
    x_mean, xdot_mean, Q_mean, Ad_mean, ...
    'VariableNames', { ...
    'file_name','u_percent','uV_expected','uSensor_mean','uValve_mean','uV_error', ...
    'ps_bar','pa_bar','pb_bar','dp_bar','x_m','xdot_mps','Q_m3ps','Ad_m2'} ...
    );

disp(results);

%% ===================== EXPORT =====================
writetable(results, fullfile(folderPath, 'results_main_down_PtoB_from_csv.csv'));

%% ===================== PLOTS =====================

% Plot 1: Expected vs measured/reference voltage
figure;
plot(u_percent, uValve_mean, '-o', 'LineWidth', 1.8, 'MarkerSize', 7);
hold on;
plot(u_percent, uV_mean, '-s', 'LineWidth', 1.8, 'MarkerSize', 7);
grid on;
xlabel('u [%]');
ylabel('U [V]');
legend('u_{ref}','U_{målt}','Location','best');
title('Reference signal vs measured spool position');

% Plot 2: Mean pressures
figure;
plot(u_percent, ps_mean, '-o', 'LineWidth', 1.5);
hold on;
plot(u_percent, pa_mean, '-o', 'LineWidth', 1.5);
plot(u_percent, pb_mean, '-o', 'LineWidth', 1.5);
grid on;
xlabel('u [%]');
ylabel('Pressure [bar]');
legend('p_s','p_A','p_B','Location','best');
title('Mean pressure values');

% Plot 3: Pressure drop
figure;
plot(u_percent, dp_mean, '-o', 'LineWidth', 1.5);
grid on;
xlabel('u [%]');
ylabel('\Deltap [bar]');
title('\Deltap = p_s - p_B');

% Plot 4: Estimated flow
figure;
plot(u_percent, Q_mean*60000, '-o', 'LineWidth', 1.5);
grid on;
xlabel('u [%]');
ylabel('Q [L/min]');
title('Estimated flow vs u');

% Plot 5: Effective orifice area
figure;
plot(u_percent, Ad_mean, 'o', 'MarkerSize', 7, 'LineWidth', 1.5);
hold on;
grid on;
xlabel('u [%]');
ylabel('A_d [m^2]');
title('Effective orifice area vs u');

%% ===================== OPTIONAL FIT =====================
valid = ~isnan(u_percent) & ~isnan(Ad_mean);

u_fit  = u_percent(valid);
Ad_fit = Ad_mean(valid);

polyDegree = 3;

if numel(u_fit) >= polyDegree + 1

    pAd = polyfit(u_fit, Ad_fit, polyDegree);

    u_dense  = linspace(min(u_fit), max(u_fit), 300);
    Ad_dense = polyval(pAd, u_dense);

    figure;
    plot(u_fit, Ad_fit, 'o', 'MarkerSize', 7, 'LineWidth', 1.5);
    hold on;
    plot(u_dense, Ad_dense, '-', 'LineWidth', 1.8);
    grid on;
    xlabel('u [%]');
    ylabel('A_d [m^2]');
    title(sprintf('A_d(u) fit, degree = %d', polyDegree));
    legend('Measured points','Polynomial fit','Location','best');

    disp('Polyfit coefficients for A_d(u):');
    disp(pAd);
end