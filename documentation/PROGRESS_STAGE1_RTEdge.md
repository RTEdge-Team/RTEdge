# RTEdge — Stage 1 Progress Record

## Project

**Project Name:** RTEdge — Intelligent Battery Remaining-Time Estimation
**Project Theme:** AI/ML-based Battery Management System for EV
**Current Stage:** Stage 1 — NASA RW3 Battery Remaining-Time Benchmark
**MATLAB:** R2024b (Version 24.2), Update 6

---

# 1. Overall Project Plan

The project is being developed in three major stages:

```text
Stage 1 — NASA Experimental Benchmark
NASA experimental battery data
        ↓
Data inspection
        ↓
Data cleaning and trajectory extraction
        ↓
Remaining-time target generation
        ↓
Trajectory-aware Train/Validation/Test split
        ↓
Feature analysis
        ↓
Linear Regression baseline
        ↓
Random Forest baseline
        ↓
Hyperparameter tuning
        ↓
Final Random Forest
        ↓
Model and error analysis


Stage 2 — Vehicle-Aware Simulation
Vehicle velocity
        ↓
Acceleration
        ↓
Road slope
        ↓
Vehicle dynamics
        ↓
Required traction power
        ↓
Motor / electrical power
        ↓
Battery current
        ↓
Simulink battery model
        ↓
EV-aware simulation dataset
        ↓
Vehicle-aware ML model


Stage 3 — Integrated System and Validation
Integrated EV + Battery + ML system
        ↓
Remaining-time / runtime prediction
        ↓
Additional outputs as applicable
        ↓
Simulation-to-experimental validation
        ↓
Final results and project deliverables
```

**Status:** The NASA experimental benchmark portion of Stage 1 has been completed.

A basic Simulink battery model has also been successfully created as the foundation for the upcoming simulation and validation work.

---

# 2. Current Scope

Stage 1 is a **cell-level experimental battery remaining-time study** using the NASA RW3 dataset.

It should not yet be described as a complete production EV battery-management system or vehicle-level BMS.

The current Stage-1 model uses battery measurements such as:

```text
Voltage
Current
Elapsed Time
```

Vehicle operating conditions will be introduced in Stage 2 through vehicle dynamics, drive-cycle simulation, and battery-load modeling.

---

# 3. Current Project Folder Structure

The project is organized into separate areas for data, MATLAB models/scripts, Python work, outputs, documentation, research material, and reports.

Current structure:

```text
RTEdge
│
├── .python
│   ├── src
│   ├── outputs
│   ├── notebooks
│   └── configs
│
├── outputs
│   ├── predictions
│   ├── models
│   ├── metrics
│   └── figures
│
├── matlab
│   ├── 01_inspect_nasa
│   ├── 02_battery_model
│   ├── 03_validation
│   ├── 04_vehicle_model
│   └── 05_dataset_generation
│
├── documentation
│   ├── PROGRESS_STAGE1_RTEdge.md
│   └── experiment_log.md
│
├── docs
│   └── viva
│
├── research paper
│
├── report
│
├── reading docs
│
└── data
    ├── simulation_raw
    ├── simulation_processed
    ├── nasa_raw
    │   └── RW3.mat
    └── nasa_processed
```

The folder structure is maintained to keep raw data, processed data, MATLAB implementation, generated outputs, and documentation separated.

A screenshot of the folder architecture is retained as project evidence.

---

# 4. NASA RW3 Dataset Inspection

## Raw Dataset

File:

```text
data/nasa_raw/RW3.mat
```

The original NASA dataset is preserved as raw data and is not modified directly.

The dataset was inspected before building the processing pipeline.

### Top-Level Structure

The loaded dataset contains:

```text
data
├── step
├── procedure
└── description
```

`data.step` is a `1x12826` structure array.

### Step Fields

Each step contains fields including:

```text
comment
type
time
relativeTime
voltage
current
temperature
date
```

### Step Type Counts

```text
Charge (C)       = 867
Discharge (D)    = 5728
Rest (R)         = 6231
```

### Purpose

The purpose of this stage was to understand the actual NASA file structure and identify the random-walk discharge sections that could be converted into machine-learning trajectories.

