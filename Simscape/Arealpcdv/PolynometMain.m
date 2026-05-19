%% Plot av ventilpolynomer

clear; clc; close all;

%% fKv-område
fKv = linspace(0, 10, 1000);

%% Polynomer opp
fPoly_Up_Main_a5 = 7.1494408773e-04;
fPoly_Up_Main_a4 = -1.0009185688e-02;
fPoly_Up_Main_a3 = 5.0292811747e-02;
fPoly_Up_Main_a2 = -1.0886516780e-01;
fPoly_Up_Main_a1 = 2.0677542004e-01;
fPoly_Up_Main_a0 = 2.3438288370e-01;

%% Polynomer ned
fPoly_Down_Main_a5 = -1.3063349639e-03;
fPoly_Down_Main_a4 = 1.6877559214e-02;
fPoly_Down_Main_a3 = -7.8541245328e-02;
fPoly_Down_Main_a2 = 1.5603273194e-01;
fPoly_Down_Main_a1 = -2.4076519579e-01;
fPoly_Down_Main_a0 = -2.1351759561e-01;

%% Beregn polynomene
Poly_Up = fPoly_Up_Main_a5 .* fKv.^5 + ...
          fPoly_Up_Main_a4 .* fKv.^4 + ...
          fPoly_Up_Main_a3 .* fKv.^3 + ...
          fPoly_Up_Main_a2 .* fKv.^2 + ...
          fPoly_Up_Main_a1 .* fKv + ...
          fPoly_Up_Main_a0;

Poly_Down = fPoly_Down_Main_a5 .* fKv.^5 + ...
            fPoly_Down_Main_a4 .* fKv.^4 + ...
            fPoly_Down_Main_a3 .* fKv.^3 + ...
            fPoly_Down_Main_a2 .* fKv.^2 + ...
            fPoly_Down_Main_a1 .* fKv + ...
            fPoly_Down_Main_a0;

%% Plot
figure;
plot(fKv, Poly_Up, 'LineWidth', 2);
hold on;
plot(fKv, Poly_Down, 'LineWidth', 2);
grid on;

xlabel('fKv');
ylabel('Polynomverdi');
title('Plot av ventilpolynomer');
legend('Up Main', 'Down Main', 'Location', 'best');

ylim([-1.2 1.2]);
yline(1, '--');
yline(-1, '--');
xline(0, '--');