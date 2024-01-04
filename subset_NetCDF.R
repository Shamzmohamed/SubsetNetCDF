library(doParallel)
library(foreach)
library(raster)
library(sf)

setwd("/home/mohamed/Documents/I-CISK/")

# ---------- For 7 bands (Used 2 methods to extract the bands)
nc<- brick ("clipped_buff14.nc") #Subset nc file
spain <- st_read("Meteo_data_Spain_Andalucia-main/Andalucia")  # Shapefile

num_bands <- 79
num_cores <- detectCores()
bands_per_iteration <- 3
num_iterations <- ceiling(num_bands / bands_per_iteration)

clipped_vectors_list <- mclapply(1:num_iterations, function(i) {
  start_band <- (i - 1) * bands_per_iteration + 1
  end_band <- min(i * bands_per_iteration, num_bands)
  
  band_list <- lapply(start_band:end_band, function(j) {
    raster_data <- nc[[j]]
    vector_data <- rasterToPolygons(raster_data, dissolve = TRUE)
    vector_sf <- st_as_sf(vector_data)
    vector_sf <- st_transform(vector_sf, crs = st_crs(spain))
    clip_vect <- st_intersection(vector_sf, spain)
    clip_vect <- clip_vect[, 1, drop = FALSE]
    band_name <- paste0(names(raster_data)[1])
    names(clip_vect) <- colnames(clip_vect)
    names(clip_vect)[1] <- band_name
    
    return(clip_vect)
  })
  return(band_list)
}, mc.cores = num_cores)

all_bands <- do.call(c, clipped_vectors_list)
saveRDS(all_bands, "batch/CSU.rds")
