# RTEdge --- Stage 1 Progress Record

## Project

**Project Name:** RTEdge --- Intelligent Battery Remaining-Time
Estimation\
**Project Theme:** AI/ML-based Battery Management System for EV\
**Current Stage:** Stage 1 --- NASA RW3 Battery Remaining-Time
Benchmark\
**MATLAB:** R2024b (Version 24.2), Update 6

------------------------------------------------------------------------

# 1. Overall Project Plan

The project is being developed in three major stages:

``` text
Stage 1
NASA experimental battery data
        ↓
Data cleaning and trajectory extraction
        ↓
Remaining-time target
        ↓
Trajectory-aware train/validation/test split
        ↓
Linear Regression baseline
        ↓
Random Forest baseline
        ↓
Model analysis and tuning

Stage 2
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
Battery current
        ↓
Simulink battery model
        ↓
EV-aware dataset
        ↓
Improved ML model

Stage 3
Integrated EV + Battery + ML system
        ↓
Remaining driving-time prediction
        ↓
Validation and final results
```

Stage 1 has now been completed.

------------------------------------------------------------------------

# 2. Folder Structure

Current recommended project structure:

``` text
RTEdge
├── data
│   └── nasa_raw
│       └── RW3.mat
│
├── 01_inspect_nasa
│
├── 02_battery_model
│
├── 03_vehicle_model
│
├── 04_validation
│
├── 05_dataset_generation
│
└── documentation
    ├── PROGRESS.md
    ├── experiment_log.md
    └── screenshots
```

------------------------------------------------------------------------

# 3. MATLAB/Simulink Battery Model Completed

## Battery Model

A basic battery equivalent-circuit model was created in Simulink.

### Battery

-   Battery type: Panasonic NCR18650PF lithium-ion cell
-   Capacity: 2.84 Ah
-   Initial SOC: 100%
-   Thermal model: Constant temperature

### Electrical components

-   Battery Equivalent Circuit
-   DC Current Source
-   Current Sensor
-   Voltage Sensor
-   PS-Simulink Converter
-   Scopes
-   Electrical Reference
-   Solver Configuration

### Test condition

-   Constant discharge current: approximately 1 A
-   Simulation time: 600 seconds

### Observed result

Battery voltage decreased approximately:

``` text
4.14 V → 4.03 V
```

This established the first successful Simulink battery validation.

A screenshot of the Simulink model and scope results should be retained
in:

``` text
documentation/screenshots/
```

Suggested model filename:

``` text
battery_equivalent_circuit_v1.slx
```

------------------------------------------------------------------------

# 4. NASA RW3 Dataset Inspection

## Raw Dataset

File:

``` text
data/nasa_raw/RW3.mat
```

The dataset contains:

``` text
data
├── step
├── procedure
└── description
```

`data.step` is a `1x12826` struct array.

### Step fields

``` text
comment
type
time
relativeTime
voltage
current
temperature
date
```

### Step type counts

  Type                Count
  ----------------- -------
  C --- Charge          867
  D --- Discharge      5728
  R --- Rest           6231

------------------------------------------------------------------------

# 5. Random-Walk Discharge Extraction

The NASA dataset contains random-walk discharge experiments.

Identified:

-   Random-walk discharge steps: 5463
-   Potential random-walk episode endings: 823
-   Random-walk trajectories: 823

The random-walk discharge sequences were grouped into complete discharge
trajectories.

The first trajectories showed behavior such as:

``` text
Initial voltage ≈ 4.199 V
        ↓
Random discharge current
        ↓
Voltage decreases
        ↓
Endpoint around 3.2 V
```

------------------------------------------------------------------------

# 6. Data Quality Investigation

Raw temperature data contained invalid values.

Example invalid values included extremely negative temperatures such as
approximately:

``` text
-4094 °C
```

These values were treated as invalid and converted to `NaN`.

Important finding:

``` text
Missing/invalid temperature samples ≈ 68.04%
```

Therefore temperature was **not used as an input feature for the first
ML benchmark**.

