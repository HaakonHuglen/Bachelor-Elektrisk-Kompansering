% ===================== FIGUR 5: Kv vs u (FORBEDRET) =====================

Kv_mean = nan(nFiles,1);
u_meas_percent = nan(nFiles,1);

for k = 1:nFiles

    filePath = fullfile(files(k).folder, files(k).name);
    rawLines = readlines(filePath);

    t_ms = []; ps = []; pa = []; pb = []; x = []; uSense = [];

    for i = 1:numel(rawLines)
        line = strtrim(rawLines(i));
        if line == "" || contains(line,'Name') || contains(line,'File') || ...
           contains(line,'Start') || contains(line,'End') || line == "EOF"
            continue;
        end

        line = replace(line, ',', '.');
        parts = split(line, ';');

        if numel(parts) < 12
            continue;
        end

        vals = str2double(parts(1:12));
        if any(isnan(vals))
            continue;
        end

        t_ms(end+1,1) = vals(1);
        ps(end+1,1)   = vals(2);
        pa(end+1,1)   = vals(4);
        pb(end+1,1)   = vals(6);
        x(end+1,1)    = vals(8);
        uSense(end+1,1) = vals(10);
    end

    if numel(t_ms) < 20
        continue;
    end

    t = t_ms / 1000;

    % Glatting
    x_filt = smoothdata(x, 'movmean', 15);
    xdot   = gradient(x_filt, t);

    % -------- FILTER (DETTE ER KRITISK) --------
    dp = ps - pa;

    mask = abs(xdot) > 2e-5 & dp > 2;   % <-- strengere filter

    if sum(mask) < 10
        Kv_mean(k) = 0;   % dødbånd
        continue;
    end

    % -------- STABILE VERDIER --------
    xdot_med = median(xdot(mask));
    dp_med   = median(dp(mask));

    Q = A_piston * abs(xdot_med);

    Kv = Q / sqrt(dp_med * 1e5);   % SI
    Kv = Kv * 60000 * sqrt(1e5);   % -> L/min/sqrt(bar)

    Kv_mean(k) = Kv;

    % Målt u (sensor)
    u_meas_percent(k) = (median(uSense(mask)) - 5) / 5 * 100;
end

% ===================== RYDD DATA =====================

valid_kv    = Kv_mean > 0;
deadband_kv = Kv_mean == 0;

u_fit  = u_meas_percent(valid_kv);
Kv_fit = Kv_mean(valid_kv);

% ===================== PLOT =====================

figure;
plot(u_fit, Kv_fit, 'o', 'MarkerSize', 7, 'LineWidth', 1.5);
hold on;

% Dødbånd som røde kryss
if any(deadband_kv)
    plot(u_meas_percent(deadband_kv), zeros(sum(deadband_kv),1), ...
        'rx', 'MarkerSize', 10, 'LineWidth', 2);
end

% Smooth fit (IKKE for høy grad)
if numel(u_fit) >= 3
    pKv = polyfit(u_fit, Kv_fit, 2);   % <-- lavere grad = penere
    u_dense = linspace(min(u_fit), max(u_fit), 300);
    Kv_dense = polyval(pKv, u_dense);
    plot(u_dense, Kv_dense, '-', 'LineWidth', 2);
end

grid on;
xlabel('u_{målt} [%]');
ylabel('K_v [L/(min \cdot \surdbar)]');
title('K_v vs målt spoleposisjon');

legend('Målepunkter', 'Dødbånd', 'Fit', 'Location','best');