### Important Scripts

The NASA inspection directory contains scripts such as:

```text
matlab/01_inspect_nasa/
├── summarize_rw3.m
├── plot_rw3_step1.m
├── inspect_rw_block1.m
├── inspect_rw3.m
├── inspect_rw3_sequence.m
├── find_rw_trajectories.m
└── check_rw_boundaries.m
```

---

# 5. Random-Walk Discharge Extraction

The NASA RW3 dataset contains randomized battery-use experiments.

The discharge sections were investigated and grouped into individual random-walk discharge trajectories.

### Results

```text
Random-walk discharge steps       = 5463
Potential episode endings        = 823
Random-walk trajectories          = 823
```

The extracted trajectories represent continuous discharge episodes that can be used for remaining-time prediction.

Conceptually:

```text
NASA RW3
    ↓
Identify random-walk discharge sections
    ↓
Group related discharge samples
    ↓
Individual trajectories
    ↓
Remaining-time target generation
```

---

# 6. Data Quality Investigation

The raw temperature measurements contained a significant number of invalid values.

Examples included extremely negative values such as:

```text
approximately -4094 °C
```

These values were treated as invalid.

Invalid temperature measurements were converted to `NaN` where appropriate.

### Temperature Statistics

```text
Missing/invalid temperature samples ≈ 68.04%
```

Therefore, temperature was not used as a primary input feature for the first ML benchmark.

Valid temperature information was retained in the processed dataset for future analysis.

### Important Decision

The presence of missing temperature data did not automatically cause complete trajectories to be deleted.

Instead:

```text
Invalid temperature
        ↓
NaN

Valid electrical trajectory
        ↓
Retain trajectory
```

Only trajectories that were themselves considered invalid or incomplete were excluded.

---

# 7. Corrupt Trajectory Investigation

Trajectory 175 was investigated separately because it did not represent a valid random-walk discharge trajectory.

### Characteristics

```text
Number of samples = 3
Duration          ≈ 0.5 s
Current           = 0 A
Voltage           ≈ 4.197 V → 4.227 V
Temperature       = invalid
```

The trajectory did not show valid discharge behavior and was therefore excluded.

### Final trajectory count

```text
Detected trajectories       = 823
Excluded trajectory         = 1
Excluded trajectory ID      = 175

Usable trajectories         = 822
```

This exclusion was based on trajectory-level data-quality investigation rather than arbitrary row deletion.

---

# 8. Remaining-Time Target

The supervised-learning target is:

```text
remaining_time_s
```

## Endpoint Definition

The discharge endpoint was defined as:

> The first observed sample where voltage <= 3.2 V.

For each trajectory:

```text
remaining_time_s
=
endpoint_time - current_trajectory_time
```

Elapsed time was reset for every trajectory:

```text
time_s = time - time(1)
```

### Endpoint Validation

The endpoint behavior was checked across the usable trajectories.

```text
Usable trajectories = 822
```

The endpoint voltage range observed in the final dataset was:

```text
3.1120 V → 3.2000 V
```

Some trajectories crossed slightly below 3.2 V because the first observed sample satisfying the endpoint condition could be below the threshold.

This follows the documented rule of using the **first observed sample at or below 3.2 V** rather than interpolating or inventing a future endpoint.

### Target Sanity Checks

The final target was checked for:

```text
Negative remaining time = 0
Remaining time approaches zero at endpoint
Endpoint condition consistently applied
```

---

# 9. Final NASA Dataset

The processed NASA dataset was saved as:

```text
RW3_random_walk_dataset_FINAL.mat
```

This file represents the cleaned and labeled dataset used for the ML experiments.

## Dataset Statistics

```text
Usable trajectories:
822

Total samples:
1,474,100
```

### Voltage

```text
Minimum = 3.1120 V
Maximum = 4.1990 V
```

### Current

```text
Minimum = 0 A
Maximum = 4.1470 A
```

### Valid Temperature

```text
Minimum = 19.5016 °C
Maximum = 40.4714 °C
```

### Missing Temperature

```text
Missing samples = 1,002,941
Percentage       ≈ 68.0375%
```