However, valid temperature measurements were retained in the processed
dataset.

------------------------------------------------------------------------

# 7. Corrupt Trajectory Investigation

Trajectory 175 was identified as clearly invalid/incomplete.

Characteristics:

-   Only 3 samples
-   Temperature approximately -1187.5 °C to -132.6 °C
-   Voltage approximately 4.197 V to 4.227 V
-   Current = 0 A
-   Did not represent a valid complete random-walk discharge

Therefore:

``` text
Trajectory 175 → excluded
```

Final usable trajectories:

``` text
823 detected
− 1 excluded
= 822 usable trajectories
```

------------------------------------------------------------------------

# 8. Final NASA Dataset

Final processed dataset:

``` text
RW3_random_walk_dataset_FINAL.mat
```

### Dataset statistics

``` text
Usable trajectories: 822
Total samples: 1,474,100

Voltage:
Minimum = 3.1120 V
Maximum = 4.1990 V

Current:
Minimum = 0 A
Maximum = 4.1470 A

Valid temperature:
Minimum = 19.5016 °C
Maximum = 40.4714 °C

Missing temperature samples:
1,002,941
≈ 68.0375%

Remaining time:
Minimum = 0 s
Maximum = 4296.6900 s
```

No negative remaining-time values were present.

------------------------------------------------------------------------

# 9. Remaining-Time Target

The target variable is:

``` text
remaining_time_s
```

Endpoint definition:

> First observed sample where voltage \<= 3.2 V.

For each trajectory:

``` text
remaining_time_s
=
endpointTime - currentTrajectoryTime
```

Elapsed time was reset for every trajectory:

``` text
time_s = time - time(1)
```

Endpoint validation showed:

``` text
822 / 823 trajectories reached <= 3.2 V
```

The excluded trajectory was trajectory 175.

Some valid trajectories crossed below 3.2 V slightly due to observed
sampling behavior. The endpoint convention remains the first observed
sample at or below 3.2 V.

------------------------------------------------------------------------

# 10. Trajectory-Aware Data Split

File:

``` text
RW3_train_validation_test_split.mat
```

Variables:

``` text
trainData
trainIDs

validationData
validationIDs

testData
testIDs
```

Split:

  Dataset        Trajectories     Samples
  ------------ -------------- -----------
  Training                575   1,026,256
  Validation              123     234,864
  Test                    124     212,980

Random seed:

``` matlab
rng(42)
```

### Leakage check

``` text
Train ∩ Validation = 0
Train ∩ Test = 0
Validation ∩ Test = 0
```

Every trajectory was assigned exactly once.

This trajectory-level split was used to avoid leakage from neighboring
samples of the same battery trajectory.

------------------------------------------------------------------------

# 11. ML Features

Initial ML features:

``` text
voltage_V
current_A
time_s
```

Target:

``` text
remaining_time_s
```

Temperature was excluded from the baseline because approximately 68% of
its samples were invalid/missing.

### Feature correlations

  Feature          Correlation with Remaining Time
  -------------- ---------------------------------
  Voltage                                  +0.4786
  Current                                  -0.0256
  Elapsed Time                             -0.4889
  Temperature                              -0.6704

The temperature correlation was strong, but temperature quality was
insufficient for the initial model.

------------------------------------------------------------------------

# 12. Linear Regression Baseline

Script:

``` text
06_train_baseline_model.m
```

Features:

``` text
Voltage
Current
Elapsed Time
```

Target:

``` text
Remaining Time
```

### Results

  Metric     Validation       Test
  -------- ------------ ----------
  MAE          445.09 s   426.90 s
  RMSE         571.16 s   550.99 s
  R²             0.4873     0.4659

Test MAE:

``` text
426.90 s ≈ 7.11 min
```

Model saved as:

``` text
baseline_linear_model.mat
```

------------------------------------------------------------------------

# 13. Random Forest Baseline

Script:

``` text
07_train_random_forest.m
```

Configuration:

``` text
Method = Bag
Number of trees = 100
Minimum leaf size = 20
```

Features:

