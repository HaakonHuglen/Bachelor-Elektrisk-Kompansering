clc;
clear;
close all;

%% ===================== INNSTILLINGER =====================
folderPathMain = 'C:\Users\hakon\OneDrive - Universitetet i Agder\Skrivebord\BACHELOR_PROSJEKT\Bachelor-Oppgave---Elektrisk-Kompansering\Mapping_Kv_f(u)\P_Supply120BAR\Mapping_MAIN_UP_120\MainOpp120bar';

dc   = 0.160;   % [m]
drod = 0.100;   % [m]

A_piston  = pi*dc^2/4;
A_annulus = A_piston - pi*drod^2/4;

activeSide   = 'A';     % Main opp -> P til A
Cd           = 0.64;
rho          = 850;
velThreshold = 1e-5;

%% ===================== LES MAPPE =====================
T_main = lesMappeMainOpp(folderPathMain, false, activeSide, A_piston, A_annulus, Cd, rho, velThreshold);

%% ===================== SORTER =====================
results = sortrows(T_main, 'u_percent');
results = results(~isnan(results.u_percent), :);

disp(results);
writetable(results, fullfile(folderPathMain, 'results_combined_main_up.csv'));

%% ===================== HENT VARIABLER =====================
u      = results.u_percent;
ps     = results.ps_bar;
pa     = results.pa_bar;
pb     = results.pb_bar;
Q      = results.Q_m3ps;
Ad     = results.Ad_m2;
Kv     = results.Kv_Lmin_sqrtbar;
uRef   = results.uV_ref;
uMaalt = results.uV_sensor;

%% ===================== FIGUR 1: U_ref vs U_målt =====================
figure;
plot(u, uRef, '-o', 'LineWidth', 1.8, 'MarkerSize', 7);
hold on;
plot(u, uMaalt, '-s', 'LineWidth', 1.8, 'MarkerSize', 7);
grid on;
xlabel('u [%]');
ylabel('U [V]');
legend('U_{ref}', 'U_{målt}', 'Location', 'best');
title('Referansesignal vs målt spoleposisjon - Main opp');

%% ===================== FIGUR 2: TRYKK =====================
figure;
plot(u, ps, '-o', u, pa, '-o', u, pb, '-o', 'LineWidth', 1.5);
grid on;
xlabel('u [%]');
ylabel('Trykk [bar]');
legend('p_{supply}', 'p_A', 'p_B', 'Location', 'best');
title('Middeltrykksverdier vs u - Main opp');

%% ===================== FIGUR 3: FLOW =====================
figure;
plot(u, Q * 60000, '-o', 'LineWidth', 1.5);
grid on;
xlabel('u [%]');
ylabel('Q [L/min]');
title('Estimert flow vs u - Main opp');

%% ===================== FIGUR 4: Ad vs u =====================
plotMedFitMainOpp(u, Ad, ...
    'A_d [m^2]', ...
    'Effektivt orifice-areal vs u - Main opp', ...
    'A_d');

%% ===================== FIGUR 5: Kv vs u =====================
plotMedFitMainOpp(u, Kv, ...
    'K_v [L/(min \cdot \surdbar)]', ...
    'K_v vs u - Main opp', ...
    'K_v');

