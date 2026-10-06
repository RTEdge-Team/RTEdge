%% run_phase2_batch.m
% Generates one load-profile CSV per test condition, plus a manifest.
%
%   >> run_phase2_batch
%
% Output: profiles/<id>.csv          one row per second, for the Pi
%         profiles/_manifest.csv     one row per condition, for the report
%
% The CSV's operative column is P_cell_W. The Pi computes
%       I_cmd = P_cell_W / V_measured,  clamped to >= 0.2 A
% every second. It must NOT use I_cell_nominal_A for control - that
% column assumes a fixed 3.635 V and is a planning reference only.

clear; clc;
C = phase2_config();
mdl = build_phase2_model(C);

% Resolve the output folder to an ABSOLUTE path before testing for it.
% exist('profiles','dir') searches the whole MATLAB path, so if a folder
% called 'profiles' exists anywhere else on the path this test passes,
% mkdir is skipped, and writetable then fails with
%   "Unable to open file 'profiles/....csv' ... No such file or directory"
% because no such folder exists in the CURRENT directory.
outdir = fullfile(pwd, C.sim.outdir);
if exist(outdir,'dir') ~= 7
    [ok, msg] = mkdir(outdir);
    if ~ok
        error('run_phase2_batch:mkdir', ...
              'Could not create output folder %s: %s', outdir, msg);
    end
end
fprintf('Writing profiles to: %s\n', outdir);

nT = numel(C.tests);
man = cell(nT,1);

fprintf('\n%-18s %8s %8s %8s %7s %7s %8s %7s\n', ...
        'condition','Pmean_W','Pmax_W','Icell_A','Imax_A','Cmax','t_dis_h','<0.2A');
fprintf('%s\n', repmat('-',1,82));

for i = 1:nT
    T = C.tests(i);

    % ---- build the trace for this condition ------------------------
    [t, v_ms, grade_pct] = make_drive_cycle(C, T);

    driveCycleData.time = t;
    driveCycleData.signals.values = v_ms;
    driveCycleData.signals.dimensions = 1;

    gradeData.time = t;
    gradeData.signals.values = grade_pct;
    gradeData.signals.dimensions = 1;

    % ---- vehicle parameters for this condition ---------------------
    % Payload is the only one that varies across the matrix, but all
    % five are pushed every run so the model can never pick up a stale
    % value from an earlier condition.
    m = C.veh.kerb_kg + T.rider_kg;

    assignin('base','driveCycleData',driveCycleData);
    assignin('base','gradeData',gradeData);
    assignin('base','VEH_M',   m);
    assignin('base','VEH_CDA', C.veh.CdA);
    assignin('base','VEH_CRR', C.veh.Crr);
    assignin('base','VEH_RHO', C.sim.rho);
    assignin('base','VEH_G',   C.sim.g);

    set_param(mdl,'StopTime',num2str(t(end)));

    % ---- run -------------------------------------------------------
    % sim() returns a SimulationOutput object; the logged signal must be
    % indexed out of it, not read from the base workspace.
    simOut = sim(mdl);
    D  = simOut.simlog.signals.values;    % N x 9, order set by the Mux
    tt = simOut.simlog.time;

    v    = D(:,1);  acc  = D(:,2);  gr    = D(:,3);  F     = D(:,4);
    Pw   = D(:,5);  Ppk  = D(:,6);  Pcell = D(:,7);
    regf = double(D(:,8));           limf  = double(D(:,9));

    % Regen magnitude, per cell. Recorded for completeness and for
    % Phase 3 comparison; NEVER commanded on the bench.
    P_regen_cell = max(-Pw,0) * C.veh.eta / (C.pack.Ns * C.cell.Np_eq);

    % Planning reference only - see header note.
    I_nom = Pcell / C.cell.V_nom;

    % Which samples the DL24P physically cannot reach.
    floor_flag = double(I_nom > 0 & I_nom < C.load.I_min_A);

    Tb = table(tt, v*3.6, acc, gr, F, Pw, Ppk, Pcell, P_regen_cell, ...
               I_nom, regf, limf, floor_flag, ...
        'VariableNames', {'time_s','velocity_kmh','accel_mps2','grade_pct', ...
        'F_total_N','P_wheel_W','P_pack_W','P_cell_W','P_regen_cell_W', ...
        'I_cell_nominal_A','regen_flag','power_limited_flag','current_floor_flag'});

    fn = fullfile(outdir, [T.id '.csv']);
    writetable(Tb, fn);

    % ---- per-condition summary -------------------------------------
    drv    = I_nom(I_nom > 0);
    Imean  = mean(I_nom);
    t_dis  = C.cell.Ah_actual / max(Imean, eps);       % hours
    if isempty(drv)
        pctFlr = 0;
    else
        pctFlr = 100 * mean(floor_flag(I_nom > 0));
    end

    fprintf('%-18s %8.0f %8.0f %8.3f %7.2f %7.2f %8.1f %6.0f%%\n', ...
        T.id, mean(Ppk), max(Ppk), Imean, max(I_nom), ...
        max(I_nom)/C.cell.Ah_actual, t_dis, pctFlr);

    % Guard: the profile must outlast the discharge with real margin. The
    % estimate above uses rated capacity at nominal voltage; a real cell
    % can hold ~5% more and averages a slightly higher voltage, so demand
    % 1.5x rather than trusting the estimate to the minute.
    prof_h = numel(tt) / 3600;
    if prof_h < 1.5 * t_dis
        warning('run_phase2_batch:short', ...
            ['%s: profile is %.1f h but discharge is estimated at %.1f h. ' ...
             'Increase C.sim.profile_s.'], T.id, prof_h, t_dis);
    end

    man{i} = { T.id, T.cycle, T.grade, mat2str(T.g_param), T.rider_kg, ...
               numel(tt), mean(Ppk), max(Ppk), Imean, max(I_nom), ...
               max(I_nom)/C.cell.Ah_actual, t_dis, pctFlr, ...
               100*mean(regf), 100*mean(limf), T.note };
