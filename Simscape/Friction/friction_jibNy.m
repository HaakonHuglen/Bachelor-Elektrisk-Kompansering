%% ============================================================
%  COMPARE SIMULATED JIB CYLINDER FORCE WITH MEASURED FORCE
%
%  Includes polynomial fit for:
%       - Extension
%       - Retraction
%% ============================================================

clc;
clear;
close all;

%% ===================== USER SETTINGS =====================

matFile = 'Friction_parametersTuneJib1.mat';
csvFile = 'JibFricRetake.csv';

t_start_sim = 4;

smoothWindow = 35;
velThreshold = 3e-4;

simForceSign = 1;

polyOrder = 3;   % Polynomial order. Try 2, 3 or 4.

%% ===================== JIB CYLINDER GEOMETRY =====================

D_jib    = 0.150;
dRod_jib = 0.100;

A_A_jib = pi * D_jib^2 / 4;
A_B_jib = A_A_jib - pi * dRod_jib^2 / 4;

fprintf('\n================ JIB CYLINDER AREAS ================\n');
fprintf('A_A = %.6f m^2\n', A_A_jib);
fprintf('A_B = %.6f m^2\n', A_B_jib);
fprintf('phi = %.4f\n', A_B_jib/A_A_jib);

%% ===================== LOAD SIMULATION DATA =====================

load(matFile);

posSim   = data{1};
forceSim = data{2};

t_sim = posSim.Values.Time(:);
x_sim = posSim.Values.Data(:);
F_sim = forceSim.Values.Data(:);

idxSim = t_sim >= t_start_sim;

t_sim = t_sim(idxSim);
x_sim = x_sim(idxSim);
F_sim = simForceSign * F_sim(idxSim);

[x_sim_sorted, idxSortSim] = sort(x_sim);
F_sim_sorted = F_sim(idxSortSim);

%% ===================== LOAD MEASURED CSV DATA =====================

T = readTwinCATScopeCSV(csvFile);

posSignal = 'fXReal_mm';
pASignal  = 'fJib_Pa_Cyl_bar';
pBSignal  = 'fJib_Pb_Cyl_bar';

requiredSignals = {posSignal, pASignal, pBSignal};

for i = 1:numel(requiredSignals)
    if ~ismember(requiredSignals{i}, T.Properties.VariableNames)
        error('Signal "%s" was not found in file "%s".', requiredSignals{i}, csvFile);
    end
end

x_meas = T.(posSignal) / 1000;
pA_Pa  = T.(pASignal) * 1e5;
pB_Pa  = T.(pBSignal) * 1e5;

timeColumns = startsWith(T.Properties.VariableNames, 't_');

if ~any(timeColumns)
    error('No time columns were found in file "%s".', csvFile);
end

t_ms = T{:, find(timeColumns, 1, 'first')};
t_meas = t_ms / 1000;

%% ===================== CLEAN MEASURED DATA =====================

t_meas = t_meas(:);
x_meas = x_meas(:);
pA_Pa  = pA_Pa(:);
pB_Pa  = pB_Pa(:);

valid = isfinite(t_meas) & ...
        isfinite(x_meas) & ...
        isfinite(pA_Pa) & ...
        isfinite(pB_Pa);

t_meas = t_meas(valid);
x_meas = x_meas(valid);
pA_Pa  = pA_Pa(valid);
pB_Pa  = pB_Pa(valid);

[t_meas, uniqueIdx] = unique(t_meas, 'stable');

x_meas = x_meas(uniqueIdx);
pA_Pa  = pA_Pa(uniqueIdx);
pB_Pa  = pB_Pa(uniqueIdx);

%% ===================== CALCULATE MEASURED CYLINDER FORCE =====================

F_meas = A_A_jib .* pA_Pa - A_B_jib .* pB_Pa;

x_meas_smooth = movmean(x_meas, smoothWindow, 'omitnan');
F_meas_smooth = movmean(F_meas, smoothWindow, 'omitnan');

v_meas = gradient(x_meas_smooth, t_meas);
v_meas = movmean(v_meas, smoothWindow, 'omitnan');

idxMoving = abs(v_meas) > velThreshold;

x_moving = x_meas_smooth(idxMoving);
F_moving = F_meas_smooth(idxMoving);
v_moving = v_meas(idxMoving);

idxExtend  = v_moving > 0;
idxRetract = v_moving < 0;

x_extend = x_moving(idxExtend);
F_extend = F_moving(idxExtend);

x_retract = x_moving(idxRetract);
F_retract = F_moving(idxRetract);

[x_extend, idxSortExt] = sort(x_extend);
F_extend = F_extend(idxSortExt);

[x_retract, idxSortRet] = sort(x_retract);
F_retract = F_retract(idxSortRet);

%% ===================== POLYNOMIAL FIT =====================

p_extend  = polyfit(x_extend,  F_extend,  polyOrder);
p_retract = polyfit(x_retract, F_retract, polyOrder);

xFit_extend  = linspace(min(x_extend),  max(x_extend),  300);
xFit_retract = linspace(min(x_retract), max(x_retract), 300);

