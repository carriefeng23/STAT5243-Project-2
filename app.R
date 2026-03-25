library(shiny) # interactive web app in R
library(tools)
library(readxl) # reads excel files
library(jsonlite) # reads json files

options(shiny.maxRequestSize = 30 * 1024^2) # increase max upload size to 30 mb

# UI, the basic layout and components
ui <- fluidPage(
  titlePanel("STAT GR5243 Project 2 -- Web App Development"),
  
  # sidebar that has dataset selection buttons and feature engineering controls
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
      h4("Step 2: Feature Engineering"),
      
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
      
      # button to apply the selected feature engineering method
      actionButton("apply_fe", "Apply Feature Engineering"),
      br(), br(),
      
      # buttons to download outputs
      downloadButton("download_data", "Download Engineered Dataset"),
      br(), br(),
      downloadButton("download_log", "Download Feature Log")
    ),
    
    # main area that displays dataset info, preview, and feature engineering results
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
  
  # reset the working dataset and log whenever the source dataset changes
  observe({
    df <- data_raw()
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
}

# shiny app
shinyApp(ui = ui, server = server)
