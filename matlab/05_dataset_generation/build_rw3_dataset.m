clear;
clc;
close all;

%% ============================================================
% FINAL RW3 RANDOM-WALK DATASET GENERATION
%
% Battery:
%       RW3
%
% Total detected trajectories:
%       823
%
% Excluded trajectory:
%       175
%
% Final usable trajectories:
%       822
%
% Endpoint:
%       First observed sample with voltage <= 3.2 V
%
% Target:
%       Remaining time until endpoint
% ============================================================

fprintf('============================================\n');
fprintf('FINAL RW3 DATASET GENERATION\n');
fprintf('============================================\n\n');


%% 1. Load NASA RW3

fileName = '..\..\data\nasa_raw\RW3.mat';

S = load(fileName);

steps = S.data.step;

numSteps = numel(steps);

fprintf('Total raw steps: %d\n', numSteps);


%% 2. Read step comments

comments = strings(numSteps,1);

for i = 1:numSteps
    comments(i) = string(steps(i).comment);
end


%% 3. Find random-walk discharge steps

rwD = comments == "discharge (random walk)";

rwIndices = find(rwD);

fprintf('Random-walk discharge steps: %d\n', ...
    numel(rwIndices));


%% 4. Find episode endings

episodeEnd = [];

for i = 1:numel(rwIndices)

    idx = rwIndices(i);

    if idx == numSteps

        episodeEnd(end+1) = idx;

    elseif comments(idx + 1) ~= "rest (random walk)"

        episodeEnd(end+1) = idx;

    end

end


%% 5. Find episode starts

chargeSteps = find( ...
    comments == "charge (after random walk discharge)");

episodeStart = chargeSteps + 1;


%% 6. Verify episode count

if numel(episodeStart) ~= numel(episodeEnd)

    error(['Episode start/end mismatch. ', ...
           'Starts = %d, Ends = %d'], ...
           numel(episodeStart), ...
           numel(episodeEnd));

end


numEpisodes = numel(episodeStart);

fprintf('Detected random-walk trajectories: %d\n', ...
    numEpisodes);


%% 7. Exclude corrupted trajectory

excludedTrajectory = 175;

validTrajectoryIDs = ...
    setdiff(1:numEpisodes, excludedTrajectory);

fprintf('Excluded trajectory: %d\n', ...
    excludedTrajectory);

fprintf('Usable trajectories: %d\n\n', ...
    numel(validTrajectoryIDs));


%% 8. Prepare storage

trajectoryData = cell(numel(validTrajectoryIDs),1);

summaryData = cell(numel(validTrajectoryIDs),1);


%% 9. Process valid trajectories

for n = 1:numel(validTrajectoryIDs)

    k = validTrajectoryIDs(n);

    startStep = episodeStart(k);
    endStep   = episodeEnd(k);


    %% -----------------------------------------
    % Collect raw samples
    % ------------------------------------------

    time = [];
    voltage = [];
    current = [];
    temperature = [];

    for s = startStep:endStep

        time = [time; steps(s).time(:)];

        voltage = [voltage; steps(s).voltage(:)];

        current = [current; steps(s).current(:)];

        temperature = [temperature; ...
                       steps(s).temperature(:)];

    end


    %% -----------------------------------------
    % Convert to relative time
    % ------------------------------------------

    time_s = time - time(1);


    %% -----------------------------------------
    % Find first observed <= 3.2 V endpoint
    % ------------------------------------------

    endpointIndex = find(voltage <= 3.2, 1, 'first');


    if isempty(endpointIndex)

        error(['Trajectory %d does not reach ', ...
               'the 3.2 V endpoint.'], k);

    end


    %% -----------------------------------------
    % Keep data only up to endpoint
    % ------------------------------------------

    time_s = time_s(1:endpointIndex);

    voltage = voltage(1:endpointIndex);

    current = current(1:endpointIndex);

    temperature = temperature(1:endpointIndex);


    %% -----------------------------------------
    % Endpoint time
    % ------------------------------------------

    endpointTime = time_s(end);


    %% -----------------------------------------
    % Remaining time
    % ------------------------------------------

    remaining_time_s = ...
        endpointTime - time_s;


    %% -----------------------------------------
    % Clean invalid temperature
    % ------------------------------------------

    invalidTemperature = ...
        temperature < -50 | ...
        temperature > 100 | ...
        ~isfinite(temperature);

    temperature(invalidTemperature) = NaN;


    %% -----------------------------------------
    % IDs
    % ------------------------------------------

    battery_id = repmat( ...
        "RW3", ...
        numel(time_s), ...
        1);

    trajectory_id = repmat( ...
        k, ...
        numel(time_s), ...
        1);


    %% -----------------------------------------
    % Create trajectory table
    % ------------------------------------------

    T = table( ...
        time_s, ...
        voltage, ...
        current, ...
        temperature, ...
        remaining_time_s, ...
        battery_id, ...
        trajectory_id, ...
        'VariableNames', { ...
        'time_s', ...
        'voltage_V', ...
        'current_A', ...
        'temperature_C', ...
        'remaining_time_s', ...
        'battery_id', ...
        'trajectory_id'});


    trajectoryData{n} = T;


    %% -----------------------------------------
    % Summary
    % ------------------------------------------

    summaryData{n} = { ...
        k, ...
        startStep, ...
        endStep, ...
        height(T), ...
        time_s(end), ...
        voltage(1), ...
        voltage(end), ...
        min(voltage), ...
        max(current), ...
        sum(isnan(temperature))};