### Remaining Time

```text
Minimum = 0 s
Maximum = 4296.6900 s
```

No negative remaining-time values were present.

---

# 10. Trajectory-Aware Train/Validation/Test Split

The final dataset was split at the **trajectory level**, rather than randomly splitting individual rows.

This was done to prevent samples from the same discharge trajectory from appearing in both training and test sets.

File:

```text
RW3_train_validation_test_split.mat
```

## Dataset Variables

The split file contains:

```text
trainData
trainIDs

validationData
validationIDs

testData
testIDs
```

## Split

| Dataset    | Trajectories |       Samples |
| ---------- | -----------: | ------------: |
| Training   |          575 |     1,026,256 |
| Validation |          123 |       234,864 |
| Test       |          124 |       212,980 |
| **Total**  |      **822** | **1,474,100** |

Random seed:

```matlab
rng(42)
```

## Leakage Check

```text
Train ∩ Validation = 0
Train ∩ Test      = 0
Validation ∩ Test  = 0
```

Every trajectory was assigned exactly once.

This provides a leakage-safe evaluation setup for the benchmark.

---

# 11. ML Features

The initial machine-learning benchmark used:

```text
voltage_V
current_A
time_s
```

Target:

```text
remaining_time_s
```

Temperature was excluded from the baseline model because approximately 68% of the temperature samples were missing or invalid.

---

# 12. Feature Analysis

The feature relationships with remaining time were investigated before training the ML models.

## Correlation Results

| Feature      | Correlation with Remaining Time |
| ------------ | ------------------------------: |
| Voltage      |                         +0.4786 |
| Current      |                         -0.0256 |
| Elapsed Time |                         -0.4889 |
| Temperature  |                         -0.6704 |

### Observations

Voltage showed a moderate positive relationship with remaining time.

Elapsed time showed a moderate negative relationship with remaining time.

Current had very weak overall linear correlation with remaining time.

Temperature showed a stronger correlation, but its large amount of missing/invalid data prevented it from being used as a primary baseline feature.

These correlations are descriptive and do not by themselves determine model usefulness.

---

# 13. Linear Regression Baseline

## Purpose

A simple Linear Regression model was trained first to establish a baseline for the more nonlinear Random Forest model.

Script:

```text
train_baseline_model.m
```

Features:

```text
Voltage
Current
Elapsed Time
```

Target:

```text
Remaining Time
```

Model output:

```text
baseline_linear_model.mat
```

## Results

| Metric | Validation |     Test |
| ------ | ---------: | -------: |
| MAE    |   445.09 s | 426.90 s |
| RMSE   |   571.16 s | 550.99 s |
| R²     |     0.4873 |   0.4659 |

Test MAE:

```text
426.90 s ≈ 7.11 minutes
```

This model serves as the initial quantitative baseline.

---

# 14. Random Forest Baseline

A Random Forest regression model was then trained using the same basic input features.

Script:

```text
train_random_forest.m
```

Initial configuration:

```text
Method            = Bag
Number of trees   = 100
Minimum leaf size = 20
```

Features:

```text
Voltage
Current
Elapsed Time
```

## Results

| Metric | Validation |     Test |
| ------ | ---------: | -------: |
| MAE    |   404.35 s | 391.16 s |
| RMSE   |   532.81 s | 510.44 s |
| R²     |     0.5538 |   0.5416 |

Training time:

```text
≈ 113.50 s
```

Model:

```text
random_forest_model.mat
```

---

# 15. Model Comparison

The initial Linear Regression and Random Forest models were compared.

Script:

```text
compare_models.m
```

## Results

| Model             | Test MAE | Test RMSE | Test R² |
| ----------------- | -------: | --------: | ------: |
| Linear Regression | 426.90 s |  550.99 s |  0.4659 |
| Random Forest     | 391.16 s |  510.44 s |  0.5416 |

Relative improvement of the initial Random Forest over Linear Regression:

```text
Test MAE improvement  ≈ 8.37%
Test RMSE improvement ≈ 7.36%
R² increase           ≈ 0.0757
```

### Interpretation

For this experiment and feature set, Random Forest captured nonlinear relationships better than Linear Regression.

