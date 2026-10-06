function [t, v_ms, grade_pct] = make_drive_cycle(C, test)
%MAKE_DRIVE_CYCLE  Build a 1 Hz speed and gradient trace for one condition.
%
%   [t, v_ms, grade_pct] = make_drive_cycle(C, test)
%
% IMPORTANT - PROVENANCE OF THE IDC TRACE
% ---------------------------------------
% The second-by-second IDC profile below is a RECONSTRUCTION. It is tuned
% to reproduce the published IDC statistics exactly:
%
%       108 s cycle, repeated 6 times      max speed   42.0 km/h
%       average speed 21.9 km/h            distance    3.94 km
%       max acceleration <= 0.64 m/s^2     (this trace peaks at 0.583)
%
% but the phase-by-phase SHAPE is not the certified table. That table is
% published in AIS-039 / IS 14513, which is not freely available. Replace
% idc_base() with the certified trace when you obtain the standard, and
% state the reconstruction in any report until you do.

dt = C.sim.dt;

% PROFILE LENGTH. Every profile is generated to C.sim.profile_s seconds
% (default 14 h), far longer than any discharge in the matrix (the longest,
% E_payload_60, is ~7.9 h). The rig stops at the cell's V_end - NOT at the
% end of the file - so a profile that ends first would leave the cell
% part-charged and the trajectory without a valid runtime label.
% Earlier fixed repetition counts left 8 of 24 profiles too short.
target_s = C.sim.profile_s;

switch lower(test.cycle)

    case 'idc'
        base = idc_base();                       % 108 s, m/s
        reps = pick_reps(test.reps, ceil(target_s/numel(base)));
        v_ms = repmat(base, reps, 1);

    case 'cruise'
        % Ramp gently to the target, then hold. No idle segments, so the
        % commanded current never approaches the DL24P's 0.2 A floor.
        vt   = test.cyc_param / 3.6;
        ramp = (0:dt:12)' / 12 * vt;             % 12 s ramp, ~0.8-1.4 m/s^2
        hold_n = max(target_s - numel(ramp), 0);
        if test.reps > 0, hold_n = test.reps * 108; end
        v_ms = [ramp; repmat(vt, hold_n, 1)];

    case 'mixed'
        % Urban block, cruise block, urban block, slow block. Reproduces
        % the structure of a real commute rather than one repeated cycle.
        % Each cruise block ends with an explicit deceleration to rest at
        % ~0.6 m/s^2 before the next urban block. Without it the trace
        % steps 45 -> 0 km/h in one sample, which the backward-difference
        % derivative reports as -12.5 m/s^2 - physically impossible, and
        % written straight into the accel_mps2 column the model trains on.
        base = idc_base();
        blk  = [ base
                 ramp_hold(base(end), 45/3.6, 12, 180)
                 ramp_hold(45/3.6,    0,      21, 0)
                 base
                 ramp_hold(base(end), 25/3.6, 10, 120)
                 ramp_hold(25/3.6,    0,      12, 0) ];
        reps = pick_reps(test.reps, ceil(target_s/numel(blk)));
        v_ms = repmat(blk, reps, 1);

    otherwise
        error('make_drive_cycle:cycle','Unknown cycle type "%s"', test.cycle);
end

n = numel(v_ms);
t = (0:dt:(n-1)*dt)';

% ---- gradient ------------------------------------------------------
switch lower(test.grade)

    case 'const'
        grade_pct = repmat(test.g_param(1), n, 1);

    case 'sine'
        % Zero-mean rolling terrain. Costs MORE energy than flat, because
        % the descents cannot be recovered - the load sinks only.
        amp = test.g_param(1);  per = test.g_param(2);
        grade_pct = amp * sin(2*pi*(0:n-1)'/per);

    case 'randwalk'
        % Mean-reverting (Ornstein-Uhlenbeck) grade: slow-varying terrain
        % that wanders around zero with a stationary spread.
        %
        % NOT a plain random walk. A plain walk's spread grows as sqrt(n);
        % over a ~34,000 s profile it spent 90-97% of samples pinned at the
        % +/-lim rails, with stretches over an hour on a sustained descent.
        % The OU process holds std near sd_pct and touches the rails <1%
        % of the time.
        lim  = test.g_param(1);  seed = test.g_param(2);
        tau  = 300;               % s, terrain correlation time
        sd   = 2.0;               % %, stationary standard deviation
        phi  = exp(-dt/tau);
        se   = sd * sqrt(1 - phi^2);
        rs   = RandStream('mt19937ar','Seed',seed);
        e    = randn(rs, n, 1) * se;
        gw   = filter(1, [1 -phi], e);      % g(k) = phi*g(k-1) + e(k)
        gw   = max(min(gw, lim), -lim);
        grade_pct = gw - mean(gw);

    otherwise
        error('make_drive_cycle:grade','Unknown grade mode "%s"', test.grade);
end

end

% =====================================================================
function v = idc_base()
% One 108 s Indian Driving Cycle, in m/s at 1 Hz. See provenance note.
% Segments are [target_kmh, ramp_s, hold_s].
segs = [  0   0   4
         21  10  20
         33   8   8
         42   6  16
          0  22   0 ];
v = 0;
for k = 1:size(segs,1)
    tgt = segs(k,1)/3.6;  ramp = segs(k,2);  hold_s = segs(k,3);
    if ramp > 0
        step = linspace(v(end), tgt, ramp+1)';
        v = [v; step(2:end)];                                    %#ok<AGROW>
    end
    if hold_s > 0
        v = [v; repmat(tgt, hold_s, 1)];                         %#ok<AGROW>
    end
end
if numel(v) < 108, v = [v; zeros(108-numel(v),1)]; end
v = v(1:108);
end

% ---------------------------------------------------------------------
function seg = ramp_hold(v0, vt, ramp_s, hold_s)
step = linspace(v0, vt, ramp_s+1)';
seg  = [step(2:end); repmat(vt, hold_s, 1)];
end

% ---------------------------------------------------------------------
function r = pick_reps(requested, default_reps)
if requested > 0, r = requested; else, r = default_reps; end
end
