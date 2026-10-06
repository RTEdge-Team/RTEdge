function C = phase2_config()
%PHASE2_CONFIG  Single source of truth for the Phase 2 HIL rig.
%
% Every parameter the vehicle model and the batch runner use lives here.
% Edit ONLY this file when something changes.
%
% ===================================================================
%  SECTION 1 - INITIAL CONDITIONS TO CONFIRM BEFORE THE FIRST RUN
%  Each entry is marked [SOURCED], [ASSUMED] or [MEASURE].
%  [MEASURE] entries MUST be replaced with your own bench measurement
%  before the dataset campaign starts. Leave them and the labels in
%  your dataset will be wrong.
% ===================================================================

%% --- Reference vehicle: Ather 450X, 3.5 kWh ------------------------
C.veh.name        = 'Ather 450X (3.5 kWh)';
C.veh.kerb_kg     = 111.6;    % [SOURCED] Ather specifications page
C.veh.rider_kg    = 75.0;     % [ASSUMED] nominal rider; swept in Block E
C.veh.CdA         = 0.54;     % [ASSUMED] 0.9 x 0.6 m^2, scooter + rider
                              %   cross-check: 0.50 implied by 90 km/h @ 6.4 kW
C.veh.Crr         = 0.015;    % [ASSUMED] scooter tyre on asphalt
C.veh.eta         = 0.85;     % [ASSUMED] PMSM + belt drive, elec -> wheel
C.veh.P_peak_W    = 6400;     % [SOURCED] 6.4 kW controller peak
C.veh.torque_Nm   = 26;       % [SOURCED] for reference only
C.veh.vmax_kmh    = 90;       % [SOURCED]
C.veh.grade_max_deg = 20;     % [SOURCED] published gradeability

%% --- Reference pack ------------------------------------------------
C.pack.energy_Wh  = 3500;     % [SOURCED] installed capacity
C.pack.V_nom      = 51.1;     % [SOURCED-OLD] earlier Ather spec sheet;
                              %   NOT on the current specifications page
C.pack.Ns         = 14;       % [DERIVED] round(51.1 / 3.65)
C.pack.Ah         = C.pack.energy_Wh / C.pack.V_nom;   % 68.5 Ah

%% --- Bench cell: LG INR18650MJ1 ------------------------------------
C.cell.name       = 'LG INR18650MJ1';
C.cell.Ah_rated   = 3.40;     % [SOURCED] datasheet MINIMUM capacity
                              %   (nominal 3.50 Ah)
C.cell.Ah_actual  = 3.40;     % [MEASURE] <<< replace with your measured
                              %   reference-discharge capacity in Week 1
C.cell.V_nom      = 3.635;    % [SOURCED]
C.cell.V_full     = 4.20;     % [SOURCED]
C.cell.V_end      = 3.20;     % [DECIDE] 3.20 keeps Phase 1 consistency;
                              %   2.50 is the datasheet floor. FIX IT NOW
                              %   AND NEVER CHANGE IT MID-CAMPAIGN.
C.cell.I_max_A    = 10.0;     % [SOURCED] max continuous discharge
C.cell.I_chg_A    = 1.70;     % [SOURCED] standard CC-CV charge current
                              %   (the TP4056 modules charge at 1.0 A)
C.cell.chg_temp_C = [0 45];   % [SOURCED] charging temperature range
C.cell.cycle_life = 400;      % [SOURCED] approx. cycles to 80% capacity;
                              %   the campaign uses < 30 cycles per cell
C.cell.R_int_mOhm = 40;       % [MEASURE] DC internal resistance, Week 1

% Parallel-string equivalence: one bench cell stands in for one of
% Np_eq strings, so it sees the same C-rate as every cell in the pack.
C.cell.Np_eq      = C.pack.Ah / C.cell.Ah_actual;      % ~20.15

%% --- Instrument: ATORCH DL24P --------------------------------------
C.load.I_min_A    = 0.20;     % [SOURCED] hard floor - cannot go lower
C.load.I_max_A    = 20.0;     % [SOURCED]
C.load.P_max_W    = 180;      % [SOURCED]
C.load.V_min      = 2.0;      % [SOURCED]
C.load.accuracy   = 0.03;     % [SOURCED] +/-3% + 3 counts

%% --- Simulation ----------------------------------------------------
C.sim.dt          = 1.0;      % s, matches rig logging rate
C.sim.rho         = 1.225;    % kg/m^3
C.sim.g           = 9.81;     % m/s^2
C.sim.model       = 'EV_Phase2_VehicleModel';
C.sim.outdir      = 'profiles';
C.sim.profile_s   = 14*3600;  % s, length of EVERY generated profile. Must
                              %   exceed the longest discharge in the matrix
                              %   with margin; the batch runner checks this
                              %   and warns per condition.

% ===================================================================
%  SECTION 2 - TEST MATRIX
%
%  Feasibility was checked before this matrix was written. Two results
%  drove the design:
%
%   * CONSTANT NEGATIVE GRADES ARE NOT RUNNABLE. At -4% a trajectory
%     takes 35 h and 23% of samples fall under the load's 0.2 A floor;
%     at -6% it takes 97 h. Downhill therefore appears ONLY inside
%     zero-mean rolling / random profiles, never as a standalone run.
%
%   * POSITIVE GRADE BUYS BOTH SIGNAL AND THROUGHPUT. Mean cell current
%     spans 0.45 A (flat) to 1.15 A (+6%), and trajectory time falls
%     from 7.5 h to 3.0 h.
%
%  Fields:
%    id        short tag, becomes the CSV filename
%    cycle     'idc' | 'cruise' | 'mixed'
%    cyc_param cruise speed in km/h (cruise only), else []
%    grade     'const' | 'sine' | 'randwalk'
%    g_param   [pct] | [amplitude_pct period_s] | [limit_pct seed]
%    rider_kg  payload
%    reps      how many times to repeat the base cycle to fill a
%              discharge; the runner sizes this automatically if 0
%    note      why this condition is in the matrix
% ===================================================================

