clear;
clc;

%% ============================================================
% CHECK 3.2 V DISCHARGE ENDPOINTS
% ============================================================

fprintf('============================================\n');
fprintf('3.2 V DISCHARGE ENDPOINT CHECK\n');
fprintf('============================================\n\n');

%% Load clean dataset

load('RW3_random_walk_dataset_clean.mat');

trajectoryIDs = unique(dataset.trajectory_id);

numTrajectories = numel(trajectoryIDs);

fprintf('Total trajectories: %d\n\n', numTrajectories);


%% Storage

crossingVoltage = NaN(numTrajectories,1);
crossingTime = NaN(numTrajectories,1);
crossingIndex = NaN(numTrajectories,1);

noCrossing = false(numTrajectories,1);


%% Find first voltage <= 3.2 V

for i = 1:numTrajectories

    id = trajectoryIDs(i);

    T = dataset(dataset.trajectory_id == id,:);

    idx = find(T.voltage_V <= 3.2, 1, 'first');

    if isempty(idx)

        noCrossing(i) = true;

    else

        crossingVoltage(i) = T.voltage_V(idx);

        crossingTime(i) = T.time_s(idx);

        crossingIndex(i) = idx;

    end

end


%% Results

fprintf('Trajectories reaching <= 3.2 V: %d\n', ...
    sum(~noCrossing));

fprintf('Trajectories NOT reaching <= 3.2 V: %d\n\n', ...
    sum(noCrossing));


%% Crossing voltage statistics

validCrossingVoltage = crossingVoltage(~noCrossing);

fprintf('First-crossing voltage statistics:\n');

fprintf('Minimum: %.4f V\n', ...
    min(validCrossingVoltage));

fprintf('Maximum: %.4f V\n', ...
    max(validCrossingVoltage));

fprintf('Mean: %.4f V\n', ...
    mean(validCrossingVoltage));

fprintf('Median: %.4f V\n\n', ...
    median(validCrossingVoltage));


%% Find trajectories with crossing significantly below 3.2 V

largeOvershoot = ...
    trajectoryIDs(~noCrossing & crossingVoltage < 3.15);

fprintf('Trajectories first crossing below 3.15 V: %d\n', ...
    numel(largeOvershoot));

if ~isempty(largeOvershoot)

    fprintf('IDs:\n');
    disp(largeOvershoot');

end


%% Show trajectory 109 and 412

inspectIDs = [109; 175; 412];

fprintf('\n============================================\n');
fprintf('SELECTED TRAJECTORIES\n');
fprintf('============================================\n\n');

for i = 1:numel(inspectIDs)

    id = inspectIDs(i);

    T = dataset(dataset.trajectory_id == id,:);

    idx = find(T.voltage_V <= 3.2, 1, 'first');

    fprintf('Trajectory %d\n', id);

    fprintf('Samples: %d\n', height(T));

    fprintf('Duration: %.2f s\n', T.time_s(end));

    if isempty(idx)

        fprintf('No sample <= 3.2 V\n');

    else

        fprintf('First <= 3.2 V sample: %d\n', idx);

        fprintf('Crossing time: %.2f s\n', T.time_s(idx));

        fprintf('Crossing voltage: %.4f V\n', ...
            T.voltage_V(idx));

    end

    fprintf('\n');

end


%% Plot crossing voltage

figure;

histogram(validCrossingVoltage, 30);

grid on;

xlabel('First Voltage at or Below 3.2 V (V)');
ylabel('Number of Trajectories');

title('RW3 Discharge Endpoint Distribution');


fprintf('============================================\n');
fprintf('CHECK COMPLETE\n');
fprintf('============================================\n');