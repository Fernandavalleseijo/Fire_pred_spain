# =============================================================================
# EXPLORATION OF MONTHLY FWI (IBERIA, 1961-2025)
# File: fwi_month_Iberia.nc  (CSIC, 0.025 deg, 780 months)
# Workflow: 1) inspect the NetCDF  2) load with terra  3) summaries  4) ggplots
# =============================================================================
# NOTE ON UNITS: the "units: celsius" attribute in the file is a metadata error.
# The FWI is DIMENSIONLESS (Van Wagner, 1987): do not put degrees C on the axes.
# =============================================================================


# -----------------------------------------------------------------------------
# 0. LIBRARIES AND PATH
# -----------------------------------------------------------------------------
library(ncdf4)      # low-level NetCDF reading (metadata inspection)
library(terra)      # raster handling: summaries, extraction, maps
library(tidyverse)  # dplyr + tidyr + ggplot2 (includes tibble, pipes, etc.)

path <- ""
f_nc <- file.path(path, "fwi_month_Iberia.nc")


# -----------------------------------------------------------------------------
# 1. FILE INSPECTION WITH ncdf4
# -----------------------------------------------------------------------------
nc <- nc_open(f_nc)

print(nc)            # summary: dimensions (lon 545, lat 342, time 780),
# variables (crs, fwi) and global attributes
names(nc$var)        # variables: "crs" "fwi"
names(nc$dim)        # dimensions: "longitude" "latitude" "time"

# ---- Load the full array (OPTIONAL, heavy) ----------------------------------
# 545 x 342 x 780 = ~145 million values (~1.2 GB as double in R).
# Not needed for exploration: terra (section 2) is much lighter.
# Left commented out; uncomment if you want to work with the raw array.
# fwi_array <- ncvar_get(nc, "fwi")
# dim(fwi_array)                 # 545 342 780  (lon, lat, time)
# fwi_array[, , 1]               # careful: prints a huge matrix (max.print)

# Date vector (days since 1970-01-01). Useful to locate a specific month.
dates <- as.Date(ncvar_get(nc, "time"), origin = "1970-01-01")
# idx <- which(dates == as.Date("2022-08-01"))   # index of August 2022
# fwi_array[, , idx]                              # August 2022 layer (array)

nc_close(nc)   # close the file connection once it is no longer needed


# -----------------------------------------------------------------------------
# 2. LOAD WITH terra (SpatRaster with 780 layers, one per month)
# -----------------------------------------------------------------------------
r <- rast(f_nc, subds = "fwi")   # subds = subdataset: only the fwi variable

nlyr(r)        # 780 layers
time(r)        # date of each layer (1961-01-01 ... 2025-12-01)
r              # summary: 342 rows x 545 cols, res 0.025 deg, EPSG:4326

r[[1]]         # raster for January 1961 (first layer)

# Quick map of a specific month (August 2022) with terra's plot()
plot(r[[time(r) == as.Date("2022-08-01")]])

# Subset: all August layers (65 years -> 65 layers)
augusts <- r[[format(time(r), "%m") == "08"]]

# Time series of the spatial mean (one value per month for all of Iberia)
# Note: global() averages all valid pixels in each layer.
fwi_series <- global(r, "mean", na.rm = TRUE)[, 1]
plot(time(r), fwi_series, type = "l")   # quick look in base R

# Value at a point (e.g. Madrid: lon -3.7, lat 40.4) -> series of 780 values
# as.numeric() avoids printing a giant row of fwi_1 ... fwi_780 columns
fwi_madrid <- as.numeric(extract(r, cbind(-3.7, 40.4)))
# plot(time(r), fwi_madrid, type = "l")


# -----------------------------------------------------------------------------
# 3. PREPARATION: monthly table of the spatial mean (light, for ggplot)
# -----------------------------------------------------------------------------
# Important: do NOT convert the full cube to a data.frame (145 M rows).
# Always summarise with terra and plot only the summaries.