F_fit_extend  = polyval(p_extend,  xFit_extend);
F_fit_retract = polyval(p_retract, xFit_retract);

%% ===================== PRINT POLYNOMIALS =====================

fprintf('\n================ JIB POLYNOMIALS ================\n');

fprintf('\nExtension polynomial coefficients:\n');
disp(p_extend);

fprintf('F_extend(x) = ');
for i = 1:numel(p_extend)
    power = polyOrder - i + 1;
    fprintf('%.6e*x^%d', p_extend(i), power);
    if i < numel(p_extend)
        fprintf(' + ');
    end
end
fprintf('\n');

fprintf('\nRetraction polynomial coefficients:\n');
disp(p_retract);

fprintf('F_retract(x) = ');
for i = 1:numel(p_retract)
    power = polyOrder - i + 1;
    fprintf('%.6e*x^%d', p_retract(i), power);
    if i < numel(p_retract)
        fprintf(' + ');
    end
end
fprintf('\n');

%% ===================== PLOT FORCE VS POSITION =====================

figure('Name','Jib cylinder force: simulation vs measured','Color','w');

plot(x_sim_sorted, F_sim_sorted, 'k', 'LineWidth', 2.0);
hold on;

plot(x_extend, F_extend, '.', 'MarkerSize', 8);
plot(x_retract, F_retract, '.', 'MarkerSize', 8);

plot(xFit_extend, F_fit_extend, '--', 'LineWidth', 2.5);
plot(xFit_retract, F_fit_retract, '--', 'LineWidth', 2.5);

grid on;
xlabel('Cylinder position [m]');
ylabel('Cylinder force [N]');
title('Jib cylinder force over position');

legend( ...
    'Simulation', ...
    'Measured extend', ...
    'Measured retract', ...
    'Polynomial extend', ...
    'Polynomial retract', ...
    'Location','best');

%% ===================== OPTIONAL: FORCE VS TIME =====================

figure('Name','Jib simulation force over time','Color','w');

plot(t_sim, F_sim, 'LineWidth', 1.8);

grid on;
xlabel('Time [s]');
ylabel('Simulated cylinder force [N]');
title('Simulated jib cylinder force over time');

%% ===================== PRINT CHECK VALUES =====================

fprintf('\n================ JIB FORCE CHECK ================\n');
fprintf('MAT file: %s\n', matFile);
fprintf('CSV file: %s\n', csvFile);

fprintf('\nMeasured force from CSV:\n');
fprintf('Mean force, moving data: %.2f kN\n', mean(F_moving, 'omitnan')/1000);
fprintf('Mean force, extend:      %.2f kN\n', mean(F_extend, 'omitnan')/1000);
fprintf('Mean force, retract:     %.2f kN\n', mean(F_retract, 'omitnan')/1000);

fprintf('\nSimulation force after %.2f s:\n', t_start_sim);
fprintf('Mean simulation force:   %.2f kN\n', mean(F_sim, 'omitnan')/1000);
fprintf('Min simulation force:    %.2f kN\n', min(F_sim)/1000);
fprintf('Max simulation force:    %.2f kN\n', max(F_sim)/1000);

%% ============================================================
%  LOCAL FUNCTION: READ TWINCAT SCOPE CSV
%% ============================================================

function T = readTwinCATScopeCSV(fileName)

    fid = fopen(fileName, 'r');

    if fid == -1
        error('Could not open file: %s', fileName);
    end

    nHeaderLines = 8;
    lines = strings(nHeaderLines,1);

    for i = 1:nHeaderLines
        lines(i) = string(fgetl(fid));
    end

    fclose(fid);

    headerLine = "";

    for i = 1:numel(lines)
        if contains(lines(i), 'Name;')
            headerLine = lines(i);
        end
    end

    if headerLine == ""
        error('Could not find TwinCAT signal header line in file "%s".', fileName);
    end

    parts = split(headerLine, ';');

    signalNames = {};

    for i = 2:2:numel(parts)

        name = strtrim(parts(i));

        if strlength(name) > 0
            signalNames{end+1} = char(name); %#ok<AGROW>
        end

    end

    raw = readtable(fileName, ...
        'FileType','text', ...
        'Delimiter',';', ...
        'DecimalSeparator','.', ...
        'NumHeaderLines',nHeaderLines, ...
        'ReadVariableNames',false);

    emptyCols = false(1,width(raw));

    for i = 1:width(raw)
        emptyCols(i) = all(ismissing(raw{:,i}));
    end

    raw(:,emptyCols) = [];

    varNames = {};

    for i = 1:numel(signalNames)

        varNames{end+1} = ['t_' signalNames{i}]; %#ok<AGROW>
        varNames{end+1} = signalNames{i};        %#ok<AGROW>

    end

    nCols = min(width(raw), numel(varNames));

    raw = raw(:,1:nCols);
    raw.Properties.VariableNames = matlab.lang.makeValidName(varNames(1:nCols));

    T = raw;

end