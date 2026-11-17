# ==============================================================================
# Daily Spain-wide mean FWI for June-September (area-weighted)
# ==============================================================================
#
# WHAT THIS SCRIPT DOES
#   1. Reads a DAILY gridded FWI NetCDF.
#   2. Keeps only the days from June to September.
#   3. Computes the area-weighted Spain-wide mean FWI for each day.
#   4. Saves the result as a CSV with two columns: date, fwi.
#
# This is the slow step of the analysis, so it is run once and the CSV is
# reused afterwards.
# ==============================================================================

# ------------------------------------------------------------------------------
# 0) Libraries, paths and parameters
# ------------------------------------------------------------------------------
library(terra)      # read the NetCDF raster (daily FWI)
library(dplyr)      # data manipulation
library(tibble)     # tibbles
library(lubridate)  # dates
library(readr)      # CSV writing

# Input FWI file and output CSV (edit both)
path_fwi_daily   <- ""
path_daily_output <- ""

# Months to keep (June to September)
daily_months <- 6:9

# ------------------------------------------------------------------------------
# 1) Read the raster and keep only the June-September days
# ------------------------------------------------------------------------------
fwi_raster <- rast(path_fwi_daily)

layer_dates <- as.Date(time(fwi_raster))
keep        <- month(layer_dates) %in% daily_months
fwi_raster  <- fwi_raster[[which(keep)]]
layer_dates <- layer_dates[keep]

# ------------------------------------------------------------------------------
# 2) Area-weighted Spain-wide mean for each day
# ------------------------------------------------------------------------------
# Area of each grid cell (km2): cells of a lat/lon grid are smaller toward the
# pole, so each cell is weighted by its real area when averaging.
cell_area <- cellSize(fwi_raster[[1]], unit = "km")

# Cells without data (sea, outside the domain) are ignored (na.rm = TRUE).
# This can take a while for a long daily record at high resolution.
message("Computing daily Spain-wide FWI (", nlyr(fwi_raster), " days)...")
fwi_daily <- tibble(
  date = layer_dates,
  fwi  = global(fwi_raster, "mean", weights = cell_area, na.rm = TRUE)$weighted_mean
)

# ------------------------------------------------------------------------------
# 3) Save
# ------------------------------------------------------------------------------
dir.create(dirname(path_daily_output), showWarnings = FALSE, recursive = TRUE)
write_csv(fwi_daily, path_daily_output)
message("Saved: ", path_daily_output)