month_labels <- c("Jan","Feb","Mar","Apr","May","Jun",
                  "Jul","Aug","Sep","Oct","Nov","Dec")

df <- tibble(
  date = time(r),
  fwi  = fwi_series                     # spatial mean already computed above
) |>
  mutate(
    year  = as.integer(format(date, "%Y")),
    # month as an ordered factor with English labels (for axes/boxplots)
    month = factor(as.integer(format(date, "%m")), levels = 1:12,
                   labels = month_labels)
  )


# -----------------------------------------------------------------------------
# 4. PLOT 1: time series + 12-month moving average
#    What it shows: interannual variability and the underlying trend.
# -----------------------------------------------------------------------------
df |>
  # centred 12-month moving average (removes the seasonal cycle)
  # as.numeric() converts the ts object returned by filter() to a plain vector
  mutate(ma12 = as.numeric(stats::filter(fwi, rep(1/12, 12), sides = 2))) |>
  ggplot(aes(date, fwi)) +
  geom_line(color = "grey70", linewidth = .3) +                  # monthly series
  geom_line(aes(y = ma12), color = "firebrick", linewidth = .8,  # moving average
            na.rm = TRUE) +                                      # NA at the edges
  labs(x = NULL, y = "Mean FWI (Iberia)",
       title = "Monthly mean FWI and 12-month moving average") +
  theme_minimal()


# -----------------------------------------------------------------------------
# 5. PLOT 2: seasonal cycle (distribution by month)
#    What it shows: which months have high FWI and how much spread there is
#    between years.
# -----------------------------------------------------------------------------
ggplot(df, aes(month, fwi)) +
  geom_boxplot(fill = "orange", alpha = .6, outlier.size = .8) +
  labs(x = NULL, y = "Mean FWI",
       title = "Seasonal cycle of FWI (1961-2025)") +
  theme_minimal()


# -----------------------------------------------------------------------------
# 6. PLOT 3: year x month heatmap
#    What it shows: extreme years/months and gradual changes at a glance.
# -----------------------------------------------------------------------------
ggplot(df, aes(month, year, fill = fwi)) +
  geom_tile() +
  scale_fill_viridis_c(option = "inferno", direction = -1) +  # dark = high FWI
  scale_y_reverse(breaks = seq(1961, 2025, 8)) +              # 1961 at the top
  labs(x = NULL, y = NULL, fill = "FWI",
       title = "Mean FWI by year and month") +
  theme_minimal()


# -----------------------------------------------------------------------------
# 7. PLOT 4: fire-season trend (JJA)
#    What it shows: evolution of summer FWI, with linear fit and smoother.
#    For JJAS: add "Sep" to the vector of months.
# -----------------------------------------------------------------------------
jja <- df |>
  filter(month %in% c("Jun", "Jul", "Aug")) |>
  group_by(year) |>
  summarise(fwi = mean(fwi), .groups = "drop")   # one value per year

ggplot(jja, aes(year, fwi)) +
  geom_point() +
  geom_line(color = "grey60") +
  geom_smooth(method = "lm", color = "firebrick", fill = "firebrick",
              alpha = .15) +                                       # linear trend
  geom_smooth(method = "loess", se = FALSE, color = "steelblue",
              linetype = 2) +                                      # non-linear trend
  labs(x = NULL, y = "Mean FWI JJA",
       title = "Summer (JJA) FWI trend") +
  theme_minimal()

# Significance: non-parametric test (assumes neither normality nor linearity)
install.packages("trend")   # if not installed
trend::mk.test(jja$fwi)       # Mann-Kendall: is there a monotonic trend?
trend::sens.slope(jja$fwi)    # Sen's slope (FWI units per year)


# -----------------------------------------------------------------------------
# 8. PLOT 5: distribution of values (August, pixel level)
#    FWI is highly skewed (many values near 0), so we look at the full
#    distribution and not just the mean. Pixels are sampled to avoid
#    loading everything into memory.
# -----------------------------------------------------------------------------
set.seed(1)   # reproducible sampling

