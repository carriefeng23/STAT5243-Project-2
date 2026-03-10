#load packages for the app
library(shiny) #interactie web app in R
library(tools)
library(readxl) #reads excel files
library(jsonlite) #reads json files

options(shiny.maxRequestSize = 30*1024^2) #increase max upload size to 30 mb

#UI, the basix layout and components
ui <- fluidPage(
  titlePanel("STAT GR5243 Project 2 -- Web App Development"),
  
  #sidebar that has dataset selection buttons
  sidebarLayout(
    sidebarPanel(
      h4("Step 1: Choose a dataset"),
      radioButtons(
        "data_source","Select data source:",
        choices = c("Upload file" = "upload",
                    "Use sample dataset" = "sample"),
        selected = "upload"
      ),
      
      #file upload input
      conditionalPanel(
        condition = "input.data_source == 'upload'",
        fileInput(
          "file","Upload a dataset",
          accept = c(".csv", ".xlsx", ".xls", ".rds",".json") #acceptable file formats
        )
      ),
      
      #dropdown menu for the built in datasets, using iris and mtcars datasets
      conditionalPanel(
        condition = "input.data_source == 'sample'",
        selectInput("sample_data", "Choose a built-in dataset:", choices = c("iris", "mtcars"))
      )
    ),
    
    #main area that displays info about dataset and the preview
    mainPanel(
      p("Upload your own dataset or choose a built-in example to preview and inspect its structure."),
      
      h3("Dataset Information"),
      verbatimTextOutput("data_info"),
      
      br(),
      h3("Data Preview"),
      tableOutput("preview")
    )
  )
)

server <- function(input, output, session) {
  
  data_raw <- reactive({
    if (input$data_source == "sample") {
      if (input$sample_data == "iris") return(as.data.frame(iris))
      if (input$sample_data == "mtcars") return(as.data.frame(mtcars))
    }
    
    req(input$file) #make sure the file is uploaded before continuing
    
    #get the file name and path
    file_name <- as.character(input$file$name[[1]])
    file_path <- as.character(input$file$datapath[[1]])
    ext <- tolower(file_ext(file_name))
    
    #read dataset based on file format
    if (ext == "csv") {
      df <- read.csv(file_path, stringsAsFactors = FALSE, check.names = FALSE)
    } else if (ext %in% c("xlsx", "xls")) {
      df <- as.data.frame(read_excel(file_path))
    } else if (ext == "rds") {
      df <- as.data.frame(readRDS(file_path))
    } else if (ext == "json") {
      df <- as.data.frame(jsonlite::fromJSON(file_path))
    } else {
      stop(paste("Unsupported file type. Supported types:", paste(supported_types, collapse = ", "))) #error message for unsupported file types
    }
    
    as.data.frame(df) #make sure to returna data frame
  })
  
  #output
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
}
#shiny app
shinyApp(ui = ui, server = server)