%% ===================== PLOT MED FIT MAIN OPP =====================
function plotMedFitMainOpp(u, y, ylbl, ttl, varName)

    valid    = ~isnan(u) & ~isnan(y) & y > 0;
    deadband = ~isnan(u) & ~isnan(y) & y == 0;

    figure;
    hold on;

    if any(valid)
        plot(u(valid), y(valid), 'o', 'MarkerSize', 7, 'LineWidth', 1.5);
    end

    if any(deadband)
        plot(u(deadband), zeros(sum(deadband),1), 'rx', ...
            'MarkerSize', 10, 'LineWidth', 2);
    end

    % Main opp: positive u-verdier, ikke bruk overgangsområdet nær dødbånd
    fitMask = valid & u >= 17.0;

    if sum(fitMask) >= 4
        polyDeg = 3;
    elseif sum(fitMask) >= 3
        polyDeg = 2;
    elseif sum(fitMask) >= 2
        polyDeg = 1;
    else
        polyDeg = NaN;
    end

    if ~isnan(polyDeg)
        p = polyfit(u(fitMask), y(fitMask), polyDeg);

        u_dense = linspace(min(u(fitMask)), max(u(fitMask)), 300);
        y_fit   = polyval(p, u_dense);
        y_fit(y_fit < 0) = NaN;

        plot(u_dense, y_fit, '-', 'LineWidth', 1.8);
    end

    if any(deadband)
        u_db = max(u(deadband));   % øvre grense for dødbånd (positiv retning)
        xline(u_db, '--k', 'LineWidth', 1.2);

        if any(valid)
            text(u_db + 0.2, max(y(valid))*0.5, 'Dødbånd', 'FontSize', 10);
        end
    end

    grid on;
    xlabel('u [%]');
    ylabel(ylbl);
    title(ttl);

    if ~isnan(polyDeg)
        legend('Målepunkter', ...
               sprintf('Dødbånd (%s = 0)', varName), ...
               sprintf('Polynomfit grad %d', polyDeg), ...
               'Location', 'best');
    else
        legend('Målepunkter', ...
               sprintf('Dødbånd (%s = 0)', varName), ...
               'Location', 'best');
    end
end

%% ===================== LES MAPPE MAIN OPP =====================
function T = lesMappeMainOpp(folderPath, isDeadbandFolder, activeSide, A_piston, A_annulus, Cd, rho, velThreshold)

    if ~isfolder(folderPath)
        warning('Mappen finnes ikke: %s', folderPath);
        T = tomTabell();
        return;
    end

    files = dir(fullfile(folderPath, '**', '*.csv'));
    files = files(~contains({files.name}, 'results', 'IgnoreCase', true));

    if isempty(files)
        warning('Ingen CSV-filer funnet i: %s', folderPath);
        T = tomTabell();
        return;
    end

    nFiles = numel(files);

    file_names     = strings(nFiles,1);
    u_percent      = nan(nFiles,1);
    uV_ref_mean    = nan(nFiles,1);
    uV_sensor_mean = nan(nFiles,1);
    ps_mean        = nan(nFiles,1);
    pa_mean        = nan(nFiles,1);
    pb_mean        = nan(nFiles,1);
    dp_mean        = nan(nFiles,1);
    x_mean         = nan(nFiles,1);
    xdot_mean      = nan(nFiles,1);
    Q_mean         = nan(nFiles,1);
    Ad_mean        = nan(nFiles,1);
    Kv_mean        = nan(nFiles,1);

    for k = 1:nFiles

        file_names(k) = string(files(k).name);
        filePath = fullfile(files(k).folder, files(k).name);
        rawLines = readlines(filePath);

        u_percent(k) = hentProsentFraFilnavn(files(k).name);

        if isnan(u_percent(k))
            warning('Kunne ikke lese prosent fra filnavn: %s', files(k).name);
            continue;
        end

        t_ms = [];
        ps   = [];
        pa   = [];
        pb   = [];
        x    = [];
        uRef = [];
        uSen = [];

        for i = 1:numel(rawLines)

            line = strtrim(rawLines(i));

            if line == "" || line == "EOF" || ...
               contains(line, 'Name') || contains(line, 'File') || ...
               contains(line, 'Start') || contains(line, 'End')
                continue;
            end

            line  = replace(line, ',', '.');
            parts = split(line, ';');
            vals  = str2double(parts);

            if numel(vals) < 10 || any(isnan(vals(1:min(10,numel(vals)))))
                continue;
            end

            t_ms(end+1,1) = vals(1);
            ps(end+1,1)   = vals(2);

            if numel(vals) >= 12
                pa(end+1,1)   = vals(4);
                pb(end+1,1)   = vals(6);
                uRef(end+1,1) = vals(10);
                uSen(end+1,1) = vals(12);
            else
                pb(end+1,1)   = vals(4);
                pa(end+1,1)   = vals(6);
                uRef(end+1,1) = NaN;
                uSen(end+1,1) = vals(10);
            end

            if isDeadbandFolder
                x(end+1,1) = vals(8) * 1e-3;
            else
                x(end+1,1) = vals(8);
            end
        end

        if numel(t_ms) < 5
            warning('For få datapunkter i %s', files(k).name);
            continue;
        end

        % Main opp: +100 % -> 10 V, 0 % -> 5 V
        if all(isnan(uRef))
            uRef(:) = 5 + 5*(u_percent(k)/100);
        end

        t = t_ms / 1000;

        % Robust hastighet basert på lineær fit av posisjon
        p_x = polyfit(t, x, 1);
        xdot_mean(k) = p_x(1);

        uV_ref_mean(k)    = mean(uRef, 'omitnan');
        uV_sensor_mean(k) = mean(uSen, 'omitnan');

        ps_mean(k) = mean(ps, 'omitnan');
        pa_mean(k) = mean(pa, 'omitnan');
        pb_mean(k) = mean(pb, 'omitnan');

        % Main opp: P -> A
        dp_mean(k) = mean(ps - pa, 'omitnan');

        x_mean(k) = mean(x, 'omitnan');

        switch upper(activeSide)
            case 'A'
                Q = A_piston * abs(xdot_mean(k));
            case 'B'
                Q = A_annulus * abs(xdot_mean(k));
            otherwise
                error('activeSide må være ''A'' eller ''B''.');
        end

        if abs(xdot_mean(k)) < velThreshold || dp_mean(k) <= 0
            Q_mean(k)  = 0;
            Ad_mean(k) = 0;
            Kv_mean(k) = 0;
        else
            dp_Pa = dp_mean(k) * 1e5;
            Q_mean(k)  = Q;
            Ad_mean(k) = Q / (Cd * sqrt(2*dp_Pa/rho));
            Kv_mean(k) = (Q / sqrt(dp_Pa)) * 60000 * sqrt(1e5);
        end
    end

    uV_error = uV_sensor_mean - uV_ref_mean;

    T = table(file_names, u_percent, uV_ref_mean, uV_sensor_mean, uV_error, ...
        ps_mean, pa_mean, pb_mean, dp_mean, ...
        x_mean, xdot_mean, Q_mean, Ad_mean, Kv_mean, ...
        'VariableNames', {'file_name','u_percent','uV_ref','uV_sensor','uV_error', ...
        'ps_bar','pa_bar','pb_bar','dp_bar', ...
        'x_m','xdot_mps','Q_m3ps','Ad_m2','Kv_Lmin_sqrtbar'});