``` text
Voltage
Current
Elapsed Time
```

### Results

  Metric     Validation       Test
  -------- ------------ ----------
  MAE          404.35 s   391.16 s
  RMSE         532.81 s   510.44 s
  R²             0.5538     0.5416

Training time:

``` text
≈ 113.50 s
```

Model saved as:

``` text
random_forest_model.mat
```

------------------------------------------------------------------------

# 14. Model Comparison

Script:

``` text
08_compare_models.m
```

### Results

  Model                 Test MAE   Test RMSE   Test R²
  ------------------- ---------- ----------- ---------
  Linear Regression     426.90 s    550.99 s    0.4659
  Random Forest         391.16 s    510.44 s    0.5416

Relative improvement of the baseline RF over Linear Regression:

``` text
Test MAE improvement  ≈ 8.37%
Test RMSE improvement ≈ 7.36%
R² increase           ≈ 0.0757
```

Interpretation:

The Random Forest captured nonlinear relationships better than the
Linear Regression baseline for the tested NASA trajectories.

Files:

``` text
model_comparison.mat
model_comparison.csv
```

------------------------------------------------------------------------

# 15. Random Forest Feature Importance

Script:

``` text
09_analyze_feature_importance.m
```

Feature importance:

  Feature          Importance
  -------------- ------------
  Voltage              18.233
  Elapsed Time         11.983
  Current              5.5719

Ordering:

``` text
Voltage
   ↓
Elapsed Time
   ↓
Current
```

This indicates that voltage was the strongest predictor among the three
features in this Random Forest configuration.

Saved files:

``` text
random_forest_feature_importance.png
random_forest_feature_importance.mat
random_forest_feature_importance.csv
```

------------------------------------------------------------------------

# 16. Random Forest Prediction Analysis

Script:

``` text
10_analyze_rf_predictions.m
```

Test results:

``` text
MAE  = 391.16 s
RMSE = 510.44 s
R²   = 0.5416
```

Equivalent:

``` text
MAE  ≈ 6.52 min
RMSE ≈ 8.51 min
```

Generated visualizations:

``` text
rf_actual_vs_predicted.png
rf_prediction_error_distribution.png
rf_error_vs_actual.png
rf_single_trajectory_prediction.png
```

The prediction analysis showed that:

-   The model captures the general actual-vs-predicted relationship.
-   Prediction errors are distributed around zero but can become large.
-   Error magnitude increases for high remaining-time regions.
-   Individual trajectory predictions can contain abrupt changes because
    Random Forest predictions are tree-based.

------------------------------------------------------------------------

# 17. Trajectory-Level Error Analysis

Script:

``` text
11_trajectory_error_analysis.m
```

Number of test trajectories:

``` text
124
```

### Trajectory-level metrics

``` text
Mean trajectory MAE   = 420.88 s
Median trajectory MAE = 375.81 s

Minimum trajectory MAE = 111.60 s
Maximum trajectory MAE = 1190.10 s

Mean trajectory RMSE   = 481.12 s
Median trajectory RMSE = 439.70 s
```

Some difficult trajectories had very large errors.

Examples:

    Trajectory        MAE       RMSE        R²
  ------------ ---------- ---------- ---------
           490   1190.1 s   1239.4 s    -39.39
           707   1080.2 s   1089.8 s   -128.44
           524   1004.8 s   1031.9 s   -93.098
           534   987.59 s   1036.1 s   -30.662

Negative trajectory-level R² values indicate that, for those individual
trajectories, the model prediction error was larger than the error of
predicting that trajectory's mean remaining time.

### Error by remaining-time range

  Remaining Time     Samples        MAE
  ---------------- --------- ----------
  0--600 s            69,471   364.57 s
  600--1200 s         59,290   318.34 s
  1200--1800 s        45,952   365.22 s
  1800--2400 s        26,066   475.37 s
  2400--3000 s         9,558   704.35 s
  3000--3600 s         2,031   1088.7 s
  \>3600 s               612   1620.9 s

Important finding:

> The current Random Forest becomes substantially less accurate when the
> actual remaining time is large.

