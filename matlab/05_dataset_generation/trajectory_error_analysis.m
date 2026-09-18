%% RTEdge - Trajectory-Level Random Forest Error Analysis
%
% This script analyzes Random Forest performance:
%
%   1. For each individual test trajectory
%   2. Across different remaining-time ranges
%
% IMPORTANT:
% This script does NOT retrain or modify the Random Forest model.
%
% Test data is used only for analysis of the already-trained baseline.

clear;
clc;
close all;

%% ============================================================
% 1. Load Model and Dataset
% =============================================================

load('random_forest_model.mat');

load('RW3_train_validation_test_split.mat');

disp('========================================');
disp(' TRAJECTORY-LEVEL ERROR ANALYSIS');
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
% 3. Extract Test Data
% =============================================================

X_test = testData(:, featureNames);

Y_test = testData.(targetName);

trajectoryID = testData.trajectory_id;

%% ============================================================
% 4. Remove Invalid Samples
% =============================================================

validRows = all(isfinite(table2array(X_test)), 2) ...
            & isfinite(Y_test) ...
            & isfinite(trajectoryID);

X_test = X_test(validRows, :);

Y_test = Y_test(validRows);

trajectoryID = trajectoryID(validRows);

%% ============================================================
% 5. Generate Predictions
% =============================================================

X_test_matrix = X_test{:, featureNames};

Y_pred = predict(randomForestModel, X_test_matrix);

Y_pred = Y_pred(:);

Y_test = Y_test(:);

trajectoryID = trajectoryID(:);

%% ============================================================
% 6. Calculate Sample-Level Errors
% =============================================================

error_s = Y_test - Y_pred;

absoluteError_s = abs(error_s);

squaredError_s = error_s.^2;

%% ============================================================
% 7. Identify Test Trajectories
% =============================================================

uniqueTrajectories = unique(trajectoryID);

numTrajectories = length(uniqueTrajectories);

fprintf('\nNumber of test trajectories: %d\n', ...
    numTrajectories);

%% ============================================================
% 8. Preallocate Trajectory Results
% =============================================================

trajectoryMAE = zeros(numTrajectories, 1);

trajectoryRMSE = zeros(numTrajectories, 1);

trajectoryR2 = zeros(numTrajectories, 1);

trajectorySamples = zeros(numTrajectories, 1);

trajectoryDuration = zeros(numTrajectories, 1);

trajectoryMeanActual = zeros(numTrajectories, 1);

%% ============================================================
% 9. Calculate Metrics for Each Trajectory
% =============================================================

for i = 1:numTrajectories

    currentID = uniqueTrajectories(i);

    rows = trajectoryID == currentID;

    actual = Y_test(rows);

    predicted = Y_pred(rows);

    currentTime = X_test.time_s(rows);

    currentError = actual - predicted;

    %% MAE

    trajectoryMAE(i) = mean(abs(currentError));

    %% RMSE

    trajectoryRMSE(i) = sqrt(mean(currentError.^2));

    %% R2

    SS_res = sum(currentError.^2);

    SS_tot = sum((actual - mean(actual)).^2);

    if SS_tot > 0

        trajectoryR2(i) = 1 - SS_res / SS_tot;

    else

        trajectoryR2(i) = NaN;

    end

    %% Number of samples

    trajectorySamples(i) = length(actual);

    %% Duration

    trajectoryDuration(i) = max(currentTime) ...
                            - min(currentTime);

    %% Mean actual remaining time

    trajectoryMeanActual(i) = mean(actual);

end

%% ============================================================
% 10. Create Trajectory Results Table
% =============================================================

trajectoryResults = table( ...
    uniqueTrajectories, ...
    trajectorySamples, ...
    trajectoryDuration, ...
    trajectoryMeanActual, ...
    trajectoryMAE, ...
    trajectoryRMSE, ...
    trajectoryR2, ...
    'VariableNames', { ...
    'Trajectory_ID', ...
    'Samples', ...
    'Duration_s', ...
    'Mean_Remaining_Time_s', ...
    'MAE_s', ...
    'RMSE_s', ...
    'R2'});

%% ============================================================
% 11. Display Summary
% =============================================================

disp(' ');
disp('========================================');
disp(' TRAJECTORY METRIC SUMMARY');
disp('========================================');

fprintf('Mean trajectory MAE  : %.2f s\n', ...
    mean(trajectoryMAE, 'omitnan'));

fprintf('Median trajectory MAE: %.2f s\n', ...
    median(trajectoryMAE, 'omitnan'));

fprintf('Minimum trajectory MAE: %.2f s\n', ...
    min(trajectoryMAE));

fprintf('Maximum trajectory MAE: %.2f s\n', ...
    max(trajectoryMAE));

fprintf('\nMean trajectory RMSE : %.2f s\n', ...
    mean(trajectoryRMSE, 'omitnan'));

fprintf('Median trajectory RMSE: %.2f s\n', ...
    median(trajectoryRMSE, 'omitnan'));

%% ============================================================
% 12. Sort Trajectories by MAE
% =============================================================

