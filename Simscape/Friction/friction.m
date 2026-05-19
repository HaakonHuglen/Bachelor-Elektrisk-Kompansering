%% ============================================================
%  CYLINDER FRICTION ESTIMATION
%
%  Files:
%       MainHard1.csv
%       JibHard1 (1).csv
%
%  Method:
%       F_hyd = A_A*p_A - A_B*p_B
%
%       F_fric = abs(F_extend - F_retract)/2
%
%  Pressures are assumed to be in bar.
%  Positions are assumed to be in mm.
%
%  IMPORTANT:
%       Main uses:
%           p_A = fMain_Pa_Cyl_bar
%           p_B = fMain_Pb_bar
%
%       Jib uses:
%           p_A = fJib_Pa_Cyl_bar
%           p_B = fJib_Pb_Cyl_bar
%
%       Both files use fXReal_mm as the measured cylinder position.
%% ============================================================

clc;
clear;
close all;

%% ===================== USER SETTINGS =====================

mainFile = 'MainHard1.csv';
jibFile  = 'JibHard2.csv';

%% ===================== CYLINDER GEOMETRY =====================

% Main cylinder geometry
D_main    = 0.160;   % Main bore diameter [m]
dRod_main = 0.100;   % Main rod diameter [m]

A_A_main = pi * D_main^2 / 4;                 % Main piston-side area [m^2]
A_B_main = A_A_main - pi * dRod_main^2 / 4;   % Main annulus-side area [m^2]

% Jib cylinder geometry
D_jib    = 0.150;    % Jib bore diameter [m]
dRod_jib = 0.100;    % Jib rod diameter [m]

A_A_jib = pi * D_jib^2 / 4;                   % Jib piston-side area [m^2]
A_B_jib = A_A_jib - pi * dRod_jib^2 / 4;      % Jib annulus-side area [m^2]

% Print area values for verification
fprintf('\n================ CYLINDER AREAS ================\n');
fprintf('Main A_A = %.6f m^2\n', A_A_main);
fprintf('Main A_B = %.6f m^2\n', A_B_main);
fprintf('Main phi = %.4f\n', A_B_main/A_A_main);

fprintf('\nJib  A_A = %.6f m^2\n', A_A_jib);
fprintf('Jib  A_B = %.6f m^2\n', A_B_jib);
fprintf('Jib  phi = %.4f\n', A_B_jib/A_A_jib);

%% ===================== FILTERING SETTINGS =====================

velThreshold   = 3e-4;   % Minimum velocity for valid motion [m/s]
smoothWindow   = 35;     % Moving average window for stroke and force
removeFraction = 0.10;   % Remove 10% from start/end of each movement section
nInterp        = 300;    % Number of interpolation points

%% ===================== TIME RANGE SETTINGS =====================
% Only data inside these time intervals are used.
% Use inf as end time if you want to use the rest of the test.

mainTimeMin = 15.0;   % [s]
mainTimeMax = inf;    % [s]

jibTimeMin  = 15.0;   % [s]
jibTimeMax  = inf;    % [s]

%% ===================== STABLE STROKE RANGES =====================
% These ranges are used only for reporting the final friction values.
% They should be inside the measured stroke range after time filtering.

mainStableMin = 0.250;   % [m]
mainStableMax = 0.380;   % [m]

jibStableMin  = 0.200;   % [m]
jibStableMax  = 0.340;   % [m]

%% ===================== PROCESS MAIN CYLINDER =====================

main = processFrictionFile( ...
    mainFile, ...
    'fXReal_mm', ...
    'fMain_Pa_Cyl_bar', ...
    'fMain_Pb_bar', ...              % fMain_Pb_Cyl_bar is zero in this file
    A_A_main, A_B_main, ...
    velThreshold, smoothWindow, removeFraction, nInterp, ...
    mainTimeMin, mainTimeMax);

%% ===================== PROCESS JIB CYLINDER =====================

jib = processFrictionFile( ...
    jibFile, ...
    'fXReal_mm', ...
    'fJib_Pa_Cyl_bar', ...
    'fJib_Pb_Cyl_bar', ...
    A_A_jib, A_B_jib, ...
    velThreshold, smoothWindow, removeFraction, nInterp, ...
    jibTimeMin, jibTimeMax);

%% ===================== SELECT STABLE STROKE RANGE =====================

mainValidRange = main.strokeCommon > mainStableMin & main.strokeCommon < mainStableMax;
jibValidRange  = jib.strokeCommon  > jibStableMin  & jib.strokeCommon  < jibStableMax;