end

%% ===================== HENT PROSENT FRA FILNAVN =====================
function u = hentProsentFraFilnavn(fileName)

    u = NaN;

    name = lower(string(fileName));
    name = replace(name, ',', '.');

    token = regexp(name, '(-?\d+(?:[.-]\d+)?)\s*prosent', 'tokens', 'once');

    if isempty(token)
        token = regexp(name, '(-?\d+(?:[.-]\d+)?)', 'tokens', 'once');
    end

    if isempty(token)
        return;
    end

    txt = string(token{1});

    if startsWith(txt, "-")
        txt = "-" + replace(extractAfter(txt, 1), "-", ".");
    else
        txt = replace(txt, "-", ".");
    end

    u = str2double(txt);
end

%% ===================== TOM TABELL =====================
function T = tomTabell()

    T = table(strings(0,1), zeros(0,1), zeros(0,1), zeros(0,1), zeros(0,1), ...
        zeros(0,1), zeros(0,1), zeros(0,1), zeros(0,1), ...
        zeros(0,1), zeros(0,1), zeros(0,1), zeros(0,1), zeros(0,1), ...
        'VariableNames', {'file_name','u_percent','uV_ref','uV_sensor','uV_error', ...
        'ps_bar','pa_bar','pb_bar','dp_bar', ...
        'x_m','xdot_mps','Q_m3ps','Ad_m2','Kv_Lmin_sqrtbar'});
end