This comparison is used as a benchmark result and does not imply that Random Forest will remain the best model after adding vehicle-aware features in Stage 2.

Files:

```text
model_comparison.mat
model_comparison.csv
```

---

# 16. Random Forest Feature Importance

Feature importance was analyzed to understand the contribution of the three input features.

Script:

```text
analyze_feature_importance.m
```

Initial Random Forest feature importance:

| Feature      | Importance |
| ------------ | ---------: |
| Voltage      |     18.233 |
| Elapsed Time |     11.983 |
| Current      |     5.5719 |

Ordering:

```text
Voltage
   ↓
Elapsed Time
   ↓
Current
```

Voltage was the strongest feature among the three features for this Random Forest configuration.

Saved outputs include:

```text
random_forest_feature_importance.png
random_forest_feature_importance.mat
random_forest_feature_importance.csv
```

---

# 17. Random Forest Prediction Analysis

Script:

```text
analyze_rf_predictions.m
```

The Random Forest predictions were analyzed using:

```text
Actual vs Predicted Remaining Time
Prediction Error Distribution
Prediction Error vs Actual Remaining Time
Single-Trajectory Prediction
```

Initial Random Forest test results:

```text
MAE  = 391.16 s
RMSE = 510.44 s
R²   = 0.5416
```

Equivalent:

```text
MAE  ≈ 6.52 minutes
RMSE ≈ 8.51 minutes
```

Generated figures include:

```text
rf_actual_vs_predicted.png
rf_prediction_error_distribution.png
rf_error_vs_actual.png
rf_single_trajectory_prediction.png
```

### Observations

The model captured the general actual-vs-predicted relationship.

Prediction errors were distributed around zero but could become large.

Errors were generally larger in regions with high remaining time.

Individual trajectory predictions showed changes caused by the tree-based nature of Random Forest regression.

---

# 18. Trajectory-Level Error Analysis

Trajectory-level performance was analyzed instead of relying only on pooled sample-level metrics.

Script:

```text
trajectory_error_analysis.m
```

Number of test trajectories:

```text
124
```

## Trajectory-Level Metrics

```text
Mean trajectory MAE   = 420.88 s
Median trajectory MAE = 375.81 s

Minimum trajectory MAE = 111.60 s
Maximum trajectory MAE = 1190.10 s

Mean trajectory RMSE   = 481.12 s
Median trajectory RMSE = 439.70 s
```

Some trajectories were substantially harder to predict.

Examples:

| Trajectory |      MAE |     RMSE |      R² |
| ---------: | -------: | -------: | ------: |
|        490 | 1190.1 s | 1239.4 s |  -39.39 |
|        707 | 1080.2 s | 1089.8 s | -128.44 |
|        524 | 1004.8 s | 1031.9 s | -93.098 |
|        534 | 987.59 s | 1036.1 s | -30.662 |

Negative trajectory-level R² values indicate that, for those individual trajectories, the model performed worse than a prediction based on that trajectory's mean remaining time.

---

# 19. Error by Remaining-Time Range

Prediction error was also analyzed according to the actual remaining-time range.

| Remaining Time | Samples |      MAE |
| -------------- | ------: | -------: |
| 0–600 s        |  69,471 | 364.57 s |
| 600–1200 s     |  59,290 | 318.34 s |
| 1200–1800 s    |  45,952 | 365.22 s |
| 1800–2400 s    |  26,066 | 475.37 s |
| 2400–3000 s    |   9,558 | 704.35 s |
| 3000–3600 s    |   2,031 | 1088.7 s |
| >3600 s        |     612 | 1620.9 s |

### Important Finding

The current Random Forest becomes substantially less accurate when the actual remaining time is large.

This indicates that the early-discharge/high-remaining-time region is a difficult prediction region for the current feature set.

Generated files include:

```text
rf_trajectory_mae.png
rf_trajectory_rmse.png
rf_mae_by_remaining_time.png
rf_trajectory_mae_vs_remaining_time.png
rf_trajectory_error_results.csv
rf_error_by_remaining_time.csv
rf_trajectory_error_analysis.mat
```

---

# 20. Random Forest Hyperparameter Tuning

