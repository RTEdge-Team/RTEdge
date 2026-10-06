%% phase2_smoke_test.m
% Run this BEFORE run_phase2_batch. It builds the model and exercises one
% condition, so that any Simulink API problem shows up in seconds rather
% than part-way through a 24-run batch.
%
%   >> phase2_smoke_test
%
% This is a SCRIPT - run it by name. Do not paste its contents into
% phase2_config.m or any other function file.

clear; clc;

fprintf('=== 1. config ===\n');
C = phase2_config();
fprintf('  vehicle : %s\n', C.veh.name);
fprintf('  cell    : %s, %.2f Ah -> Np_eq %.2f\n', ...
        C.cell.name, C.cell.Ah_actual, C.cell.Np_eq);
fprintf('  tests   : %d conditions\n', numel(C.tests));

fprintf('\n=== 2. build model ===\n');
mdl = build_phase2_model(C);
open_system(mdl);

fprintf('\n=== 3. drive cycle for condition 1 (%s) ===\n', C.tests(1).id);
T = C.tests(1);
[t, v, gr] = make_drive_cycle(C, T);
fprintf('  length %d s | v_max %.2f km/h | v_avg %.2f km/h | a_max %.3f m/s^2\n', ...
        numel(v), max(v)*3.6, mean(v)*3.6, max(abs(diff(v))));
fprintf('  EXPECT  28080 s | 42.00 | 21.89 | 0.583\n');

fprintf('\n=== 4. run 1080 s (10 IDC cycles) ===\n');
driveCycleData.time = t;
driveCycleData.signals.values = v;
driveCycleData.signals.dimensions = 1;
gradeData.time = t;
gradeData.signals.values = gr;
gradeData.signals.dimensions = 1;
assignin('base','driveCycleData',driveCycleData);
assignin('base','gradeData',gradeData);
assignin('base','VEH_M',   C.veh.kerb_kg + T.rider_kg);
assignin('base','VEH_CDA', C.veh.CdA);
assignin('base','VEH_CRR', C.veh.Crr);
assignin('base','VEH_RHO', C.sim.rho);
assignin('base','VEH_G',   C.sim.g);

set_param(mdl,'StopTime','1080');
simOut = sim(mdl);
D = simOut.simlog.signals.values;

fprintf('  P_pack  mean %7.1f W   peak %7.1f W\n', mean(D(:,6)), max(D(:,6)));
fprintf('  EXPECT       ~462             ~1946\n');
fprintf('  P_cell  mean %7.3f W   peak %7.3f W\n', mean(D(:,7)), max(D(:,7)));
fprintf('  EXPECT       ~1.59            ~6.70\n');
fprintf('  regen samples %.0f%%   power-limited %.0f%% (expect 0%%)\n', ...
        100*mean(D(:,8)), 100*mean(D(:,9)));

fprintf('\n=== 5. hand-check one cruise sample ===\n');
vv = D(:,1); aa = D(:,2); FF = D(:,4);
k = find(abs(aa) < 1e-9 & vv > 1, 1);
if isempty(k)
    fprintf('  no steady-speed sample found in this window\n');
else
    m = C.veh.kerb_kg + T.rider_kg;
    F_hand = m*C.sim.g*C.veh.Crr + 0.5*C.sim.rho*C.veh.CdA*vv(k)^2;
    fprintf('  at %.1f km/h: model %.2f N vs hand %.2f N  (%.3f%% error)\n', ...
            vv(k)*3.6, FF(k), F_hand, 100*abs(FF(k)-F_hand)/F_hand);
    fprintf('  EXPECT error < 0.01%%\n');
end

fprintf('\nIf steps 3-5 match, run:  run_phase2_batch\n');
