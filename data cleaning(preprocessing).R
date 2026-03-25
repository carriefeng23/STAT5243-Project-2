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
