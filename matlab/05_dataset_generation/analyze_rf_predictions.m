%% RTEdge - Random Forest Prediction and Error Analysis
% This script analyzes the already-trained Random Forest model.
%
% Outputs:
%   1. Actual vs Predicted Remaining Time
%   2. Prediction Error Distribution
%   3. Prediction Error vs Actual Remaining Time
%   4. Actual vs Predicted Remaining Time for one trajectory
%
% IMPORTANT:
% This script does NOT retrain or modify the Random Forest model.

clear;
clc;
close all;

%% ============================================================
% 1. Load Random Forest Model
% =============================================================

load('random_forest_model.mat');

disp('========================================');
disp(' RANDOM FOREST PREDICTION ANALYSIS');
disp('========================================');

%% ============================================================
% 2. Load Train/Validation/Test Dataset
% =============================================================

load('RW3_train_validation_test_split.mat');

disp('Dataset loaded successfully.');

%% ============================================================
% 3. Define Features and Target
% =============================================================

featureNames = {
    'voltage_V'
    'current_A'
    'time_s'
};

targetName = 'remaining_time_s';

%% ============================================================
% 4. Check Dataset Variables
% =============================================================

disp(' ');
disp('Variables in workspace:');
whos trainData validationData testData

%% ============================================================
% 5. Extract Test Features and Target
% =============================================================

X_test = testData(:, featureNames);
Y_test = testData.(targetName);

%% ============================================================
% 6. Remove Invalid Rows
% =============================================================

validRows = all(isfinite(table2array(X_test)), 2) ...
            & isfinite(Y_test);

X_test = X_test(validRows, :);
Y_test = Y_test(validRows);

disp(' ');
fprintf('Valid test samples: %d\n', height(X_test));

%% ============================================================
% 7. Generate Random Forest Predictions
% =============================================================

% Convert feature table to numeric matrix.
% The Random Forest was trained using a numeric matrix,
% so MATLAB expects predictors x1, x2, x3.

X_test_matrix = X_test{:, featureNames};

Y_pred = predict(randomForestModel, X_test_matrix);

% Convert prediction to column vector if necessary
Y_pred = Y_pred(:);
Y_test = Y_test(:);

%% ============================================================
% 8. Calculate Prediction Error
% =============================================================

error_s = Y_test - Y_pred;

absoluteError_s = abs(error_s);

%% ============================================================
% 9. Calculate Evaluation Metrics
% =============================================================

MAE = mean(absoluteError_s);

RMSE = sqrt(mean(error_s.^2));

SS_res = sum((Y_test - Y_pred).^2);
SS_tot = sum((Y_test - mean(Y_test)).^2);

R2 = 1 - SS_res / SS_tot;

fprintf('\n');
disp('========================================');
disp(' TEST SET RESULTS');
disp('========================================');

fprintf('MAE  : %.2f seconds\n', MAE);
fprintf('RMSE : %.2f seconds\n', RMSE);
fprintf('R^2  : %.4f\n', R2);

fprintf('\nMAE in minutes  : %.2f minutes\n', MAE / 60);
fprintf('RMSE in minutes : %.2f minutes\n', RMSE / 60);

%% ============================================================
% 10. Plot 1 - Actual vs Predicted
% =============================================================

figure;

scatter(Y_test, Y_pred, 8, 'filled');

hold on;

minValue = min([Y_test; Y_pred]);
maxValue = max([Y_test; Y_pred]);

plot([minValue maxValue], ...
     [minValue maxValue], ...
     'k--', ...
     'LineWidth', 1.5);

hold off;

xlabel('Actual Remaining Time (s)');
ylabel('Predicted Remaining Time (s)');

title('Random Forest: Actual vs Predicted Remaining Time');

legend('Predictions', 'Ideal Prediction', ...
       'Location', 'best');

grid on;

saveas(gcf, ...
    'rf_actual_vs_predicted.png');

%% ============================================================
% 11. Plot 2 - Prediction Error Distribution
% =============================================================

figure;

histogram(error_s, 50);

xlabel('Prediction Error (s)');
ylabel('Number of Samples');

title('Random Forest Prediction Error Distribution');

grid on;

xline(0, 'k--', 'LineWidth', 1.5);

saveas(gcf, ...
    'rf_prediction_error_distribution.png');

%% ============================================================
% 12. Plot 3 - Prediction Error vs Actual Remaining Time
% =============================================================

figure;