Script:

```text
tune_random_forest.m
```

Hyperparameter tuning was performed using the training and validation datasets.

The test dataset was not used for model selection.

Configurations tested:

```text
Number of trees:
100
200

Minimum leaf size:
10
20
50
```

## Results

| Trees | Min Leaf | Validation MAE | Validation RMSE | Validation R² |
| ----: | -------: | -------------: | --------------: | ------------: |
|   100 |       10 |       405.92 s |        535.22 s |        0.5498 |
|   100 |       20 |       403.78 s |        532.31 s |        0.5547 |
|   100 |       50 |       403.80 s |        531.00 s |        0.5569 |
|   200 |       10 |       404.87 s |        533.66 s |        0.5524 |
|   200 |       20 |       404.18 s |        532.72 s |        0.5540 |
|   200 |       50 |       403.95 s |        530.90 s |        0.5570 |

The configuration with the lowest validation MAE was:

```text
100 trees
Minimum leaf size = 20
```

The tested configurations were relatively close in performance.

### Conclusion

Increasing Random Forest complexity alone did not produce a major improvement.

This suggests that future performance improvement may depend more on adding physically meaningful and causal features than simply increasing model complexity.

Saved files:

```text
random_forest_tuning_results.mat
random_forest_tuning_results.csv
```

---

# 21. Final NASA Random Forest

Script:

```text
train_final_random_forest.m
```

After hyperparameter selection, the final Random Forest was trained using the selected configuration.

## Selected Configuration

```text
Number of trees   = 100
Minimum leaf size = 20
```

Final training data:

```text
Training + Validation
= 1,261,120 samples
```

The test dataset remained untouched for final evaluation.

## Final Test Results

```text
Test MAE  = 393.66 s
Test RMSE = 511.08 s
Test R²   = 0.5405
```

Equivalent:

```text
MAE  ≈ 6.56 minutes
RMSE ≈ 8.52 minutes
```

Training time:

```text
136.31 s
```

## Final Feature Importance

| Feature      | Importance |
| ------------ | ---------: |
| Voltage      |      16.74 |
| Elapsed Time |     9.6342 |
| Current      |     4.9401 |

Final ordering:

```text
Voltage
   ↓
Elapsed Time
   ↓
Current
```

Important files:

```text
final_random_forest_model.mat
final_random_forest_metrics.csv
final_random_forest_feature_importance.csv
final_rf_actual_vs_predicted.png
```

---

# 22. Final Stage-1 NASA Benchmark

The final Stage-1 benchmark is:

```text
Model:
Random Forest

Number of trees:
100

Minimum leaf size:
20

Input features:
Voltage
Current
Elapsed Time

Target:
Remaining Time
```

Final held-out test performance:

```text
MAE  = 393.66 s
RMSE = 511.08 s
R²   = 0.5405
```

Equivalent:

```text
MAE  ≈ 6.56 minutes
RMSE ≈ 8.52 minutes
```

These are the measured results of the current NASA RW3 benchmark.

They should be treated as the **Stage-1 reference performance**, not as the final performance of the complete RTEdge EV system.

---

# 23. Simulation Foundation — Battery Model V1

Alongside the NASA benchmark, a basic MATLAB/Simulink battery model was created as the starting point for the simulation side of the project.

This is a **simulation milestone**, not yet the NASA-vs-Simulink validation.

## Battery Model

A Battery Equivalent Circuit model was created in Simulink.

### Battery

```text
Battery type:
Panasonic NCR18650PF lithium-ion cell

Capacity:
2.84 Ah

Initial SOC:
100%

Thermal model:
Constant temperature
```

### Electrical Components

```text
Battery Equivalent Circuit
DC Current Source
Current Sensor
Voltage Sensor
PS-Simulink Converter
Scopes
Electrical Reference
Solver Configuration
```

### Test Condition

```text
Discharge current ≈ 1 A
Simulation time = 600 seconds
```

## Observed Result

The simulation completed successfully.

Battery voltage decreased approximately:

```text
4.14 V → 4.03 V
```

while the discharge current remained approximately:

```text
1 A
```

### Conclusion

