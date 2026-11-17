# ==============================================================================
# Lagged correlation between the Spain-wide monthly FWI and large-scale
# climate indices (lags of 0 to 6 months)
# ==============================================================================
#
# WHAT THIS SCRIPT DOES
#   1. Builds one monthly time series of the Fire Weather Index (FWI) for Spain
#      (area-weighted spatial mean of the gridded FWI file).
#   2. Reads the climate indices (NAO, AMO, ENSO indices, etc.) from CSV files
#      and puts them in one common "long" table: date, index, value.
#   3. Removes the seasonal cycle (standardized monthly anomalies) and,
#      optionally, the linear trend, so that only interannual variability is
#      correlated.
#   4. Pairs each index value at month t with the FWI at month t + lag
#      (lag = 0, 1, ..., 6). The index always LEADS the FWI.
#   5. Computes correlations:
#        A) all calendar months pooled together, for each index and lag
#        B) separately for each target month of the FWI, for each index and lag
#   6. Saves the results as CSV files and as heatmaps.
#
# LAG CONVENTION
#   lag = 2 and target month = July means: index of May vs FWI of July.
# ==============================================================================

# ------------------------------------------------------------------------------
# 0) Libraries, paths and parameters
# ------------------------------------------------------------------------------
library(terra)      # read the NetCDF raster (FWI)
library(dplyr)      # data manipulation
library(tidyr)      # reshaping (pivot_longer, crossing)
library(tibble)     # tibbles
library(lubridate)  # dates (floor_date, month, %m+%)
library(readr)      # fast CSV reading / writing
library(purrr)      # map_dfr
library(ggplot2)    # plots

# Input / output paths
path_fwi <- ""
path_CliIdx <- ""
path_corr <- ""
out_dir  <- file.path(dirname(path_corr), "Correlations")
dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)

# Analysis parameters
max_lag       <- 6           # maximum lag in months
detrend       <- TRUE        # remove the linear trend (avoids spurious
# correlations caused by shared warming trends)
min_pairs     <- 20          # minimum number of valid pairs to compute a correlation
wemoi_obs_only <- TRUE       # TRUE: WeMOi only with observed data (up to 2020);
# FALSE: also includes the machine-learning extension
cor_method    <- "spearman"  # "pearson" or "spearman"

# ------------------------------------------------------------------------------
# 1) FWI: monthly Spain-wide mean series
# ------------------------------------------------------------------------------

fwi_daily <- read_csv(path_fwi, show_col_types = FALSE) %>%
  mutate(date = as.Date(date))

# ------------------------------------------------------------------------------
# 2) Climate indices -> one long data frame with columns: date, index, value
# ------------------------------------------------------------------------------

# Helper: read a CSV from path_CliIdx
read_index_csv <- function(file_name) {
  read_csv(file.path(path_CliIdx, file_name), show_col_types = FALSE)
}

# Helper: for CSVs with columns (year, month, <value column>), return a
# standardized table with columns year, month, index, value
read_monthly_index <- function(file_name, value_col, index_name) {
  read_index_csv(file_name) %>%
    transmute(year, month, index = index_name, value = .data[[value_col]])
}

# --- SST indices (Nino regions): anomaly columns only -------------------------
# After read.table() + write.csv() the repeated "ANOM" columns are renamed:
#   NINO1.2, ANOM, NINO3, ANOM.1, NINO4, ANOM.2, NINO3.4, ANOM.3
sst_raw <- read_index_csv("sst_NOAA_1982_2026.csv")
print(names(sst_raw))   # check that the column names are the expected ones

sst_indices <- sst_raw %>%
  transmute(year, month,
            `NINO1+2_anom` = ANOM,
            NINO3_anom     = ANOM.1,
            NINO4_anom     = ANOM.2,
            `NINO3.4_anom` = ANOM.3) %>%
  pivot_longer(-c(year, month), names_to = "index", values_to = "value")

# --- RONI (seasonal, 3-month running mean) ------------------------------------
# Each season is assigned to its central month (DJF -> 1, JFM -> 2, ..., NDJ -> 12)
season_to_month <- c(DJF = 1, JFM = 2, FMA = 3, MAM = 4, AMJ = 5, MJJ = 6,
                     JJA = 7, JAS = 8, ASO = 9, SON = 10, OND = 11, NDJ = 12)

roni <- read_index_csv("RONI_NOAA_1950_2026.csv") %>%
  transmute(year,
            month = unname(season_to_month[season]),
            index = "RONI",
            value = roni)