years_r <- as.integer(format(time(r), "%Y"))
month_r <- format(time(r), "%m")

# Function: sample n cells from the Augusts of a period [start_year, end_year]
# and return all their values (cells x years) in a tibble.
dist_period <- function(start_year, end_year, n = 5000) {
  i <- which(month_r == "08" & years_r %in% start_year:end_year)  # August layers
  m <- spatSample(r[[i]], size = n, method = "random",
                  values = TRUE, as.df = FALSE)       # matrix: n x number of years
  tibble(period = paste(start_year, end_year, sep = "–"),
         fwi    = as.vector(na.omit(m)))              # drop NA cells (sea)
}

# Two periods to compare: "classic" climatology vs. recent
dist_df <- bind_rows(dist_period(1961, 1990),
                     dist_period(1991, 2025))

# 8a. Overlaid densities
ggplot(dist_df, aes(fwi, fill = period)) +
  geom_density(alpha = .5) +
  labs(x = "FWI (August, pixels)", y = "Density",
       title = "Distribution of August FWI by period") +
  theme_minimal()

# 8b. ECDF: easier to read for comparing tails (extreme values)
ggplot(dist_df, aes(fwi, color = period)) +
  stat_ecdf(linewidth = .8) +
  labs(x = "FWI (August, pixels)", y = "Cumulative probability",
       title = "ECDF of August FWI by period") +
  theme_minimal()


# -----------------------------------------------------------------------------
# 9. SPATIAL MAPS
# -----------------------------------------------------------------------------
# Helper: 1-layer SpatRaster -> data.frame -> ggplot (geom_raster)

plot_map <- function(x, map_title) {
  as.data.frame(x, xy = TRUE, na.rm = TRUE) |>   # columns: x, y, value
    setNames(c("x", "y", "v")) |>
    ggplot(aes(x, y, fill = v)) +
    geom_raster() +
    coord_quickmap() +                           # roughly correct lon/lat aspect ratio
    labs(title = map_title, x = NULL, y = NULL, fill = "FWI") +
    theme_minimal()
}

# 9a. August climatology (mean of the 65 Augusts, pixel by pixel)
aug_stack <- r[[month_r == "08"]]
clim_aug  <- mean(aug_stack, na.rm = TRUE)

plot_map(clim_aug, "Mean August FWI (1961–2025)") +
  scale_fill_viridis_c(option = "inferno", direction = -1)

# 9b. August 2022 anomaly relative to climatology (red = more dangerous)
anom_2022 <- r[[time(r) == as.Date("2022-08-01")]] - clim_aug

plot_map(anom_2022, "FWI anomaly, August 2022") +
  scale_fill_gradient2(low = "navy", mid = "white", high = "firebrick",
                       midpoint = 0)   # white = no anomaly


# -----------------------------------------------------------------------------
# 10. PER-PIXEL TREND MAP (JJA, units per decade)
# -----------------------------------------------------------------------------
# Step 1: keep only the Jun-Jul-Aug layers
jja_r   <- r[[as.integer(format(time(r), "%m")) %in% 6:8]]
jja_yrs <- as.integer(format(time(jja_r), "%Y"))

# Step 2: JJA mean per year (1 layer per year -> 65 layers)
jja_annual <- tapp(jja_r, index = jja_yrs, fun = "mean", na.rm = TRUE)

# Step 3: pixel-wise linear regression against year
# regress() returns 2 layers: [[1]] intercept, [[2]] slope -> we use the slope
# x10 to express it in FWI units per decade
trend_map <- regress(jja_annual, as.numeric(unique(jja_yrs)), na.rm = TRUE)[[2]] * 10

plot_map(trend_map, "JJA FWI trend (units/decade)") +
  scale_fill_gradient2(low = "navy", mid = "white", high = "firebrick",
                       midpoint = 0)

# NOTE: this slope is only descriptive (it says nothing about significance per pixel).
# For spatial significance, apply Mann-Kendall per pixel (terra::app() with a
# function using trend::mk.test) and correct for multiple comparisons (e.g. FDR).

