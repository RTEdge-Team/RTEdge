clear;
clc;

%% Load generated dataset

load('RW3_random_walk_dataset.mat');

fprintf('============================================\n');
fprintf('RW3 DATASET QUALITY CHECK\n');
fprintf('============================================\n\n');

%% Temperature check

temp = dataset.temperature_C;

invalidTemp = temp < -50 | temp > 100 | ~isfinite(temp);

fprintf('Total samples              : %d\n', height(dataset));
fprintf('Invalid temperature samples: %d\n', sum(invalidTemp));
fprintf('Percentage invalid         : %.4f %%\n\n', ...
    100 * sum(invalidTemp) / height(dataset));

%% Show temperature range excluding invalid values

validTemp = temp(~invalidTemp);

fprintf('Valid temperature minimum: %.4f C\n', min(validTemp));
fprintf('Valid temperature maximum: %.4f C\n\n', max(validTemp));

%% Find trajectories containing invalid temperature

badTrajectories = unique(dataset.trajectory_id(invalidTemp));

fprintf('Trajectories with invalid temperature: %d\n', ...
    numel(badTrajectories));

fprintf('\nFirst 20 affected trajectory IDs:\n');
disp(badTrajectories(1:min(20,end)));

%% Remaining-time check

fprintf('\n============================================\n');
fprintf('REMAINING TIME CHECK\n');
fprintf('============================================\n\n');

fprintf('Minimum remaining time: %.4f s\n', ...
    min(dataset.remaining_time_s));

fprintf('Maximum remaining time: %.4f s\n', ...
    max(dataset.remaining_time_s));

%% Check final sample of each trajectory

trajectoryIDs = unique(dataset.trajectory_id);

lastRows = zeros(numel(trajectoryIDs),1);

for i = 1:numel(trajectoryIDs)

    idx = find(dataset.trajectory_id == trajectoryIDs(i), 1, 'last');

    lastRows(i) = idx;

end

finalVoltage = dataset.voltage_V(lastRows);
finalRemaining = dataset.remaining_time_s(lastRows);

fprintf('\nFinal voltage range:\n');
fprintf('Minimum: %.4f V\n', min(finalVoltage));
fprintf('Maximum: %.4f V\n', max(finalVoltage));

fprintf('\nFinal remaining-time range:\n');
fprintf('Minimum: %.4f s\n', min(finalRemaining));
fprintf('Maximum: %.4f s\n', max(finalRemaining));