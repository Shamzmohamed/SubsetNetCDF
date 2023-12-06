library(raster)
library(dplyr)
library(sf)

setwd("/home/mohamed/Documents/I-CISK/")

# ---------- For 19 bands (Used 2 methods to extract the bands)
nc <- brick("download/CSU_C3S-glob-agric_hadgem2-es_rcp8p5_season_20110101-20401231_v1.1.nc")
spain <- st_read("Meteo_data_Spain_Andalucia-main/Andalucia")  # Shapefile
num_bands <- 19                  # No of bands to process
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
# Load clipped vectors in R
clipped_vectors_list <- list()
for (i in 1:num_bands) {
  file_path <- paste0("clip_shp/band_", i, ".rds")
  
  # Check if the file exists before attempting to read it
  if (file.exists(file_path)) {
    clipped_vectors_list[[i]] <- readRDS(file_path)
  } else {
    warning(paste("File not found:", file_path))}
}