end


%% 10. Combine trajectories

dataset = vertcat(trajectoryData{:});


%% 11. Create summary table

summary = vertcat(summaryData{:});

summary = cell2table( ...
    summary, ...
    'VariableNames', { ...
    'trajectory_id', ...
    'start_step', ...
    'end_step', ...
    'num_samples', ...
    'duration_s', ...
    'start_voltage_V', ...
    'end_voltage_V', ...
    'minimum_voltage_V', ...
    'maximum_current_A', ...
    'missing_temperature_samples'});


%% 12. Validate dataset

fprintf('============================================\n');
fprintf('FINAL DATASET VALIDATION\n');
fprintf('============================================\n\n');

fprintf('Usable trajectories: %d\n', ...
    numel(unique(dataset.trajectory_id)));

fprintf('Total samples: %d\n', ...
    height(dataset));


%% Voltage

fprintf('\nVoltage:\n');

fprintf('Minimum: %.4f V\n', ...
    min(dataset.voltage_V));

fprintf('Maximum: %.4f V\n', ...
    max(dataset.voltage_V));


%% Current

fprintf('\nCurrent:\n');

fprintf('Minimum: %.4f A\n', ...
    min(dataset.current_A));

fprintf('Maximum: %.4f A\n', ...
    max(dataset.current_A));


%% Temperature

validTemp = ...
    dataset.temperature_C( ...
    ~isnan(dataset.temperature_C));

fprintf('\nTemperature:\n');

fprintf('Valid minimum: %.4f C\n', ...
    min(validTemp));

fprintf('Valid maximum: %.4f C\n', ...
    max(validTemp));

fprintf('Missing samples: %d\n', ...
    sum(isnan(dataset.temperature_C)));

fprintf('Missing percentage: %.4f %%\n', ...
    100 * sum(isnan(dataset.temperature_C)) ...
    / height(dataset));


%% Remaining time

fprintf('\nRemaining time:\n');

fprintf('Minimum: %.4f s\n', ...
    min(dataset.remaining_time_s));

fprintf('Maximum: %.4f s\n', ...
    max(dataset.remaining_time_s));


%% 13. Check for negative remaining time

if any(dataset.remaining_time_s < -1e-6)

    error('Negative remaining-time values detected.');

else

    fprintf('\nNo negative remaining-time values.\n');

end


%% 14. Check endpoints

trajectoryIDs = ...
    unique(dataset.trajectory_id);

lastRows = zeros(numel(trajectoryIDs),1);

for i = 1:numel(trajectoryIDs)

    idx = find( ...
        dataset.trajectory_id == trajectoryIDs(i), ...
        1, ...
        'last');

    lastRows(i) = idx;

end


endpointVoltage = ...
    dataset.voltage_V(lastRows);

endpointRemaining = ...
    dataset.remaining_time_s(lastRows);


fprintf('\nEndpoint voltage:\n');

fprintf('Minimum: %.4f V\n', ...
    min(endpointVoltage));

fprintf('Maximum: %.4f V\n', ...
    max(endpointVoltage));


fprintf('\nEndpoint remaining time:\n');

fprintf('Minimum: %.4f s\n', ...
    min(endpointRemaining));

fprintf('Maximum: %.4f s\n', ...
    max(endpointRemaining));


%% 15. Check excluded trajectory

if any(dataset.trajectory_id == excludedTrajectory)

    error('Excluded trajectory 175 is still present.');

else

    fprintf('\nTrajectory 175 successfully excluded.\n');

end


%% 16. Save final dataset

outputFile = ...
    'RW3_random_walk_dataset_FINAL.mat';

save( ...
    outputFile, ...
    'dataset', ...
    'summary', ...
    '-v7.3');


%% 17. Display first rows

fprintf('\n============================================\n');
fprintf('FINAL DATASET CREATED\n');
fprintf('============================================\n\n');

disp(dataset(1:10,:));

fprintf('\nSaved as:\n%s\n', outputFile);

fprintf('\n============================================\n');
fprintf('DATASET GENERATION COMPLETE\n');
fprintf('============================================\n');