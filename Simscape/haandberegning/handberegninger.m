clc;
clear;

c = 0.64;
rho = 850;
p_supply = 178;
p_supply_math = p_supply * 10^5;
p_a = 24;
p_a_math = p_a * 10^5;
p_b = 90;
p_b_math = p_b * 10^5;
delta_p = p_supply_math - p_b_math;
a_eff = pi*(0.08^2 - 0.05^2);
a_pis = pi*(0.08^2);
delta_tid = 0.01;

punkt_lengde_100 = 0.46662;
punkt_lengde_200 = 0.43775;
v = (punkt_lengde_100-punkt_lengde_200)/(delta_tid*100);

%Q = a * c * sqrt((2*delta_p)/rho);
Q_m3s = abs(v * a_eff);
Q_m3s1 = abs(v * a_pis);

Q = Q_m3s*6*10^4;

a = Q_m3s/(c * sqrt((2*delta_p)/rho));


Ad_AT = Q_m3s1 / (c*sqrt(2*p_a_math / rho))