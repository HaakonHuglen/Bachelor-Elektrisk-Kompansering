%% ============================================================
%  COMPARE SIMULATED CYLINDER FORCE WITH MEASURED CYLINDER FORCE
%
%  Includes:
%   - Low-pass filtering of pressures
%   - Removal of invalid samples
%   - Velocity-based movement detection
%   - Polynomial fit for extension/retraction
%
%% ============================================================

clc;
clear;
close all;

%% ===================== USER SETTINGS =====================

compareCylinder = 'main';

matFile  = 'friction_testMain09.05.mat';

mainFile = 'MainFrictionRetake.csv';
jibFile  = 'JibFrictionRetake.csv';

t_start_sim = 6.0;

smoothWindow = 35;
velThreshold = 3e-4;

polyOrder = 3;

%% ===================== CYLINDER GEOMETRY =====================

% Main cylinder
D_main    = 0.160;
dRod_main = 0.100;

A_A_main = pi * D_main^2 / 4;
A_B_main = A_A_main - pi * dRod_main^2 / 4;

% Jib cylinder
D_jib    = 0.150;
dRod_jib = 0.100;

A_A_jib = pi * D_jib^2 / 4;
A_B_jib = A_A_jib - pi * dRod_jib^2 / 4;

%% ===================== SELECT CYLINDER =====================

switch lower(compareCylinder)

    case 'main'

        csvFile = mainFile;

        posSignal = 'fXReal_mm';

        pASignal = 'fMain_Pa_Cyl_bar';

        % fMain_Pb_Cyl_bar is zero
        pBSignal = 'fMain_Pb_bar';

        A_A = A_A_main;
        A_B = A_B_main;

        plotTitle = 'Main cylinder force comparison';

    case 'jib'

        csvFile = jibFile;

        posSignal = 'fXReal_mm';

        pASignal = 'fJib_Pa_Cyl_bar';
        pBSignal = 'fJib_Pb_Cyl_bar';

        A_A = A_A_jib;
        A_B = A_B_jib;

        plotTitle = 'Jib cylinder force comparison';

    otherwise

        error('compareCylinder must be either "main" or "jib".');

end

fprintf('\n================ SELECTED CYLINDER ================\n');
fprintf('Cylinder: %s\n', compareCylinder);

%% ===================== LOAD SIMULATION DATA =====================

load(matFile);

posSim   = data{1};
forceSim = data{2};

t_sim = posSim.Values.Time(:);
x_sim = posSim.Values.Data(:);
F_sim = forceSim.Values.Data(:);

% Remove transient
idxSim = t_sim >= t_start_sim;

t_sim = t_sim(idxSim);
x_sim = x_sim(idxSim);
F_sim = F_sim(idxSim);

% Sort simulation data
[x_sim_sorted, idxSortSim] = sort(x_sim);
F_sim_sorted = F_sim(idxSortSim);

%% ===================== LOAD CSV DATA =====================

T = readTwinCATScopeCSV(csvFile);

requiredSignals = {posSignal, pASignal, pBSignal};

for i = 1:numel(requiredSignals)

    if ~ismember(requiredSignals{i}, T.Properties.VariableNames)

        error('Signal "%s" not found.', requiredSignals{i});

    end
end

%% ===================== EXTRACT DATA =====================

x_meas = T.(posSignal) / 1000;

pA_bar_raw = T.(pASignal);
pB_bar_raw = T.(pBSignal);

timeColumns = startsWith(T.Properties.VariableNames, 't_');

if ~any(timeColumns)
    error('No time columns found.');
end

t_ms = T{:, find(timeColumns,1,'first')};

t_meas = t_ms / 1000;

%% ===================== COLUMN VECTORS =====================

t_meas     = t_meas(:);
x_meas     = x_meas(:);
pA_bar_raw = pA_bar_raw(:);
pB_bar_raw = pB_bar_raw(:);

%% ===================== REMOVE INVALID VALUES =====================

valid = isfinite(t_meas) & ...
        isfinite(x_meas) & ...
        isfinite(pA_bar_raw) & ...
        isfinite(pB_bar_raw);

t_meas     = t_meas(valid);
x_meas     = x_meas(valid);
pA_bar_raw = pA_bar_raw(valid);
pB_bar_raw = pB_bar_raw(valid);

%% ===================== REMOVE DUPLICATE TIME =====================

[t_meas, uniqueIdx] = unique(t_meas, 'stable');

x_meas     = x_meas(uniqueIdx);
pA_bar_raw = pA_bar_raw(uniqueIdx);
pB_bar_raw = pB_bar_raw(uniqueIdx);

%% ===================== LOW PASS FILTER =====================

Fs = 100;
Fc = 2;

[b, a] = butter(2, Fc/(Fs/2), 'low');

