clear;
clc;

%% NASA RW3 Inspection

fileName = '..\..\data\nasa_raw\RW3.mat';

%% Check whether file exists

if ~isfile(fileName)
    error('RW3.mat was not found. Check the file path.');
end

fprintf('File found successfully!\n');
fprintf('Path: %s\n\n', fileName);

%% Display contents of MAT file

disp('===== FILE CONTENTS =====');

whos('-file', fileName);

%% Load the file

S = load(fileName);

disp(' ');
disp('===== TOP-LEVEL VARIABLES =====');

disp(fieldnames(S));
disp(' ');
disp('===== DATA STRUCTURE =====');

disp(fieldnames(S.data));
disp(' ');
disp('===== TYPE AND SIZE OF DATA FIELDS =====');

fprintf('data.step        : %s, size = ', class(S.data.step));
disp(size(S.data.step));

fprintf('data.procedure   : %s, size = ', class(S.data.procedure));
disp(size(S.data.procedure));

fprintf('data.description : %s, size = ', class(S.data.description));
disp(size(S.data.description));
disp(' ');
disp('===== STEP STRUCTURE =====');

disp(fieldnames(S.data.step));
disp(' ');
disp('===== FIRST STEP =====');

disp(S.data.step(1));
disp(' ');
disp('===== FIRST STEP DATA CHECK =====');

fprintf('Number of samples: %d\n', numel(S.data.step(1).time));

fprintf('\nTime:\n');
fprintf('  First = %.4f\n', S.data.step(1).time(1));
fprintf('  Last  = %.4f\n', S.data.step(1).time(end));

fprintf('\nRelative Time:\n');
fprintf('  First = %.4f\n', S.data.step(1).relativeTime(1));
fprintf('  Last  = %.4f\n', S.data.step(1).relativeTime(end));

fprintf('\nVoltage:\n');
fprintf('  First = %.4f\n', S.data.step(1).voltage(1));
fprintf('  Last  = %.4f\n', S.data.step(1).voltage(end));

fprintf('\nCurrent:\n');
fprintf('  First = %.4f\n', S.data.step(1).current(1));
fprintf('  Last  = %.4f\n', S.data.step(1).current(end));

fprintf('\nTemperature:\n');
fprintf('  First = %.4f\n', S.data.step(1).temperature(1));
fprintf('  Last  = %.4f\n', S.data.step(1).temperature(end));

disp(' ');
disp('===== STEP TYPES =====');

types = {S.data.step.type};

uniqueTypes = unique(types);

disp(uniqueTypes');

disp(' ');
disp('===== SIGNAL LENGTH CHECK =====');

fprintf('Time         : %d\n', numel(S.data.step(1).time));
fprintf('RelativeTime : %d\n', numel(S.data.step(1).relativeTime));
fprintf('Voltage      : %d\n', numel(S.data.step(1).voltage));
fprintf('Current      : %d\n', numel(S.data.step(1).current));
fprintf('Temperature  : %d\n', numel(S.data.step(1).temperature));


disp(' ');
disp('===== TIME DIFFERENCE CHECK =====');

dt = diff(S.data.step(1).relativeTime);

fprintf('Minimum dt = %.4f\n', min(dt));
fprintf('Maximum dt = %.4f\n', max(dt));
fprintf('Mean dt    = %.4f\n', mean(dt));


disp(' ');
disp('===== MONOTONICITY CHECK =====');

fprintf('Time monotonic        : %d\n', all(diff(S.data.step(1).time) > 0));
fprintf('Relative time monotonic: %d\n', all(diff(S.data.step(1).relativeTime) > 0));