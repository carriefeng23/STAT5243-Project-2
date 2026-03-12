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

## Team Members
- Carrie Yan Yin Feng – Data upload and preview
- Shuzhi Yang – Data cleaning
- Haoyun Tong – Feature engineering
- Yolanda He – EDA

## Data Cleaning (Preprocessing) Notebook Content

### 1 Setting

```python
import re
import warnings
import numpy as np
import pandas as pd

from IPython.display import display
from sklearn.preprocessing import StandardScaler, MinMaxScaler, RobustScaler

warnings.filterwarnings("ignore")
pd.set_option("display.max_columns", 200)
pd.set_option("display.max_rows", 200)
```

### 2 Utility Functions

```python
NA_STRINGS = {
    "", " ", "na", "n/a", "nan", "null", "none", "missing", "unknown", "?"
}

def clean_column_name(name):
    name = str(name).strip().lower()
    name = re.sub(r"[^\w]+", "_", name)
    name = re.sub(r"_+", "_", name).strip("_")
    return name

def standardize_column_names(df):
    out = df.copy()
    out.columns = [clean_column_name(col) for col in out.columns]
    return out

def normalize_missing_markers(df):
    out = df.copy()
    text_cols = out.select_dtypes(include=["object", "string", "category"]).columns
    
    for col in text_cols:
        s = out[col].astype("string").str.strip()
        s = s.replace(list(NA_STRINGS), pd.NA)
        s = s.mask(s == "", pd.NA)
        out[col] = s
    
    return out

def standardize_text_columns(df, lower=False):
    out = df.copy()
    text_cols = out.select_dtypes(include=["object", "string", "category"]).columns
    
    for col in text_cols:
        s = out[col].astype("string").str.strip()
        if lower:
            s = s.str.lower()
        out[col] = s
    
    return out

def try_convert_numeric(series, threshold=0.8):
    """
    Try converting an object/string column to numeric.
    Convert only when most non-null values parse successfully.
    """
    if pd.api.types.is_numeric_dtype(series) or pd.api.types.is_datetime64_any_dtype(series):
        return series
    
    s = series.astype("string").str.strip()
    non_null = s.dropna()
    
    if len(non_null) == 0:
        return series
    
    # If many values look like 00123, treat as ID-like and keep as text
    leading_zero_ratio = non_null.str.match(r"^0\d+$", na=False).mean()
    if leading_zero_ratio > 0.5:
        return series
    
    cleaned = s.str.replace(",", "", regex=False)
    cleaned = cleaned.str.replace(r"\$", "", regex=True)
    cleaned = cleaned.str.replace(r"%", "", regex=True)
    cleaned = cleaned.str.replace(r"^\((.*)\)$", r"-\1", regex=True)  # (123) -> -123
    
    converted = pd.to_numeric(cleaned, errors="coerce")
    parse_ratio = converted.notna().sum() / len(non_null)
    
    if parse_ratio >= threshold:
        return converted
    
    return series

def try_convert_datetime(series, threshold=0.8):
    """
    Try converting an object/string column to datetime.
    Convert only when most non-null values parse successfully.
    """
    if pd.api.types.is_datetime64_any_dtype(series) or pd.api.types.is_numeric_dtype(series):
        return series
    
    s = series.astype("string").str.strip()
    non_null = s.dropna()
    
    if len(non_null) == 0:
        return series
    
    converted = pd.to_datetime(s, errors="coerce")
    parse_ratio = converted.notna().sum() / len(non_null)
    
    if parse_ratio >= threshold:
        return converted
    
    return series
```

### 3 Cleaning Toolkit

