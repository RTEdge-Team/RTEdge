clc;
clear;
close all;

fprintf('============================================\n');
fprintf('MODEL COMPARISON\n');
fprintf('============================================\n\n');


%% Results from Linear Regression

linearValMAE  = 445.09;
linearValRMSE = 571.16;
linearValR2   = 0.4873;

linearTestMAE  = 426.90;
linearTestRMSE = 550.99;
linearTestR2   = 0.4659;


%% Results from Random Forest

rfValMAE  = 404.35;
rfValRMSE = 532.81;
rfValR2   = 0.5538;

rfTestMAE  = 391.16;
rfTestRMSE = 510.44;
rfTestR2   = 0.5416;


%% Create comparison table

Model = {
    'Linear Regression'
    'Random Forest'
    };

Validation_MAE_s = [
    linearValMAE
    rfValMAE
    ];

Validation_RMSE_s = [
    linearValRMSE
    rfValRMSE
    ];

Validation_R2 = [
    linearValR2
    rfValR2
    ];

Test_MAE_s = [
    linearTestMAE
    rfTestMAE
    ];

Test_RMSE_s = [
    linearTestRMSE
    rfTestRMSE
    ];

Test_R2 = [
    linearTestR2
    rfTestR2
    ];


resultsTable = table( ...
    Model, ...
    Validation_MAE_s, ...
    Validation_RMSE_s, ...
    Validation_R2, ...
    Test_MAE_s, ...
    Test_RMSE_s, ...
    Test_R2);


%% Display table

disp(resultsTable);


%% Calculate improvements

maeImprovement = ...
    (linearTestMAE - rfTestMAE) / linearTestMAE * 100;

rmseImprovement = ...
    (linearTestRMSE - rfTestRMSE) / linearTestRMSE * 100;

r2Improvement = ...
    rfTestR2 - linearTestR2;


fprintf('\n============================================\n');
fprintf('RANDOM FOREST IMPROVEMENT OVER LINEAR REGRESSION\n');
fprintf('============================================\n\n');

fprintf('Test MAE improvement  : %.2f %%\n', maeImprovement);

fprintf('Test RMSE improvement : %.2f %%\n', rmseImprovement);

fprintf('Test R^2 increase     : %.4f\n', r2Improvement);


%% Convert MAE to minutes

linearMAE_minutes = linearTestMAE / 60;
rfMAE_minutes = rfTestMAE / 60;

fprintf('\n');
fprintf('Linear Regression Test MAE : %.2f minutes\n', ...
    linearMAE_minutes);

fprintf('Random Forest Test MAE     : %.2f minutes\n', ...
    rfMAE_minutes);


%% Save comparison

save( ...
    'model_comparison.mat', ...
    'resultsTable', ...
    'maeImprovement', ...
    'rmseImprovement', ...
    'r2Improvement');


writetable( ...
    resultsTable, ...
    'model_comparison.csv');


fprintf('\nComparison saved as:\n');

fprintf('model_comparison.mat\n');
fprintf('model_comparison.csv\n');


fprintf('\n============================================\n');
fprintf('MODEL COMPARISON COMPLETE\n');
fprintf('============================================\n');