clc;
clear;
close all;

fprintf('============================================\n');
fprintf('BASELINE ML MODEL\n');
fprintf('============================================\n\n');

%% Load train/validation/test split

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


%% Extract training data

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


%% Train linear regression model

fprintf('Training linear regression model...\n');

linearModel = fitlm(X_train, Y_train);

fprintf('Linear regression training complete.\n\n');
%% Validation prediction

Y_val_pred = predict(linearModel, X_val);


%% Test prediction

Y_test_pred = predict(linearModel, X_test);


%% Calculate validation metrics

valError = Y_val_pred - Y_val;

valMAE = mean(abs(valError));

valRMSE = sqrt(mean(valError.^2));

valR2 = 1 - ...
    sum((Y_val - Y_val_pred).^2) / ...
    sum((Y_val - mean(Y_val)).^2);


%% Calculate test metrics

testError = Y_test_pred - Y_test;

testMAE = mean(abs(testError));

testRMSE = sqrt(mean(testError.^2));

testR2 = 1 - ...
    sum((Y_test - Y_test_pred).^2) / ...
    sum((Y_test - mean(Y_test)).^2);


%% Display results

fprintf('============================================\n');
fprintf('LINEAR REGRESSION RESULTS\n');
fprintf('============================================\n\n');

fprintf('Validation MAE  : %.2f seconds\n', valMAE);
fprintf('Validation RMSE : %.2f seconds\n', valRMSE);
fprintf('Validation R^2  : %.4f\n\n', valR2);

fprintf('Test MAE        : %.2f seconds\n', testMAE);
fprintf('Test RMSE       : %.2f seconds\n', testRMSE);
fprintf('Test R^2        : %.4f\n\n', testR2);


%% Plot actual vs predicted

figure;

scatter(Y_test, Y_test_pred, 8, 'filled');

hold on;

minValue = min([Y_test; Y_test_pred]);
maxValue = max([Y_test; Y_test_pred]);

plot([minValue maxValue], ...
     [minValue maxValue], ...
     'k--', ...
     'LineWidth', 2);

xlabel('Actual Remaining Time (s)');
ylabel('Predicted Remaining Time (s)');

title('Linear Regression: Actual vs Predicted');

grid on;

hold off;


%% Save model

save('baseline_linear_model.mat', ...
    'linearModel', ...
    'featureNames', ...
    'targetName', ...
    'valMAE', ...
    'valRMSE', ...
    'valR2', ...
    'testMAE', ...
    'testRMSE', ...
    'testR2');

fprintf('Model saved as baseline_linear_model.mat\n');

fprintf('\n============================================\n');
fprintf('BASELINE MODEL COMPLETE\n');
fprintf('============================================\n');