The first battery-only Simulink model runs successfully and produces a plausible voltage response under constant-current discharge.

This model will later be extended and validated against NASA trajectories before being used as a controlled simulation data generator.

Suggested model file:

```text
matlab/02_battery_model/battery_model_v1.slx
```

---

# 24. Stage-1 Conclusion

The NASA experimental benchmark portion of Stage 1 successfully established an end-to-end remaining-time prediction pipeline.

Completed pipeline:

```text
NASA RW3.mat
      ↓
Dataset inspection
      ↓
Random-walk identification
      ↓
Trajectory extraction
      ↓
Data-quality investigation
      ↓
Corrupt trajectory removal
      ↓
3.2 V endpoint definition
      ↓
Remaining-time labels
      ↓
Trajectory-aware Train/Validation/Test split
      ↓
Feature analysis
      ↓
Linear Regression
      ↓
Random Forest
      ↓
Feature importance
      ↓
Prediction analysis
      ↓
Trajectory-level error analysis
      ↓
Hyperparameter tuning
      ↓
Final Random Forest
```

The resulting Stage-1 benchmark provides a reproducible reference for future EV-aware modeling.

A basic battery-only Simulink model has also been successfully created and will form the foundation for the simulation and vehicle-aware stages.

---

# 25. Why Stage 2 Is Needed

The current Stage-1 model uses:

```text
Voltage
Current
Elapsed Time
```

These variables describe the battery's observed state but do not explicitly represent the vehicle's operating conditions.

An EV battery experiences changing electrical demand as the vehicle:

```text
Accelerates
Brakes
Changes speed
Climbs or descends slopes
Experiences aerodynamic drag
Experiences rolling resistance
```

Therefore, Stage 2 will introduce physically meaningful vehicle variables.

Planned inputs include:

```text
Velocity
Acceleration
Road slope
Vehicle mass
Rolling resistance
Aerodynamic drag
Traction force
Wheel power
Motor power
Battery power
Battery current
```

The goal is to connect vehicle operating conditions to battery load and then generate a controlled EV-aware simulation dataset.

---

# 26. Stage 2 Planned Architecture

```text
                 EV Drive Cycle
                       ↓
                    Velocity
                       ↓
                  Acceleration
                       ↓
          ┌──────────────────────────┐
          │    Vehicle Dynamics      │
          │                          │
          │ Vehicle mass             │
          │ Rolling resistance       │
          │ Aerodynamic drag         │
          │ Road slope               │
          └────────────┬─────────────┘
                       ↓
                 Traction Force
                       ↓
                  Wheel Power
                       ↓
                  Motor Power
                       ↓
                 Battery Power
                       ↓
                Battery Current
                       ↓
          ┌──────────────────────────┐
          │    Simulink Battery      │
          │       Model              │
          └────────────┬─────────────┘
                       ↓
               Voltage / SOC
                       ↓
             EV-aware dataset
                       ↓
                 ML pipeline
                       ↓
          Remaining-Time Prediction
```

---

# 27. Stage 2 Development Plan

Stage 2 will be developed incrementally.

## Step 1 — Drive Cycle

Introduce a time-varying vehicle speed profile.

```text
Drive Cycle
     ↓
Velocity
```

---

## Step 2 — Acceleration

Derive acceleration from velocity:

```text
a(t) = dv(t) / dt
```

Do not independently invent velocity and acceleration profiles.

---

## Step 3 — Vehicle Dynamics

Calculate the major longitudinal forces:

```text
Inertial force
Rolling resistance
Aerodynamic drag
Grade force
```

Conceptually:

```text
F_total =
m*a
+ m*g*Crr
+ 0.5*rho*Cd*A*v²
+ m*g*sin(theta)
```

---

## Step 4 — Vehicle Power

Calculate:

```text
Traction force
      ↓
Wheel power
      ↓
Motor power
      ↓
Battery power
```

---

## Step 5 — Battery Load

Convert battery power to battery current using the simulated battery voltage and the selected power/sign convention.

```text
Battery power
      ↓
Battery current
      ↓
Simulink battery model
```

---

## Step 6 — Simulation Dataset

Record variables such as:

