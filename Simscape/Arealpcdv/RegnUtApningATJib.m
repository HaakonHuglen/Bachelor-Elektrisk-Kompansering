clear; clc;

% Les fil
filename = "FinneOpeningATJib .csv";

opts = detectImportOptions(filename, ...
    "Delimiter", ";", ...
    "DecimalSeparator", ",");

data = readtable(filename, opts);

% Hent kolonner
paagangsdrag = data{:,1};   % Kolonne A
deltaP_bar   = data{:,4};   % Kolonne E
Qb           = data{:,5};   % Kolonne B

% Konstanter
rho = 850;      % kg/m^3
Cd  = 0.64;

Aa = (pi*(0.150)^2)/4;
Ab = (pi*(0.150)^2)/4 - (pi*(0.100)^2)/4;

% Beregn Qb
Qa = Qb .* (Aa/Ab); % Qb * Aa = Qa * Ab

% Konverter deltaP fra bar til Pa
deltaP = deltaP_bar * 1e5;

% Orifice equation:
% Q = Cd * A * sqrt(2*deltaP/rho)
% Løst for A:
A = Qa ./ (Cd .* sqrt((2 .* deltaP) ./ rho));

% Legg til resultater i tabellen
data.Qa_m3ps = Qa;
data.A_m2 = A;

% Vis resultater
disp(data)

% Plot av åpningareal
figure;
plot(paagangsdrag, A, 'o-', 'LineWidth', 1.5)
grid on

xlabel('Pågangsdrag [%]')
ylabel('Åpningsareal A [m^2]')
title('Beregnet åpningareal - AT Jib')

% Lagre resultatfil
writetable(data, "resultat_ATJib_med_A.csv")