sortedResults = sortrows( ...
    trajectoryResults, ...
    'MAE_s', ...
    'descend');

disp(' ');
disp('Top 10 trajectories with largest MAE:');

disp(sortedResults( ...
    1:min(10,height(sortedResults)), :));

%% ============================================================
% 13. Plot 1 - MAE for Every Trajectory
% =============================================================

figure;

plot( ...
    trajectoryResults.Trajectory_ID, ...
    trajectoryResults.MAE_s, ...
    '.', ...
    'MarkerSize', 10);

xlabel('Trajectory ID');

ylabel('MAE (s)');

title('Random Forest MAE Across Test Trajectories');

grid on;

saveas(gcf, ...
    'rf_trajectory_mae.png');

%% ============================================================
% 14. Plot 2 - RMSE for Every Trajectory
% =============================================================

figure;

plot( ...
    trajectoryResults.Trajectory_ID, ...
    trajectoryResults.RMSE_s, ...
    '.', ...
    'MarkerSize', 10);

xlabel('Trajectory ID');

ylabel('RMSE (s)');

title('Random Forest RMSE Across Test Trajectories');

grid on;

saveas(gcf, ...
    'rf_trajectory_rmse.png');

%% ============================================================
% 15. Remaining-Time Error Bins
% =============================================================

% Define remaining-time ranges.

binEdges = [
    0
    600
    1200
    1800
    2400
    3000
    3600
    inf
];

binLabels = {
    '0-600 s'
    '600-1200 s'
    '1200-1800 s'
    '1800-2400 s'
    '2400-3000 s'
    '3000-3600 s'
    '>3600 s'
};

numBins = length(binEdges) - 1;

binMAE = zeros(numBins,1);

binRMSE = zeros(numBins,1);

binSamples = zeros(numBins,1);

%% ============================================================
% 16. Calculate Error by Remaining-Time Range
% =============================================================

for b = 1:numBins

    if b < numBins

        rows = Y_test >= binEdges(b) ...
             & Y_test < binEdges(b+1);

    else

        rows = Y_test >= binEdges(b);

    end

    if any(rows)

        binErrors = error_s(rows);

        binMAE(b) = mean(abs(binErrors));

        binRMSE(b) = sqrt(mean(binErrors.^2));

        binSamples(b) = sum(rows);

    else

        binMAE(b) = NaN;

        binRMSE(b) = NaN;

        binSamples(b) = 0;

    end

end

%% ============================================================
% 17. Create Error-Bin Table
% =============================================================

errorBinResults = table( ...
    binLabels, ...
    binSamples, ...
    binMAE, ...
    binRMSE, ...
    'VariableNames', { ...
    'Remaining_Time_Range', ...
    'Samples', ...
    'MAE_s', ...
    'RMSE_s'});

disp(' ');
disp('========================================');
disp(' ERROR BY REMAINING-TIME RANGE');
disp('========================================');

disp(errorBinResults);

%% ============================================================
% 18. Plot 3 - MAE by Remaining-Time Range
% =============================================================

figure;

bar(binMAE);

xlabel('Remaining-Time Range');

ylabel('MAE (s)');

title('Random Forest MAE by Remaining-Time Range');

set(gca, ...
    'XTick', 1:numBins, ...
    'XTickLabel', binLabels);

grid on;

saveas(gcf, ...
    'rf_mae_by_remaining_time.png');

%% ============================================================
% 19. Plot 4 - Mean Absolute Error vs Mean Remaining Time
% =============================================================

figure;

scatter( ...
    trajectoryResults.Mean_Remaining_Time_s, ...
    trajectoryResults.MAE_s, ...
    25, ...
    'filled');

xlabel('Mean Remaining Time (s)');

ylabel('Trajectory MAE (s)');

title('Trajectory MAE vs Mean Remaining Time');

grid on;

saveas(gcf, ...
    'rf_trajectory_mae_vs_remaining_time.png');

%% ============================================================
% 20. Save Results
% =============================================================

writetable( ...
    trajectoryResults, ...
    'rf_trajectory_error_results.csv');

writetable( ...
    errorBinResults, ...
    'rf_error_by_remaining_time.csv');

save( ...
    'rf_trajectory_error_analysis.mat', ...
    'trajectoryResults', ...
    'errorBinResults', ...
    'error_s', ...
    'Y_test', ...
    'Y_pred');

%% ============================================================
% 21. Final Summary
% =============================================================

disp(' ');
disp('========================================');
disp(' ANALYSIS COMPLETED');
disp('========================================');

disp('Generated files:');

disp('1. rf_trajectory_mae.png');
disp('2. rf_trajectory_rmse.png');
disp('3. rf_mae_by_remaining_time.png');
disp('4. rf_trajectory_mae_vs_remaining_time.png');
disp('5. rf_trajectory_error_results.csv');
disp('6. rf_error_by_remaining_time.csv');
disp('7. rf_trajectory_error_analysis.mat');

disp(' ');
disp('Random Forest model was NOT modified.');