end

%% ---- manifest -----------------------------------------------------
M = cell2table(vertcat(man{:}), 'VariableNames', ...
    {'condition_id','cycle','grade_mode','grade_param','rider_kg', ...
     'profile_len_s','P_pack_mean_W','P_pack_max_W','I_cell_mean_A', ...
     'I_cell_max_A','C_rate_max','est_discharge_h','pct_below_floor', ...
     'pct_regen_samples','pct_power_limited','note'});
writetable(M, fullfile(outdir,'_manifest.csv'));

tot = sum(M.est_discharge_h);
fprintf('\n%d profiles written to %s/\n', nT, outdir);
fprintf('Campaign estimate: %.0f h discharge + %.0f h recharge = %.1f days continuous\n', ...
        tot, nT*2.5, (tot + nT*2.5)/24);
fprintf('Expected dataset size: ~%s rows at 1 Hz\n', ...
        addcommas(round(tot*3600)));

%% ---- sanity check you can quote in the report ---------------------
% Hand-calculate the road load at one cruise point and compare.
Tb1 = readtable(fullfile(outdir,[C.tests(1).id '.csv']));
idx = find(abs(Tb1.accel_mps2) < 1e-6 & Tb1.velocity_kmh > 1, 1);
if ~isempty(idx)
    mm = C.veh.kerb_kg + C.tests(1).rider_kg;
    vv = Tb1.velocity_kmh(idx)/3.6;
    F_hand = mm*C.sim.g*C.veh.Crr + 0.5*C.sim.rho*C.veh.CdA*vv^2;
    fprintf(['\nCruise check @ %.1f km/h: model %.2f N, hand %.2f N ' ...
             '(%.2f%% error)\n'], vv*3.6, Tb1.F_total_N(idx), F_hand, ...
             100*abs(Tb1.F_total_N(idx)-F_hand)/F_hand);
end

function s = addcommas(n)
s = regexprep(num2str(n), '(\d)(?=(\d{3})+$)', '$1,');
end
