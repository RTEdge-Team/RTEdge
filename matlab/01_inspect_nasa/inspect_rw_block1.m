clear;
clc;

%% Load NASA RW3

fileName = '..\..\data\nasa_raw\RW3.mat';

S = load(fileName);
steps = S.data.step;

%% Block 1

startStep = 32;
endStep = 55;

fprintf('===== RW BLOCK 1 DETAILED INSPECTION =====\n\n');

fprintf('Showing steps %d to %d\n\n', startStep, endStep);

%% Display step information

for i = startStep:endStep

    fprintf('Step %d\n', i);
    fprintf('  Type    : %s\n', steps(i).type);
    fprintf('  Comment : %s\n', steps(i).comment);
    fprintf('  Samples : %d\n', numel(steps(i).time));
    fprintf('  Start   : %.2f s\n', steps(i).time(1));
    fprintf('  End     : %.2f s\n', steps(i).time(end));

    if numel(steps(i).time) > 1
        fprintf('  Duration: %.2f s\n', ...
            steps(i).time(end) - steps(i).time(1));
    else
        fprintf('  Duration: single sample\n');
    end

    fprintf('\n');

end

%% Check gaps between consecutive steps

fprintf('===== GAPS BETWEEN STEPS =====\n\n');

for i = startStep:(endStep-1)

    gap = steps(i+1).time(1) - steps(i).time(end);

    fprintf('Step %d -> Step %d : %.2f s\n', ...
        i, i+1, gap);

end