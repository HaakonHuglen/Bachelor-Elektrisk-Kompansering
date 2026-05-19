%% Plot logged Simulink data over time
clear; clc; close all;

%% Load data
load("Pressuredrop_Main1.mat");

% Logged dataset
logs = data;

%% Extract signals
PA_main_dcv = logs.getElement("PA_main_dcv:1").Values;
PB_main_dcv = logs.getElement("PB_main_dcv:1").Values;
PS          = logs.getElement("PS:1").Values;

main_pos    = logs.getElement("main_pos:1").Values;
posisjon    = logs.getElement("Posisjon og fart:1").Values;

Utotal      = logs.getElement("Utotal").Values;
UPID        = logs.getElement("UPID").Values;
TransferFcn = logs.getElement("Transfer Fcn hentet fra EMIL:1").Values;
UFF         = logs.getElement("U_FF:1").Values;

%% Figure 1: Pressure signals
figure;
plot(PA_main_dcv.Time, PA_main_dcv.Data, 'LineWidth', 1.5); hold on;
plot(PB_main_dcv.Time, PB_main_dcv.Data, 'LineWidth', 1.5);
plot(PS.Time, PS.Data, 'LineWidth', 1.5);

grid on;
xlabel('Time [s]');
ylabel('Pressure [bar]');
title('Pressure Over Time');
xlim([0 125]);

legend('PA main DCV', 'PB main DCV', 'PS', ...
    'Location', 'best');

%% Figure 2: Position signals
figure;
plot(main_pos.Time, main_pos.Data, 'LineWidth', 1.5); hold on;
plot(posisjon.Time, posisjon.Data, 'LineWidth', 1.5);

grid on;
xlabel('Time [s]');
ylabel('Position [m]');
title('Position Over Time');
xlim([0, 125]);

legend({'Main Position', 'Ref Position'}, ...
    'Location', 'best');

%% Figure 3: Control signals
figure;
plot(Utotal.Time, Utotal.Data, 'LineWidth', 1.5); hold on;
plot(UPID.Time, UPID.Data, 'LineWidth', 1.5);
plot(UFF.Time, UFF.Data, 'LineWidth', 1.5);

grid on;
xlabel('Time [s]');
xlim([0, 125]);
ylabel('Control Signal');
title('Control Signals Over Time');

legend('Utotal', 'UPID', 'UFF', ...
    'Location', 'best');