k = 0; T = struct([]);

% ---- Block A: baseline, repeated for reproducibility ---------------
for r = 1:3
    k=k+1; T(k).id=sprintf('A%d_idc_flat',r);      T(k).cycle='idc';
    T(k).cyc_param=[]; T(k).grade='const'; T(k).g_param=0;
    T(k).rider_kg=75; T(k).reps=0;
    T(k).note='baseline; three repeats establish run-to-run spread';
end

% ---- Block B: positive gradient sweep ------------------------------
for gp = [2 4 6]
    k=k+1; T(k).id=sprintf('B_grade_p%d',gp);      T(k).cycle='idc';
    T(k).cyc_param=[]; T(k).grade='const'; T(k).g_param=gp;
    T(k).rider_kg=75; T(k).reps=0;
    T(k).note='gradient is the strongest single axis in the matrix';
end

% ---- Block C: sustained cruise (no idle -> clears the load floor) --
% These also cover the speed range the IDC never reaches. The IDC tops
% out at 42 km/h and only exercises ~30% of the motor's peak, so without
% Block C the dataset would contain no high-speed behaviour at all.
% They are honestly synthetic: they make no claim to be a standard cycle.
for sp = [35 45 60]
    k=k+1; T(k).id=sprintf('C_cruise_%d',sp);      T(k).cycle='cruise';
    T(k).cyc_param=sp; T(k).grade='const'; T(k).g_param=0;
    T(k).rider_kg=75; T(k).reps=0;
    T(k).note='high, steady current; covers the speed band IDC omits';
end

% ---- Block D: rolling terrain, zero mean grade ---------------------
for amp = [3 5]
    k=k+1; T(k).id=sprintf('D_rolling_%d',amp);    T(k).cycle='idc';
    T(k).cyc_param=[]; T(k).grade='sine'; T(k).g_param=[amp 240+120*(amp==5)];
    T(k).rider_kg=75; T(k).reps=0;
    T(k).note='zero-mean grade still costs more than flat: regen is discarded';
end

% ---- Block E: payload sweep ----------------------------------------
for rk = [60 90 120]
    k=k+1; T(k).id=sprintf('E_payload_%d',rk);     T(k).cycle='idc';
    T(k).cyc_param=[]; T(k).grade='const'; T(k).g_param=0;
    T(k).rider_kg=rk; T(k).reps=0;
    T(k).note='weak axis (~21% current spread 60->120 kg) but free to collect';
end

% ---- Block F: randomised missions - the bulk of the dataset --------
% Deliberately mirrors the NASA random-walk structure: Blocks A-E are
% the characterisation runs, Block F is the randomised operating data.
for s = 1:10
    k=k+1; T(k).id=sprintf('F_mission_%02d',s);    T(k).cycle='mixed';
    T(k).cyc_param=[]; T(k).grade='randwalk'; T(k).g_param=[5 s];
    T(k).rider_kg=60+30*mod(s,3);  T(k).reps=0;
    T(k).note='randomised grade and cycle mix; the generalisation set';
end

% ---- Block G: WMTC Class 1 - SLOT RESERVED, NOT YET POPULATED ------
% The reference vehicle classifies as WMTC Class 1 (125 cc-equivalent,
% i.e. <150 cc, and vmax 90 km/h < 100 km/h). Class 1 runs two ~600 s
% parts, both reduced-speed, weighted 0.5 / 0.5.
%
% NOT ENABLED, deliberately. The certified second-by-second table is in
% UNECE GTR No. 2; it is public but could not be retrieved here. Writing
% a reconstruction would repeat the provenance weakness that already
% applies to the IDC trace, and unlike the IDC we do not even have the
% published summary statistics to tune against.
%
% TO ENABLE: download GTR No. 2, add the Part 1 / Part 2 reduced tables
% as a 'wmtc1' case in make_drive_cycle.m, then uncomment below.
%
% for p = 1:2
%     k=k+1; T(k).id=sprintf('G_wmtc1_part%d',p); T(k).cycle='wmtc1';
%     T(k).cyc_param=p; T(k).grade='const'; T(k).g_param=0;
%     T(k).rider_kg=75; T(k).reps=0;
%     T(k).note='certified international two-wheeler cycle, Class 1';
% end

C.tests = T;

% ===================================================================
%  SECTION 3 - HARDWARE-SIDE CONDITIONS
%  These are NOT simulated. Simulink cannot produce them; they are
%  recorded by the rig and joined to the profile by timestamp.
% ===================================================================
C.hw.ambient_C_target = [20 25 30 35];  % log actual, do not assume
C.hw.log_channels = { 'timestamp','V_cell','I_cell','T_cell','T_ambient', ...
                      'cycle_index','condition_id' };
C.hw.notes = [ ...
 'Ambient temperature is the single most valuable channel this rig adds: ' ...
 'Phase 1 had to discard it because 68% of the public sensor data was ' ...
 'invalid, despite it being the strongest correlate of remaining runtime ' ...
 '(-0.6704). Record it every second, on every run, without exception.'];

end