```text
time
velocity
acceleration
road slope
braking/regen state
battery current
battery voltage
battery power
battery temperature
SOC
SOH
distance
energy
remaining runtime
remaining range
```

Each simulation should also contain metadata such as:

```text
simulation_id
battery_id
drive_cycle_id
model_version
temperature
initial_SOC
initial_SOH
random_seed
```

---

## Step 7 — Vehicle-Aware ML

The generated simulation dataset will then be used to investigate whether adding vehicle information improves remaining-time prediction.

The Stage-1 NASA model will remain the reference baseline.

---

# 28. Stage 2 Research Comparison

The key comparison will be:

```text
Stage 1
Battery-only features
        ↓
Voltage + Current + Time
        ↓
NASA Random Forest

             VS

Stage 2
Vehicle-aware features
        ↓
Voltage + Current + Time
+ Velocity
+ Acceleration
+ Load / Power
+ Other validated vehicle variables
        ↓
EV-aware Random Forest
```

The purpose is to experimentally determine whether vehicle operating information provides useful additional predictive information.

No improvement should be assumed before the experiment is performed.

---

# 29. Important Modeling and Leakage Rules

The ML models must use only information available at prediction time.

The following must not be used as input features:

```text
cutoff_time_s
remaining_time_s
future current
future velocity
future acceleration
future energy
future SOC
future SOH
post-cutoff measurements
future distance
centered rolling windows containing future samples
```

Feature engineering must use current and past information only.

Dataset splitting must remain trajectory/scenario aware.

For simulation datasets, complete simulation scenarios should be kept together during evaluation rather than randomly splitting rows from the same simulation.

---

# 30. Important Files at Stage-1 Completion

## Raw Data

```text
data/nasa_raw/RW3.mat
```

## NASA Inspection

```text
matlab/01_inspect_nasa/
```

## Battery Model

```text
matlab/02_battery_model/battery_model_v1.slx
```

## Dataset Generation / ML

```text
matlab/05_dataset_generation/
```

## Processed Dataset

```text
RW3_random_walk_dataset_FINAL.mat
```

## Train/Validation/Test Split

```text
RW3_train_validation_test_split.mat
```

## Linear Regression Model

```text
baseline_linear_model.mat
```

## Random Forest Models

```text
random_forest_model.mat
final_random_forest_model.mat
```

## Model Comparison

```text
model_comparison.mat
model_comparison.csv
```

## Random Forest Metrics

```text
final_random_forest_metrics.csv
```

## Feature Importance

```text
random_forest_feature_importance.csv
random_forest_feature_importance.mat
```

## Tuning Results

```text
random_forest_tuning_results.csv
random_forest_tuning_results.mat
```

## Documentation

```text
documentation/PROGRESS_STAGE1_RTEdge.md
documentation/experiment_log.md
```

---

# 31. Evidence / Screenshot Checklist

The following evidence should be retained for the final project report and presentation.

## MATLAB / NASA

```text
MATLAB version
RW3 structure
RW3 step fields
Charge / Discharge / Rest counts
Random-walk trajectory detection
Trajectory 175 investigation
Endpoint validation
Final dataset statistics
Final dataset sample preview
Trajectory distribution
Train/Validation/Test split
Leakage check
Feature correlation results
```

## Simulink

```text
Battery model block diagram
Battery parameters
Current input
Voltage scope
Current scope
600-second simulation result
```

## Machine Learning

```text
Linear Regression metrics
Linear Regression actual-vs-predicted
Random Forest metrics
Random Forest feature importance
Random Forest actual-vs-predicted
Prediction error distribution
Prediction error vs actual remaining time
Single-trajectory prediction
Trajectory MAE
Trajectory RMSE
MAE by remaining-time range
Hyperparameter tuning results
Final Random Forest results
```

---

# 32. Experiment Log

Every major experiment should have a short corresponding entry in:

```text
documentation/experiment_log.md
```

Recommended entries:

