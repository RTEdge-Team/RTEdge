clear;
clc;

%% Load NASA RW3

fileName = '..\..\data\nasa_raw\RW3.mat';

S = load(fileName);

steps = S.data.step;

numSteps = numel(steps);

%% Convert comments to strings

comments = strings(numSteps,1);

types = strings(numSteps,1);

for i = 1:numSteps
    comments(i) = string(steps(i).comment);
    types(i) = string(steps(i).type);
end

%% Find random-walk discharge steps

rwDischarge = comments == "discharge (random walk)";

rwIndices = find(rwDischarge);

fprintf('Total random-walk discharge steps: %d\n', ...
    numel(rwIndices));

%% Find random-walk blocks

% A new block starts when a random-walk discharge step
% follows a non-random-walk step.

blockStart = [];

for i = 1:numel(rwIndices)

    idx = rwIndices(i);

    if i == 1

        blockStart(end+1) = idx;

    else

        previousIdx = rwIndices(i-1);

        if idx ~= previousIdx + 2
            blockStart(end+1) = idx;
        end

    end

end

%% Determine block end

numBlocks = numel(blockStart);

blockEnd = zeros(numBlocks,1);

for b = 1:numBlocks

    if b < numBlocks
        blockEnd(b) = rwIndices( ...
            find(rwIndices < blockStart(b+1), 1, 'last'));
    else
        blockEnd(b) = rwIndices(end);
    end

end

%% Display block summary

disp(' ');
disp('===== RANDOM-WALK TRAJECTORY BLOCKS =====');

fprintf('\nNumber of random-walk blocks found: %d\n\n', ...
    numBlocks);

for b = 1:numBlocks

    startStep = blockStart(b);
    endStep = blockEnd(b);

    fprintf(['Block %2d | Steps %5d -> %5d | ', ...
             'Number of D steps = %4d\n'], ...
        b, ...
        startStep, ...
        endStep, ...
        sum(rwDischarge(startStep:endStep)));

end