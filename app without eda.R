library(shiny) # interactive web app in R
library(tools)
library(readxl) # reads excel files
library(jsonlite) # reads json files

options(shiny.maxRequestSize = 30 * 1024^2) # increase max upload size to 30 mb

# UI, the basic layout and components
ui <- fluidPage(
  titlePanel("STAT GR5243 Project 2 -- Web App Development"),
  
  # sidebar that has dataset selection buttons, cleaning controls, and feature engineering controls
  sidebarLayout(
    sidebarPanel(
      h4("Step 1: Choose a dataset"),
      radioButtons(
        "data_source", "Select data source:",
        choices = c("Upload file" = "upload",
                    "Use sample dataset" = "sample"),
        selected = "upload"
      ),
      
      # file upload input
      conditionalPanel(
        condition = "input.data_source == 'upload'",
        fileInput(
          "file", "Upload a dataset",
          accept = c(".csv", ".xlsx", ".xls", ".rds", ".json") # acceptable file formats
        )
      ),
      
      # dropdown menu for the built-in datasets, using iris and mtcars datasets
      conditionalPanel(
        condition = "input.data_source == 'sample'",
        selectInput("sample_data", "Choose a built-in dataset:", choices = c("iris", "mtcars"))
      ),
      
      hr(),
      h4("Step 2: Data Cleaning"),
      
      # remove duplicate rows
      checkboxInput("remove_duplicates", "Remove duplicate rows", value = TRUE),
      
      # handle missing values
      checkboxInput("handle_missing", "Handle missing values", value = TRUE),
      selectInput(
        "missing_method",
        "Missing value method:",
        choices = c("Remove rows with missing values" = "remove",
                    "Mean imputation (numeric only)" = "mean")
      ),
      
      # handle outliers
      checkboxInput("handle_outliers", "Handle outliers", value = FALSE),
      selectInput(
        "outlier_method",
        "Outlier method:",
        choices = c("Cap outliers using IQR" = "cap",
                    "Remove rows with outliers" = "remove")
      ),
      
      # scale numeric variables
      checkboxInput("scale_numeric", "Scale numeric variables", value = FALSE),
      selectInput(
        "scaling_method",
        "Scaling method:",
        choices = c("Standardization (z-score)" = "standard",
                    "Min-Max scaling" = "minmax")
      ),
      
      # apply cleaning and download outputs
      actionButton("apply_cleaning", "Apply Data Cleaning"),
      br(), br(),
      downloadButton("download_cleaned_data", "Download Cleaned Dataset"),
      br(), br(),
      downloadButton("download_cleaning_log", "Download Cleaning Log"),
      
      hr(),
      h4("Step 3: Feature Engineering"),
      
      # choose the feature engineering method
      radioButtons(
        "fe_type",
        "Choose feature engineering type:",
        choices = c(
          "Single-variable transformation" = "single",
          "Two-variable interaction" = "interaction",
          "Binning" = "binning"
        ),
        selected = "single"
      ),
      
      # controls for single-variable transformations
      conditionalPanel(
        condition = "input.fe_type == 'single'",
        uiOutput("single_var_ui"),
        selectInput(
          "single_method",
          "Choose transformation:",
          choices = c("Log", "Square", "Square Root")
        )
      ),
      
      # controls for interaction features
      conditionalPanel(
        condition = "input.fe_type == 'interaction'",
        uiOutput("var1_ui"),
        uiOutput("var2_ui"),
        selectInput(
          "interaction_method",
          "Choose operation:",
          choices = c("Multiply", "Divide", "Add", "Subtract")
        )
      ),
      
      # controls for numeric binning
      conditionalPanel(
        condition = "input.fe_type == 'binning'",
        uiOutput("bin_var_ui"),
        numericInput("n_bins", "Number of bins:", value = 4, min = 2, max = 10)
      ),
      
      # apply feature engineering and download outputs
      actionButton("apply_fe", "Apply Feature Engineering"),
      br(), br(),
      downloadButton("download_data", "Download Engineered Dataset"),
      br(), br(),
      downloadButton("download_log", "Download Feature Log")
    ),
    
    # main area that displays dataset info, preview, cleaning results, and feature engineering results
    mainPanel(
      tabsetPanel(
        tabPanel(
          "Upload & Preview",
          p("Upload your own dataset or choose a built-in example to preview and inspect its structure."),
          
          h3("Dataset Information"),
          verbatimTextOutput("data_info"),
          
          br(),
          h3("Data Preview"),
          tableOutput("preview")
        ),
        
        tabPanel(
          "Data Cleaning",
          h3("Cleaned Dataset Preview"),
          tableOutput("clean_preview"),
          
          br(),
          h3("Cleaning Log"),
          tableOutput("clean_log_preview"),
          
          br(),
          verbatimTextOutput("clean_status")
        ),
        
        tabPanel(
          "Feature Engineering",
          h3("Current Dataset Preview"),
          tableOutput("fe_preview"),
          
          br(),
          h3("Feature Engineering Log"),
          tableOutput("fe_log_preview"),
          
          br(),
          verbatimTextOutput("fe_status")
        )
      )
    )
  )
)

