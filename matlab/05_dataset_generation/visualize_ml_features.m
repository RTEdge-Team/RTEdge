clear;
clc;
close all;

%% ============================================================
% VISUALIZE FEATURES VS REMAINING TIME
% ============================================================

fprintf('============================================\n');
fprintf('ML FEATURE VISUALIZATION\n');
fprintf('============================================\n\n');


%% 1. Load train/validation/test split

load('RW3_train_validation_test_split.mat');


%% 2. Basic information

fprintf('Training samples: %d\n', height(trainData));
fprintf('Validation samples: %d\n', height(validationData));
fprintf('Test samples: %d\n\n', height(testData));


%% ============================================================
% FIGURE 1: VOLTAGE VS REMAINING TIME
% ============================================================

figure;

scatter( ...
    trainData.voltage_V, ...
    trainData.remaining_time_s, ...
    3, ...
    'filled');

grid on;

xlabel('Voltage (V)');
ylabel('Remaining Time (s)');

title('Voltage vs Remaining Time - Training Data');


%% ============================================================
% FIGURE 2: CURRENT VS REMAINING TIME
% ============================================================

figure;

scatter( ...
    trainData.current_A, ...
    trainData.remaining_time_s, ...
    3, ...
    'filled');

grid on;

xlabel('Current (A)');
ylabel('Remaining Time (s)');

title('Current vs Remaining Time - Training Data');


%% ============================================================
% FIGURE 3: VOLTAGE VS CURRENT
% ============================================================

figure;

scatter( ...
    trainData.current_A, ...
    trainData.voltage_V, ...
    3, ...
    'filled');

grid on;

xlabel('Current (A)');
ylabel('Voltage (V)');

title('Voltage vs Current - Training Data');


%% ============================================================
% FIGURE 4: ELAPSED TIME VS REMAINING TIME
% ============================================================

figure;

scatter( ...
    trainData.time_s, ...
    trainData.remaining_time_s, ...
    3, ...
    'filled');

grid on;

xlabel('Elapsed Time in Trajectory (s)');
ylabel('Remaining Time (s)');

title('Elapsed Time vs Remaining Time - Training Data');


%% ============================================================
% FIGURE 5: TEMPERATURE VS REMAINING TIME
% ============================================================

validTemperature = ...
    ~isnan(trainData.temperature_C);

figure;

scatter( ...
    trainData.temperature_C(validTemperature), ...
    trainData.remaining_time_s(validTemperature), ...
    3, ...
    'filled');

grid on;

xlabel('Temperature (°C)');
ylabel('Remaining Time (s)');

title('Temperature vs Remaining Time - Available Measurements');


%% ============================================================
% PRINT CORRELATIONS
% ============================================================

fprintf('============================================\n');
fprintf('CORRELATION ANALYSIS\n');
fprintf('============================================\n\n');


%% Voltage correlation

r_voltage = corr( ...
    trainData.voltage_V, ...
    trainData.remaining_time_s);

fprintf('Voltage vs Remaining Time:\n');
fprintf('Correlation = %.4f\n\n', r_voltage);


%% Current correlation

r_current = corr( ...
    trainData.current_A, ...
    trainData.remaining_time_s);

fprintf('Current vs Remaining Time:\n');
fprintf('Correlation = %.4f\n\n', r_current);


%% Elapsed time correlation

r_time = corr( ...
    trainData.time_s, ...
    trainData.remaining_time_s);

fprintf('Elapsed Time vs Remaining Time:\n');
fprintf('Correlation = %.4f\n\n', r_time);


%% Temperature correlation

tempData = trainData.temperature_C;
targetData = trainData.remaining_time_s;

valid = ~isnan(tempData);

r_temperature = corr( ...
    tempData(valid), ...
    targetData(valid));

fprintf('Temperature vs Remaining Time:\n');
fprintf('Correlation = %.4f\n\n', r_temperature);


fprintf('============================================\n');
fprintf('VISUALIZATION COMPLETE\n');
fprintf('============================================\n');