Generated files:

``` text
rf_trajectory_mae.png
rf_trajectory_rmse.png
rf_mae_by_remaining_time.png
rf_trajectory_mae_vs_remaining_time.png
rf_trajectory_error_results.csv
rf_error_by_remaining_time.csv
rf_trajectory_error_analysis.mat
```

------------------------------------------------------------------------

# 18. Random Forest Hyperparameter Tuning

Script:

``` text
12_tune_random_forest.m
```

Only training and validation datasets were used for tuning.

The test dataset was not used for model selection.

Configurations tested:

``` text
Trees: 100, 200
MinLeafSize: 10, 20, 50
```

### Results

    Trees   MinLeaf    Val MAE   Val RMSE   Val R²
  ------- --------- ---------- ---------- --------
      100        10   405.92 s   535.22 s   0.5498
      100        20   403.78 s   532.31 s   0.5547
      100        50   403.80 s   531.00 s   0.5569
      200        10   404.87 s   533.66 s   0.5524
      200        20   404.18 s   532.72 s   0.5540
      200        50   403.95 s   530.90 s   0.5570

The configuration with the lowest validation MAE was:

``` text
100 trees
MinLeafSize = 20
```

However, the configurations were very close.

Important conclusion:

> Increasing the number of trees or changing leaf size did not produce a
> major improvement. The larger improvement opportunity is therefore
> likely to come from better physically meaningful input features rather
> than simply increasing Random Forest complexity.

Saved files:

``` text
random_forest_tuning_results.mat
random_forest_tuning_results.csv
```

------------------------------------------------------------------------

# 19. Final NASA Random Forest

Script:

``` text
13_train_final_random_forest.m
```

Selected configuration:

``` text
Number of trees = 100
Minimum leaf size = 20
```

Final training data:

``` text
Training + Validation
= 1,261,120 samples
```

Test data remained untouched until final evaluation.

### Final test results

``` text
Test MAE  = 393.66 s
Test RMSE = 511.08 s
Test R²   = 0.5405
```

Equivalent:

``` text
MAE  ≈ 6.56 minutes
RMSE ≈ 8.52 minutes
```

Training time:

``` text
136.31 s
```

### Final feature importance

  Feature          Importance
  -------------- ------------
  Voltage               16.74
  Elapsed Time         9.6342
  Current              4.9401

Final ordering remains:

``` text
Voltage > Elapsed Time > Current
```

Files:

``` text
final_random_forest_model.mat
final_random_forest_metrics.csv
final_random_forest_feature_importance.csv
final_rf_actual_vs_predicted.png
```

------------------------------------------------------------------------

# 20. Final Stage-1 Conclusion

Stage 1 successfully established an end-to-end NASA battery
remaining-time benchmark.

Completed pipeline:

``` text
NASA RW3.mat
    ↓
Inspect dataset
    ↓
Identify random-walk discharge
    ↓
Segment trajectories
    ↓
Investigate invalid data
    ↓
Remove corrupt trajectory 175
    ↓
Define 3.2 V endpoint
    ↓
Calculate remaining time
    ↓
Trajectory-aware split
    ↓
Feature analysis
    ↓
Linear Regression baseline
    ↓
Random Forest baseline
    ↓
Feature importance
    ↓
Prediction/error analysis
    ↓
Trajectory-level analysis
    ↓
Hyperparameter tuning
    ↓
Final Random Forest
```

Final NASA benchmark:

``` text
Random Forest
100 trees
MinLeafSize = 20

Test MAE  = 393.66 s
Test RMSE = 511.08 s
Test R²   = 0.5405
```

This should be treated as the **Stage-1 benchmark**, not as the final EV
prediction performance.

------------------------------------------------------------------------

# 21. Why Stage 2 Is Needed

The current model uses only:

``` text
Voltage
Current
Elapsed Time
```

These describe the battery measurement but do not explicitly represent
the vehicle operating condition.

For an EV-oriented model, the next stage should introduce physically
meaningful vehicle variables:

