clc; clear; 
format long e;

filename = "C:\Users\Oscar\OneDrive - Universitetet i Agder\Bachelor\FinneOpningBT.csv";

opts = detectImportOptions(filename, ...
    'FileType', 'text', ...
    'Delimiter', ';', ...
    'DecimalSeparator', ',');

T = readtable(filename, opts);

disp(T.Properties.VariableNames)
disp(T(1:10,:))

% Kolonner
Qa = T{:,1};             % Kolonne A
Qb = T{:,4};             % Kolonne C
Pb = T{:,7};             % Kolonne G
apningssignal = T{:,9};  % Kolonne I

% Tving til numerisk hvis noe er lest som tekst
Qa = str2double(strrep(string(Qa), ',', '.'));
Qb = str2double(strrep(string(Qb), ',', '.'));
Pb = str2double(strrep(string(Pb), ',', '.'));
apningssignal = str2double(strrep(string(apningssignal), ',', '.'));

% Konstanter
rho = 850;   % kg/m^3

% Enheter
Qb_m3s = Qb;        % Bruk denne hvis Qb allerede er m^3/s
deltap = Pb * 1e5; % Bruk denne hvis Pb er i bar

% Beregn areal
Ad = Qb_m3s ./ sqrt((2 .* deltap) ./ rho);

% Fjern ugyldige verdier
Ad(deltap <= 0 | Qb_m3s <= 0) = NaN;

% Resultattabell
resultat = table(apningssignal, Qa, Qb, Pb, Qb_m3s, deltap, Ad, ...
    'VariableNames', {'Apningssignal','Qa','Qb_original','Pb_bar','Qb_m3s','deltap_Pa','Ad_m2'});

disp(resultat)

fprintf('\nGjennomsnittlig Ad = %.12e m^2\n', mean(Ad,'omitnan'));
fprintf('Median Ad = %.12e m^2\n', median(Ad,'omitnan'));

% Plot Ad som funksjon av åpningssignal
figure;
plot(apningssignal, Ad, 'o-', 'LineWidth', 1.5);
grid on;
xlabel('Åpningssignal [%]');
ylabel('A_d [m^2]');
title('Åpningsareal B-T som funksjon av åpningssignal');

% Sortert plot, nyttig hvis målepunktene ikke ligger i stigende rekkefølge
[apningssignal_sortert, idx] = sort(apningssignal);
Ad_sortert = Ad(idx);

figure;
plot(apningssignal_sortert, Ad_sortert, 'o-', 'LineWidth', 1.5);
grid on;
xlabel('Åpningssignal [%]');
ylabel('A_d [m^2]');
title('Sortert åpningsareal B-T som funksjon av åpningssignal');

% Lagre resultat
writetable(resultat, "Beregnet_Apning_BT.csv");