```text
EXP-001 — NASA RW3 Dataset Inspection
EXP-002 — Random-Walk Trajectory Extraction
EXP-003 — Data Quality Investigation
EXP-004 — Corrupt Trajectory Investigation
EXP-005 — Remaining-Time Target Generation
EXP-006 — Final NASA Dataset
EXP-007 — Train/Validation/Test Split
EXP-008 — Feature Analysis
EXP-009 — Linear Regression Baseline
EXP-010 — Random Forest Baseline
EXP-011 — Feature Importance Analysis
EXP-012 — Prediction Error Analysis
EXP-013 — Trajectory-Level Error Analysis
EXP-014 — Random Forest Hyperparameter Tuning
EXP-015 — Final Random Forest
EXP-016 — Battery Simulation V1
```

Each experiment should record:

```text
Date
Input
Purpose
Script/model used
Important parameters
Result
Output files
Evidence/screenshot
```

---

# 33. Reproducibility Rule

At every future milestone, save:

1. Exact MATLAB/Simulink/Python script or model
2. Input dataset
3. Important parameters
4. Generated output
5. Final metrics
6. Successful-result screenshot
7. Short experiment-log entry

Do not modify or overwrite the original raw NASA dataset.

Important Stage-1 artifacts should remain available so that the benchmark can be reproduced later.

---

# 34. Current Status

```text
NASA RW3 inspection                    COMPLETE
Random-walk extraction                 COMPLETE
Data-quality analysis                 COMPLETE
Corrupt trajectory investigation      COMPLETE
Remaining-time target                 COMPLETE
Final NASA dataset                    COMPLETE
Trajectory-aware split                COMPLETE
Feature analysis                      COMPLETE
Linear Regression baseline            COMPLETE
Random Forest baseline                COMPLETE
Feature importance                    COMPLETE
Prediction analysis                  COMPLETE
Trajectory error analysis             COMPLETE
RF hyperparameter tuning              COMPLETE
Final NASA Random Forest              COMPLETE

Basic Battery Simulink Model V1       COMPLETE
NASA vs Simulink validation            NOT STARTED

Vehicle dynamics                       NEXT
EV drive cycle                         NEXT
Velocity / acceleration                NEXT
Battery-load coupling                 NEXT
NASA-vs-Simulink validation            NEXT
EV-aware simulation dataset            NEXT
Vehicle-aware ML                       NEXT
Integrated Simulink + ML system       FUTURE
Final validation                       FUTURE
```

---

# 35. Stage 1 Checkpoint

**Stage 1 NASA Experimental Benchmark: COMPLETE**

The project now has a reproducible NASA-based remaining-time benchmark consisting of:

```text
Raw NASA data
      ↓
Processed trajectories
      ↓
Remaining-time labels
      ↓
Leakage-safe dataset split
      ↓
Feature analysis
      ↓
Linear Regression baseline
      ↓
Random Forest
      ↓
Hyperparameter tuning
      ↓
Final Random Forest
      ↓
Error analysis
```

The current final Stage-1 benchmark is:

```text
Random Forest
100 trees
Minimum leaf size = 20

Test MAE  = 393.66 s
Test RMSE = 511.08 s
Test R²   = 0.5405
```

A basic Battery Equivalent Circuit Simulink model has also been successfully created:

```text
Panasonic NCR18650PF
Capacity = 2.84 Ah
Initial SOC = 100%
Discharge = approximately 1 A
Simulation = 600 s

Voltage:
4.14 V → 4.03 V
```

The next major objective is to validate and extend the battery simulation and then introduce vehicle operating conditions to create the Stage-2 EV-aware modeling pipeline.

---

# 36. Stage Transition

```text
=============================
       STAGE 1 COMPLETE
=============================

NASA Experimental Benchmark
          ↓
       Baseline
          ↓
  Random Forest Model
          ↓
  Error / Feature Analysis
          ↓
   Reference Performance

              ↓
              ↓
              ↓

=============================
       STAGE 2 NEXT
=============================

Validate Battery Model
          ↓
Temperature / Aging
          ↓
Drive Cycle
          ↓
Velocity
          ↓
Acceleration
          ↓
Vehicle Dynamics
          ↓
Battery Load
          ↓
EV Simulation Dataset
          ↓
Vehicle-Aware ML
```

**Stage-1 benchmark is now frozen as the reference point for Stage 2.**
