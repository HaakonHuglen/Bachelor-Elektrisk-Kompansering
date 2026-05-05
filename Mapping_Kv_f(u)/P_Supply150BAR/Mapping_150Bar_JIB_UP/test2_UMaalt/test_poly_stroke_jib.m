clc;
clear;
close all;

%% ===================== SETTINGS =====================
folderPathMain  = 'C:\Users\hakon\OneDrive - Universitetet i Agder\Skrivebord\BACHELOR_PROSJEKT\Bachelor-Oppgave---Elektrisk-Kompansering\Mapping_Kv_f(u)\P_Supply150BAR\Mapping_150Bar_JIB_UP\Test2_UMaalt';
folderPathExtra = 'C:\Users\hakon\OneDrive - Universitetet i Agder\Skrivebord\BACHELOR_PROSJEKT\Bachelor-Oppgave---Elektrisk-Kompansering\Mapping_Kv_f(u)\P_Supply150BAR\Mapping_150Bar_JIB_UP\Dødbånd';

dc   = 0.150;   % [m]
drod = 0.100;   % [m]

A_piston  = pi*dc^2/4;
A_annulus = A_piston - pi*drod^2/4;

activeSide = 'A';   % Jib opp -> P til A

Cd  = 0.64;
rho = 850;

velThreshold = 1e-5;

polyDeg_uKv = 5;    % polynom for u = f(Kv)

%% ===================== STROKE CORRECTION POLYNOMIAL =====================
% x_real_mm = f(x_twincat_mm)
pStroke = [-2.6766141745e-05, ...
            9.9764623655e-01, ...
            1.8743836626e+01];

%% ===================== READ DATA =====================
T_main_raw  = lesMappeJibOpp_KvCompare(folderPathMain,  false, false, pStroke, activeSide, A_piston, A_annulus, Cd, rho, velThreshold);
T_extra_raw = lesMappeJibOpp_KvCompare(folderPathExtra, true,  false, pStroke, activeSide, A_piston, A_annulus, Cd, rho, velThreshold);

T_main_corr  = lesMappeJibOpp_KvCompare(folderPathMain,  false, true, pStroke, activeSide, A_piston, A_annulus, Cd, rho, velThreshold);
T_extra_corr = lesMappeJibOpp_KvCompare(folderPathExtra, true,  true, pStroke, activeSide, A_piston, A_annulus, Cd, rho, velThreshold);

T_raw  = sortrows([T_main_raw;  T_extra_raw],  'u_percent');
T_corr = sortrows([T_main_corr; T_extra_corr], 'u_percent');

T_raw  = T_raw(~isnan(T_raw.u_percent), :);
T_corr = T_corr(~isnan(T_corr.u_percent), :);

%% ===================== EXTRACT VARIABLES =====================
u_raw  = T_raw.u_percent;
Kv_raw = T_raw.Kv_Lmin_sqrtbar;

u_corr  = T_corr.u_percent;
Kv_corr = T_corr.Kv_Lmin_sqrtbar;

%% ===================== PLOT Kv AGAINST u =====================
figure;
plot(u_raw, Kv_raw, 'o-', 'LineWidth', 1.5, 'MarkerSize', 7);
hold on;
plot(u_corr, Kv_corr, 's-', 'LineWidth', 1.5, 'MarkerSize', 7);
grid on;

xlabel('u [%]');
ylabel('K_v [L/(min \cdot \surdbar)]');
title('Effect of jib stroke correction on K_v - Jib opp 150 bar');
legend('Without stroke correction', 'With stroke correction', 'Location', 'best');

%% ===================== COMPARE TABLE =====================
compareTable = table(T_corr.file_name, u_corr, ...
    T_raw.xdot_mps, T_corr.xdot_mps, ...
    T_raw.Kv_Lmin_sqrtbar, T_corr.Kv_Lmin_sqrtbar, ...
    T_corr.Kv_Lmin_sqrtbar - T_raw.Kv_Lmin_sqrtbar, ...
    'VariableNames', {'file_name','u_percent', ...
    'xdot_raw','xdot_corrected', ...
    'Kv_raw','Kv_corrected','Delta_Kv'});

disp('Comparison between raw and corrected Kv:');
disp(compareTable);

%% ===================== u = f(Kv) USING CORRECTED DATA =====================
valid = ~isnan(Kv_corr) & Kv_corr > 0 & ~isnan(u_corr);

Kv_fit = Kv_corr(valid);

