clear;
clc;
close all;

%% Load RW3
fileName = '..\..\data\nasa_raw\RW3.mat';

S = load(fileName);
steps = S.data.step;

numSteps = numel(steps);

%% Convert comments and types
comments = strings(numSteps,1);
types = strings(numSteps,1);

for i = 1:numSteps
    comments(i) = string(steps(i).comment);
    types(i) = string(steps(i).type);
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

    else

        nextComment = comments(idx + 1);

        if nextComment ~= "rest (random walk)"
            episodeEnd(end+1) = idx;
        end

    end
end

%% Find episode starts
%
% Each episode starts after a
% "charge (after random walk discharge)" step.

chargeSteps = find( ...
    comments == "charge (after random walk discharge)");

episodeStart = chargeSteps + 1;

%% Safety check
fprintf('============================================\n');
fprintf('RANDOM-WALK EPISODE INSPECTION\n');
fprintf('============================================\n\n');

fprintf('Number of episode starts : %d\n', numel(episodeStart));
fprintf('Number of episode ends   : %d\n\n', numel(episodeEnd));

%% Inspect first 10 episodes

numToShow = min(10, numel(episodeStart));

for k = 1:numToShow

    startStep = episodeStart(k);
    endStep   = episodeEnd(k);

    fprintf('--------------------------------------------\n');
    fprintf('Episode %d\n', k);
    fprintf('Steps: %d -> %d\n', startStep, endStep);

    %% Collect all samples from the episode
    time = [];
    voltage = [];
    current = [];
    temperature = [];

    for s = startStep:endStep

        time = [time, steps(s).time];
        voltage = [voltage, steps(s).voltage];
        current = [current, steps(s).current];
        temperature = [temperature, steps(s).temperature];

    end

    %% Statistics

    duration = time(end) - time(1);

    fprintf('Samples      : %d\n', numel(time));
    fprintf('Duration (s) : %.2f\n', duration);

    fprintf('Voltage      : %.4f -> %.4f V\n', ...
        voltage(1), voltage(end));

    fprintf('Current min  : %.4f A\n', min(current));
    fprintf('Current max  : %.4f A\n', max(current));

    fprintf('Temperature  : %.2f -> %.2f C\n', ...
        temperature(1), temperature(end));

    %% Plot
    figure;

    subplot(3,1,1);
    plot(time-time(1), voltage);
    grid on;
    ylabel('Voltage (V)');
    title(sprintf('RW3 Random-Walk Episode %d', k));

    subplot(3,1,2);
    plot(time-time(1), current);
    grid on;
    ylabel('Current (A)');

    subplot(3,1,3);
    plot(time-time(1), temperature);
    grid on;
    ylabel('Temperature (C)');
    xlabel('Time from episode start (s)');

end