```python
class DataCleaningToolkit:
    def __init__(self, df):
        self.original_df = df.copy()
        self.df = df.copy()
        self.log = []
    
    def _record(self, message):
        self.log.append(message)
    
    def overall_summary(self):
        summary = {
            "rows": self.df.shape[0],
            "columns": self.df.shape[1],
            "duplicate_rows": int(self.df.duplicated().sum()),
            "total_missing_values": int(self.df.isna().sum().sum()),
            "numeric_columns": len(self.df.select_dtypes(include=np.number).columns),
            "categorical_columns": len(self.df.select_dtypes(include=["object", "string", "category", "bool"]).columns),
            "datetime_columns": len(self.df.select_dtypes(include=["datetime64[ns]", "datetimetz"]).columns),
        }
        return pd.DataFrame([summary])
    
    def column_report(self):
        report = pd.DataFrame({
            "dtype": self.df.dtypes.astype(str),
            "missing_count": self.df.isna().sum(),
            "missing_pct": (self.df.isna().mean() * 100).round(2),
            "n_unique": self.df.nunique(dropna=True)
        })
        return report.sort_values(["missing_pct", "n_unique"], ascending=[False, True])
    
    def standardize_formats(self, lower_text=False, parse_numeric=True, parse_dates=True):
        old_columns = list(self.df.columns)
        self.df = standardize_column_names(self.df)
        new_columns = list(self.df.columns)
        
        if old_columns != new_columns:
            self._record("Standardized column names.")
        
        self.df = normalize_missing_markers(self.df)
        self.df = standardize_text_columns(self.df, lower=lower_text)
        self._record("Standardized text columns and normalized common missing-value markers.")
        
        if parse_numeric:
            converted_numeric_cols = []
            for col in self.df.columns:
                old_dtype = self.df[col].dtype
                new_series = try_convert_numeric(self.df[col])
                new_dtype = new_series.dtype
                
                if old_dtype != new_dtype and pd.api.types.is_numeric_dtype(new_series):
                    self.df[col] = new_series
                    converted_numeric_cols.append(col)
            
            if converted_numeric_cols:
                self._record(f"Converted numeric-like columns to numeric: {converted_numeric_cols}")
        
        if parse_dates:
            converted_date_cols = []
            for col in self.df.columns:
                old_dtype = self.df[col].dtype
                new_series = try_convert_datetime(self.df[col])
                new_dtype = new_series.dtype
                
                if old_dtype != new_dtype and pd.api.types.is_datetime64_any_dtype(new_series):
                    self.df[col] = new_series
                    converted_date_cols.append(col)
            
            if converted_date_cols:
                self._record(f"Converted date-like columns to datetime: {converted_date_cols}")
        
        return self
    
    def remove_duplicates(self, subset=None, keep="first"):
        before = len(self.df)
        
        if keep == "remove_all":
            dup_mask = self.df.duplicated(subset=subset, keep=False)
        else:
            dup_mask = self.df.duplicated(subset=subset, keep=keep)
        
        removed = int(dup_mask.sum())
        self.df = self.df.loc[~dup_mask].copy()
        
        self._record(f"Removed {removed} duplicate rows (before={before}, after={len(self.df)}).")
        return self
    
    def drop_missing(self, axis="rows", threshold=0.5):
        """
        threshold is the maximum allowed missing ratio.
        For example, with threshold=0.5:
        - axis='rows': drop rows with missing ratio > 50%
        - axis='columns': drop columns with missing ratio > 50%
        """
        if axis not in {"rows", "columns"}:
            raise ValueError("axis must be 'rows' or 'columns'")
        
        if not (0 <= threshold <= 1):
            raise ValueError("threshold must be between 0 and 1")
        
        if axis == "rows":
            before = len(self.df)
            row_missing_ratio = self.df.isna().mean(axis=1)
            self.df = self.df.loc[row_missing_ratio <= threshold].copy()
            removed = before - len(self.df)
            self._record(f"Dropped {removed} rows with missing ratio > {threshold:.0%}.")
        
        else:
            before = self.df.shape[1]
            col_missing_ratio = self.df.isna().mean(axis=0)
            keep_cols = col_missing_ratio[col_missing_ratio <= threshold].index
            self.df = self.df[keep_cols].copy()
            removed = before - self.df.shape[1]
            self._record(f"Dropped {removed} columns with missing ratio > {threshold:.0%}.")
        
        return self
    
    def impute_missing(self, numeric_strategy="median", categorical_strategy="mode", fill_value="missing"):
        """
        numeric_strategy: 'mean', 'median', 'zero'
        categorical_strategy: 'mode', 'constant'
        """
        numeric_cols = self.df.select_dtypes(include=np.number).columns.tolist()
        categorical_cols = self.df.select_dtypes(include=["object", "string", "category", "bool"]).columns.tolist()
        
        # Impute numeric columns
        for col in numeric_cols:
            if self.df[col].isna().sum() == 0:
                continue
            
            if numeric_strategy == "mean":
                value = self.df[col].mean()
            elif numeric_strategy == "median":
                value = self.df[col].median()
            elif numeric_strategy == "zero":
                value = 0
            else:
                raise ValueError("numeric_strategy must be 'mean', 'median', or 'zero'")
            
            self.df[col] = self.df[col].fillna(value)
        
        # Impute categorical columns
        for col in categorical_cols:
            if self.df[col].isna().sum() == 0:
                continue
            
            if categorical_strategy == "mode":
                modes = self.df[col].mode(dropna=True)
                value = modes.iloc[0] if len(modes) > 0 else fill_value
            elif categorical_strategy == "constant":
                value = fill_value
            else:
                raise ValueError("categorical_strategy must be 'mode' or 'constant'")
            
            self.df[col] = self.df[col].fillna(value)
        
        self._record(
            f"Imputed missing values: numeric='{numeric_strategy}', categorical='{categorical_strategy}'."
        )
        return self
    
    def handle_outliers(self, columns=None, method="cap", multiplier=1.5):
        """
        Handle outliers with the IQR method
        method:
        - 'cap'    : clip outliers to lower/upper bounds
        - 'remove' : drop rows containing outliers
        """
        numeric_cols = self.df.select_dtypes(include=np.number).columns.tolist()
        if columns is None:
            columns = numeric_cols
        else:
            columns = [c for c in columns if c in numeric_cols]
        
        if not columns:
            self._record("No numeric columns available for outlier handling.")
            return self
        
        if method == "cap":
            capped_count = 0
            
            for col in columns:
                s = self.df[col]
                if s.dropna().shape[0] < 4:
                    continue
                
                q1 = s.quantile(0.25)
                q3 = s.quantile(0.75)
                iqr = q3 - q1
                
                if pd.isna(iqr) or iqr == 0:
                    continue
                
                lower = q1 - multiplier * iqr
                upper = q3 + multiplier * iqr
                
                before_outliers = ((s < lower) | (s > upper)).sum()
                self.df[col] = s.clip(lower=lower, upper=upper)
                capped_count += int(before_outliers)
            
            self._record(f"Capped {capped_count} outlier values using IQR method (multiplier={multiplier}).")
        
        elif method == "remove":
            keep_mask = pd.Series(True, index=self.df.index)
            
            for col in columns:
                s = self.df[col]
                if s.dropna().shape[0] < 4:
                    continue
                
                q1 = s.quantile(0.25)
                q3 = s.quantile(0.75)
                iqr = q3 - q1
                
                if pd.isna(iqr) or iqr == 0:
                    continue
                
                lower = q1 - multiplier * iqr
                upper = q3 + multiplier * iqr
                
                col_mask = s.isna() | ((s >= lower) & (s <= upper))
                keep_mask &= col_mask
            
            before = len(self.df)
            self.df = self.df.loc[keep_mask].copy()
            removed = before - len(self.df)
            self._record(f"Removed {removed} rows containing outliers using IQR method (multiplier={multiplier}).")
        
        else:
            raise ValueError("method must be 'cap' or 'remove'")
        
        return self
    
    def scale_numeric(self, columns=None, method="standard", exclude_binary=True):
        numeric_cols = self.df.select_dtypes(include=np.number).columns.tolist()
        
        if columns is None:
            columns = numeric_cols
        else:
            columns = [c for c in columns if c in numeric_cols]
        
        if exclude_binary:
            columns = [c for c in columns if self.df[c].dropna().nunique() > 2]
        
        if not columns:
            self._record("No eligible numeric columns available for scaling.")
            return self
        
        if method == "standard":
            scaler = StandardScaler()
        elif method == "minmax":
            scaler = MinMaxScaler()
        elif method == "robust":
            scaler = RobustScaler()
        else:
            raise ValueError("method must be 'standard', 'minmax', or 'robust'")
        
        self.df[columns] = scaler.fit_transform(self.df[columns])
        self._record(f"Scaled numeric columns using {method} scaler: {columns}")
        return self
    
    def encode_categorical(self, columns=None, method="onehot", drop_first=False, max_levels=None):
        categorical_cols = self.df.select_dtypes(include=["object", "string", "category", "bool"]).columns.tolist()
        
        if columns is None:
            columns = categorical_cols
        else:
            columns = [c for c in columns if c in categorical_cols]
        
        if not columns:
            self._record("No categorical columns available for encoding.")
            return self
        
        if max_levels is not None:
            kept_cols = []
            skipped_cols = []
            for col in columns:
                if self.df[col].nunique(dropna=True) <= max_levels:
                    kept_cols.append(col)
                else:
                    skipped_cols.append(col)
            columns = kept_cols
            if skipped_cols:
                self._record(f"Skipped high-cardinality categorical columns: {skipped_cols}")
        
        if not columns:
            self._record("No categorical columns remained after max_levels filtering.")
            return self
        
        if method == "onehot":
            self.df = pd.get_dummies(
                self.df,
                columns=columns,
                drop_first=drop_first,
                dtype=int
            )
            self._record(f"Applied one-hot encoding to columns: {columns}")
            return self
        
        elif method == "ordinal":
            mappings = {}
            for col in columns:
                codes, uniques = pd.factorize(self.df[col], sort=True)
                self.df[col] = np.where(codes == -1, np.nan, codes)
                mappings[col] = {str(v): int(i) for i, v in enumerate(uniques)}
            self._record(f"Applied ordinal encoding to columns: {columns}")
            return mappings
        
        else:
            raise ValueError("method must be 'onehot' or 'ordinal'")
    
    def cleaning_log(self):
        return pd.DataFrame({
            "step": range(1, len(self.log) + 1),
            "action": self.log
        })
```