% Jib opp -> direkte positivt TwinCAT-signal
u_fit_target = u_corr(valid) / 100;

p_uKv = polyfit(Kv_fit, u_fit_target, polyDeg_uKv);

u_pred = polyval(p_uKv, Kv_fit);

SS_res = sum((u_fit_target - u_pred).^2);
SS_tot = sum((u_fit_target - mean(u_fit_target)).^2);
R2 = 1 - SS_res / SS_tot;

%% ===================== PLOT u = f(Kv) =====================
Kv_dense = linspace(min(Kv_fit), max(Kv_fit), 300);
u_dense  = polyval(p_uKv, Kv_dense);

figure;
plot(Kv_fit, u_fit_target, 'o', 'MarkerSize', 7, 'LineWidth', 1.5);
hold on;
plot(Kv_dense, u_dense, '-', 'LineWidth', 1.8);
grid on;

xlabel('K_v [L/(min \cdot \surdbar)]');
ylabel('u_{ctrl} [-]');
title('TwinCAT-polynom with stroke correction: u_{FF} = f(K_v) - Jib opp 150 bar');
legend('Corrected data points', ...
    sprintf('Polynomial degree %d | R^2 = %.4f', polyDeg_uKv, R2), ...
    'Location', 'best');

%% ===================== PRINT TWINCAT RESULT =====================
fprintf('\n====================================================\n');
fprintf('TwinCAT-polynom: JIB OPP 150 bar WITH STROKE CORRECTION\n');
fprintf('====================================================\n');

fprintf('Definitions:\n');
fprintf('Stroke correction:\n');
fprintf('x_real_mm = -2.6766141745e-05*x_twincat_mm^2 + 9.9764623655e-01*x_twincat_mm + 1.8743836626e+01\n\n');

fprintf('Q  = A_piston * abs(xdot_corrected) * 60000 [L/min]\n');
fprintf('dp = ps - pa                                [bar]\n');
fprintf('Kv = Q / sqrt(dp)                           [L/(min*sqrt(bar))]\n');
fprintf('u_ctrl = u_percent / 100                    [-], direct positive signal\n\n');

fprintf('Polynomial degree: %d\n', polyDeg_uKv);
fprintf('R^2 = %.6f\n\n', R2);

fprintf('Coefficients from highest degree to constant term:\n');
disp(p_uKv);

fprintf('TwinCAT Structured Text:\n');
fprintf('fU_FF := ');
for j = 1:numel(p_uKv)
    expVal = polyDeg_uKv - j + 1;
    coeff = p_uKv(j);

    if j > 1
        if coeff >= 0
            fprintf('\n        +');
        else
            fprintf('\n        ');
        end
    end

    if expVal > 1
        fprintf('%.10e * EXPT(fKv, %d)', coeff, expVal);
    elseif expVal == 1
        fprintf('%.10e * fKv', coeff);
    else
        fprintf('%.10e', coeff);
    end
end
fprintf(';\n');

fprintf('====================================================\n\n');

