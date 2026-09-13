clear;
clc;

%% ============================================================
% TRAJECTORY-AWARE TRAIN / VALIDATION / TEST SPLIT
%
% Dataset:
%       RW3_random_walk_dataset_FINAL.mat
%
% Split:
%       70% Train
%       15% Validation
%       15% Test
%
% IMPORTANT:
%       Splitting is performed by trajectory ID,
%       NOT by individual samples.
% ============================================================

fprintf('============================================\n');
fprintf('TRAJECTORY-AWARE DATASET SPLIT\n');
fprintf('============================================\n\n');


%% 1. Load final dataset

load('RW3_random_walk_dataset_FINAL.mat');

fprintf('Final dataset loaded.\n');


%% 2. Get trajectory IDs

trajectoryIDs = unique(dataset.trajectory_id);

numTrajectories = numel(trajectoryIDs);

fprintf('Total trajectories: %d\n\n', ...
    numTrajectories);


%% 3. Set random seed

% Using a fixed seed makes the split reproducible.

rng(42);


%% 4. Randomly shuffle trajectory IDs

shuffledIDs = trajectoryIDs(randperm(numTrajectories));


%% 5. Calculate split sizes

numTrain = floor(0.70 * numTrajectories);

numValidation = floor(0.15 * numTrajectories);

numTest = numTrajectories ...
          - numTrain ...
          - numValidation;


fprintf('Train trajectories      : %d\n', numTrain);

fprintf('Validation trajectories : %d\n', numValidation);

fprintf('Test trajectories       : %d\n\n', numTest);


%% 6. Assign trajectory IDs

trainIDs = shuffledIDs( ...
    1:numTrain);

validationIDs = shuffledIDs( ...
    numTrain + 1 : ...
    numTrain + numValidation);

testIDs = shuffledIDs( ...
    numTrain + numValidation + 1 : ...
    end);


%% 7. Create datasets

trainData = dataset( ...
    ismember(dataset.trajectory_id, trainIDs), :);

validationData = dataset( ...
    ismember(dataset.trajectory_id, validationIDs), :);

testData = dataset( ...
    ismember(dataset.trajectory_id, testIDs), :);


%% 8. Display sample counts

fprintf('============================================\n');
fprintf('SAMPLE COUNTS\n');
fprintf('============================================\n\n');

fprintf('Training samples      : %d\n', ...
    height(trainData));

fprintf('Validation samples    : %d\n', ...
    height(validationData));

fprintf('Test samples          : %d\n\n', ...
    height(testData));


%% 9. Verify trajectory counts

fprintf('============================================\n');
fprintf('TRAJECTORY COUNTS\n');
fprintf('============================================\n\n');

fprintf('Training trajectories   : %d\n', ...
    numel(unique(trainData.trajectory_id)));

fprintf('Validation trajectories : %d\n', ...
    numel(unique(validationData.trajectory_id)));

fprintf('Test trajectories       : %d\n\n', ...
    numel(unique(testData.trajectory_id)));


%% 10. Verify no overlap

trainValOverlap = intersect( ...
    trainIDs, validationIDs);

trainTestOverlap = intersect( ...
    trainIDs, testIDs);

valTestOverlap = intersect( ...
    validationIDs, testIDs);


fprintf('============================================\n');
fprintf('LEAKAGE CHECK\n');
fprintf('============================================\n\n');

fprintf('Train ∩ Validation: %d\n', ...
    numel(trainValOverlap));

fprintf('Train ∩ Test      : %d\n', ...
    numel(trainTestOverlap));

fprintf('Validation ∩ Test : %d\n\n', ...
    numel(valTestOverlap));


if ~isempty(trainValOverlap) || ...
   ~isempty(trainTestOverlap) || ...
   ~isempty(valTestOverlap)

    error('Trajectory overlap detected!');

else

    fprintf('No trajectory overlap detected.\n');

end


%% 11. Verify all trajectories are assigned

allAssigned = [ ...
    trainIDs;
    validationIDs;
    testIDs];

allAssigned = sort(allAssigned);

if isequal(allAssigned(:), ...
           sort(trajectoryIDs(:)))

    fprintf('\nAll trajectories assigned exactly once.\n');

else

    error('Some trajectories are missing or duplicated.');

end


%% 12. Save split

save( ...
    'RW3_train_validation_test_split.mat', ...
    'trainData', ...
    'validationData', ...
    'testData', ...
    'trainIDs', ...
    'validationIDs', ...
    'testIDs');


%% 13. Display examples

fprintf('\n============================================\n');
fprintf('EXAMPLE TRAJECTORY IDs\n');
fprintf('============================================\n\n');

fprintf('First 10 training IDs:\n');

disp(trainIDs(1:min(10,end))');

fprintf('First 10 validation IDs:\n');

disp(validationIDs(1:min(10,end))');

fprintf('First 10 test IDs:\n');

disp(testIDs(1:min(10,end))');


%% 14. Final message

fprintf('\n============================================\n');
fprintf('SPLIT COMPLETE\n');
fprintf('============================================\n\n');

fprintf('Saved as:\n');
fprintf('RW3_train_validation_test_split.mat\n');