scatter(Y_test, error_s, 8, 'filled');

hold on;

yline(0, 'k--', 'LineWidth', 1.5);

hold off;

xlabel('Actual Remaining Time (s)');
ylabel('Prediction Error (s)');

title('Random Forest Prediction Error vs Actual Remaining Time');

grid on;

saveas(gcf, ...
    'rf_error_vs_actual.png');

%% ============================================================
% 13. Find Trajectory ID Column
% =============================================================

testVariables = testData.Properties.VariableNames;

disp(' ');
disp('Test dataset columns:');

disp(testVariables');

%% ============================================================
% 14. Identify Trajectory ID
% =============================================================

trajectoryCandidates = {
    'trajectory_id'
    'trajectoryID'
    'trajectory'
    'trajectory_ID'
    'episode_id'
    'episodeID'
    'episode'
};

trajectoryColumn = '';

for i = 1:length(trajectoryCandidates)

    if ismember(trajectoryCandidates{i}, testVariables)

        trajectoryColumn = trajectoryCandidates{i};
        break;

    end

end

%% ============================================================
% 15. Plot One Complete Test Trajectory
% =============================================================

if ~isempty(trajectoryColumn)

    trajectoryIDs = testData.(trajectoryColumn);

    trajectoryIDs = trajectoryIDs(validRows);

    uniqueIDs = unique(trajectoryIDs);

    % Select the first complete test trajectory
    selectedID = uniqueIDs(1);

    trajectoryRows = trajectoryIDs == selectedID;

    trajectoryActual = Y_test(trajectoryRows);
    trajectoryPredicted = Y_pred(trajectoryRows);

    trajectoryTime = X_test.time_s(trajectoryRows);

    %% Sort according to elapsed time

    [trajectoryTime, sortIndex] = sort(trajectoryTime);

    trajectoryActual = trajectoryActual(sortIndex);
    trajectoryPredicted = trajectoryPredicted(sortIndex);

    %% Plot

    figure;

    plot(trajectoryTime, ...
         trajectoryActual, ...
         'LineWidth', 1.8);

    hold on;

    plot(trajectoryTime, ...
         trajectoryPredicted, ...
         '--', ...
         'LineWidth', 1.8);

    hold off;

    xlabel('Elapsed Time (s)');
    ylabel('Remaining Time (s)');

    title(sprintf( ...
        'Random Forest Prediction - Test Trajectory %g', ...
        selectedID));

    legend('Actual Remaining Time', ...
           'Predicted Remaining Time', ...
           'Location', 'best');

    grid on;

    saveas(gcf, ...
        'rf_single_trajectory_prediction.png');

    fprintf('\n');
    fprintf('Selected test trajectory ID: %g\n', selectedID);

else

    disp(' ');
    disp('WARNING: No recognized trajectory ID column found.');
    disp('Single trajectory plot was skipped.');

end

%% ============================================================
% 16. Save Prediction Results
% =============================================================

predictionResults = table( ...
    Y_test, ...
    Y_pred, ...
    error_s, ...
    absoluteError_s, ...
    'VariableNames', { ...
    'Actual_Remaining_Time_s', ...
    'Predicted_Remaining_Time_s', ...
    'Error_s', ...
    'Absolute_Error_s'});

writetable( ...
    predictionResults, ...
    'rf_prediction_results.csv');

%% ============================================================
% 17. Save MATLAB Results
% =============================================================

save( ...
    'rf_prediction_analysis.mat', ...
    'Y_test', ...
    'Y_pred', ...
    'error_s', ...
    'absoluteError_s', ...
    'MAE', ...
    'RMSE', ...
    'R2');

%% ============================================================
% 18. Final Summary
% =============================================================

disp(' ');
disp('========================================');
disp(' ANALYSIS COMPLETED');
disp('========================================');

fprintf('MAE  = %.2f s (%.2f min)\n', MAE, MAE/60);
fprintf('RMSE = %.2f s (%.2f min)\n', RMSE, RMSE/60);
fprintf('R^2  = %.4f\n', R2);

disp(' ');
disp('Generated files:');

disp('1. rf_actual_vs_predicted.png');
disp('2. rf_prediction_error_distribution.png');
disp('3. rf_error_vs_actual.png');
disp('4. rf_single_trajectory_prediction.png');
disp('5. rf_prediction_results.csv');
disp('6. rf_prediction_analysis.mat');

disp(' ');
disp('Random Forest model was NOT modified.');