%% ===================== FUNCTION: READ FOLDER =====================
function T = lesMappeJibOpp_KvCompare(folderPath, isDeadbandFolder, useStrokeCorrection, pStroke, activeSide, A_piston, A_annulus, Cd, rho, velThreshold)

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

    file_names = strings(nFiles,1);
    u_percent  = nan(nFiles,1);

    ps_mean   = nan(nFiles,1);
    pa_mean   = nan(nFiles,1);
    pb_mean   = nan(nFiles,1);
    dp_mean   = nan(nFiles,1);

    x_mean    = nan(nFiles,1);
    xdot_mean = nan(nFiles,1);
    Q_mean    = nan(nFiles,1);
    Ad_mean   = nan(nFiles,1);
    Kv_mean   = nan(nFiles,1);

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

        headerIdx = find(contains(rawLines, 'fPresSupply_bar'), 1);

        if ~isempty(headerIdx)

            headerParts = split(strtrim(rawLines(headerIdx)), ';');

            signalNames = strings(0);
            for j = 2:2:numel(headerParts)
                signalNames(end+1,1) = strtrim(headerParts(j));
            end

            idx_ps  = find(signalNames == "fPresSupply_bar", 1);
            idx_pa  = find(signalNames == "fPres1A_bar",     1);
            idx_pb  = find(signalNames == "fPres1B_bar",     1);

            idx_xm  = find(signalNames == "fCylinder1_m",    1);
            idx_xmm = find(signalNames == "fCylinder1_mm",   1);

            if ~isempty(idx_xm)
                idx_x = idx_xm;
                xScale = 1.0;
            elseif ~isempty(idx_xmm)
                idx_x = idx_xmm;
                xScale = 1e-3;
            else
                idx_x = [];
                xScale = NaN;
            end

            if ~isempty(idx_ps) && ~isempty(idx_pa) && ~isempty(idx_pb) && ~isempty(idx_x)

                for i = headerIdx+1:numel(rawLines)

                    line = strtrim(rawLines(i));

                    if line == "" || line == "EOF" || ...
                       contains(line, 'Name') || contains(line, 'File') || ...
                       contains(line, 'Start') || contains(line, 'End')
                        continue;
                    end

                    line  = replace(line, ',', '.');
                    parts = split(line, ';');

                    if numel(parts) < 2*numel(signalNames)
                        continue;
                    end

                    vals = str2double(parts(1:2*numel(signalNames)));

                    if any(isnan(vals))
                        continue;
                    end

                    valVals = vals(2:2:end);

                    t_ms(end+1,1) = vals(1);
                    ps(end+1,1)   = valVals(idx_ps);
                    pa(end+1,1)   = valVals(idx_pa);
                    pb(end+1,1)   = valVals(idx_pb);
                    x(end+1,1)    = valVals(idx_x) * xScale;
                end
            end
        end

        % Fallback for fixed column format
        if numel(t_ms) < 5

            t_ms = [];
            ps   = [];
            pa   = [];
            pb   = [];
            x    = [];

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

                if numel(vals) >= 12
                    t_ms(end+1,1) = vals(1);
                    ps(end+1,1)   = vals(2);
                    pa(end+1,1)   = vals(4);
                    pb(end+1,1)   = vals(6);

                    if isDeadbandFolder
                        x(end+1,1) = vals(8) * 1e-3;
                    else
                        x(end+1,1) = vals(8);
                    end
                else
                    t_ms(end+1,1) = vals(1);
                    ps(end+1,1)   = vals(2);
                    pb(end+1,1)   = vals(4);
                    pa(end+1,1)   = vals(6);

                    if isDeadbandFolder
                        x(end+1,1) = vals(8) * 1e-3;
                    else
                        x(end+1,1) = vals(8);
                    end
                end
            end
        end

        if numel(t_ms) < 5
            warning('For få datapunkter i %s', files(k).name);
            continue;
        end

        t = t_ms / 1000;

        if useStrokeCorrection
            x_mm = x * 1000;
            x_corr_mm = polyval(pStroke, x_mm);
            x_used = x_corr_mm / 1000;
        else
            x_used = x;
        end

        p_x = polyfit(t, x_used, 1);
        xdot_mean(k) = p_x(1);

        ps_mean(k) = mean(ps, 'omitnan');
        pa_mean(k) = mean(pa, 'omitnan');
        pb_mean(k) = mean(pb, 'omitnan');

        % Jib opp: P -> A
        dp_mean(k) = mean(ps - pa, 'omitnan');

        x_mean(k) = mean(x_used, 'omitnan');

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

            % Kv = Q/sqrt(dp), Q in L/min and dp in bar
            Kv_mean(k) = (Q * 60000) / sqrt(dp_mean(k));
        end
    end

    T = table(file_names, u_percent, ps_mean, pa_mean, pb_mean, dp_mean, ...
        x_mean, xdot_mean, Q_mean, Ad_mean, Kv_mean, ...
        'VariableNames', {'file_name','u_percent', ...
        'ps_bar','pa_bar','pb_bar','dp_bar', ...
        'x_m','xdot_mps','Q_m3ps','Ad_m2','Kv_Lmin_sqrtbar'});
end

%% ===================== READ PERCENT FROM FILENAME =====================
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

%% ===================== EMPTY TABLE =====================
function T = tomTabell()

    T = table(strings(0,1), zeros(0,1), ...
        zeros(0,1), zeros(0,1), zeros(0,1), zeros(0,1), ...
        zeros(0,1), zeros(0,1), zeros(0,1), zeros(0,1), zeros(0,1), ...
        'VariableNames', {'file_name','u_percent', ...
        'ps_bar','pa_bar','pb_bar','dp_bar', ...
        'x_m','xdot_mps','Q_m3ps','Ad_m2','Kv_Lmin_sqrtbar'});
end