clc;
clear;
close all;

folderPath = 'C:\Users\hakon\OneDrive - Universitetet i Agder\Skrivebord\BACHELOR_PROSJEKT\Bachelor-Oppgave---Elektrisk-Kompansering\Mapping_Kv_f(u)\P_Supply180BAR\Mapping_JIB_NED_180\JibNed180bar';

% ===================== SYLINDERDATA =====================
dc   = 0.150;   % [m]
drod = 0.100;   % [m]

A_piston  = pi*dc^2/4;
A_annulus = A_piston - pi*drod^2/4;

% Aktiv side: 'A' eller 'B'
activeSide = 'B';

Cd  = 0.64;
rho = 850;      % [kg/m^3]

velThreshold = 1e-5;   % [m/s]

% ===================== FINN FILER =====================
files = dir(fullfile(folderPath, '*prosent*.csv'));
files = files(~contains({files.name}, 'results'));

if isempty(files)
    error('Fant ingen CSV-filer i valgt mappe.');
end

% ===================== PREALLOKER =====================
nFiles = numel(files);

u_percent   = nan(nFiles,1);
uSensor_mean = nan(nFiles,1);
uValve_mean  = nan(nFiles,1);

ps_mean   = nan(nFiles,1);
pa_mean   = nan(nFiles,1);
pb_mean   = nan(nFiles,1);
dp_mean   = nan(nFiles,1);

x_mean    = nan(nFiles,1);
xdot_mean = nan(nFiles,1);
Q_mean    = nan(nFiles,1);
Ad_mean   = nan(nFiles,1);

file_names = strings(nFiles,1);

% ===================== LOOP GJENNOM FILER =====================
for k = 1:nFiles

    file_names(k) = string(files(k).name);
    filePath = fullfile(files(k).folder, files(k).name);

    % Les prosent fra filnavn
    token = regexp(files(k).name, '(-?\d+)', 'tokens', 'once');
    if isempty(token)
        warning('Kunne ikke lese prosent fra filnavn: %s', files(k).name);
        continue;
    end
    u_percent(k) = str2double(token{1});

    % Les alle linjer
    rawLines = readlines(filePath);

    % ---- FINN DATARADER ----
    % Formatet har header på rad 7: Name;fPresSupply_bar;...
    % Selve data starter etter en blank linje (rad 9 og utover)
    % Kolonner: t;ps; t;pA; t;pB; t;x; t;sensor; t;valve
    
    t_ms   = [];
    ps     = [];
    pa     = [];
    pb     = [];
    x      = [];
    uSense = [];
    uValve = [];

    for i = 1:numel(rawLines)
        line = strtrim(rawLines(i));
        if line == "" || contains(line, 'Name') || contains(line, 'File') || ...
           contains(line, 'Start') || contains(line, 'End') || line == "EOF"
            continue;
        end

        % Bytt komma mot punktum for desimaler
        line = replace(line, ',', '.');
        parts = split(line, ';');

        if numel(parts) < 12
            continue;
        end

        vals = str2double(parts(1:12));
        if any(isnan(vals))
            continue;
        end

        % Kolonneformat:
        % t ; ps ; t ; pA ; t ; pB ; t ; x ; t ; sensor ; t ; valve
        t_ms(end+1,1)   = vals(1);
        ps(end+1,1)     = vals(2);
        pa(end+1,1)     = vals(4);
        pb(end+1,1)     = vals(6);
        x(end+1,1)      = vals(8);
        uSense(end+1,1) = vals(10);
        uValve(end+1,1) = vals(12);
    end

    if numel(t_ms) < 5
        warning('For få datapunkter i %s', files(k).name);
        continue;
    end

    % ---- BEREGNINGER ----
    t = t_ms / 1000;  % ms -> s

    % Smooth posisjon og deriver til hastighet
    win = min(15, numel(x));
    x_filt = smoothdata(x, 'movmean', win);
    xdot = gradient(x_filt, t);

    % Middelverdier
    uSensor_mean(k) = mean(uSense, 'omitnan');
    uValve_mean(k)  = mean(uValve, 'omitnan');

    ps_mean(k) = mean(ps, 'omitnan');
    pa_mean(k) = mean(pa, 'omitnan');
    pb_mean(k) = mean(pb, 'omitnan');

    % Trykkfall P->B (Main ned)
    dp_mean(k) = mean(ps - pb, 'omitnan');

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

    % Effektivt areal
    if abs(xdot_mean(k)) < velThreshold || dp_mean(k) <= 0
        Q_mean(k)  = 0;
        Ad_mean(k) = 0;
    else
        dp_Pa = dp_mean(k) * 1e5;
        Q_mean(k)  = Q;
        Ad_mean(k) = abs(Q) / (Cd * sqrt(2 * dp_Pa / rho));
    end
