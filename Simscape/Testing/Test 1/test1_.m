% Parametere
A = 100;          % amplitude
f = 0.07;        % frekvens
offseta = 300;     % midtpunkt 
offsetb = 500;

% x-verdier
x = linspace(0, 14.5, 1000);

% Sinusfunksjon 
y1 = offseta + A * sin(2*pi*f*x - pi/2);
y2 = offsetb + A * sin(2*pi*f*x - pi/2);
% Plot
figure;
plot(x, y1, 'LineWidth', 3);
hold on;
plot(x, y2, 'Color', [0.8500 0.3250 0.0980], 'LineWidth', 3)
grid on;

xlabel('Tid [s]');
ylabel('Cylinder Stroke [mm]');
title('Position Reference');
legend('Jib Pos Ref', 'Main Pos Ref', 'FontSize', 10);

ylim([150 650]);
xlim([0 14.4])