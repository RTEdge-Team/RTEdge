clear;
clc;

%% Load RW3

fileName = '..\..\data\nasa_raw\RW3.mat';

S = load(fileName);
steps = S.data.step;

numSteps = numel(steps);

%% Convert comments

comments = strings(numSteps,1);
types = strings(numSteps,1);

for i = 1:numSteps
    comments(i) = string(steps(i).comment);
    types(i) = string(steps(i).type);
end

%% Find random-walk discharge steps

rwD = comments == "discharge (random walk)";

rwIndices = find(rwD);

%% Find the end of each random-walk episode
%
% An episode ends when the next step is NOT
% another random-walk rest/discharge sequence.

episodeEnd = [];

for i = 1:numel(rwIndices)

    idx = rwIndices(i);

    % If next step is not random-walk rest,
    % this discharge may be the final discharge.
    if idx == numSteps

        episodeEnd(end+1) = idx;

    else

        nextComment = comments(idx + 1);

        if nextComment ~= "rest (random walk)"

            episodeEnd(end+1) = idx;

        end

    end

end

%% Display results

fprintf('===== RANDOM-WALK EPISODE END CHECK =====\n\n');

fprintf('Total random-walk discharge steps : %d\n', ...
    numel(rwIndices));

fprintf('Potential episode endings         : %d\n\n', ...
    numel(episodeEnd));

%% Inspect first 30 endings

fprintf('===== FIRST 30 EPISODE ENDINGS =====\n\n');

for i = 1:min(30,numel(episodeEnd))

    idx = episodeEnd(i);

    fprintf(['End %2d | Step %5d | Type %s | ', ...
             'Comment: %s\n'], ...
        i, ...
        idx, ...
        types(idx), ...
        comments(idx));

    if idx < numSteps

        fprintf('       Next step: %5d | Type %s | Comment: %s\n', ...
            idx + 1, ...
            types(idx + 1), ...
            comments(idx + 1));

    end

    fprintf('\n');

end