clear;
clc;

%% Load NASA RW3

fileName = '..\..\data\nasa_raw\RW3.mat';

S = load(fileName);

steps = S.data.step;

numSteps = numel(steps);

%% Create basic information for every step

stepNumber = (1:numSteps)';

stepType = strings(numSteps,1);
comment = strings(numSteps,1);

startTime = zeros(numSteps,1);
endTime = zeros(numSteps,1);
duration = zeros(numSteps,1);

for i = 1:numSteps

    stepType(i) = string(steps(i).type);
    comment(i) = string(steps(i).comment);

    startTime(i) = steps(i).time(1);
    endTime(i) = steps(i).time(end);

    duration(i) = endTime(i) - startTime(i);

end

%% Create table

stepSummary = table( ...
    stepNumber, ...
    stepType, ...
    comment, ...
    startTime, ...
    endTime, ...
    duration);

%% Display selected columns

disp('===== STEP SEQUENCE SUMMARY =====');

disp(stepSummary(1:50,[1 2 3 4 5 6]));

%% Display transitions between comments

disp(' ');
disp('===== FIRST 50 STEP COMMENTS =====');

for i = 1:min(50,numSteps)

    fprintf('%5d | %-2s | %s\n', ...
        i, ...
        stepType(i), ...
        comment(i));

end

%% Check gaps between consecutive steps

disp(' ');
disp('===== LARGE TIME GAPS BETWEEN STEPS =====');

gap = zeros(numSteps-1,1);

for i = 1:numSteps-1

    gap(i) = steps(i+1).time(1) - steps(i).time(end);

end

largeGapIndex = find(gap > 1000);

fprintf('Number of gaps greater than 1000 seconds: %d\n', ...
    numel(largeGapIndex));

disp(' ');

for k = 1:min(30,numel(largeGapIndex))

    i = largeGapIndex(k);

    fprintf(['Step %d -> Step %d | Gap = %.2f s | ', ...
             '%s -> %s\n'], ...
        i, ...
        i+1, ...
        gap(i), ...
        comment(i), ...
        comment(i+1));

end

%% Summary of comment and sample count combinations

disp(' ');
disp('===== COMMENT / SAMPLE COUNT SUMMARY =====');

uniqueComments = unique(comment);

for i = 1:numel(uniqueComments)

    mask = comment == uniqueComments(i);

    fprintf('\n%s\n', uniqueComments(i));

    fprintf('Number of steps: %d\n', sum(mask));

    fprintf('Minimum samples: %d\n', min( ...
        arrayfun(@(x) numel(x.time), steps(mask))));

    fprintf('Maximum samples: %d\n', max( ...
        arrayfun(@(x) numel(x.time), steps(mask))));

end