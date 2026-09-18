%% RTEdge - Random Forest Hyperparameter Tuning
%
% Purpose:
%   Find a better Random Forest configuration using ONLY
%   the training and validation datasets.
%
% IMPORTANT:
%   The TEST dataset is NOT used for model selection.
%
% Current baseline:
%   100 trees
%   MinLeafSize = 20
%
% We will compare several configurations.

clear;
clc;
close all;

%% ============================================================
% 1. Load Dataset
% =============================================================

load('RW3_train_validation_test_split.mat');

disp('========================================');
disp(' RANDOM FOREST HYPERPARAMETER TUNING');
disp('========================================');

%% ============================================================
% 2. Define Features and Target
% =============================================================

featureNames = {
    'voltage_V'
    'current_A'
    'time_s'
};

targetName = 'remaining_time_s';

%% ============================================================
% 3. Extract Training Data
% =============================================================

X_train = trainData{:, featureNames};

Y_train = trainData.(targetName);

%% ============================================================
% 4. Extract Validation Data
% =============================================================

X_val = validationData{:, featureNames};

Y_val = validationData.(targetName);

%% ============================================================
% 5. Remove Invalid Rows
% =============================================================

validTrain = ...
    all(isfinite(X_train), 2) ...
    & isfinite(Y_train);

validVal = ...
    all(isfinite(X_val), 2) ...
    & isfinite(Y_val);

X_train = X_train(validTrain, :);
Y_train = Y_train(validTrain);

X_val = X_val(validVal, :);
Y_val = Y_val(validVal);

fprintf('\nTraining samples   : %d\n', size(X_train,1));
fprintf('Validation samples : %d\n', size(X_val,1));

%% ============================================================
% 6. Define Candidate Hyperparameters
% =============================================================

numTreesList = [100 200];

minLeafList = [10 20 50];

numConfigurations = ...
    length(numTreesList) * length(minLeafList);

%% ============================================================
% 7. Prepare Results Table
% =============================================================

results = table( ...
    zeros(numConfigurations,1), ...
    zeros(numConfigurations,1), ...
    zeros(numConfigurations,1), ...
    zeros(numConfigurations,1), ...
    zeros(numConfigurations,1), ...
    'VariableNames', { ...
    'NumTrees', ...
    'MinLeafSize', ...
    'Validation_MAE_s', ...
    'Validation_RMSE_s', ...
    'Validation_R2'});

%% ============================================================
% 8. Run Experiments
% =============================================================

resultIndex = 0;

for t = 1:length(numTreesList)

    for l = 1:length(minLeafList)

        resultIndex = resultIndex + 1;

        numTrees = numTreesList(t);

        minLeaf = minLeafList(l);

        fprintf('\n');
        fprintf('========================================\n');
        fprintf('Configuration %d / %d\n', ...
            resultIndex, numConfigurations);

        fprintf('NumTrees    = %d\n', numTrees);
        fprintf('MinLeafSize = %d\n', minLeaf);

        %% Create tree template

        treeTemplate = templateTree( ...
            'MinLeafSize', minLeaf);

        %% Train Random Forest

        tic;

        model = fitrensemble( ...
            X_train, ...
            Y_train, ...
            'Method', 'Bag', ...
            'NumLearningCycles', numTrees, ...
            'Learners', treeTemplate);

        trainingTime = toc;

        fprintf('Training time: %.2f seconds\n', ...
            trainingTime);

        %% Validation prediction

        Y_val_pred = predict( ...
            model, ...
            X_val);

        Y_val_pred = Y_val_pred(:);

        %% Validation error

        validationError = ...
            Y_val - Y_val_pred;

        validationMAE = ...
            mean(abs(validationError));

        validationRMSE = ...
            sqrt(mean(validationError.^2));

        %% Validation R2

        SS_res = ...
            sum(validationError.^2);

        SS_tot = ...
            sum((Y_val - mean(Y_val)).^2);

        validationR2 = ...
            1 - SS_res / SS_tot;

        %% Store result

        results.NumTrees(resultIndex) = numTrees;

        results.MinLeafSize(resultIndex) = minLeaf;

        results.Validation_MAE_s(resultIndex) = ...
            validationMAE;

        results.Validation_RMSE_s(resultIndex) = ...
            validationRMSE;

        results.Validation_R2(resultIndex) = ...
            validationR2;

        %% Display

        fprintf('Validation MAE  : %.2f s\n', ...
            validationMAE);

        fprintf('Validation RMSE : %.2f s\n', ...
            validationRMSE);

        fprintf('Validation R2   : %.4f\n', ...
            validationR2);

    end

end

%% ============================================================
% 9. Display All Results
% =============================================================

disp(' ');
disp('========================================');
disp(' TUNING RESULTS');
disp('========================================');

disp(results);

%% ============================================================
% 10. Find Best Configuration
% =============================================================

[~, bestIndex] = ...
    min(results.Validation_MAE_s);

bestNumTrees = ...
    results.NumTrees(bestIndex);

bestMinLeaf = ...
    results.MinLeafSize(bestIndex);

bestMAE = ...
    results.Validation_MAE_s(bestIndex);

bestRMSE = ...
    results.Validation_RMSE_s(bestIndex);

bestR2 = ...
    results.Validation_R2(bestIndex);

%% ============================================================
% 11. Display Best Configuration
% =============================================================

disp(' ');
disp('========================================');
disp(' BEST CONFIGURATION');
disp('========================================');

fprintf('NumTrees    : %d\n', bestNumTrees);

fprintf('MinLeafSize : %d\n', bestMinLeaf);

fprintf('Validation MAE  : %.2f s\n', bestMAE);

fprintf('Validation RMSE : %.2f s\n', bestRMSE);

fprintf('Validation R2   : %.4f\n', bestR2);

%% ============================================================
% 12. Save Tuning Results
% =============================================================

save( ...
    'random_forest_tuning_results.mat', ...
    'results', ...
    'bestIndex', ...
    'bestNumTrees', ...
    'bestMinLeaf', ...
    'bestMAE', ...
    'bestRMSE', ...
    'bestR2');

writetable( ...
    results, ...
    'random_forest_tuning_results.csv');

disp(' ');
disp('Tuning results saved:');

disp('1. random_forest_tuning_results.mat');

disp('2. random_forest_tuning_results.csv');

disp(' ');
disp('IMPORTANT: Test data was NOT used.');