### 4 Load Dataset

```python
import pandas as pd
from sklearn.datasets import load_iris

def load_person1_dataset(data_source="sample", sample_data="iris", file_path=None):
    if data_source == "sample":
        if sample_data == "iris":
            iris = load_iris(as_frame=True)
            return iris.frame.copy()
        elif sample_data == "mtcars":
            from pydataset import data
            return pd.DataFrame(data("mtcars"))
        else:
            raise ValueError("sample_data must be 'iris' or 'mtcars'")
    
    elif data_source == "upload":
        if file_path is None:
            raise ValueError("file_path cannot be None when data_source='upload'")
        
        ext = file_path.split(".")[-1].lower()
        
        if ext == "csv":
            return pd.read_csv(file_path)
        elif ext in ["xlsx", "xls"]:
            return pd.read_excel(file_path)
        elif ext == "json":
            return pd.read_json(file_path)
        elif ext == "rds":
            import pyreadr
            result = pyreadr.read_r(file_path)
            return pd.DataFrame(list(result.values())[0])
        else:
            raise ValueError("Unsupported file type")
    
    else:
        raise ValueError("data_source must be 'sample' or 'upload'")

df = load_person1_dataset(
    data_source="sample",
    sample_data="iris"
)

print(df.shape)
display(df.head())
```