``` text
Velocity
Acceleration
Road slope
Vehicle mass
Rolling resistance
Aerodynamic drag
Vehicle/traction power
Motor efficiency
Battery power
Battery current
```

The vehicle demand will be connected to the Simulink battery model.

------------------------------------------------------------------------

# 22. Stage 2 Planned Architecture

``` text
              EV Drive Cycle
                    ↓
                Velocity
                    ↓
              Acceleration
                    ↓
        ┌────────────────────────┐
        │ Vehicle Dynamics       │
        │                        │
        │ Vehicle mass           │
        │ Rolling resistance     │
        │ Aerodynamic drag       │
        │ Road slope             │
        └───────────┬────────────┘
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
        ┌────────────────────────┐
        │ Simulink Battery Model │
        └───────────┬────────────┘
                    ↓
             Voltage / SOC
                    ↓
             EV-aware dataset
                    ↓
            Random Forest / ML
                    ↓
       Remaining Driving Time
```

------------------------------------------------------------------------

# 23. Stage 2 Development Rule

Stage 2 will be built incrementally.

First:

``` text
Velocity
    ↓
Acceleration
    ↓
Force
    ↓
Power
```

Then:

``` text
Power
    ↓
Motor
    ↓
Battery current
```

Then:

``` text
Battery current
    ↓
Existing Simulink battery model
```

Then:

``` text
Simulink outputs
    +
vehicle features
    ↓
new EV-aware dataset
```

Finally:

``` text
EV-aware dataset
    ↓
Improved ML model
```

This avoids adding too many components at once and makes debugging and
validation easier.

------------------------------------------------------------------------

# 24. Evidence/Screenshot Checklist

The following screenshots should be retained for the final
report/presentation.

## MATLAB/NASA

-   MATLAB version
-   RW3 structure
-   Step fields
-   C/D/R counts
-   Random-walk trajectory detection
-   Trajectory 175 investigation
-   Endpoint validation
-   Final dataset statistics
-   Final dataset sample preview
-   Trajectory distribution
-   Train/validation/test split
-   Leakage check
-   Feature correlation plots

## Simulink

-   Battery model block diagram
-   Battery parameters
-   Current input
-   Voltage scope
-   Current scope
-   600-second simulation result

## ML

-   Linear Regression metrics
-   Linear Regression actual-vs-predicted plot
-   Random Forest metrics
-   Random Forest feature importance
-   Random Forest actual-vs-predicted plot
-   Prediction error distribution
-   Prediction error vs actual remaining time
-   Single trajectory prediction
-   Trajectory MAE
-   Trajectory RMSE
-   MAE by remaining-time range
-   Hyperparameter tuning results
-   Final Random Forest results

------------------------------------------------------------------------

# 25. Current Status

``` text
NASA data inspection                 COMPLETE
Random-walk extraction               COMPLETE
Data cleaning                        COMPLETE
Endpoint validation                  COMPLETE
Dataset creation                     COMPLETE
Trajectory-aware split               COMPLETE
Feature analysis                     COMPLETE
Linear Regression                    COMPLETE
Random Forest baseline               COMPLETE
Feature importance                   COMPLETE
Prediction analysis                 COMPLETE
Trajectory error analysis            COMPLETE
RF hyperparameter tuning             COMPLETE
Final NASA RF benchmark              COMPLETE

Vehicle dynamics                     NEXT
EV drive cycle                       NEXT
Battery load coupling                NEXT
EV-aware dataset                     NEXT
Improved ML model                    NEXT
Integrated Simulink + ML system      NEXT
```

------------------------------------------------------------------------

# 26. Important Reproducibility Rule

Do not delete the Stage-1 scripts, models, datasets, CSV results, or
screenshots.

Stage 1 is the baseline against which the Stage-2 EV-aware model will be
compared.

The final project should be able to demonstrate:

``` text
Stage 1:
NASA battery-only benchmark

versus

Stage 2:
Vehicle-aware EV battery model
```

This comparison will provide the main evidence for whether adding
vehicle operating information improves remaining-time estimation.
