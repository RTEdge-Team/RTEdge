clear;
clc;
close all;

%% Load NASA RW3 data

fileName = '..\..\data\nasa_raw\RW3.mat';

S = load(fileName);

%% Select Step 1

step = S.data.step(1);

%% Extract signals

time = step.relativeTime;
voltage = step.voltage;
current = step.current;
temperature = step.temperature;

%% Create plots

figure;

plot(time, voltage, 'LineWidth', 1.5);

xlabel('Time (s)');
ylabel('Voltage (V)');
title('NASA RW3 - Step 1 Battery Voltage');

grid on;


figure;

plot(time, current, 'LineWidth', 1.5);

xlabel('Time (s)');
ylabel('Current (A)');
title('NASA RW3 - Step 1 Battery Current');

grid on;


figure;

plot(time, temperature, 'LineWidth', 1.5);

xlabel('Time (s)');
ylabel('Temperature (°C)');
title('NASA RW3 - Step 1 Battery Temperature');

grid on;