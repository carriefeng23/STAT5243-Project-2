# STAT5243-Project-2 -- Web App Development

This project is an interactive Shiny web application for dataset upload, preprocessing, feature engineering, and exploratory data analysis.

## Current Features
- Upload datasets in CSV, Excel, RDS, and JSON formats
- Use built-in sample datasets
- Preview uploaded data
- Display dataset information

## How to Run
1. Open the project in RStudio
2. Install required packages:
   - shiny
   - readxl
   - jsonlite
3. Run `app.R`
4. Run data cleaning notebook `data cleaning(preprocessing).ipynb`:
   - Open the notebook in Jupyter Notebook / JupyterLab / VS Code
   - Make sure Python packages are installed: `pandas`, `numpy`, `scikit-learn`, `IPython`
   - Run all cells to generate:
     - `cleaned_dataset.csv`
     - `cleaning_log.csv`

## Team Members
- Carrie Yan Yin Feng – Data upload and preview
- Shuzhi Yang – Data cleaning
- Haoyun Tong – Feature engineering
- Yolanda He – EDA

## Data Cleaning (Preprocessing)

This part is implemented in `data cleaning(preprocessing).ipynb` and focuses on turning raw uploaded/sample data into analysis-ready data.

### What It Does
- Standardizes column names and text formats
- Normalizes missing-value markers
- Detects and converts numeric-like/date-like columns
- Removes duplicates
- Drops rows/columns with excessive missing values (optional)
- Imputes missing values for numeric and categorical features
- Handles outliers with IQR (`cap` or `remove`)
- Scales numeric features (`standard`, `minmax`, `robust`)
- Encodes categorical features (`onehot` or `ordinal`)

### Configurable Parameters
- Missing-value thresholds for rows/columns
- Imputation strategy (`mean` / `median` / `zero`, `mode` / `constant`)
- Outlier method and IQR multiplier
- Scaling method and selected columns
- Encoding method, `drop_first`, and `max_levels`

### Outputs
- `cleaned_dataset.csv`: cleaned dataset
- `cleaning_log.csv`: step-by-step cleaning actions



## Feature Engineering

- `This part is implemented in the Shiny application and focuses on creating additional variables from the cleaned dataset to enhance data exploration and downstream analysis.

### What It Does

- `Allows users to upload a cleaned dataset or use a built-in sample dataset (iris, mtcars)

- `Supports interactive feature engineering operations through the Shiny interface

- `Generates new variables dynamically without modifying the original dataset

- `Records each transformation step in a feature engineering log

- `Provides a preview of the updated dataset after new features are created

### Supported Feature Engineering Methods

- `Single-variable transformations:

- `Log transformation (log(x + 1))

- `Square transformation (x²)

- `Square root transformation (√x)

- `Two-variable interaction features:

- `Multiplication (x * y)

- `Division (x / y)

- `Addition (x + y)

- `Subtraction (x - y)

### Numeric binning:

- `Converts continuous numeric variables into categorical bins

- `Number of bins can be selected interactively

### Key Features

- `Automatically detects numeric variables available for transformation

- `Prevents invalid operations such as division by zero

- `Handles negative values safely for logarithm and square root transformations

- `Avoids overwriting existing columns by generating unique feature names

- `Updates the dataset preview immediately after each transformation

### Outputs

- `engineered_dataset.csv: dataset with newly created features

- `feature_log.csv: step-by-step record of feature engineering operations
