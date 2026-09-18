%% RTEdge - Random Forest Feature Importance
% Analyze which input features contribute most to the RF prediction.

clear;
clc;
close all;

%% 1. Load Random Forest model

load('random_forest_model.mat');

%% 2. Display variables loaded

whos

%% 3. Define feature names

featureNames = {
    'Voltage (V)'
    'Current (A)'
    'Elapsed Time (s)'
};

%% 4. Calculate predictor importance

importance = predictorImportance(randomForestModel);

%% 5. Display results

importanceTable = table( ...
    featureNames, ...
    importance(:), ...
    'VariableNames', {'Feature', 'Importance'});

importanceTable = sortrows(importanceTable, 'Importance', 'descend');

disp('========================================');
disp(' RANDOM FOREST FEATURE IMPORTANCE');
disp('========================================');

disp(importanceTable);

%% 6. Plot feature importance

figure;

bar(importanceTable.Importance);

set(gca, ...
    'XTick', 1:numel(importanceTable.Feature), ...
    'XTickLabel', importanceTable.Feature);

xlabel('Feature');
ylabel('Predictor Importance');
title('Random Forest Feature Importance');

grid on;

%% 7. Save figure

saveas(gcf, 'random_forest_feature_importance.png');

%% 8. Save results

save('random_forest_feature_importance.mat', ...
    'importanceTable');

writetable(importanceTable, ...
    'random_forest_feature_importance.csv');

disp(' ');
disp('Feature importance analysis completed.');
disp('Files saved:');
disp(' - random_forest_feature_importance.png');
disp(' - random_forest_feature_importance.mat');
disp(' - random_forest_feature_importance.csv');