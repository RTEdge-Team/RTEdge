clear;
clc;
close all;

%% ============================================================
%  TRAJECTORY DISTRIBUTION CHECK
% =============================================================

fprintf('============================================\n');
fprintf('RW3 TRAJECTORY DISTRIBUTION CHECK\n');
fprintf('============================================\n\n');


%% 1. Load clean dataset

load('RW3_random_walk_dataset_clean.mat');

fprintf('Dataset loaded successfully.\n\n');


%% 2. Get unique trajectory IDs

trajectoryIDs = unique(dataset.trajectory_id);

numTrajectories = numel(trajectoryIDs);

fprintf('Number of trajectories: %d\n\n', ...
    numTrajectories);


%% 3. Extract trajectory statistics

duration_s = zeros(numTrajectories,1);
num_samples = zeros(numTrajectories,1);
start_voltage = zeros(numTrajectories,1);
end_voltage = zeros(numTrajectories,1);
max_current = zeros(numTrajectories,1);
missing_temp_percent = zeros(numTrajectories,1);

for i = 1:numTrajectories

    id = trajectoryIDs(i);

    T = dataset(dataset.trajectory_id == id,:);

    duration_s(i) = T.time_s(end);

    num_samples(i) = height(T);

    start_voltage(i) = T.voltage_V(1);

    end_voltage(i) = T.voltage_V(end);

    max_current(i) = max(T.current_A);

    missing_temp_percent(i) = ...
        100 * sum(isnan(T.temperature_C)) / height(T);

end


%% 4. Display statistics

fprintf('============================================\n');
fprintf('TRAJECTORY STATISTICS\n');
fprintf('============================================\n\n');

fprintf('Duration:\n');
fprintf('  Minimum : %.2f s\n', min(duration_s));
fprintf('  Maximum : %.2f s\n', max(duration_s));
fprintf('  Mean    : %.2f s\n', mean(duration_s));
fprintf('  Median  : %.2f s\n', median(duration_s));

fprintf('\nSamples per trajectory:\n');
fprintf('  Minimum : %d\n', min(num_samples));
fprintf('  Maximum : %d\n', max(num_samples));
fprintf('  Mean    : %.2f\n', mean(num_samples));
fprintf('  Median  : %.2f\n', median(num_samples));

fprintf('\nStarting voltage:\n');
fprintf('  Minimum : %.4f V\n', min(start_voltage));
fprintf('  Maximum : %.4f V\n', max(start_voltage));
fprintf('  Mean    : %.4f V\n', mean(start_voltage));

fprintf('\nEnding voltage:\n');
fprintf('  Minimum : %.4f V\n', min(end_voltage));
fprintf('  Maximum : %.4f V\n', max(end_voltage));
fprintf('  Mean    : %.4f V\n', mean(end_voltage));

fprintf('\nMaximum current:\n');
fprintf('  Minimum : %.4f A\n', min(max_current));
fprintf('  Maximum : %.4f A\n', max(max_current));
fprintf('  Mean    : %.4f A\n', mean(max_current));

fprintf('\nMissing temperature:\n');
fprintf('  Minimum : %.2f %%\n', min(missing_temp_percent));
fprintf('  Maximum : %.2f %%\n', max(missing_temp_percent));
fprintf('  Mean    : %.2f %%\n', mean(missing_temp_percent));


%% 5. Find unusual trajectories

fprintf('\n============================================\n');
fprintf('POTENTIAL OUTLIERS\n');
fprintf('============================================\n\n');


%% Very short trajectories

shortThreshold = 500;

shortTrajectories = ...
    trajectoryIDs(duration_s < shortThreshold);

fprintf('Trajectories shorter than %d s: %d\n', ...
    shortThreshold, ...
    numel(shortTrajectories));

if ~isempty(shortTrajectories)

    fprintf('IDs:\n');
    disp(shortTrajectories');

end


%% Very long trajectories

longThreshold = 4500;

longTrajectories = ...
    trajectoryIDs(duration_s > longThreshold);

fprintf('Trajectories longer than %d s: %d\n', ...
    longThreshold, ...
    numel(longTrajectories));

if ~isempty(longTrajectories)

    fprintf('IDs:\n');
    disp(longTrajectories');

end


%% Unusual endpoint voltage

badEndpointVoltage = ...
    trajectoryIDs(end_voltage < 3.15 | end_voltage > 3.25);

fprintf('\nTrajectories with endpoint voltage outside 3.15-3.25 V: %d\n', ...
    numel(badEndpointVoltage));

if ~isempty(badEndpointVoltage)

    fprintf('IDs:\n');
    disp(badEndpointVoltage');

end


%% 6. Create summary table

trajectorySummary = table( ...
    trajectoryIDs, ...
    duration_s, ...
    num_samples, ...
    start_voltage, ...
    end_voltage, ...
    max_current, ...
    missing_temp_percent, ...
    'VariableNames', { ...
    'trajectory_id', ...
    'duration_s', ...
    'num_samples', ...
    'start_voltage_V', ...
    'end_voltage_V', ...
    'max_current_A', ...
    'missing_temperature_percent'});


%% 7. Display first rows

fprintf('\n============================================\n');
fprintf('TRAJECTORY SUMMARY\n');
fprintf('============================================\n\n');

disp(trajectorySummary(1:10,:));


%% 8. Plot duration distribution

figure;

histogram(duration_s, 30);

grid on;

xlabel('Trajectory Duration (s)');
ylabel('Number of Trajectories');

title('RW3 Random-Walk Trajectory Duration Distribution');


%% 9. Plot sample-count distribution

figure;

histogram(num_samples, 30);

grid on;

xlabel('Samples per Trajectory');
ylabel('Number of Trajectories');

title('RW3 Samples per Trajectory Distribution');


%% 10. Plot endpoint voltage

figure;

histogram(end_voltage, 30);

grid on;

xlabel('Endpoint Voltage (V)');
ylabel('Number of Trajectories');

title('RW3 Endpoint Voltage Distribution');


%% 11. Plot maximum current

figure;

histogram(max_current, 30);

grid on;

xlabel('Maximum Current (A)');
ylabel('Number of Trajectories');

title('RW3 Maximum Current Distribution');


%% 12. Save summary

save( ...
    'RW3_trajectory_summary.mat', ...
    'trajectorySummary');


fprintf('\n============================================\n');
fprintf('DISTRIBUTION CHECK COMPLETE\n');
fprintf('============================================\n\n');

fprintf('Summary saved as:\n');
fprintf('RW3_trajectory_summary.mat\n');