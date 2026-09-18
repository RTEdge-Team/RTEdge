%% RTEdge - Final Random Forest Model
%
% Stage 1:
% NASA RW3 Battery Remaining-Time Estimation
%
% The hyperparameters were selected using the validation dataset.
%
% Selected configuration:
%   NumLearningCycles = 100
%   MinLeafSize       = 20
%
% Final training:
%   Training + Validation data
%
% Final evaluation:
%   Test data ONLY
%
% IMPORTANT:
% The test dataset is not used during model selection or training.

clear;
clc;
close all;

%% ============================================================
% 1. Load Dataset
% =============================================================

load('RW3_train_validation_test_split.mat');

disp('========================================');
disp(' FINAL RANDOM FOREST MODEL');
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
% 5. Extract Test Data
% =============================================================

X_test = testData{:, featureNames};

Y_test = testData.(targetName);

%% ============================================================
% 6. Remove Invalid Rows
% =============================================================

validTrain = ...
    all(isfinite(X_train), 2) ...
    & isfinite(Y_train);

validVal = ...
    all(isfinite(X_val), 2) ...
    & isfinite(Y_val);

validTest = ...
    all(isfinite(X_test), 2) ...
    & isfinite(Y_test);

X_train = X_train(validTrain, :);
Y_train = Y_train(validTrain);

X_val = X_val(validVal, :);
Y_val = Y_val(validVal);

X_test = X_test(validTest, :);
Y_test = Y_test(validTest);

%% ============================================================
% 7. Combine Training + Validation
% =============================================================

X_final_train = [
    X_train
    X_val
];

Y_final_train = [
    Y_train
    Y_val
];

fprintf('\nTraining samples       : %d\n', ...
    size(X_train,1));

fprintf('Validation samples     : %d\n', ...
    size(X_val,1));

fprintf('Final training samples : %d\n', ...
    size(X_final_train,1));

fprintf('Test samples           : %d\n', ...
    size(X_test,1));

%% ============================================================
% 8. Selected Hyperparameters
% =============================================================

numTrees = 100;

minLeafSize = 20;

fprintf('\n');
fprintf('Selected configuration:\n');

fprintf('Number of trees : %d\n', ...
    numTrees);

fprintf('Minimum leaf size : %d\n', ...
    minLeafSize);

%% ============================================================
% 9. Train Final Random Forest
% =============================================================

treeTemplate = templateTree( ...
    'MinLeafSize', minLeafSize);

disp(' ');
disp('Training final Random Forest...');

tic;

finalRandomForestModel = fitrensemble( ...
    X_final_train, ...
    Y_final_train, ...
    'Method', 'Bag', ...
    'NumLearningCycles', numTrees, ...
    'Learners', treeTemplate);

trainingTime = toc;

fprintf('Final training time: %.2f seconds\n', ...
    trainingTime);

%% ============================================================
% 10. Predict Test Set
% =============================================================

disp(' ');
disp('Evaluating on untouched test set...');

Y_test_pred = predict( ...
    finalRandomForestModel, ...
    X_test);

Y_test_pred = Y_test_pred(:);

Y_test = Y_test(:);

%% ============================================================
% 11. Calculate Test Error
% =============================================================

testError = Y_test - Y_test_pred;

absoluteError = abs(testError);

testMAE = mean(absoluteError);

testRMSE = sqrt(mean(testError.^2));

%% ============================================================
% 12. Calculate Test R2
% =============================================================

SS_res = sum(testError.^2);

SS_tot = sum( ...
    (Y_test - mean(Y_test)).^2);

testR2 = 1 - SS_res / SS_tot;

%% ============================================================
% 13. Display Final Results
% =============================================================

disp(' ');
disp('========================================');
disp(' FINAL NASA TEST RESULTS');
disp('========================================');

fprintf('Test MAE  : %.2f seconds\n', testMAE);

fprintf('Test RMSE : %.2f seconds\n', testRMSE);

fprintf('Test R2   : %.4f\n', testR2);

fprintf('\n');

fprintf('Test MAE  : %.2f minutes\n', ...
    testMAE / 60);

fprintf('Test RMSE : %.2f minutes\n', ...
    testRMSE / 60);

%% ============================================================
% 14. Actual vs Predicted Plot
% =============================================================

figure;

scatter( ...
    Y_test, ...
    Y_test_pred, ...
    8, ...
    'filled');

hold on;

minValue = min([Y_test; Y_test_pred]);

maxValue = max([Y_test; Y_test_pred]);

plot( ...
    [minValue maxValue], ...
    [minValue maxValue], ...
    'k--', ...
    'LineWidth', 1.5);

hold off;

xlabel('Actual Remaining Time (s)');

ylabel('Predicted Remaining Time (s)');

title('Final Random Forest: Actual vs Predicted');

legend( ...
    'Predictions', ...
    'Ideal Prediction', ...
    'Location', 'best');

grid on;

saveas( ...
    gcf, ...
    'final_rf_actual_vs_predicted.png');

%% ============================================================
% 15. Feature Importance
% =============================================================

importance = predictorImportance( ...
    finalRandomForestModel);

importanceTable = table( ...
    featureNames, ...
    importance(:), ...
    'VariableNames', ...
    {'Feature', 'Importance'});

importanceTable = sortrows( ...
    importanceTable, ...
    'Importance', ...
    'descend');

disp(' ');
disp('========================================');
disp(' FINAL MODEL FEATURE IMPORTANCE');
disp('========================================');

disp(importanceTable);

%% ============================================================
% 16. Save Final Model
% =============================================================

save( ...
    'final_random_forest_model.mat', ...
    'finalRandomForestModel', ...
    'featureNames', ...
    'targetName', ...
    'numTrees', ...
    'minLeafSize', ...
    'trainingTime', ...
    'testMAE', ...
    'testRMSE', ...
    'testR2', ...
    'importanceTable');

%% ============================================================
% 17. Save Final Metrics
% =============================================================

finalMetrics = table( ...
    testMAE, ...
    testRMSE, ...
    testR2, ...
    trainingTime, ...
    numTrees, ...
    minLeafSize, ...
    'VariableNames', { ...
    'Test_MAE_s', ...
    'Test_RMSE_s', ...
    'Test_R2', ...
    'Training_Time_s', ...
    'NumTrees', ...
    'MinLeafSize'});

writetable( ...
    finalMetrics, ...
    'final_random_forest_metrics.csv');

writetable( ...
    importanceTable, ...
    'final_random_forest_feature_importance.csv');

%% ============================================================
% 18. Final Summary
% =============================================================

disp(' ');
disp('========================================');
disp(' FINAL MODEL SAVED');
disp('========================================');

disp('Files created:');

disp('1. final_random_forest_model.mat');

disp('2. final_random_forest_metrics.csv');

disp('3. final_random_forest_feature_importance.csv');

disp('4. final_rf_actual_vs_predicted.png');

disp(' ');

disp('Test dataset was used ONLY for final evaluation.');

disp('Stage 1 NASA Random Forest benchmark completed.');