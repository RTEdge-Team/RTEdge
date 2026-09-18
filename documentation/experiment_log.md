## EXP-008 — Random Forest Baseline

Input:

RW3_train_validation_test_split.mat

Features:

- voltage_V
- current_A
- time_s

Target:

remaining_time_s

Model:

Random Forest regression using MATLAB fitrensemble.

Configuration:

Number of trees = 100

Minimum leaf size = 20

Training samples:

1,026,256

Validation samples:

234,864

Test samples:

212,980

Training time:

113.50 seconds

Validation results:

MAE = 404.35 seconds

RMSE = 532.81 seconds

R² = 0.5538

Test results:

MAE = 391.16 seconds

RMSE = 510.44 seconds

R² = 0.5416

Model file:

random_forest_model.mat


## EXP-009 — Model Comparison

### Objective

Compare the first Linear Regression baseline with the first Random Forest regression model using the same NASA RW3 trajectory-aware train/validation/test split.

### Input

`RW3_train_validation_test_split.mat`

### Features

* `voltage_V`
* `current_A`
* `time_s`

### Target

`remaining_time_s`

### Models

1. Linear Regression
2. Random Forest

### Random Forest configuration

* Number of trees: 100
* Minimum leaf size: 20
* Training time: 113.50 seconds

### Results

| Model             | Validation MAE (s) | Validation RMSE (s) | Validation R² | Test MAE (s) | Test RMSE (s) | Test R² |
| ----------------- | -----------------: | ------------------: | ------------: | -----------: | ------------: | ------: |
| Linear Regression |             445.09 |              571.16 |        0.4873 |       426.90 |        550.99 |  0.4659 |
| Random Forest     |             404.35 |              532.81 |        0.5538 |       391.16 |        510.44 |  0.5416 |

### Random Forest relative improvement

Compared with Linear Regression on the test set:

* MAE improvement: 8.37%
* RMSE improvement: 7.36%
* R² increase: 0.0757

Test MAE in minutes:

* Linear Regression: 7.11 minutes
* Random Forest: 6.52 minutes

### Interpretation

The first Random Forest experiment produced lower MAE and RMSE and a higher R² than the Linear Regression baseline on the held-out NASA RW3 test trajectories.

This indicates that the Random Forest was able to model relationships between voltage, current, and elapsed time that were not captured as effectively by the linear baseline.

This result is a benchmark result, not the final project model. Further investigation is required before selecting a final model.

### Output files

* `model_comparison.mat`
* `model_comparison.csv`
* `baseline_linear_model.mat`
* `random_forest_model.mat`

### Status

Completed successfully.