### 5 Before Cleaning

```python
tool = DataCleaningToolkit(df)

print("=== BEFORE CLEANING: OVERALL SUMMARY ===")
display(tool.overall_summary())

print("=== BEFORE CLEANING: COLUMN REPORT ===")
display(tool.column_report().head(20))
```

### 6 Cleaning Config

```python
config = {
    "lower_text": False,              # Convert text to lowercase
    "parse_numeric": True,            # Auto-detect numeric-like columns
    "parse_dates": True,              # Auto-detect date-like columns
    
    "remove_duplicates": True,
    "duplicate_subset": None,         # e.g. ["customer_id"]; None means full-row dedup
    "duplicate_keep": "first",        # "first", "last", "remove_all"
    
    "drop_missing_rows": False,
    "row_missing_threshold": 0.6,     # Drop rows when missing ratio > 60%
    
    "drop_missing_columns": False,
    "col_missing_threshold": 0.6,     # Drop columns when missing ratio > 60%
    
    "impute_missing": True,
    "numeric_impute": "median",       # "mean", "median", "zero"
    "categorical_impute": "mode",     # "mode", "constant"
    "categorical_fill_value": "missing",
    
    "handle_outliers": True,
    "outlier_method": "cap",          # "cap" or "remove"
    "outlier_multiplier": 1.5,
    "outlier_columns": None,          # e.g. ["age", "income"]
    
    "scale_numeric": True,
    "scaling_method": "standard",     # "standard", "minmax", "robust"
    "scaling_columns": None,
    
    "encode_categorical": True,
    "encoding_method": "onehot",      # "onehot" or "ordinal"
    "encoding_columns": None,
    "drop_first": False,
    "max_levels": 15                  # Prevent high-cardinality columns from exploding feature count
}
```

