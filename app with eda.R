library(shiny)
library(tools)
library(readxl)
library(jsonlite)
library(ggplot2)

options(shiny.maxRequestSize = 30 * 1024^2)

ui <- fluidPage(
  titlePanel("STAT GR5243 Project 2 -- Web App Development"),
  
  sidebarLayout(
    sidebarPanel(
      h4("Step 1: Choose a dataset"),
      radioButtons(
        "data_source", "Select data source:",
        choices = c("Upload file" = "upload",
                    "Use sample dataset" = "sample"),
        selected = "upload"
      ),
      
      conditionalPanel(
        condition = "input.data_source == 'upload'",
        fileInput(
          "file", "Upload a dataset",
          accept = c(".csv", ".xlsx", ".xls", ".rds", ".json")
        )
      ),
      
      conditionalPanel(
        condition = "input.data_source == 'sample'",
        selectInput("sample_data", "Choose a built-in dataset:", choices = c("iris", "mtcars"))
      ),
      
      hr(),
      h4("Step 2: Data Cleaning"),
      
      checkboxInput("remove_duplicates", "Remove duplicate rows", value = TRUE),
      
      checkboxInput("handle_missing", "Handle missing values", value = TRUE),
      selectInput(
        "missing_method",
        "Missing value method:",
        choices = c("Remove rows with missing values" = "remove",
                    "Mean imputation (numeric only)" = "mean")
      ),
      
      checkboxInput("scale_numeric", "Scale numeric variables", value = FALSE),
      selectInput(
        "scaling_method",
        "Scaling method:",
        choices = c("Standardization (z-score)" = "standard",
                    "Min-Max scaling" = "minmax")
      ),
      
      actionButton("apply_cleaning", "Apply Data Cleaning"),
      br(), br(),
      downloadButton("download_cleaned_data", "Download Cleaned Dataset"),
      br(), br(),
      downloadButton("download_cleaning_log", "Download Cleaning Log"),
      
      hr(),
      h4("Step 3: Feature Engineering"),
      
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
      
      conditionalPanel(
        condition = "input.fe_type == 'single'",
        uiOutput("single_var_ui"),
        selectInput(
          "single_method",
          "Choose transformation:",
          choices = c("Log", "Square", "Square Root")
        )
      ),
      
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
      
      conditionalPanel(
        condition = "input.fe_type == 'binning'",
        uiOutput("bin_var_ui"),
        numericInput("n_bins", "Number of bins:", value = 4, min = 2, max = 10)
      ),
      
      actionButton("apply_fe", "Apply Feature Engineering"),
      br(), br(),
      downloadButton("download_data", "Download Engineered Dataset"),
      br(), br(),
      downloadButton("download_log", "Download Feature Log"),
      
      hr(),
      h4("Step 4: Exploratory Data Analysis"),
      
      radioButtons(
        "eda_data_choice",
        "Select dataset for EDA:",
        choices = c("Cleaned dataset" = "clean",
                    "Engineered dataset" = "engineered"),
        selected = "engineered"
      ),
      
      uiOutput("eda_var1_ui"),
      uiOutput("eda_var2_ui"),
      
      sliderInput("hist_bins", "Histogram bins:", min = 5, max = 50, value = 20, step = 1)
    ),
    
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
        ),
        
        tabPanel(
          "EDA",
          h3("Exploratory Data Analysis"),
          plotOutput("eda_plot"),
          br(),
          verbatimTextOutput("eda_summary")
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
    
    req(input$file)
    
    file_name <- as.character(input$file$name[[1]])
    file_path <- as.character(input$file$datapath[[1]])
    ext <- tolower(file_ext(file_name))
    
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
    
    as.data.frame(df)
  })
  
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
  
  data_clean <- reactiveVal(NULL)
  cleaning_log <- reactiveVal(data.frame(
    step = integer(),
    action = character(),
    details = character(),
    stringsAsFactors = FALSE
  ))
  
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
  
  observeEvent(input$apply_cleaning, {
    df <- data_raw()
    req(df)
    
    log_df <- data.frame(
      step = integer(),
      action = character(),
      details = character(),
      stringsAsFactors = FALSE
    )
    
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
  
  output$clean_preview <- renderTable({
    req(data_clean())
    head(data_clean(), 10)
  })
  
  output$clean_log_preview <- renderTable({
    req(cleaning_log())
    cleaning_log()
  })
  
  output$clean_status <- renderPrint({
    df <- data_clean()
    req(df)
    
    cat("Rows:", nrow(df), "\n")
    cat("Columns:", ncol(df), "\n")
    cat("Cleaning steps recorded:", nrow(cleaning_log()), "\n")
  })
  
  output$download_cleaned_data <- downloadHandler(
    filename = function() {
      "cleaned_dataset.csv"
    },
    content = function(file) {
      write.csv(data_clean(), file, row.names = FALSE)
    }
  )
  
  output$download_cleaning_log <- downloadHandler(
    filename = function() {
      "cleaning_log.csv"
    },
    content = function(file) {
      write.csv(cleaning_log(), file, row.names = FALSE)
    }
  )
  
  data_fe <- reactiveVal(NULL)
  fe_log <- reactiveVal(data.frame(
    step = integer(),
    feature_name = character(),
    method = character(),
    source_columns = character(),
    stringsAsFactors = FALSE
  ))
  
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
  
  numeric_cols <- reactive({
    df <- data_fe()
    req(df)
    names(df)[sapply(df, is.numeric)]
  })
  
  output$single_var_ui <- renderUI({
    req(numeric_cols())
    selectInput("single_var", "Select a numeric variable:", choices = numeric_cols())
  })
  
  output$var1_ui <- renderUI({
    req(numeric_cols())
    selectInput("var1", "Select first numeric variable:", choices = numeric_cols())
  })
  
  output$var2_ui <- renderUI({
    req(numeric_cols())
    selectInput("var2", "Select second numeric variable:", choices = numeric_cols())
  })
  
  output$bin_var_ui <- renderUI({
    req(numeric_cols())
    selectInput("bin_var", "Select a numeric variable to bin:", choices = numeric_cols())
  })
  
  make_unique_name <- function(df, base_name) {
    new_name <- base_name
    counter <- 1
    
    while (new_name %in% names(df)) {
      counter <- counter + 1
      new_name <- paste0(base_name, "_", counter)
    }
    
    new_name
  }
  
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
  
  output$fe_preview <- renderTable({
    req(data_fe())
    head(data_fe(), 10)
  })
  
  output$fe_log_preview <- renderTable({
    req(fe_log())
    fe_log()
  })
  
  output$fe_status <- renderPrint({
    df <- data_fe()
    req(df)
    
    cat("Rows:", nrow(df), "\n")
    cat("Columns:", ncol(df), "\n")
    cat("New features created:", nrow(fe_log()), "\n")
  })
  
  output$download_data <- downloadHandler(
    filename = function() {
      "engineered_dataset.csv"
    },
    content = function(file) {
      write.csv(data_fe(), file, row.names = FALSE)
    }
  )
  
  output$download_log <- downloadHandler(
    filename = function() {
      "feature_log.csv"
    },
    content = function(file) {
      write.csv(fe_log(), file, row.names = FALSE)
    }
  )
  
  eda_data <- reactive({
    if (input$eda_data_choice == "clean") {
      req(data_clean())
      return(data_clean())
    } else {
      req(data_fe())
      return(data_fe())
    }
  })
  
  output$eda_var1_ui <- renderUI({
    req(eda_data())
    selectInput("eda_var1", "Select primary variable:", choices = names(eda_data()))
  })
  
  output$eda_var2_ui <- renderUI({
    req(eda_data())
    selectInput(
      "eda_var2",
      "Select secondary variable (optional):",
      choices = c("None", names(eda_data())),
      selected = "None"
    )
  })
  
  output$eda_plot <- renderPlot({
    df <- eda_data()
    req(df, input$eda_var1)
    
    var1 <- input$eda_var1
    var2 <- input$eda_var2
    x <- df[[var1]]
    
    if (var2 == "None") {
      if (is.numeric(x)) {
        ggplot(df, aes(x = .data[[var1]])) +
          geom_histogram(bins = input$hist_bins, fill = "steelblue", color = "white") +
          geom_density(aes(y = after_stat(count)), color = "red", linewidth = 1, na.rm = TRUE) +
          labs(title = paste("Distribution of", var1), x = var1, y = "Count") +
          theme_minimal()
      } else {
        plot_df <- as.data.frame(table(x, useNA = "ifany"), stringsAsFactors = FALSE)
        names(plot_df) <- c("category", "count")
        
        ggplot(plot_df, aes(x = category, y = count)) +
          geom_col(fill = "steelblue") +
          labs(title = paste("Bar Plot of", var1), x = var1, y = "Count") +
          theme_minimal() +
          theme(axis.text.x = element_text(angle = 45, hjust = 1))
      }
    } else {
      y <- df[[var2]]
      
      if (is.numeric(x) && is.numeric(y)) {
        ggplot(df, aes(x = .data[[var1]], y = .data[[var2]])) +
          geom_point(alpha = 0.7) +
          geom_smooth(method = "lm", se = FALSE, color = "red") +
          labs(title = paste("Scatter Plot:", var1, "vs", var2), x = var1, y = var2) +
          theme_minimal()
      } else if (is.numeric(x) && !is.numeric(y)) {
        ggplot(df, aes(x = .data[[var2]], y = .data[[var1]])) +
          geom_boxplot(fill = "steelblue") +
          labs(title = paste("Boxplot of", var1, "by", var2), x = var2, y = var1) +
          theme_minimal() +
          theme(axis.text.x = element_text(angle = 45, hjust = 1))
      } else if (!is.numeric(x) && is.numeric(y)) {
        ggplot(df, aes(x = .data[[var1]], y = .data[[var2]])) +
          geom_boxplot(fill = "steelblue") +
          labs(title = paste("Boxplot of", var2, "by", var1), x = var1, y = var2) +
          theme_minimal() +
          theme(axis.text.x = element_text(angle = 45, hjust = 1))
      } else {
        plot_df <- as.data.frame(table(df[[var1]], df[[var2]], useNA = "ifany"), stringsAsFactors = FALSE)
        names(plot_df) <- c("var1", "var2", "count")
        
        ggplot(plot_df, aes(x = var1, y = count, fill = var2)) +
          geom_col(position = "dodge") +
          labs(title = paste("Grouped Bar Chart:", var1, "by", var2), x = var1, y = "Count", fill = var2) +
          theme_minimal() +
          theme(axis.text.x = element_text(angle = 45, hjust = 1))
      }
    }
  })
  
  output$eda_summary <- renderPrint({
    df <- eda_data()
    req(df, input$eda_var1)
    
    var1 <- input$eda_var1
    var2 <- input$eda_var2
    x <- df[[var1]]
    
    if (var2 == "None") {
      if (is.numeric(x)) {
        cat("Summary statistics for", var1, ":\n")
        print(summary(x))
        cat("\nStandard deviation:", sd(x, na.rm = TRUE), "\n")
      } else {
        cat("Frequency table for", var1, ":\n")
        print(table(x, useNA = "ifany"))
      }
    } else {
      y <- df[[var2]]
      
      if (is.numeric(x) && is.numeric(y)) {
        cat("Correlation between", var1, "and", var2, ":\n")
        print(cor(x, y, use = "complete.obs"))
      } else if (is.numeric(x) && !is.numeric(y)) {
        cat("Grouped summary of", var1, "by", var2, ":\n")
        print(tapply(x, y, summary))
      } else if (!is.numeric(x) && is.numeric(y)) {
        cat("Grouped summary of", var2, "by", var1, ":\n")
        print(tapply(y, x, summary))
      } else {
        cat("Contingency table for", var1, "and", var2, ":\n")
        print(table(x, y, useNA = "ifany"))
      }
    }
  })
}

shinyApp(ui = ui, server = server)