end

% ===================== SORTER ETTER u =====================
[u_percent, idx] = sort(u_percent);
file_names    = file_names(idx);
uSensor_mean  = uSensor_mean(idx);
uValve_mean   = uValve_mean(idx);
ps_mean       = ps_mean(idx);
pa_mean       = pa_mean(idx);
pb_mean       = pb_mean(idx);
dp_mean       = dp_mean(idx);
x_mean        = x_mean(idx);
xdot_mean     = xdot_mean(idx);
Q_mean        = Q_mean(idx);
Ad_mean       = Ad_mean(idx);

% ===================== RESULTATTABELL =====================
results = table( ...
    file_names, u_percent, uSensor_mean, uValve_mean, ...
    ps_mean, pa_mean, pb_mean, dp_mean, ...
    x_mean, xdot_mean, Q_mean, Ad_mean, ...
    'VariableNames', { ...
    'file_name','u_percent','uSensor_V','uValve_V', ...
    'ps_bar','pa_bar','pb_bar','dp_bar', ...
    'x_m','xdot_mps','Q_m3ps','Ad_m2'} );

disp(results);

% Eksporter
writetable(results, fullfile(folderPath, 'results_main_down_PtoB.csv'));

% ===================== FIGUR 1: U_målt vs U_ref =====================
figure;
plot(u_percent, uValve_mean, '-o', 'LineWidth', 1.8, 'MarkerSize', 7);
hold on;
plot(u_percent, uSensor_mean, '-s', 'LineWidth', 1.8, 'MarkerSize', 7);
grid on;
xlabel('u [%]');
ylabel('U [V]');
legend('U_{ref} (fValve1\_V)', 'U_{målt} (fSensor1\_V)', 'Location', 'best');
title('Referansesignal vs målt spoleposisjon');

% ===================== FIGUR 2: Trykk vs u =====================
figure;
plot(u_percent, ps_mean, '-o', 'LineWidth', 1.5);
hold on;
plot(u_percent, pa_mean, '-o', 'LineWidth', 1.5);
plot(u_percent, pb_mean, '-o', 'LineWidth', 1.5);
grid on;
xlabel('u [%]');
ylabel('Trykk [bar]');
legend('p_{supply}', 'p_A', 'p_B', 'Location', 'best');
title('Middeltrykksverdier vs u');

% ===================== FIGUR 3: Flow vs u =====================
figure;
plot(u_percent, Q_mean * 60000, '-o', 'LineWidth', 1.5);
grid on;
xlabel('u [%]');
ylabel('Q [L/min]');
title('Estimert flow vs u');

% ===================== FIGUR 4: Ad vs u =====================
figure;

% Skill mellom gyldige punkter og dødbånd (Ad = 0)
valid    = ~isnan(u_percent) & ~isnan(Ad_mean) & Ad_mean > 0;
deadband = ~isnan(u_percent) & Ad_mean == 0;

u_fit  = u_percent(valid);
Ad_fit = Ad_mean(valid);

% Plot gyldige målepunkter
plot(u_percent(valid), Ad_mean(valid), 'o', 'MarkerSize', 7, 'LineWidth', 1.5);
hold on;

% Plot dødbånd-punkter eksplisitt som røde kryss ved y=0
if any(deadband)
    plot(u_percent(deadband), zeros(sum(deadband),1), 'rx', ...
        'MarkerSize', 10, 'LineWidth', 2);
end

polyDegree = 3;
if numel(u_fit) >= polyDegree + 1
    pAd = polyfit(u_fit, Ad_fit, polyDegree);
    u_dense  = linspace(min(u_fit), max(u_fit), 300);
    Ad_dense = polyval(pAd, u_dense);
    plot(u_dense, Ad_dense, '-', 'LineWidth', 1.8);

    % Tegn vertikal strek ved grensen til dødbåndet
    if any(deadband) && any(valid)
        u_db_grense = max(u_percent(deadband));  % øverste dødbåndpunkt
        ymax = max(Ad_mean(valid));
        xline(u_db_grense, '--k', 'LineWidth', 1.2);
        text(u_db_grense + 0.5, ymax * 0.5, 'Dødbånd', ...
            'FontSize', 10, 'Color', 'k');
    end

    legend('Målepunkter', 'Dødbånd (A_d = 0)', ...
           sprintf('Polynomfit grad %d', polyDegree), 'Location', 'best');
    disp('Polyfit-koeffisienter for A_d(u):');
    disp(pAd);
else
    legend('Målepunkter', 'Dødbånd (A_d = 0)', 'Location', 'best');
end

grid on;
xlabel('u [%]');
ylabel('A_d [m^2]');
title('Effektivt orifice-areal vs u');