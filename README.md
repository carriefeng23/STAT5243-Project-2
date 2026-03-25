# STAT5243-Project-2 -- Web App Development

This project is an interactive Shiny web application for dataset upload, preprocessing, feature engineering, and exploratory data analysis.

 # App Workflow
The application follows a 4-step data analysis pipeline:

- Dataset Upload & Preview
- Data Cleaning
- Feature Engineering
- Exploratory Data Analysis (EDA)
# Step 1: Dataset Upload & Preview
 ## What to Do
- Choose:
- Upload file, or
- Use sample dataset (iris / mtcars)
- If uploading:
- Click Upload a dataset
- Supported formats:
.csv
.xlsx / .xls
.rds
.json
## What You Get
- Dataset structure:
- Number of rows and columns
- Column names and types
- Missing values per column
- Data preview:
- First 10 rows of the dataset
# Step 2: Data Cleaning
## Available Operations (can be selected from the side bar)
- Remove Duplicate Rows
  - 1. Removes exact duplicate observations

- Handle Missing Values
  - 1. Choose one method from the drop down menu `Missing value method`:
    - Remove rows with missing values
    - Mean imputation (numeric only)
- Handle outliers
  - 1. Choose one method from the drop down menu `Outlier method`:
    - Cap outliers using IQR
    - Remove rows with outliers
- Scale Numeric Variables (Optional)
  - 1. Choose one method from the drop down menu `Scaling method`:
    - Standardization (z-score)
    - Min-Max scaling
## How to Use
- Select cleaning options in the sidebar
- Click Apply Data Cleaning
- Go to Data Cleaning tab panel
## Outputs
- Cleaned dataset preview
- Cleaning log (step-by-step actions)
## Download
user can choose to download cleaned dataset and cleaning log as csv files by clicking `Download Cleaned Dataset` and `Download Cleaning Log` at the side bar
- cleaned_dataset.csv
- cleaning_log.csv
# Step 3: Feature Engineering
## Supported Methods
user can choose which feature engineering type to use
- Single-variable Transformations
  - 1. Choose transformation type through drop down menu `Choose transformation:`
    - Log: log(x + 1)
    - Square: x²
    - Square root: √x
- Two-variable Interaction Features
  - 1. Choose operation type through drop down menu `Choose operation:`
    - Multiply: x * y
    - Divide: x / y (safe division)
    - Add: x + y
    - Subtract: x - y
- Binning
  - 1. Select the number of bins in `Number of bins:`
## How to Use
- Select feature engineering type
- Choose variables
- Click Apply Feature Engineering
- Check results in Feature Engineering tab panel
## Key Features
- Only numeric variables are selectable
- Prevents invalid operations (e.g., division by zero)
- Automatically generates unique feature names
- Updates dataset instantly
## Outputs
- Updated dataset with new features
- Feature engineering log
## Download
user can choose to download engineered dataset and feature log as csv files by clicking `Download Engineered Dataset` and `Download Feature Log` at the side bar
- engineered_dataset.csv
- feature_log.csv
# Step 4: Exploratory Data Analysis (EDA)
- Dataset Selection
- Choose:
- Cleaned dataset
- Engineered dataset
## Univariate Analysis
- Numeric Variables
- Histogram
- Density curve
- Summary statistics (mean, median, sd, etc.)
- Categorical Variables
- Bar plot
- Frequency table
## Bivariate Analysis
- Numeric vs Numeric
- Scatter plot
- Linear trend line
- Correlation coefficient
- Numeric vs Categorical
- Boxplot
- Categorical vs Categorical
- Grouped bar chart
## Correlation Analysis
- Correlation matrix for all numeric variables
- Heatmap visualization
- Automatically handles missing values
## How to Use
- Select dataset
- Choose primary variable
- (Optional) Choose secondary variable
- View plot and summary
## Outputs
- Interactive plots
- Summary statistics
- Correlation matrix and heatmap

## Team Members
- Carrie Yan Yin Feng – Data upload and preview
- Shuzhi Yang – Data cleaning
- Haoyun Tong – Feature engineering
- Yolanda He – EDA