server <- function(input, output, session) {
  
  data_raw <- reactive({
    if (input$data_source == "sample") {
      if (input$sample_data == "iris") return(as.data.frame(iris))
      if (input$sample_data == "mtcars") return(as.data.frame(mtcars))
    }
    
    req(input$file) # make sure the file is uploaded before continuing
    
    # get the file name and path
    file_name <- as.character(input$file$name[[1]])
    file_path <- as.character(input$file$datapath[[1]])
    ext <- tolower(file_ext(file_name))
    
    # read dataset based on file format
    if (ext == "csv") {
      df <- read.csv(file_path, stringsAsFactors = FALSE, check.names = FALSE)
    } else if (ext %in% c("xlsx", "xls")) {
      df <- as.data.frame(read_excel(file_path))
    } else if (ext == "rds") {
      df <- as.data.frame(readRDS(file_path))
    } else if (ext == "json") {
      df <- as.data.frame(jsonlite::fromJSON(file_path))
    } else {
      stop("Unsupported file type. Supported types: csv, xlsx, xls, rds, json")
    }
    
    as.data.frame(df) # make sure to return a data frame
  })
  
  # output for upload and preview
  output$data_info <- renderPrint({
    df <- data_raw()
    
    cat("Rows:", nrow(df), "\n")
    cat("Columns:", ncol(df), "\n\n")
    
    cat("Column Names:\n")
    print(names(df))
    
    cat("\nColumn Types:\n")
    print(sapply(df, function(x) class(x)[1]))
    
    cat("\nMissing Values Per Column:\n")
    print(colSums(is.na(df)))
  })
  
  output$preview <- renderTable({
    head(data_raw(), 10)
  })
  
  # store the cleaned dataset after data cleaning operations
  data_clean <- reactiveVal(NULL)
  
  # store the cleaning history for traceability
  cleaning_log <- reactiveVal(data.frame(
    step = integer(),
    action = character(),
    details = character(),
    stringsAsFactors = FALSE
  ))
  
  # reset the cleaned dataset and cleaning log whenever the source dataset changes
  observe({
    df <- data_raw()
    req(df)
    
    data_clean(df)
    cleaning_log(data.frame(
      step = integer(),
      action = character(),
      details = character(),
      stringsAsFactors = FALSE
    ))
  })
  
  # cap outliers using IQR
  cap_outliers_iqr <- function(x) {
    if (!is.numeric(x)) return(x)
    
    q1 <- quantile(x, 0.25, na.rm = TRUE)
    q3 <- quantile(x, 0.75, na.rm = TRUE)
    iqr <- q3 - q1
    lower <- q1 - 1.5 * iqr
    upper <- q3 + 1.5 * iqr
    
    x[x < lower] <- lower
    x[x > upper] <- upper
    x
  }
  
  # remove rows containing outliers using IQR
  remove_outlier_rows_iqr <- function(df) {
    numeric_cols <- names(df)[sapply(df, is.numeric)]
    if (length(numeric_cols) == 0) return(df)
    
    keep <- rep(TRUE, nrow(df))
    
    for (col in numeric_cols) {
      x <- df[[col]]
      q1 <- quantile(x, 0.25, na.rm = TRUE)
      q3 <- quantile(x, 0.75, na.rm = TRUE)
      iqr <- q3 - q1
      lower <- q1 - 1.5 * iqr
      upper <- q3 + 1.5 * iqr
      
      keep <- keep & (is.na(x) | (x >= lower & x <= upper))
    }
    
    df[keep, , drop = FALSE]
  }
  
  # apply the selected data cleaning operations
  observeEvent(input$apply_cleaning, {
    df <- data_raw()
    req(df)
    
    log_df <- data.frame(
      step = integer(),
      action = character(),
      details = character(),
      stringsAsFactors = FALSE
    )
    
    # remove duplicate rows
    if (isTRUE(input$remove_duplicates)) {
      before_n <- nrow(df)
      df <- unique(df)
      removed <- before_n - nrow(df)
      
      log_df <- rbind(
        log_df,
        data.frame(
          step = nrow(log_df) + 1,
          action = "Remove duplicates",
          details = paste("Removed", removed, "duplicate row(s)."),
          stringsAsFactors = FALSE
        )
      )
    }
    
    # handle missing values
    if (isTRUE(input$handle_missing)) {
      if (input$missing_method == "remove") {
        before_n <- nrow(df)
        df <- na.omit(df)
        removed <- before_n - nrow(df)
        
        log_df <- rbind(
          log_df,
          data.frame(
            step = nrow(log_df) + 1,
            action = "Handle missing values",
            details = paste("Removed", removed, "row(s) containing missing values."),
            stringsAsFactors = FALSE
          )
        )
      }
      
      if (input$missing_method == "mean") {
        numeric_cols_clean <- names(df)[sapply(df, is.numeric)]
        
        for (col in numeric_cols_clean) {
          if (anyNA(df[[col]])) {
            df[[col]][is.na(df[[col]])] <- mean(df[[col]], na.rm = TRUE)
          }
        }
        
        log_df <- rbind(
          log_df,
          data.frame(
            step = nrow(log_df) + 1,
            action = "Handle missing values",
            details = "Applied mean imputation to numeric columns.",
            stringsAsFactors = FALSE
          )
        )
      }
    }
    
    # handle outliers
    if (isTRUE(input$handle_outliers)) {
      if (input$outlier_method == "cap") {
        numeric_cols_clean <- names(df)[sapply(df, is.numeric)]
        
        for (col in numeric_cols_clean) {
          df[[col]] <- cap_outliers_iqr(df[[col]])
        }
        
        log_df <- rbind(
          log_df,
          data.frame(
            step = nrow(log_df) + 1,
            action = "Handle outliers",
            details = "Capped numeric outliers using the IQR rule.",
            stringsAsFactors = FALSE
          )
        )
      }
      
      if (input$outlier_method == "remove") {
        before_n <- nrow(df)
        df <- remove_outlier_rows_iqr(df)
        removed <- before_n - nrow(df)
        
        log_df <- rbind(
          log_df,
          data.frame(
            step = nrow(log_df) + 1,
            action = "Handle outliers",
            details = paste("Removed", removed, "row(s) containing numeric outliers."),
            stringsAsFactors = FALSE
          )
        )
      }
    }
    
    # scale numeric variables
    if (isTRUE(input$scale_numeric)) {
      numeric_cols_clean <- names(df)[sapply(df, is.numeric)]
      
      if (input$scaling_method == "standard") {
        for (col in numeric_cols_clean) {
          s <- sd(df[[col]], na.rm = TRUE)
          m <- mean(df[[col]], na.rm = TRUE)
          
          if (!is.na(s) && s != 0) {
            df[[col]] <- (df[[col]] - m) / s
          }
        }
        
        log_df <- rbind(
          log_df,
          data.frame(
            step = nrow(log_df) + 1,
            action = "Scale numeric variables",
            details = "Applied z-score standardization to numeric columns.",
            stringsAsFactors = FALSE
          )
        )
      }
      
      if (input$scaling_method == "minmax") {
        for (col in numeric_cols_clean) {
          min_val <- min(df[[col]], na.rm = TRUE)
          max_val <- max(df[[col]], na.rm = TRUE)
          
          if (!is.na(min_val) && !is.na(max_val) && max_val != min_val) {
            df[[col]] <- (df[[col]] - min_val) / (max_val - min_val)
          }
        }
        
        log_df <- rbind(
          log_df,
          data.frame(
            step = nrow(log_df) + 1,
            action = "Scale numeric variables",
            details = "Applied min-max scaling to numeric columns.",
            stringsAsFactors = FALSE
          )
        )
      }
    }
    
    data_clean(df)
    cleaning_log(log_df)
  })
  
  # display a preview of the cleaned dataset
  output$clean_preview <- renderTable({
    req(data_clean())
    head(data_clean(), 10)
  })
  
  # display the cleaning log
  output$clean_log_preview <- renderTable({
    req(cleaning_log())
    cleaning_log()
  })
  
  # display the cleaned dataset status
  output$clean_status <- renderPrint({
    df <- data_clean()
    req(df)
    
    cat("Rows:", nrow(df), "\n")
    cat("Columns:", ncol(df), "\n")
    cat("Cleaning steps recorded:", nrow(cleaning_log()), "\n")
  })
  
  # download the current cleaned dataset as a csv file
  output$download_cleaned_data <- downloadHandler(
    filename = function() {
      "cleaned_dataset.csv"
    },
    content = function(file) {
      write.csv(data_clean(), file, row.names = FALSE)
    }
  )
  
  # download the cleaning log as a csv file
  output$download_cleaning_log <- downloadHandler(
    filename = function() {
      "cleaning_log.csv"
    },
    content = function(file) {
      write.csv(cleaning_log(), file, row.names = FALSE)
    }
  )
  
  # store the current working dataset after feature engineering operations
  data_fe <- reactiveVal(NULL)
  
  # store the feature engineering history for traceability
  fe_log <- reactiveVal(data.frame(
    step = integer(),
    feature_name = character(),
    method = character(),
    source_columns = character(),
    stringsAsFactors = FALSE
  ))
  
  # reset the working dataset and log whenever the cleaned dataset changes
  observe({
    df <- data_clean()
    req(df)
    
    data_fe(df)
    fe_log(data.frame(
      step = integer(),
      feature_name = character(),
      method = character(),
      source_columns = character(),
      stringsAsFactors = FALSE
    ))
  })
  
  # keep only numeric columns for current feature engineering methods
  numeric_cols <- reactive({
    df <- data_fe()
    req(df)
    names(df)[sapply(df, is.numeric)]
  })
  
  # generate the variable selector for single-variable transformations
  output$single_var_ui <- renderUI({
    req(numeric_cols())
    selectInput("single_var", "Select a numeric variable:", choices = numeric_cols())
  })
  
  # generate the first variable selector for interaction features
  output$var1_ui <- renderUI({
    req(numeric_cols())
    selectInput("var1", "Select first numeric variable:", choices = numeric_cols())
  })
  
  # generate the second variable selector for interaction features
  output$var2_ui <- renderUI({
    req(numeric_cols())
    selectInput("var2", "Select second numeric variable:", choices = numeric_cols())
  })
  
  # generate the variable selector for binning
  output$bin_var_ui <- renderUI({
    req(numeric_cols())
    selectInput("bin_var", "Select a numeric variable to bin:", choices = numeric_cols())
  })
  
  # create a unique feature name to avoid overwriting existing columns
  make_unique_name <- function(df, base_name) {
    new_name <- base_name
    counter <- 1
    
    while (new_name %in% names(df)) {
      counter <- counter + 1
      new_name <- paste0(base_name, "_", counter)
    }
    
    new_name
  }
  
  # apply the selected feature engineering operation
  observeEvent(input$apply_fe, {
    df <- data_fe()
    req(df)
    
    log_df <- fe_log()
    
    if (input$fe_type == "single") {
      var <- input$single_var
      method <- input$single_method
      
      if (method == "Log") {
        base_name <- paste0("log_", var)
        new_name <- make_unique_name(df, base_name)
        
        # apply log(x + 1) only to non-negative values
        df[[new_name]] <- ifelse(df[[var]] >= 0, log(df[[var]] + 1), NA)
      }
      
      if (method == "Square") {
        base_name <- paste0(var, "_sq")
        new_name <- make_unique_name(df, base_name)
        df[[new_name]] <- df[[var]]^2
      }
      
      if (method == "Square Root") {
        base_name <- paste0("sqrt_", var)
        new_name <- make_unique_name(df, base_name)
        
        # apply square root only to non-negative values
        df[[new_name]] <- ifelse(df[[var]] >= 0, sqrt(df[[var]]), NA)
      }
      
      log_df <- rbind(
        log_df,
        data.frame(
          step = nrow(log_df) + 1,
          feature_name = new_name,
          method = method,
          source_columns = var,
          stringsAsFactors = FALSE
        )
      )
    }
    
    if (input$fe_type == "interaction") {
      v1 <- input$var1
      v2 <- input$var2
      method <- input$interaction_method
      
      if (method == "Multiply") {
        base_name <- paste0(v1, "_x_", v2)
        new_name <- make_unique_name(df, base_name)
        df[[new_name]] <- df[[v1]] * df[[v2]]
      }
      
      if (method == "Divide") {
        base_name <- paste0(v1, "_div_", v2)
        new_name <- make_unique_name(df, base_name)
        
        # replace division-by-zero results with NA
        df[[new_name]] <- ifelse(df[[v2]] == 0, NA, df[[v1]] / df[[v2]])
      }
      
      if (method == "Add") {
        base_name <- paste0(v1, "_plus_", v2)
        new_name <- make_unique_name(df, base_name)
        df[[new_name]] <- df[[v1]] + df[[v2]]
      }
      
      if (method == "Subtract") {
        base_name <- paste0(v1, "_minus_", v2)
        new_name <- make_unique_name(df, base_name)
        df[[new_name]] <- df[[v1]] - df[[v2]]
      }
      
      log_df <- rbind(
        log_df,
        data.frame(
          step = nrow(log_df) + 1,
          feature_name = new_name,
          method = method,
          source_columns = paste(v1, v2, sep = ", "),
          stringsAsFactors = FALSE
        )
      )
    }
    
    if (input$fe_type == "binning") {
      var <- input$bin_var
      bins <- input$n_bins
      
      base_name <- paste0(var, "_bin")
      new_name <- make_unique_name(df, base_name)
      
      # convert a continuous numeric variable into categorical bins
      df[[new_name]] <- cut(df[[var]], breaks = bins, include.lowest = TRUE)
      
      log_df <- rbind(
        log_df,
        data.frame(
          step = nrow(log_df) + 1,
          feature_name = new_name,
          method = paste("Binning:", bins, "bins"),
          source_columns = var,
          stringsAsFactors = FALSE
        )
      )
    }
    
    data_fe(df)
    fe_log(log_df)
  })
  
  # display a preview of the current engineered dataset
  output$fe_preview <- renderTable({
    req(data_fe())
    head(data_fe(), 10)
  })
  
  # display the feature engineering log
  output$fe_log_preview <- renderTable({
    req(fe_log())
    fe_log()
  })
  
  # display the dataset status and current feature count
  output$fe_status <- renderPrint({
    df <- data_fe()
    req(df)
    
    cat("Rows:", nrow(df), "\n")
    cat("Columns:", ncol(df), "\n")
    cat("New features created:", nrow(fe_log()), "\n")
  })
  
  # download the current engineered dataset as a csv file
  output$download_data <- downloadHandler(
    filename = function() {
      "engineered_dataset.csv"
    },
    content = function(file) {
      write.csv(data_fe(), file, row.names = FALSE)
    }
  )
  
  # download the feature engineering log as a csv file
  output$download_log <- downloadHandler(
    filename = function() {
      "feature_log.csv"
    },
    content = function(file) {
      write.csv(fe_log(), file, row.names = FALSE)
    }
  )
}

# shiny app
shinyApp(ui = ui, server = server)