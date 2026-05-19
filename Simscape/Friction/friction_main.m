%% ============================================================
%  COMPARE SIMULATED CYLINDER FORCE WITH MEASURED CYLINDER FORCE
%% ============================================================

clc;
clear;
close all;

%% ===================== USER SETTINGS =====================

compareCylinder = 'main';

matFile  = 'friction_testMain09.05.mat';
mainFile = 'MainFrictionRetake.csv';
jibFile  = 'JibFrictionRetake.csv';

t_start_sim  = 6.0;   % [s]
t_start_meas = 6.3;   % [s] fjern målte data før dette tidspunktet

smoothWindow = 35;
pressureSmoothWindow = 25;
velThreshold = 3e-4;

%% ===================== CYLINDER GEOMETRY =====================

D_main    = 0.160;
dRod_main = 0.100;

A_A_main = pi * D_main^2 / 4;
A_B_main = A_A_main - pi * dRod_main^2 / 4;

D_jib    = 0.150;
dRod_jib = 0.100;

A_A_jib = pi * D_jib^2 / 4;
A_B_jib = A_A_jib - pi * dRod_jib^2 / 4;

%% ===================== SELECT CYLINDER SETTINGS =====================

switch lower(compareCylinder)

    case 'main'

        csvFile = mainFile;

        posSignal = 'fXReal_mm';
        pASignal  = 'fMain_Pa_Cyl_bar';
        pBSignal  = 'fMain_Pb_bar';

        A_A = A_A_main;
        A_B = A_B_main;

        plotTitle = 'Main cylinder force comparison';

    case 'jib'

        csvFile = jibFile;

        posSignal = 'fXReal_mm';
        pASignal  = 'fJib_Pa_Cyl_bar';
        pBSignal  = 'fJib_Pb_Cyl_bar';

        A_A = A_A_jib;
        A_B = A_B_jib;

        plotTitle = 'Jib cylinder force comparison';

    otherwise

        error('compareCylinder must be either "main" or "jib".');
end

fprintf('\n================ SELECTED CYLINDER ================\n');
fprintf('Cylinder: %s\n', compareCylinder);
fprintf('A_A = %.6f m^2\n', A_A);
fprintf('A_B = %.6f m^2\n', A_B);
fprintf('phi = %.4f\n', A_B/A_A);

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
F_sim = F_sim(idxSim);

[x_sim_sorted, idxSortSim] = sort(x_sim);
F_sim_sorted = F_sim(idxSortSim);

%% ===================== LOAD MEASURED CSV DATA =====================

T = readTwinCATScopeCSV(csvFile);

requiredSignals = {posSignal, pASignal, pBSignal};

for i = 1:numel(requiredSignals)
    if ~ismember(requiredSignals{i}, T.Properties.VariableNames)
        error('Signal "%s" was not found in file "%s".', requiredSignals{i}, csvFile);
    end
end

%% ===================== EXTRACT MEASURED DATA =====================

x_meas = T.(posSignal) / 1000;

pA_bar = T.(pASignal);
pB_bar = T.(pBSignal);

timeColumns = startsWith(T.Properties.VariableNames, 't_');

if ~any(timeColumns)
    error('No time columns found in "%s".', csvFile);
end

t_ms = T{:, find(timeColumns, 1, 'first')};
t_meas = t_ms / 1000;

%% ===================== COLUMN VECTORS =====================

t_meas = t_meas(:);
x_meas = x_meas(:);
pA_bar = pA_bar(:);
pB_bar = pB_bar(:);

%% ===================== REMOVE INVALID VALUES =====================

valid = isfinite(t_meas) & ...
        isfinite(x_meas) & ...
        isfinite(pA_bar) & ...
        isfinite(pB_bar);

t_meas = t_meas(valid);
x_meas = x_meas(valid);
pA_bar = pA_bar(valid);
pB_bar = pB_bar(valid);

%% ===================== REMOVE DUPLICATE TIME VALUES =====================

[t_meas, uniqueTimeIdx] = unique(t_meas, 'stable');

x_meas = x_meas(uniqueTimeIdx);
pA_bar = pA_bar(uniqueTimeIdx);
pB_bar = pB_bar(uniqueTimeIdx);

%% ===================== REMOVE INITIAL MEASURED DATA =====================

idxMeas = t_meas >= t_start_meas;

t_meas = t_meas(idxMeas);
x_meas = x_meas(idxMeas);
pA_bar = pA_bar(idxMeas);
pB_bar = pB_bar(idxMeas);

t_meas = t_meas - t_meas(1);

%% ===================== SMOOTH PRESSURE DATA =====================

pA_bar = smoothdata(pA_bar, 'movmean', pressureSmoothWindow);
pB_bar = smoothdata(pB_bar, 'movmean', pressureSmoothWindow);

%% ===================== CONVERT PRESSURE TO PA =====================

pA = pA_bar * 1e5;
pB = pB_bar * 1e5;

%% ===================== CALCULATE MEASURED CYLINDER FORCE =====================

F_meas = A_A .* pA - A_B .* pB;

x_meas_smooth = movmean(x_meas, smoothWindow, 'omitnan');
F_meas_smooth = movmean(F_meas, smoothWindow, 'omitnan');

v_meas = gradient(x_meas_smooth, t_meas);
v_meas = movmean(v_meas, smoothWindow, 'omitnan');

idxMoving = abs(v_meas) > velThreshold;

x_meas_moving = x_meas_smooth(idxMoving);
F_meas_moving = F_meas_smooth(idxMoving);
v_meas_moving = v_meas(idxMoving);

idxExtend  = v_meas_moving > 0;
idxRetract = v_meas_moving < 0;

x_extend = x_meas_moving(idxExtend);
F_extend = F_meas_moving(idxExtend);

x_retract = x_meas_moving(idxRetract);
F_retract = F_meas_moving(idxRetract);

[x_extend, idxSortExt] = sort(x_extend);
F_extend = F_extend(idxSortExt);

[x_retract, idxSortRet] = sort(x_retract);
F_retract = F_retract(idxSortRet);

%% ===================== PLOT FORCE VS POSITION =====================

figure('Name','Simulation vs measured cylinder force','Color','w');

plot(x_sim_sorted, F_sim_sorted, 'k', 'LineWidth', 0.6);
hold on;

plot(x_extend, F_extend, 'LineWidth', 0.6);
plot(x_retract, F_retract, 'LineWidth', 0.6);

grid on;

xlabel('Cylinder position [m]');
ylabel('Cylinder force [N]');

title(plotTitle);

legend( ...
    'Simulation', ...
    'Measured extend', ...
    'Measured retract', ...
    'Location','best');

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

    raw.Properties.VariableNames = ...
        matlab.lang.makeValidName(varNames(1:nCols));

    T = raw;

end