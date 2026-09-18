clc;
clear;
close all;

fprintf('============================================\n');
fprintf('RANDOM FOREST REGRESSION MODEL\n');
fprintf('============================================\n\n');


%% Load train / validation / test split

load('RW3_train_validation_test_split.mat');

fprintf('Training samples   : %d\n', height(trainData));
fprintf('Validation samples : %d\n', height(validationData));
fprintf('Test samples       : %d\n\n', height(testData));


%% Select features

featureNames = {
    'voltage_V'
    'current_A'
    'time_s'
};

targetName = 'remaining_time_s';


%% Extract data

X_train = trainData{:, featureNames};
Y_train = trainData{:, targetName};

X_val = validationData{:, featureNames};
Y_val = validationData{:, targetName};

X_test = testData{:, featureNames};
Y_test = testData{:, targetName};


%% Remove invalid rows

validTrain = all(isfinite(X_train), 2) & isfinite(Y_train);
validVal   = all(isfinite(X_val), 2)   & isfinite(Y_val);
validTest  = all(isfinite(X_test), 2)  & isfinite(Y_test);

X_train = X_train(validTrain, :);
Y_train = Y_train(validTrain);

X_val = X_val(validVal, :);
Y_val = Y_val(validVal);

X_test = X_test(validTest, :);
Y_test = Y_test(validTest);


fprintf('Valid training samples   : %d\n', size(X_train,1));
fprintf('Valid validation samples : %d\n', size(X_val,1));
fprintf('Valid test samples       : %d\n\n', size(X_test,1));


%% Random Forest configuration

fprintf('Configuring Random Forest...\n');

numTrees = 100;

treeTemplate = templateTree( ...
    'MinLeafSize', 20);


%% Train Random Forest

fprintf('Training Random Forest with %d trees...\n', numTrees);

tic;

randomForestModel = fitrensemble( ...
    X_train, ...
    Y_train, ...
    'Method', 'Bag', ...
    'NumLearningCycles', numTrees, ...
    'Learners', treeTemplate);

trainingTime = toc;

fprintf('Random Forest training complete.\n');
fprintf('Training time: %.2f seconds\n\n', trainingTime);


%% Validation prediction

fprintf('Generating validation predictions...\n');

Y_val_pred = predict(randomForestModel, X_val);


%% Test prediction

fprintf('Generating test predictions...\n');

Y_test_pred = predict(randomForestModel, X_test);


%% Validation metrics

valError = Y_val_pred - Y_val;

valMAE = mean(abs(valError));

valRMSE = sqrt(mean(valError.^2));

valR2 = 1 - ...
    sum((Y_val - Y_val_pred).^2) / ...
    sum((Y_val - mean(Y_val)).^2);


%% Test metrics

testError = Y_test_pred - Y_test;

testMAE = mean(abs(testError));

testRMSE = sqrt(mean(testError.^2));

testR2 = 1 - ...
    sum((Y_test - Y_test_pred).^2) / ...
    sum((Y_test - mean(Y_test)).^2);


%% Display results

fprintf('\n');
fprintf('============================================\n');
fprintf('RANDOM FOREST RESULTS\n');
fprintf('============================================\n\n');

fprintf('Validation MAE  : %.2f seconds\n', valMAE);
fprintf('Validation RMSE : %.2f seconds\n', valRMSE);
fprintf('Validation R^2  : %.4f\n\n', valR2);

fprintf('Test MAE        : %.2f seconds\n', testMAE);
fprintf('Test RMSE       : %.2f seconds\n', testRMSE);
fprintf('Test R^2        : %.4f\n\n', testR2);

fprintf('Training time   : %.2f seconds\n', trainingTime);


%% Actual vs predicted plot

figure;

scatter(Y_test, Y_test_pred, 8, 'filled');

hold on;

minValue = min([Y_test; Y_test_pred]);
maxValue = max([Y_test; Y_test_pred]);

plot( ...
    [minValue maxValue], ...
    [minValue maxValue], ...
    'k--', ...
    'LineWidth', 2);

xlabel('Actual Remaining Time (s)');
ylabel('Predicted Remaining Time (s)');

title('Random Forest: Actual vs Predicted');

grid on;

hold off;


%% Save model

save( ...
    'random_forest_model.mat', ...
    'randomForestModel', ...
    'featureNames', ...
    'targetName', ...
    'numTrees', ...
    'trainingTime', ...
    'valMAE', ...
    'valRMSE', ...
    'valR2', ...
    'testMAE', ...
    'testRMSE', ...
    'testR2');


fprintf('\nModel saved as random_forest_model.mat\n');

fprintf('\n============================================\n');
fprintf('RANDOM FOREST COMPLETE\n');
fprintf('============================================\n');