mainFricStable = main.frictionForce(mainValidRange);
jibFricStable  = jib.frictionForce(jibValidRange);

mainStrokeStable = main.strokeCommon(mainValidRange);
jibStrokeStable  = jib.strokeCommon(jibValidRange);

%% ===================== FORCE PLOTS =====================

figure('Name','Hydraulic cylinder force','Color','w');

subplot(1,2,1);
plot(main.strokeExtend, main.forceExtend, 'LineWidth', 1.8);
hold on;
plot(main.strokeRetract, main.forceRetract, 'LineWidth', 1.8);
grid on;
xlabel('Piston stroke [m]');
ylabel('Force [N]');
title('Force plot Main cylinder');
legend('Force extend','Force retract','Location','best');

subplot(1,2,2);
plot(jib.strokeExtend, jib.forceExtend, 'LineWidth', 1.8);
hold on;
plot(jib.strokeRetract, jib.forceRetract, 'LineWidth', 1.8);
grid on;
xlabel('Piston stroke [m]');
ylabel('Force [N]');
title('Force plot Jib cylinder');
legend('Force extend','Force retract','Location','best');

%% ===================== FRICTION PLOTS =====================

figure('Name','Estimated cylinder friction','Color','w');

subplot(1,2,1);
plot(main.strokeCommon, main.frictionForce, 'LineWidth', 1.8);
hold on;
xline(mainStableMin, '--', 'Start stable range');
xline(mainStableMax, '--', 'End stable range');
grid on;
xlabel('Piston stroke [m]');
ylabel('Friction force [N]');
title('Friction plot Main cylinder');

subplot(1,2,2);
plot(jib.strokeCommon, jib.frictionForce, 'LineWidth', 1.8);
hold on;
xline(jibStableMin, '--', 'Start stable range');
xline(jibStableMax, '--', 'End stable range');
grid on;
xlabel('Piston stroke [m]');
ylabel('Friction force [N]');
title('Friction plot Jib cylinder');

%% ===================== PRINT RESULTS =====================

fprintf('\n================ MAIN CYLINDER ================\n');
fprintf('Time interval used:          %.2f s to %.2f s\n', mainTimeMin, mainTimeMax);
fprintf('Mean extend force:           %.2f kN\n', mean(main.forceExtend, 'omitnan')/1000);
fprintf('Mean retract force:          %.2f kN\n', mean(main.forceRetract, 'omitnan')/1000);

fprintf('\n--- Friction, full time-filtered curve ---\n');
fprintf('Mean friction force:         %.2f kN\n', mean(main.frictionForce, 'omitnan')/1000);
fprintf('Min friction force:          %.2f kN\n', min(main.frictionForce)/1000);
fprintf('Max friction force:          %.2f kN\n', max(main.frictionForce)/1000);

if isempty(mainFricStable)
    warning('No main friction data inside the selected stable stroke range.');
else
    fprintf('\n--- Friction, stable range %.3f m to %.3f m ---\n', ...
        min(mainStrokeStable), max(mainStrokeStable));
    fprintf('Mean stable friction force:  %.2f kN\n', mean(mainFricStable, 'omitnan')/1000);
    fprintf('Min stable friction force:   %.2f kN\n', min(mainFricStable)/1000);
    fprintf('Max stable friction force:   %.2f kN\n', max(mainFricStable)/1000);
end

fprintf('\n================ JIB CYLINDER =================\n');
fprintf('Time interval used:          %.2f s to %.2f s\n', jibTimeMin, jibTimeMax);
fprintf('Mean extend force:           %.2f kN\n', mean(jib.forceExtend, 'omitnan')/1000);
fprintf('Mean retract force:          %.2f kN\n', mean(jib.forceRetract, 'omitnan')/1000);

fprintf('\n--- Friction, full time-filtered curve ---\n');
fprintf('Mean friction force:         %.2f kN\n', mean(jib.frictionForce, 'omitnan')/1000);
fprintf('Min friction force:          %.2f kN\n', min(jib.frictionForce)/1000);
fprintf('Max friction force:          %.2f kN\n', max(jib.frictionForce)/1000);

if isempty(jibFricStable)
    warning('No jib friction data inside the selected stable stroke range.');
else
    fprintf('\n--- Friction, stable range %.3f m to %.3f m ---\n', ...
        min(jibStrokeStable), max(jibStrokeStable));
    fprintf('Mean stable friction force:  %.2f kN\n', mean(jibFricStable, 'omitnan')/1000);
    fprintf('Min stable friction force:   %.2f kN\n', min(jibFricStable)/1000);
    fprintf('Max stable friction force:   %.2f kN\n', max(jibFricStable)/1000);