### 7 Run Cleaning

```python
tool = DataCleaningToolkit(df)

# 1) Standardize formats
tool.standardize_formats(
    lower_text=config["lower_text"],
    parse_numeric=config["parse_numeric"],
    parse_dates=config["parse_dates"]
)

# 2) Handle duplicates
if config["remove_duplicates"]:
    tool.remove_duplicates(
        subset=config["duplicate_subset"],
        keep=config["duplicate_keep"]
    )

# 3) Drop rows/columns with too much missing data
if config["drop_missing_rows"]:
    tool.drop_missing(
        axis="rows",
        threshold=config["row_missing_threshold"]
    )

if config["drop_missing_columns"]:
    tool.drop_missing(
        axis="columns",
        threshold=config["col_missing_threshold"]
    )

# 4) Impute missing values
if config["impute_missing"]:
    tool.impute_missing(
        numeric_strategy=config["numeric_impute"],
        categorical_strategy=config["categorical_impute"],
        fill_value=config["categorical_fill_value"]
    )

# 5) Handle outliers
if config["handle_outliers"]:
    tool.handle_outliers(
        columns=config["outlier_columns"],
        method=config["outlier_method"],
        multiplier=config["outlier_multiplier"]
    )

# 6) Scale numeric features
if config["scale_numeric"]:
    tool.scale_numeric(
        columns=config["scaling_columns"],
        method=config["scaling_method"]
    )

# 7) Encode categorical features
if config["encode_categorical"]:
    encode_result = tool.encode_categorical(
        columns=config["encoding_columns"],
        method=config["encoding_method"],
        drop_first=config["drop_first"],
        max_levels=config["max_levels"]
    )

cleaned_df = tool.df.copy()

print("=== AFTER CLEANING: OVERALL SUMMARY ===")
display(tool.overall_summary())

print("=== AFTER CLEANING: COLUMN REPORT ===")
display(tool.column_report().head(20))

print("=== CLEANING LOG ===")
display(tool.cleaning_log())

print("=== CLEANED DATA PREVIEW ===")
display(cleaned_df.head())
```

### 8 Save Outputs

```python
cleaned_df.to_csv("cleaned_dataset.csv", index=False)
tool.cleaning_log().to_csv("cleaning_log.csv", index=False)

print("Files saved:")
print("- cleaned_dataset.csv")
print("- cleaning_log.csv")
```
