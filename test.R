library(colorspace)
library(leaflet)
library(ggplot2)
library(raster)
library(dplyr)
library(shiny)
library(sf)

setwd("/home/mohamed/Documents/I-CISK/")

# ---------- For 7 bands (Used 2 methods to extract the bands)
nc <- brick("download/CSU_C3S-glob-agric_hadgem2-es_rcp8p5_season_20110101-20401231_v1.1.nc")
spain <- st_read("Meteo_data_Spain_Andalucia-main/Andalucia")  # Shapefile
num_bands <- 7                  # No of bands to process
clipped_vectors_list <- list()  # List to store clipped vectors
warnings(FALSE)
# ---------- Method 1: Using for loop to extract bands
# Takes a lot time to extract (~9 mins for 19 bands)
# Loop through bands
for (i in 1:num_bands) {
  raster_data <- nc[[i]]                                        # Extract raster data for current band
  vector_data <- rasterToPolygons(raster_data, dissolve = TRUE)   # Convert raster to vector
  vector_sf <- st_as_sf(vector_data)                              # Convert vector to sf
  vector_sf <- st_transform(vector_sf, crs = st_crs(spain))       # transform CRS
  clip_vect <- st_intersection(vector_sf, spain)                  # intersection to clip vector_sf
  names(clip_vect) <- colnames(clip_vect)
  clipped_vectors_list[[i]] <- clip_vect                          # Add to list
}

# ----------- Method 2: Using Parallel Processing and saving it into .rds [r data serialized] file in local
# Takes a minimal time (~2.5 mins for 19 bands)
num_bands<-19
num_cores <- detectCores()
cl <- makeCluster(num_cores)
registerDoParallel(cl)

clipped_vectors_list <- foreach(i = 1:num_bands, .packages = c("raster", "sf")) %dopar% {
  raster_data <- nc[[i]]
  vector_data <- rasterToPolygons(raster_data, dissolve = TRUE)
  vector_sf <- st_as_sf(vector_data)
  vector_sf <- st_transform(vector_sf, crs = st_crs(spain))
  clip_vect <- st_intersection(vector_sf, spain)
  names(clip_vect) <- colnames(clip_vect)
  return(clip_vect)
}
stopCluster(cl)    # Stop parallel processing

# Save clipped vectors locally
for (i in 1:num_bands) {
  saveRDS(clipped_vectors_list[[i]], paste0("clip_shp/band_", i, ".rds"))}

num_bands<- 79
# Load clipped vectors
clipped_vectors_list <- list()
for (i in 1:num_bands) {
  file_path <- paste0("clip_shp/band_", i, ".rds")
  
  # Check if the file exists before attempting to read it
  if (file.exists(file_path)) {
    clipped_vectors_list[[i]] <- readRDS(file_path)
  } else {
    warning(paste("File not found:", file_path))
  }
}

################################## Stats ################
num_bands=79
############# Stats
num_bands <- 79
summary_list <- vector("list", length = num_bands)

# Loop through bands
for (i in 1:num_bands) {
  clip_vect <- clipped_vectors_list[[i]]
  year_month <- names(clip_vect)[1]
  
  # Calculate summary statistics
  summary_stats <- c(Band = i,
    YearMonth = year_month,
    Mean = round(mean(clip_vect[[year_month]], na.rm = TRUE)),
    Min = min(clip_vect[[year_month]], na.rm = TRUE),
    Max = max(clip_vect[[year_month]], na.rm = TRUE),
    Q1 = quantile(clip_vect[[year_month]], 0.25, na.rm = TRUE),
    Median = median(clip_vect[[year_month]], na.rm = TRUE),
    Q3 = quantile(clip_vect[[year_month]], 0.75, na.rm = TRUE))
  
  summary_list[[i]] <- summary_stats
}

# Create the data frame from the list of summary statistics
summary_data <- as.data.frame(do.call(rbind, summary_list))
summary_data$Month <- factor(month.abb[as.numeric(substr(summary_data$YearMonth, 7, 8))],
                             levels = month.abb, ordered = TRUE)

# Save the summary data as a CSV file
write.csv(summary_data, file = "band_summary_statistics.csv", row.names = FALSE)

# Filter data for the year 2020
data_2020 <- subset(summary_data, grepl("2011", YearMonth))
ggplot(data_2020, aes(x = Month, y = Mean, group = 1)) +
  geom_line() + geom_point() +
  labs(title = "Mean Values Over Months for the Year 2020", x = "Month", y = "Mean Value") +
  theme_minimal()

###### R shiny for mean graph plot
ui <- fluidPage(
  sliderInput("year", "Select Year", min = 2011, max = 2030, step = 1, value = 2020, sep=''),
  plotOutput("linePlot")
)

server <- function(input, output) {
  output$linePlot <- renderPlot({
    data_selected_year <- subset(summary_data, grepl(input$year, YearMonth))
    
    ggplot(data_selected_year, aes(x = Month, y = Mean, group = 1)) +
      geom_line() + geom_point() +
      labs(title = paste("Mean Values Over Months for the Year", input$year),
           x = "Month", y = "Mean Value") +
      theme_minimal()
  })
}

shinyApp(ui, server)


###########
summary_data <- summary_data %>%
  mutate(Month = factor(
      month.abb[as.numeric(substr(YearMonth, 7, 8))],
      levels = month.abb, ordered = TRUE),
    Mean = as.numeric(Mean)  # Ensure Mean is treated as numeric
  )

ui <- fluidPage(
  sliderInput("year", "Select Year", min = 2011, max = 2030, step = 1, value = 2020),
  plotlyOutput("linePlot"))


library(plotly)
server <- function(input, output) {
  output$linePlot <- renderPlotly({
    data_selected_year <- subset(summary_data, grepl(input$year, YearMonth))
    
    plot_ly(
      data_selected_year,
      x = ~Month,
      y = ~Mean,
      type = 'scatter',
      mode = 'lines+markers',
      name = 'Mean Values'
    ) %>%
      layout(
        title = paste("Mean Values Over Months for the Year", input$year),
        xaxis = list(title = 'Month'),
        yaxis = list(title = 'Mean Value'),
        showlegend = TRUE
      )
  })
}
shinyApp(ui, server)