end

%% ============================================================
%  LOCAL FUNCTIONS
%% ============================================================

function result = processFrictionFile(fileName, posSignal, pASignal, pBSignal, ...
                                      A_A, A_B, velThreshold, smoothWindow, ...
                                      removeFraction, nInterp, ...
                                      timeMin, timeMax)

    %% ---------- Read TwinCAT CSV ----------
    T = readTwinCATScopeCSV(fileName);

    %% ---------- Check that required signals exist ----------
    requiredSignals = {posSignal, pASignal, pBSignal};

    for i = 1:numel(requiredSignals)
        if ~ismember(requiredSignals{i}, T.Properties.VariableNames)
            error('Signal "%s" was not found in file "%s".', requiredSignals{i}, fileName);
        end
    end

    %% ---------- Extract signals ----------
    stroke_m = T.(posSignal) / 1000;       % [mm] -> [m]
    pA_Pa    = T.(pASignal) * 1e5;         % [bar] -> [Pa]
    pB_Pa    = T.(pBSignal) * 1e5;         % [bar] -> [Pa]

    %% ---------- Extract time ----------
    timeColumns = startsWith(T.Properties.VariableNames, 't_');

    if ~any(timeColumns)
        error('No time columns were found in file "%s".', fileName);
    end

    t_ms = T{:, find(timeColumns, 1, 'first')};
    t = t_ms / 1000;                       % [ms] -> [s]

    %% ---------- Remove invalid values ----------
    valid = isfinite(t) & isfinite(stroke_m) & isfinite(pA_Pa) & isfinite(pB_Pa);

    t        = t(valid);
    stroke_m = stroke_m(valid);
    pA_Pa    = pA_Pa(valid);
    pB_Pa    = pB_Pa(valid);

    %% ---------- Remove repeated time values ----------
    [t, uniqueTimeIdx] = unique(t, 'stable');

    stroke_m = stroke_m(uniqueTimeIdx);
    pA_Pa    = pA_Pa(uniqueTimeIdx);
    pB_Pa    = pB_Pa(uniqueTimeIdx);

    %% ---------- Apply selected time interval ----------
    idxTime = t >= timeMin & t <= timeMax;

    t        = t(idxTime);
    stroke_m = stroke_m(idxTime);
    pA_Pa    = pA_Pa(idxTime);
    pB_Pa    = pB_Pa(idxTime);

    if numel(t) < 20
        error('Not enough data in selected time interval for file "%s".', fileName);
    end

    %% ---------- Reset time to start from zero after filtering ----------
    t = t - t(1);

    %% ---------- Calculate hydraulic force ----------
    force_N = A_A .* pA_Pa - A_B .* pB_Pa;

    %% ---------- Smooth stroke and force ----------
    strokeSmooth = movmean(stroke_m, smoothWindow, 'omitnan');
    forceSmooth  = movmean(force_N, smoothWindow, 'omitnan');

    %% ---------- Calculate velocity ----------
    velocity = gradient(strokeSmooth, t);
    velocity = movmean(velocity, smoothWindow, 'omitnan');

    %% ---------- Split extension and retraction ----------
    idxExtendRaw  = velocity >  velThreshold;
    idxRetractRaw = velocity < -velThreshold;

    %% ---------- Remove start/stop transient sections ----------
    idxExtend  = removeEdgeTransient(idxExtendRaw, removeFraction);
    idxRetract = removeEdgeTransient(idxRetractRaw, removeFraction);

    %% ---------- Extract extension and retraction data ----------
    strokeExtend  = strokeSmooth(idxExtend);
    forceExtend   = forceSmooth(idxExtend);

    strokeRetract = strokeSmooth(idxRetract);
    forceRetract  = forceSmooth(idxRetract);

    %% ---------- Remove force outliers ----------
    [strokeExtend, forceExtend] = removeOutliers(strokeExtend, forceExtend);
    [strokeRetract, forceRetract] = removeOutliers(strokeRetract, forceRetract);

    %% ---------- Sort by stroke ----------
    [strokeExtend, idxSortExt] = sort(strokeExtend);
    forceExtend = forceExtend(idxSortExt);

    [strokeRetract, idxSortRet] = sort(strokeRetract);
    forceRetract = forceRetract(idxSortRet);

    %% ---------- Remove duplicate stroke values ----------
    [strokeExtend, idxUniqueExt] = unique(strokeExtend, 'stable');
    forceExtend = forceExtend(idxUniqueExt);

    [strokeRetract, idxUniqueRet] = unique(strokeRetract, 'stable');
    forceRetract = forceRetract(idxUniqueRet);

    %% ---------- Check available data ----------
    if numel(strokeExtend) < 10 || numel(strokeRetract) < 10
        error('Not enough valid extend/retract data in file "%s". Try lowering velThreshold or changing time range.', fileName);
    end

    %% ---------- Define common stroke range ----------
    strokeMin = max(min(strokeExtend), min(strokeRetract));
    strokeMax = min(max(strokeExtend), max(strokeRetract));

    if strokeMax <= strokeMin
        error('No overlapping stroke range between extend and retract in file "%s". Try changing time range.', fileName);
    end

    strokeCommon = linspace(strokeMin, strokeMax, nInterp);

    %% ---------- Interpolate force curves ----------
    forceExtendInterp  = interp1(strokeExtend, forceExtend, strokeCommon, 'linear');
    forceRetractInterp = interp1(strokeRetract, forceRetract, strokeCommon, 'linear');

    %% ---------- Calculate friction ----------
    frictionForce = abs(forceExtendInterp - forceRetractInterp) / 2;

    %% ---------- Smooth friction curve slightly ----------
    frictionForce = movmean(frictionForce, 15, 'omitnan');

    %% ---------- Store result ----------
    result.strokeExtend = strokeExtend;
    result.forceExtend = forceExtend;

    result.strokeRetract = strokeRetract;
    result.forceRetract = forceRetract;

    result.strokeCommon = strokeCommon;
    result.forceExtendInterp = forceExtendInterp;
    result.forceRetractInterp = forceRetractInterp;
    result.frictionForce = frictionForce;

    result.timeMin = timeMin;
    result.timeMax = timeMax;
