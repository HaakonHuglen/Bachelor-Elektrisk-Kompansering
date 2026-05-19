%% Plot logged Simulink data over time
clear; clc; close all;

%% Load data
load("Pressuredrop_2Jib.mat");

% Logged dataset
logs = data;

%% Extract signals
PA_Jib_dcv  = logs.getElement("PA_Jib_dcv:1").Values;
PB_Jib_dcv  = logs.getElement("PB_Jib_dcv:1").Values;
PS          = logs.getElement("PS:1").Values;

jib_pos     = logs.getElement("jib_pos:1").Values;
ref_pos     = logs.getElement("Referanse verdi for Posisjon og Hastighet:1").Values;

PID         = logs.getElement("PID").Values;
SumUfiltrert = logs.getElement("SumUfiltrert").Values;
TransferFcn = logs.getElement("Transfer Fcn hentet fra EMIL:1").Values;
UFF_Jib     = logs.getElement("Uff Jib").Values;

%% Figure 1: Pressure signals
figure;
plot(PA_Jib_dcv.Time, PA_Jib_dcv.Data, 'LineWidth', 1.5); hold on;
plot(PB_Jib_dcv.Time, PB_Jib_dcv.Data, 'LineWidth', 1.5);
plot(PS.Time, PS.Data, 'LineWidth', 1.5);

grid on;
xlabel('Time [s]');
ylabel('Pressure [bar]');
title('Pressure Over Time');
xlim([0, 125]);

legend({'PA Jib DCV', 'PB Jib DCV', 'PS'}, ...
    'Location', 'best');

%% Figure 2: Position signals
figure;
plot(jib_pos.Time, jib_pos.Data, 'LineWidth', 1.5); hold on;
plot(ref_pos.Time, ref_pos.Data, 'LineWidth', 1.5);

grid on;
xlabel('Time [s]');
ylabel('Position [m]');
title('Position Over Time');
xlim([0, 125]);

legend({'Jib Position', 'Reference Position'}, ...
    'Location', 'best');

%% Figure 3: Control signals
figure;
plot(SumUfiltrert.Time, SumUfiltrert.Data, 'LineWidth', 1.5); hold on;
plot(PID.Time, PID.Data, 'LineWidth', 1.5);
plot(UFF_Jib.Time, UFF_Jib.Data, 'LineWidth', 1.5);

grid on;
xlabel('Time [s]');
ylabel('Control Signal');
title('Control Signals Over Time');
xlim([0, 125]);

legend({'Sum', 'PID', 'UFF Jib'}, ...
    'Location', 'best');