# STAT5243-Project-2 -- Web App Development

This project is an interactive Shiny web application for dataset upload, preprocessing, feature engineering, and exploratory data analysis.

 ##App Workflow

-The application follows a 4-step data analysis pipeline:

# Dataset Upload & Preview
-Data Cleaning
-Feature Engineering
-Exploratory Data Analysis (EDA)
## Step 1: Dataset Upload & Preview
-What to Do
-Choose:
-Upload file, or
-Use sample dataset (iris / mtcars)
-If uploading:
-Click Upload a dataset
-Supported formats:
.csv
.xlsx / .xls
.rds
.json
-What You Get
-Dataset structure:
-Number of rows and columns
-Column names and types
-Missing values per column
-Data preview:
-First 10 rows of the dataset
# Step 2: Data Cleaning
-Available Operations
-1. Remove Duplicate Rows
-Removes exact duplicate observations
-2. Handle Missing Values

-Choose one method:

-Remove rows with missing values
-Mean imputation (numeric only)
-3. Scale Numeric Variables (Optional)

-Choose one method:

-Standardization (z-score)
-Min-Max scaling
-How to Use
-Select cleaning options in the sidebar
-Click Apply Data Cleaning
-Go to Data Cleaning tab
-Outputs
-Cleaned dataset preview
-Cleaning log (step-by-step actions)
-Download
-cleaned_dataset.csv
-cleaning_log.csv
## Step 3: Feature Engineering
-Supported Methods
-1. Single-variable Transformations
-Log transformation: log(x + 1)
-Square: x²
-Square root: √x
-2. Two-variable Interaction Features
-Multiply: x * y
-Divide: x / y (safe division)
-Add: x + y
-Subtract: x - y
-3. Numeric Binning
-Convert continuous variables into categories
-Select number of bins interactively
-How to Use
-Select feature engineering type
-Choose variables
-Click Apply Feature Engineering
-Check results in Feature Engineering tab
-Key Features
-Only numeric variables are selectable
-Prevents invalid operations (e.g., division by zero)
-Automatically generates unique feature names
-Updates dataset instantly
-Outputs
-Updated dataset with new features
-Feature engineering log
-Download
-engineered_dataset.csv
-feature_log.csv
## Step 4: Exploratory Data Analysis (EDA)
-Dataset Selection
-Choose:
-Cleaned dataset
-Engineered dataset
# Univariate Analysis
-Numeric Variables
-Histogram
-Density curve
-Summary statistics (mean, median, sd, etc.)
-Categorical Variables
-Bar plot
-Frequency table
# Bivariate Analysis
-Numeric vs Numeric
-Scatter plot
-Linear trend line
-Correlation coefficient
-Numeric vs Categorical
-Boxplot
-Categorical vs Categorical
-Grouped bar chart
# Correlation Analysis
-Correlation matrix for all numeric variables
-Heatmap visualization
-Automatically handles missing values
-How to Use
-Select dataset
-Choose primary variable
-(Optional) Choose secondary variable
-View plot and summary
-Outputs
-Interactive plots
-Summary statistics
-Correlation matrix and heatmap

## Team Members
- Carrie Yan Yin Feng – Data upload and preview
- Shuzhi Yang – Data cleaning
- Haoyun Tong – Feature engineering
- Yolanda He – EDA
