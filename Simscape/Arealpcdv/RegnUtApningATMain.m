clear; clc;

% Les fil
filename = "FinneOpningATMain.csv";

opts = detectImportOptions(filename, ...
    "Delimiter", ";", ...
    "DecimalSeparator", ",");

data = readtable(filename, opts);

% Hent kolonner
paagangsdrag = data{:,1};   % Kolonne A
deltaP_bar   = data{:,2};   % Kolonne B
Qb           = data{:,3};   % Kolonne C [m^3/s]

% Konstanter
rho = 850;      % kg/m^3
Cd  = 0.64;

Aa = (pi*(0.160)^2)/4;
Ab = (pi*(0.160)^2)/4 - (pi*(0.100)^2)/4;

% Beregn Qb
Qa = Qb .* (Aa/Ab); % Qb * Aa = Qa * Ab

% Konverter deltaP fra bar til Pa
deltaP = deltaP_bar * 1e5;

% Orifice equation:
% Q = Cd * A * sqrt(2*deltaP/rho)
% Løst for A:
A = Qa ./ (Cd .* sqrt((2 .* deltaP) ./ rho));

% Legg til i tabell
data.Qa_m3ps = Qa;
data.A_m2 = A;

% Vis resultat
disp(data)

% Plot
figure;
plot(paagangsdrag, A, 'o-')
grid on
xlabel('Pågangsdrag [%]')
ylabel('Åpningsareal A [m^2]')
title('Beregnet åpningareal fra orifice equation')

% Lagre resultat
writetable(data, "resultat_med_A.csv")