# --- MEI.v2 (bimonthly) --------------------------------------------------------
# Same convention as the plotting script (DJ -> 1, JF -> 2, ..., ND -> 12)
bimonth_to_month <- c(DJ = 1, JF = 2, FM = 3, MA = 4, AM = 5, MJ = 6,
                      JJ = 7, JA = 8, AS = 9, SO = 10, ON = 11, ND = 12)

mei <- read_index_csv("MEI_NOAA_1950_2026.csv") %>%
  transmute(year,
            month = unname(bimonth_to_month[months]),
            index = "MEI",
            value = mei)

# --- WeMOi (Western Mediterranean Oscillation index) ---------------------------
# The file has metadata lines starting with "#" and a 'date' column instead of
# separate year / month columns.
wemoi <- read_csv(file.path(path_CliIdx, "wemoi_1821_2026.csv"),
                  comment = "#", show_col_types = FALSE)
names(wemoi) <- tolower(trimws(names(wemoi)))

wemoi <- wemoi %>%
  mutate(date  = as.Date(date),
         year  = as.integer(format(date, "%Y")),
         month = as.integer(format(date, "%m")))

# Keep only observed values if requested (extended values are model estimates)
if (wemoi_obs_only) wemoi <- filter(wemoi, source == "observed")

wemoi <- wemoi %>%
  transmute(year, month, index = "WeMOi", value = wemoi)

# --- Combine all indices -------------------------------------------------------
indices_raw <- bind_rows(
  read_monthly_index("aao_NOAA_1979_2026.csv",   "aao",    "AAO"),
  read_monthly_index("nao_NOAA_1950_2026.csv",   "nao",    "NAO"),
  read_monthly_index("ea_NOAA_1950_2026.csv",    "ea",     "EA"),
  read_monthly_index("scand_NOAA_1850_2026.csv", "scand",  "SCAND"),
  read_monthly_index("amo_NOAA_1856_2022.csv",   "amo",    "AMO"),
  read_monthly_index("soi_NOAA_1951_2026.csv",   "soi_st", "SOI"),   # standardized SOI only
  read_monthly_index("olr_NOAA_1974_2026.csv",   "olr_st", "OLR"),   # standardized OLR only
  sst_indices, roni, mei, wemoi
) %>%
  mutate(value = ifelse(value < -900, NA, value),   # missing codes (-999.9, -9999) -> NA
         date  = make_date(year, month, 1)) %>%
  select(date, index, value)

# ------------------------------------------------------------------------------
# 3) Standardized anomalies by calendar month (+ optional detrending)
# ------------------------------------------------------------------------------

# Standardized anomaly by calendar month:
# for each month (all Januaries, all Februaries, ...) subtract that month's mean
# and divide by its standard deviation. This removes the seasonal cycle.
remove_seasonality <- function(df, col) {
  df %>%
    mutate(cal_month = month(date)) %>%
    group_by(cal_month) %>%
    mutate("{col}" := (.data[[col]] - mean(.data[[col]], na.rm = TRUE)) /
             sd(.data[[col]], na.rm = TRUE)) %>%
    ungroup() %>%
    select(-cal_month)
}

# Linear detrending: fit x ~ time and keep the residuals.
# Series with fewer than 10 valid values are returned unchanged.
remove_trend <- function(x, time_numeric) {
  valid <- !is.na(x)
  if (sum(valid) < 10) return(x)
  x[valid] <- resid(lm(x[valid] ~ time_numeric[valid]))
  x
}

# FWI anomalies
fwi_anom <- remove_seasonality(fwi, "fwi")
if (detrend) fwi_anom$fwi <- remove_trend(fwi_anom$fwi, as.numeric(fwi_anom$date))

# Index anomalies (each index is processed separately)
indices_anom <- indices_raw %>%
  group_by(index) %>%
  group_split() %>%
  map_dfr(function(d) {
    d <- remove_seasonality(d, "value")
    if (detrend) d$value <- remove_trend(d$value, as.numeric(d$date))
    d
  })

# ------------------------------------------------------------------------------
# 4) Lagged pairs: index(t) vs FWI(t + lag)
# ------------------------------------------------------------------------------
# Each row of 'paired' is one (index, FWI) pair:
#   date        : month of the index
#   value       : index anomaly at 'date'
#   lag         : months by which the index leads the FWI
#   date_fwi    : month of the FWI = date + lag
#   fwi         : FWI anomaly at 'date_fwi'
#   target_month: calendar month (1-12) of the FWI
paired <- indices_anom %>%
  crossing(lag = 0:max_lag) %>%                      # repeat every row for each lag
  mutate(date_fwi = date %m+% months(lag)) %>%       # shift the date forward
  inner_join(fwi_anom, by = c("date_fwi" = "date")) %>%
  mutate(target_month = month(date_fwi))

