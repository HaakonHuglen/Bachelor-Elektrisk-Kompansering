clc;
clear;
close all;

%% ===================== SETTINGS =====================
resultsFile = 'C:\Users\hakon\OneDrive - Universitetet i Agder\Skrivebord\BACHELOR_PROSJEKT\Bachelor-Oppgave---Elektrisk-Kompansering\Mapping_Kv_f(u)\P_Supply150BAR\Mapping_150Bar_JIB_UP\Test2_UMaalt\results_combined_jib_up.csv';

polyDeg = 5;   % Test gjerne 3, 4, 5 og 6

%% ===================== READ RESULTS =====================
T = readtable(resultsFile);

Kv = T.Kv_Lmin_sqrtbar;
u_percent = T.u_percent;

%% ===================== PREPARE DATA =====================
valid = ~isnan(Kv) & Kv > 0 & ~isnan(u_percent);

Kv_fit = Kv(valid);

% Jib opp: direkte positivt TwinCAT-signal
% Eksempel: 25 % -> 0.25, 100 % -> 1.00
u_fit_target = u_percent(valid) / 100;

%% ===================== POLYNOMIAL FIT =====================
p = polyfit(Kv_fit, u_fit_target, polyDeg);

u_pred = polyval(p, Kv_fit);

SS_res = sum((u_fit_target - u_pred).^2);
SS_tot = sum((u_fit_target - mean(u_fit_target)).^2);
R2 = 1 - SS_res / SS_tot;

%% ===================== PRINT RESULT =====================
fprintf('\n====================================================\n');
fprintf('TwinCAT-polynom: JIB OPP 150 bar\n');
fprintf('====================================================\n');

fprintf('Definisjoner:\n');
fprintf('Q  = A_piston * abs(xdot) * 60000    [L/min]\n');
fprintf('dp = ps - pa                         [bar]\n');
fprintf('Kv = Q / sqrt(dp)                    [L/(min*sqrt(bar))]\n');
fprintf('u_ctrl = u_percent / 100             [-], direkte positivt signal\n\n');

fprintf('Polynomgrad: %d\n', polyDeg);
fprintf('R^2 = %.6f\n\n', R2);

fprintf('Koeffisienter fra høyeste grad til konstantledd:\n');
disp(p);

fprintf('MATLAB-form:\n');
fprintf('u_ctrl(Kv) = ');
for j = 1:numel(p)
    expVal = polyDeg - j + 1;

    if expVal > 1
        fprintf('(%.10e)*Kv^%d', p(j), expVal);
    elseif expVal == 1
        fprintf('(%.10e)*Kv', p(j));
    else
        fprintf('(%.10e)', p(j));
    end

    if expVal > 0
        fprintf(' + ');
    end
end
fprintf('\n\n');

fprintf('TwinCAT Structured Text:\n');
fprintf('fU_FF := ');
for j = 1:numel(p)
    expVal = polyDeg - j + 1;
    coeff = p(j);

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

%% ===================== PLOT =====================
Kv_dense = linspace(min(Kv_fit), max(Kv_fit), 300);
u_dense = polyval(p, Kv_dense);

figure;
plot(Kv_fit, u_fit_target, 'o', 'MarkerSize', 7, 'LineWidth', 1.5);
hold on;
plot(Kv_dense, u_dense, '-', 'LineWidth', 1.8);
grid on;

xlabel('K_v [L/(min \cdot \surdbar)]');
ylabel('u_{ctrl} [-]');
title('TwinCAT-polynom: direkte u_{FF} = f(K_v) - Jib opp 150 bar');

legend('Målepunkter', ...
    sprintf('Polynomfit grad %d | R^2 = %.4f', polyDeg, R2), ...
    'Location', 'best');

%% ===================== CHECK DATA =====================
checkTable = table(T.file_name(valid), Kv_fit, u_fit_target, ...
    'VariableNames', {'file_name','Kv','u_ctrl'});

disp('Punkter brukt i fit:');
disp(checkTable);