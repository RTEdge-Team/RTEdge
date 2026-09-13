clear;
clc;

%% Load original NASA RW3 data

fileName = '..\..\data\nasa_raw\RW3.mat';

S = load(fileName);
steps = S.data.step;

fprintf('============================================\n');
fprintf('RAW TEMPERATURE INVESTIGATION\n');
fprintf('============================================\n\n');

%% Find random-walk episode boundaries

numSteps = numel(steps);

comments = strings(numSteps,1);

for i = 1:numSteps
    comments(i) = string(steps(i).comment);
end

%% Find random-walk discharge steps

rwD = comments == "discharge (random walk)";
rwIndices = find(rwD);

%% Find episode endings

episodeEnd = [];

for i = 1:numel(rwIndices)

    idx = rwIndices(i);

    if idx == numSteps

        episodeEnd(end+1) = idx;

    elseif comments(idx + 1) ~= "rest (random walk)"

        episodeEnd(end+1) = idx;

    end

end

%% Find episode starts

chargeSteps = find( ...
    comments == "charge (after random walk discharge)");

episodeStart = chargeSteps + 1;

%% Inspect trajectories around first affected region

% Trajectory 175 was the first trajectory with
% suspicious temperature values.

trajectoryNumbers = 172:178;

fprintf('Inspecting trajectories 172 to 178...\n\n');

%% Inspect selected trajectories

for k = trajectoryNumbers

    startStep = episodeStart(k);
    endStep   = episodeEnd(k);

    temp = [];

    %% Collect raw temperature values

    for s = startStep:endStep

        temp = [temp; steps(s).temperature(:)];

    end

    %% Display information

    fprintf('--------------------------------------------\n');
    fprintf('Trajectory %d\n', k);
    fprintf('Raw steps: %d -> %d\n', startStep, endStep);

    fprintf('Samples: %d\n', numel(temp));

    fprintf('Temperature min: %.4f C\n', min(temp));
    fprintf('Temperature max: %.4f C\n', max(temp));

    %% Invalid values

    invalid = temp < -50 | temp > 100 | ~isfinite(temp);

    fprintf('Invalid temperature values: %d\n', ...
        sum(invalid));

    %% NaN values

    fprintf('NaN values: %d\n', ...
        sum(isnan(temp)));

    %% Suspicious values

    suspicious = temp(invalid);

    if ~isempty(suspicious)

        fprintf('First suspicious values:\n');

        numShow = min(10, numel(suspicious));

        disp(suspicious(1:numShow));

    else

        fprintf('No suspicious temperature values.\n');

    end

    fprintf('\n');

end

fprintf('============================================\n');
fprintf('INVESTIGATION COMPLETE\n');
fprintf('============================================\n');