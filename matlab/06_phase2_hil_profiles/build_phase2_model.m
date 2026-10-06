function mdl = build_phase2_model(C)
%BUILD_PHASE2_MODEL  Construct the Phase 2 vehicle-dynamics model.
%
%   mdl = build_phase2_model(phase2_config())
%
% Uses CORE SIMULINK BLOCKS ONLY - no Powertrain Blockset, no Vehicle
% Dynamics Blockset, no Simscape. It runs on any MATLAB with Simulink.
%
% SIGNAL PATH
%   v, grade (From Workspace, 1 Hz)
%        |
%   a = dv/dt (Discrete Derivative - discrete, because the solver is
%              fixed-step discrete; a continuous Derivative block will
%              not compile here)
%        |
%   F_total = m*a + m*g*Crr*cos(th) + m*g*sin(th) + 0.5*rho*CdA*v^2
%        |
%   P_wheel = F_total * v
%        |
%   clamp to >= 0          <- the DL24P sinks current, it cannot source.
%                             Regeneration is logged, never commanded.
%        |
%   / eta                  <- driveline losses
%        |
%   clamp to <= P_peak     <- the controller will not pass more than its
%                             rating however hard the throttle is pressed
%        |
%   / (Ns*Np_eq) = P_cell  <- the quantity written to CSV. POWER, not
%                             current, because the cell's voltage moves
%                             from 4.2 V to 3.2 V during a discharge and
%                             the Pi divides by the live measurement.
%
% Vehicle parameters arrive through five scalar Constant blocks fed from
% the base-workspace scalars VEH_M/VEH_CDA/VEH_CRR/VEH_RHO/VEH_G, so a
% sweep only has to reassign those between runs - no rewiring, no
% regenerating the chart.

mdl = C.sim.model;
if bdIsLoaded(mdl), close_system(mdl, 0); end
new_system(mdl);

Ns_Np = C.pack.Ns * C.cell.Np_eq;

% Solver FIRST. The diagram update further down compiles the model, and
% compiling under the default variable-step solver would be both slower
% and inconsistent with the Discrete Derivative block.
% Fixed-step discrete at dt guarantees exactly one CSV row per second,
% aligned with the rig's logging rate. A variable-step solver would emit
% irregularly spaced samples and silently break that alignment.
set_param(mdl, 'SolverType','Fixed-step', ...
               'Solver','FixedStepDiscrete', ...
               'FixedStep',num2str(C.sim.dt), ...
               'StopTime','10');      % overridden per run by the runner

%% ---- sources ------------------------------------------------------
% Interpolation off and final-value hold: the trace is already at the
% solver rate, so any interpolation would only invent samples.
add_block('simulink/Sources/From Workspace', [mdl '/DriveCycle_v'], ...
    'VariableName','driveCycleData','Interpolate','off', ...
    'OutputAfterFinalValue','Holding final value','Position',[40 60 170 90]);
add_block('simulink/Sources/From Workspace', [mdl '/Grade'], ...
    'VariableName','gradeData','Interpolate','off', ...
    'OutputAfterFinalValue','Holding final value','Position',[40 250 170 280]);
% Vehicle parameters enter as FIVE SCALAR constants, not one vector.
% A vector input would have to have its width inferred, and the diagram
% update below runs BEFORE wiring - with no source attached Simulink
% infers width 1 and the chart body then fails on p(2)..p(5). Scalars
% infer correctly with no source, so the build is robust.
% Each Constant reads a base-workspace scalar, so a sweep only has to
% reassign those five variables between runs.
pnames = {'VehM','VEH_M'; 'VehCdA','VEH_CDA'; 'VehCrr','VEH_CRR'; ...
          'VehRho','VEH_RHO'; 'VehG','VEH_G'};
for ii = 1:size(pnames,1)
    add_block('simulink/Sources/Constant', [mdl '/' pnames{ii,1}], ...
        'Value', pnames{ii,2}, ...
        'Position',[40 320+45*(ii-1) 150 345+45*(ii-1)]);
end

%% ---- dynamics -----------------------------------------------------
add_block('simulink/Discrete/Discrete Derivative', [mdl '/Accel_dv_dt'], ...
    'Position',[235 55 315 95]);

add_block('simulink/User-Defined Functions/MATLAB Function', ...
    [mdl '/RoadLoad'], 'Position',[390 55 530 400]);

add_block('simulink/Math Operations/Product', [mdl '/P_wheel'], ...
    'Position',[600 85 640 125]);

%% ---- power chain --------------------------------------------------
add_block('simulink/Discontinuities/Saturation', [mdl '/ClampRegen'], ...
    'UpperLimit','inf','LowerLimit','0','Position',[690 85 730 125]);

add_block('simulink/Math Operations/Gain', [mdl '/DrivelineEff'], ...
    'Gain',num2str(1/C.veh.eta), 'Position',[780 85 830 125]);

add_block('simulink/Discontinuities/Saturation', [mdl '/MotorLimit'], ...
    'UpperLimit',num2str(C.veh.P_peak_W),'LowerLimit','0', ...
    'Position',[880 85 920 125]);

add_block('simulink/Math Operations/Gain', [mdl '/CellScale'], ...
    'Gain',num2str(1/Ns_Np), 'Position',[970 85 1020 125]);

%% ---- flags --------------------------------------------------------
add_block('simulink/Logic and Bit Operations/Compare To Zero', ...
    [mdl '/RegenFlag'], 'relop','<', 'Position',[690 200 750 240]);

add_block('simulink/Logic and Bit Operations/Compare To Constant', ...
    [mdl '/LimitFlag'], 'relop','>','const',num2str(C.veh.P_peak_W), ...
    'Position',[880 200 940 240]);

