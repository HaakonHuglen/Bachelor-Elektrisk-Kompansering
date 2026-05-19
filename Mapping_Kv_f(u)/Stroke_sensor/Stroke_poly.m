clc;
clear;
close all;

%% ===================== DATA =====================
% Venstre datasett = Jib, stort avvik
jib_twincat_mm = [855.00; 769.00; 685.50; 598.40; 513.00; 428.00; ...
                  342.20; 256.10; 171.30; 85.40; 59.60];

jib_measured_mm = [851.50; 770.50; 690.00; 607.00; 524.00; 441.00; ...
                   356.00; 271.50; 187.50; 110.00; 74.00];

% Høyre datasett = Main, lite avvik
main_twincat_mm = [743.00; 668.80; 594.40; 520.60; 445.75; ...
                   370.40; 297.20; 222.60; 148.60; 74.18];

main_measured_mm = [743.00; 668.00; 594.00; 520.00; 445.00; ...
                    369.00; 296.00; 222.00; 148.00; 74.00];

%% ===================== SETTINGS =====================
polyDeg = 2;   % Start med 2. Test gjerne 1, 2 og 3.

%% ===================== JIB POLYNOM =====================
% Polynom: x_real = f(x_twincat)
p_jib = polyfit(jib_twincat_mm, jib_measured_mm, polyDeg);

jib_pred_mm = polyval(p_jib, jib_twincat_mm);
jib_error_mm = jib_measured_mm - jib_pred_mm;

SS_res = sum((jib_measured_mm - jib_pred_mm).^2);
SS_tot = sum((jib_measured_mm - mean(jib_measured_mm)).^2);
R2_jib = 1 - SS_res / SS_tot;

%% ===================== MAIN CHECK =====================
p_main = polyfit(main_twincat_mm, main_measured_mm, 1);
main_pred_mm = polyval(p_main, main_twincat_mm);

SS_res_main = sum((main_measured_mm - main_pred_mm).^2);
SS_tot_main = sum((main_measured_mm - mean(main_measured_mm)).^2);
R2_main = 1 - SS_res_main / SS_tot_main;

%% ===================== PRINT RESULT =====================
fprintf('\n====================================================\n');
fprintf('TwinCAT-polynom: JIB STROKE SENSOR CORRECTION\n');
fprintf('====================================================\n');
fprintf('Definisjon:\n');
fprintf('x_real_mm = f(x_twincat_mm)\n\n');

fprintf('Polynomgrad: %d\n', polyDeg);
fprintf('R^2 = %.6f\n\n', R2_jib);

fprintf('Koeffisienter fra høyeste grad til konstantledd:\n');
disp(p_jib);

fprintf('MATLAB-form:\n');
fprintf('x_real_mm = ');
for j = 1:numel(p_jib)
    expVal = polyDeg - j + 1;

    if expVal > 1
        fprintf('(%.10e)*x_twincat_mm^%d', p_jib(j), expVal);
    elseif expVal == 1
        fprintf('(%.10e)*x_twincat_mm', p_jib(j));
    else
        fprintf('(%.10e)', p_jib(j));
    end

    if expVal > 0
        fprintf(' + ');
    end
end
fprintf('\n\n');

fprintf('TwinCAT Structured Text:\n');
fprintf('fStrokeCorrected_mm := ');
for j = 1:numel(p_jib)
    expVal = polyDeg - j + 1;
    coeff = p_jib(j);

    if j > 1
        if coeff >= 0
            fprintf('\n                      +');
        else
            fprintf('\n                      ');
        end
    end

    if expVal > 1
        fprintf('%.10e * EXPT(fStrokeTwincat_mm, %d)', coeff, expVal);
    elseif expVal == 1
        fprintf('%.10e * fStrokeTwincat_mm', coeff);
    else
        fprintf('%.10e', coeff);
    end
end
fprintf(';\n');

fprintf('====================================================\n\n');

%% ===================== PLOT JIB =====================
x_dense_jib = linspace(min(jib_twincat_mm), max(jib_twincat_mm), 400);
y_dense_jib = polyval(p_jib, x_dense_jib);

figure;
plot(jib_twincat_mm, jib_measured_mm, 'o', 'MarkerSize', 7, 'LineWidth', 1.5);
hold on;
plot(x_dense_jib, y_dense_jib, '-', 'LineWidth', 1.8);
plot(x_dense_jib, x_dense_jib, '--', 'LineWidth', 1.2);
grid on;

xlabel('Stroke from TwinCAT [mm]');
ylabel('Measured stroke [mm]');
title('Jib cylinder stroke sensor calibration');
legend('Measured points', ...
       sprintf('Polynomial degree %d | R^2 = %.4f', polyDeg, R2_jib), ...
       'Ideal: measured = TwinCAT', ...
       'Location', 'best');

%% ===================== PLOT MAIN =====================
figure;
plot(main_twincat_mm, main_measured_mm, 'o', 'MarkerSize', 7, 'LineWidth', 1.5);
hold on;
plot(main_twincat_mm, main_pred_mm, '-', 'LineWidth', 1.8);
plot(main_twincat_mm, main_twincat_mm, '--', 'LineWidth', 1.2);
grid on;

xlabel('Stroke from TwinCAT [mm]');
ylabel('Measured stroke [mm]');
title('Main cylinder stroke sensor check');
legend('Measured points', ...
       sprintf('Linear fit | R^2 = %.4f', R2_main), ...
       'Ideal: measured = TwinCAT', ...
       'Location', 'best');

%% ===================== ERROR PLOT JIB =====================
figure;
plot(jib_twincat_mm, jib_measured_mm - jib_twincat_mm, 'o-', ...
    'LineWidth', 1.5, 'MarkerSize', 7);
hold on;
plot(jib_twincat_mm, jib_error_mm, 's-', ...
    'LineWidth', 1.5, 'MarkerSize', 7);
grid on;

xlabel('Stroke from TwinCAT [mm]');
ylabel('Error [mm]');
title('Jib stroke error before and after polynomial correction');
legend('Original error: measured - TwinCAT', ...
       'Residual after correction', ...
       'Location', 'best');

%% ===================== TABLE =====================
T_jib = table(jib_twincat_mm, jib_measured_mm, jib_pred_mm, ...
    jib_measured_mm - jib_twincat_mm, jib_error_mm, ...
    'VariableNames', {'TwinCAT_mm','Measured_mm','CorrectedFit_mm', ...
                      'OriginalError_mm','ResidualAfterFit_mm'});

disp('Jib calibration table:');
disp(T_jib);