end

function idxClean = removeEdgeTransient(idxRaw, removeFraction)

    idxRawColumn = idxRaw(:);
    idxCleanColumn = false(size(idxRawColumn));

    d = diff([false; idxRawColumn; false]);

    startIdx = find(d == 1);
    endIdx   = find(d == -1) - 1;

    for k = 1:numel(startIdx)

        sectionLength = endIdx(k) - startIdx(k) + 1;

        if sectionLength < 30
            continue;
        end

        nRemove = round(removeFraction * sectionLength);

        newStart = startIdx(k) + nRemove;
        newEnd   = endIdx(k) - nRemove;

        if newEnd > newStart
            idxCleanColumn(newStart:newEnd) = true;
        end
    end

    idxClean = reshape(idxCleanColumn, size(idxRaw));
end

function [xClean, yClean] = removeOutliers(x, y)

    valid = isfinite(x) & isfinite(y);

    x = x(valid);
    y = y(valid);

    if numel(y) < 20
        xClean = x;
        yClean = y;
        return;
    end

    yMed = movmedian(y, 25, 'omitnan');
    deviation = abs(y - yMed);

    limit = 4 * median(deviation, 'omitnan');

    if limit == 0 || isnan(limit)
        xClean = x;
        yClean = y;
        return;
    end

    keep = deviation < limit;

    xClean = x(keep);
    yClean = y(keep);
end

function T = readTwinCATScopeCSV(fileName)

    %% ---------- Open file ----------
    fid = fopen(fileName, 'r');

    if fid == -1
        error('Could not open file: %s', fileName);
    end

    %% ---------- Read first header lines ----------
    nHeaderLines = 8;
    lines = strings(nHeaderLines,1);

    for i = 1:nHeaderLines
        lines(i) = string(fgetl(fid));
    end

    fclose(fid);

    %% ---------- Find line containing signal names ----------
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

    % TwinCAT Scope format:
    % Name;signal1;Name;signal2;Name;signal3;...
    for i = 2:2:numel(parts)
        name = strtrim(parts(i));

        if strlength(name) > 0
            signalNames{end+1} = char(name); %#ok<AGROW>
        end
    end

    %% ---------- Read numeric data ----------
    raw = readtable(fileName, ...
        'FileType','text', ...
        'Delimiter',';', ...
        'DecimalSeparator','.', ...
        'NumHeaderLines',nHeaderLines, ...
        'ReadVariableNames',false);

    %% ---------- Remove empty columns ----------
    emptyCols = false(1,width(raw));

    for i = 1:width(raw)
        emptyCols(i) = all(ismissing(raw{:,i}));
    end

    raw(:,emptyCols) = [];

    %% ---------- Build variable names ----------
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