% The two Compare blocks emit boolean (they accept only 'boolean' or
% 'uint8'). A Mux requires all inputs to share a data type, so convert
% both to double before logging - without this the model will not
% compile.
add_block('simulink/Signal Attributes/Data Type Conversion', ...
    [mdl '/RegenFlagD'], 'OutDataTypeStr','double', ...
    'Position',[790 200 840 240]);
add_block('simulink/Signal Attributes/Data Type Conversion', ...
    [mdl '/LimitFlagD'], 'OutDataTypeStr','double', ...
    'Position',[980 200 1030 240]);

%% ---- logging ------------------------------------------------------
% One Mux and one sink keeps the diagram legible as a report figure.
% Channel order: v, a, grade, Ftotal, Pwheel, Ppack, Pcell, regen, limit
add_block('simulink/Signal Routing/Mux', [mdl '/LogMux'], ...
    'Inputs','9','DisplayOption','bar','Position',[1090 45 1095 320]);
add_block('simulink/Sinks/To Workspace', [mdl '/SimLog'], ...
    'VariableName','simlog','SaveFormat','Structure With Time', ...
    'Position',[1160 165 1260 200]);

%% ---- populate the MATLAB Function block ---------------------------
% NOTE: set_param(...,'Script',...) does NOT work for this block type.
% The Stateflow API below is the supported route.
scriptText = sprintf([ ...
 'function Ftotal = roadload(v, a, grade_pct, m, CdA, Crr, rho, g)\n' ...
 '%%#codegen\n' ...
 '%% All inputs are scalars - see the note on the Constant blocks.\n' ...
 'theta  = atan(grade_pct/100);\n' ...
 'F_in   = m*a;\n' ...
 'F_roll = m*g*Crr*cos(theta);\n' ...
 'F_grad = m*g*sin(theta);\n' ...
 'F_aero = 0.5*rho*CdA*v^2;\n' ...
 'Ftotal = F_in + F_roll + F_grad + F_aero;\n' ...
 'end\n']);
ch = find(sfroot, '-isa','Stateflow.EMChart', 'Path',[mdl '/RoadLoad']);
ch.Script = scriptText;

% The diagram update below COMPILES the model, and compiling evaluates
% every source block's parameter expression. driveCycleData, gradeData
% and the VEH_* scalars do not exist in the base workspace at build time,
% so without
% these placeholders the update fails with
%   "Variable 'driveCycleData' does not exist".
% run_phase2_batch overwrites all three before every run.
ph.time = [0; 1];
ph.signals.values = [0; 0];
ph.signals.dimensions = 1;
assignin('base','driveCycleData', ph);
assignin('base','gradeData',      ph);
assignin('base','VEH_M',   C.veh.kerb_kg + C.veh.rider_kg);
assignin('base','VEH_CDA', C.veh.CdA);
assignin('base','VEH_CRR', C.veh.Crr);
assignin('base','VEH_RHO', C.sim.rho);
assignin('base','VEH_G',   C.sim.g);

% Force an update so RoadLoad exposes its eight input ports BEFORE wiring.
set_param(mdl, 'SimulationCommand', 'update');

%% ---- wiring -------------------------------------------------------
add_line(mdl,'DriveCycle_v/1','Accel_dv_dt/1','autorouting','on');
add_line(mdl,'DriveCycle_v/1','RoadLoad/1','autorouting','on');
add_line(mdl,'Accel_dv_dt/1','RoadLoad/2','autorouting','on');
add_line(mdl,'Grade/1','RoadLoad/3','autorouting','on');
for ii = 1:size(pnames,1)
    add_line(mdl, [pnames{ii,1} '/1'], sprintf('RoadLoad/%d', ii+3), ...
             'autorouting','on');
end

add_line(mdl,'DriveCycle_v/1','P_wheel/1','autorouting','on');
add_line(mdl,'RoadLoad/1','P_wheel/2','autorouting','on');

add_line(mdl,'P_wheel/1','ClampRegen/1','autorouting','on');
add_line(mdl,'ClampRegen/1','DrivelineEff/1','autorouting','on');
add_line(mdl,'DrivelineEff/1','MotorLimit/1','autorouting','on');
add_line(mdl,'MotorLimit/1','CellScale/1','autorouting','on');

add_line(mdl,'P_wheel/1','RegenFlag/1','autorouting','on');
add_line(mdl,'RegenFlag/1','RegenFlagD/1','autorouting','on');
add_line(mdl,'DrivelineEff/1','LimitFlag/1','autorouting','on');
add_line(mdl,'LimitFlag/1','LimitFlagD/1','autorouting','on');

add_line(mdl,'DriveCycle_v/1','LogMux/1','autorouting','on');
add_line(mdl,'Accel_dv_dt/1','LogMux/2','autorouting','on');
add_line(mdl,'Grade/1','LogMux/3','autorouting','on');
add_line(mdl,'RoadLoad/1','LogMux/4','autorouting','on');
add_line(mdl,'P_wheel/1','LogMux/5','autorouting','on');
add_line(mdl,'MotorLimit/1','LogMux/6','autorouting','on');
add_line(mdl,'CellScale/1','LogMux/7','autorouting','on');
add_line(mdl,'RegenFlagD/1','LogMux/8','autorouting','on');
add_line(mdl,'LimitFlagD/1','LogMux/9','autorouting','on');
add_line(mdl,'LogMux/1','SimLog/1','autorouting','on');

%% ---- save ---------------------------------------------------------
% (Solver was configured at the top, before the compile.)
save_system(mdl, [mdl '.slx']);
fprintf('Model built and saved: %s.slx\n', mdl);
end