# ------------------------------------------------------------------------------
# 5) Correlations
# ------------------------------------------------------------------------------

# Correlation between two vectors using only complete pairs.
# Returns r (correlation), p (p-value) and n (number of pairs used).
correlate_pairs <- function(x, y) {
  complete <- complete.cases(x, y)
  n <- sum(complete)
  if (n < min_pairs) return(tibble(r = NA_real_, p = NA_real_, n = n))
  test <- suppressWarnings(
    cor.test(x[complete], y[complete], method = cor_method, exact = FALSE)
  )
  tibble(r = unname(test$estimate), p = test$p.value, n = n)
}

# A) All calendar months pooled: one correlation per index and lag.
#    Question: "Is there a general relationship, regardless of the season?"
cor_all_months <- paired %>%
  group_by(index, lag) %>%
  reframe(correlate_pairs(value, fwi)) %>%
  mutate(p_fdr = p.adjust(p, "BH"))   # multiple-testing correction (Benjamini-Hochberg)

# B) By target month of the FWI: one correlation per index, lag and month.
#    Question: "Is the index L months earlier related to the FWI of a given month?"
#    The relationship is often seasonal and can have opposite signs in different
#    months, which would cancel out in (A).
cor_by_month <- paired %>%
  group_by(index, lag, target_month) %>%
  reframe(correlate_pairs(value, fwi)) %>%
  mutate(p_fdr = p.adjust(p, "BH"),
         signif_label = case_when(p_fdr < 0.05 ~ "**",   # significant after FDR correction
                                  p     < 0.05 ~ "*",    # significant before correction
                                  TRUE          ~ ""))

# Save results
write_csv(cor_all_months, file.path(out_dir, "cor_FWI_indices_all_months.csv"))
write_csv(cor_by_month,   file.path(out_dir, "cor_FWI_indices_by_target_month.csv"))

# Strongest correlation (largest |r|) for each index and target month
best_lags <- cor_by_month %>%
  filter(!is.na(r)) %>%
  group_by(index, target_month) %>%
  slice_max(abs(r), n = 1) %>%
  ungroup() %>%
  arrange(desc(abs(r)))
print(head(best_lags, 20))

# ------------------------------------------------------------------------------
# 6) Plots
# ------------------------------------------------------------------------------

# A) Heatmap: index x lag (all months pooled). The number in each tile is r.
plot_all_months <- ggplot(cor_all_months, aes(factor(lag), index, fill = r)) +
  geom_tile(colour = "white") +
  geom_text(aes(label = sprintf("%.2f", r)), size = 3) +
  scale_fill_gradient2(low = "blue", mid = "white", high = "red",
                       limits = c(-0.5, 0.5), oob = scales::squish,
                       name = "r") +
  labs(title    = "Spain-wide FWI vs climate indices: all months pooled",
       subtitle = paste0(tools::toTitleCase(cor_method),
                         " correlation of anomalies",
                         if (detrend) " (detrended)" else ""),
       x = "Lag (months; index leads FWI)", y = NULL) +
  theme_bw()

plot_all_months

ggsave(file.path(out_dir, "heatmap_all_months.png"),
       plot_all_months, width = 8, height = 7, dpi = 150)

# B) Heatmap: one panel per index; y axis = FWI target month, x axis = lag.
plot_by_month <- ggplot(cor_by_month,
                        aes(factor(lag), factor(target_month, levels = 1:12, labels = month.abb),
                            fill = r)) +
  geom_tile(colour = "white") +
  geom_text(aes(label = signif_label), size = 4) +
  facet_wrap(~ index, ncol = 4) +
  scale_fill_gradient2(low = "blue", mid = "white", high = "red",
                       limits = c(-0.6, 0.6), oob = scales::squish,
                       name = "r") +
  labs(title    = "FWI by target month vs climate indices (lags 0-6 months)",
       subtitle = "* p < 0.05 uncorrected; ** p < 0.05 after FDR (Benjamini-Hochberg) correction",
       x = "Lag (months; index leads FWI)", y = "FWI target month") +
  theme_bw()

plot_by_month

ggsave(file.path(out_dir, "heatmap_by_target_month.png"),
       plot_by_month, width = 14, height = 10, dpi = 150)
