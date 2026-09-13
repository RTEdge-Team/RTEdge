clear;
clc;
close all;

%% ============================================================
% INSPECT SHORT AND UNUSUAL RW3 TRAJECTORIES
% ============================================================

fprintf('============================================\n');
fprintf('SHORT TRAJECTORY INVESTIGATION\n');
fprintf('============================================\n\n');


%% 1. Load dataset and summary

load('RW3_random_walk_dataset_clean.mat');

load('RW3_trajectory_summary.mat');


%% 2. Identify short trajectories

shortThreshold = 500;

shortIDs = trajectorySummary.trajectory_id( ...
    trajectorySummary.duration_s < shortThreshold);


fprintf('Number of short trajectories: %d\n\n', ...
    numel(shortIDs));


%% 3. Display all short trajectory statistics

fprintf('============================================\n');
fprintf('SHORT TRAJECTORY SUMMARY\n');
fprintf('============================================\n\n');

shortSummary = trajectorySummary( ...
    ismember(trajectorySummary.trajectory_id, shortIDs), :);

disp(shortSummary);


%% 4. Inspect unusual endpoint trajectories

unusualIDs = [109; 175; 412];

fprintf('\n============================================\n');
fprintf('UNUSUAL ENDPOINT TRAJECTORIES\n');
fprintf('============================================\n\n');

unusualSummary = trajectorySummary( ...
    ismember(trajectorySummary.trajectory_id, unusualIDs), :);

disp(unusualSummary);


%% 5. Plot all short trajectories

figure;

hold on;

for i = 1:numel(shortIDs)

    id = shortIDs(i);

    T = dataset(dataset.trajectory_id == id,:);

    plot(T.time_s, T.voltage_V);

end

grid on;

xlabel('Time (s)');
ylabel('Voltage (V)');

title('Voltage Profiles of Short RW3 Trajectories');

hold off;


%% 6. Plot endpoint voltage versus trajectory ID

figure;

scatter( ...
    trajectorySummary.trajectory_id, ...
    trajectorySummary.end_voltage_V, ...
    20, ...
    'filled');

grid on;

xlabel('Trajectory ID');
ylabel('Endpoint Voltage (V)');

title('RW3 Endpoint Voltage vs Trajectory');


%% 7. Plot duration versus trajectory ID

figure;

scatter( ...
    trajectorySummary.trajectory_id, ...
    trajectorySummary.duration_s, ...
    20, ...
    'filled');

grid on;

xlabel('Trajectory ID');
ylabel('Duration (s)');

title('RW3 Trajectory Duration vs Trajectory ID');


%% 8. Detailed information for unusual trajectories

for i = 1:numel(unusualIDs)

    id = unusualIDs(i);

    T = dataset(dataset.trajectory_id == id,:);

    fprintf('\n--------------------------------------------\n');
    fprintf('Trajectory %d\n', id);
    fprintf('--------------------------------------------\n');

    fprintf('Samples: %d\n', height(T));

    fprintf('Duration: %.4f s\n', T.time_s(end));

    fprintf('Start voltage: %.4f V\n', T.voltage_V(1));

    fprintf('End voltage: %.4f V\n', T.voltage_V(end));

    fprintf('Minimum voltage: %.4f V\n', min(T.voltage_V));

    fprintf('Maximum voltage: %.4f V\n', max(T.voltage_V));

    fprintf('Minimum current: %.4f A\n', min(T.current_A));

    fprintf('Maximum current: %.4f A\n', max(T.current_A));

    fprintf('Missing temperature: %.2f %%\n', ...
        100 * sum(isnan(T.temperature_C)) / height(T));

end


fprintf('\n============================================\n');
fprintf('INVESTIGATION COMPLETE\n');
fprintf('============================================\n');