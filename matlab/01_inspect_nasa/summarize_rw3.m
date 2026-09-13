clear;
clc;

%% Load NASA RW3 data

fileName = '..\..\data\nasa_raw\RW3.mat';

S = load(fileName);

steps = S.data.step;

fprintf('Total number of steps: %d\n', numel(steps));

%% Get step types

types = {steps.type};

uniqueTypes = unique(types);

disp(' ');
disp('===== STEP TYPE COUNTS =====');

for i = 1:numel(uniqueTypes)

    currentType = uniqueTypes{i};

    count = sum(strcmp(types, currentType));

    fprintf('Type %s : %d steps\n', ...
        currentType, count);

end

%% Count samples in each step

numSteps = numel(steps);

sampleCount = zeros(numSteps, 1);

for i = 1:numSteps
    sampleCount(i) = numel(steps(i).time);
end

%% Create summary table

stepNumber = (1:numSteps)';

stepType = string(types');

comments = strings(numSteps, 1);

for i = 1:numSteps
    comments(i) = string(steps(i).comment);
end

summary = table( ...
    stepNumber, ...
    stepType, ...
    sampleCount, ...
    comments);

%% Display first 20 steps

disp(' ');
disp('===== FIRST 20 STEPS =====');

disp(summary(1:min(20,numSteps), :));

%% Analyze comments by step type

disp(' ');
disp('===== UNIQUE COMMENTS BY STEP TYPE =====');

for i = 1:numel(uniqueTypes)

    currentType = uniqueTypes{i};

    fprintf('\n--- Type %s ---\n', currentType);

    typeMask = strcmp(types, currentType);

    typeComments = comments(typeMask);

    uniqueComments = unique(typeComments);

    for j = 1:numel(uniqueComments)

        comment = uniqueComments(j);

        count = sum(typeComments == comment);

        fprintf('%4d : %s\n', count, comment);

    end

end