pA_bar = filtfilt(b, a, pA_bar_raw);
pB_bar = filtfilt(b, a, pB_bar_raw);

%% ===================== CONVERT TO PA =====================

pA = pA_bar * 1e5;
pB = pB_bar * 1e5;

%% ===================== CALCULATE FORCE =====================

F_meas = A_A .* pA - A_B .* pB;

%% ===================== SMOOTHING =====================

x_meas_smooth = movmean(x_meas, smoothWindow, 'omitnan');
F_meas_smooth = movmean(F_meas, smoothWindow, 'omitnan');

%% ===================== VELOCITY =====================

v_meas = gradient(x_meas_smooth, t_meas);

v_meas = movmean(v_meas, smoothWindow, 'omitnan');

%% ===================== KEEP MOVING DATA =====================

idxMoving = abs(v_meas) > velThreshold;

x_meas_moving = x_meas_smooth(idxMoving);
F_meas_moving = F_meas_smooth(idxMoving);
v_meas_moving = v_meas(idxMoving);

%% ===================== SPLIT EXTEND / RETRACT =====================

idxExtend  = v_meas_moving > 0;
idxRetract = v_meas_moving < 0;

x_extend = x_meas_moving(idxExtend);
F_extend = F_meas_moving(idxExtend);

x_retract = x_meas_moving(idxRetract);
F_retract = F_meas_moving(idxRetract);

%% ===================== SORT DATA =====================

[x_extend, idxExt] = sort(x_extend);
F_extend = F_extend(idxExt);

[x_retract, idxRet] = sort(x_retract);
F_retract = F_retract(idxRet);

%% ===================== POLYNOMIAL FIT =====================

p_extend  = polyfit(x_extend,  F_extend,  polyOrder);
p_retract = polyfit(x_retract, F_retract, polyOrder);

xFit_extend = linspace(min(x_extend), max(x_extend), 300);
xFit_retract = linspace(min(x_retract), max(x_retract), 300);

F_fit_extend = polyval(p_extend, xFit_extend);
F_fit_retract = polyval(p_retract, xFit_retract);

%% ===================== PRINT POLYNOMIALS =====================

fprintf('\n================ POLYNOMIALS ================\n');

fprintf('\nEXTEND:\n');
disp(p_extend);

fprintf('\nRETRACT:\n');
disp(p_retract);

%% ===================== PLOT FORCE VS POSITION =====================

figure('Color','w');

%plot(x_sim_sorted, F_sim_sorted, ...
   % 'k', 'LineWidth', 2.0);

hold on;

plot(x_extend, F_extend, ...
    '.', 'MarkerSize', 8);

plot(x_retract, F_retract, ...
    '.', 'MarkerSize', 8);

plot(xFit_extend, F_fit_extend, ...
    '--', 'LineWidth', 2.5);

plot(xFit_retract, F_fit_retract, ...
    '--', 'LineWidth', 2.5);

grid on;

xlabel('Cylinder position [m]');
ylabel('Cylinder force [N]');

title(plotTitle);

legend( ...
    'Simulation', ...
    'Measured extend', ...
    'Measured retract', ...
    'Polynomial extend', ...
    'Polynomial retract', ...
    'Location','best');

%% ===================== OPTIONAL TIME PLOT =====================

figure('Color','w');

plot(t_sim, F_sim, 'LineWidth', 1.8);

grid on;

xlabel('Time [s]');
ylabel('Cylinder force [N]');

title('Simulated cylinder force');

%% ===================== PRINT FORCE CHECK =====================

fprintf('\n================ FORCE CHECK ================\n');

fprintf('Mean measured force: %.2f kN\n', ...
    mean(F_meas_moving,'omitnan')/1000);

fprintf('Mean extend force: %.2f kN\n', ...
    mean(F_extend,'omitnan')/1000);

fprintf('Mean retract force: %.2f kN\n', ...
    mean(F_retract,'omitnan')/1000);

fprintf('Mean simulation force: %.2f kN\n', ...
    mean(F_sim,'omitnan')/1000);

%% ============================================================
%  LOCAL FUNCTION
%% ============================================================

function T = readTwinCATScopeCSV(fileName)

    fid = fopen(fileName, 'r');

    if fid == -1
        error('Could not open file.');
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
        error('Could not find signal header.');
    end

    parts = split(headerLine, ';');

    signalNames = {};

    for i = 2:2:numel(parts)

        name = strtrim(parts(i));

        if strlength(name) > 0

            signalNames{end+1} = char(name);

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

        varNames{end+1} = ['t_' signalNames{i}];
        varNames{end+1} = signalNames{i};

    end

    nCols = min(width(raw), numel(varNames));

    raw = raw(:,1:nCols);

    raw.Properties.VariableNames = ...
        matlab.lang.makeValidName(varNames(1:nCols));

    T = raw;

end