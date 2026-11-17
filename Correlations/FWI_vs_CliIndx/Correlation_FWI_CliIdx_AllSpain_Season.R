# ==============================================================================
# Fire-season FWI vs large-scale climate indices: several seasons and statistics
# ==============================================================================
#
# WHAT THIS SCRIPT DOES
#   1. Computes the Spain-wide DAILY FWI series ONCE (the slow step) and saves
#      it to a CSV cache. Later runs read the cache and skip the slow step.
#   2. Prepares the monthly climate indices ONCE (anomalies, detrending).
#   3. Runs the same analysis for every combination of
#         season (e.g. June-Sep, July-Aug)  x  statistic (mean, max, p90)
#      For each combination it:
#        - summarises the daily FWI of the season into one value per year
#        - builds predictors from the months BEFORE the season starts
#          (single months and multi-month windows)
#        - correlates predictors with the seasonal FWI across years
#        - saves tables and heatmaps
#   4. Saves one combined table with all results.
#
# LAG CONVENTION
#   Lags are counted from the START of each season (day 1 of its first month).
#   lag 1 = the month before the season starts, ..., lag 6 = six months before.
#   Lag 0 is not used (it would be inside the season, so not a predictor).
#     June-Sep season : lag 1 = May,  ..., lag 6 = December (previous year)
#     July-Aug season : lag 1 = June, ..., lag 6 = January
#
# NOTE ON "max" AND "p90"
#   They are computed on the Spain-wide DAILY MEAN FWI (one number per day), not
#   on individual grid cells. So "max" = the day with the highest Spain-wide
#   mean FWI of the season.
#
# SAMPLE SIZE WARNING
#   One value per year -> n is about 40-65. Only |r| > ~0.3 can be significant,
#   and running many configurations multiplies the chances of false positives.
#   Do not pick the configuration with the best-looking result without
#   accounting for this.
# ==============================================================================

# ------------------------------------------------------------------------------
# 0) Libraries, paths and parameters
# ------------------------------------------------------------------------------
library(terra)      # read the NetCDF raster (daily FWI)
library(dplyr)      # data manipulation
library(tidyr)      # reshaping (pivot_longer, crossing, expand_grid)
library(tibble)     # tibbles
library(lubridate)  # dates
library(readr)      # fast CSV reading / writing
library(purrr)      # map_dfr / imap_dfr / pmap
library(ggplot2)    # plots

# Input / output paths (edit)
path_fwi <- ""
path_CliIdx       <- ""
out_dir        <- file.path(dirname(path_CliIdx), "Correlations_Seasonal")
dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)

# --- Configurations to run -----------------------------------------------------
season_options <- list(6:9, 7:8)               # June-Sep and July-Aug
stat_options   <- c("mean", "max", "p90")      # daily FWI -> one value per season

# --- Analysis parameters ---------------------------------------------------------
min_coverage   <- 0.9          # minimum fraction of season days with data per year
max_lag        <- 6            # maximum lag in months before the season starts
detrend        <- TRUE         # remove the linear trend from all series
min_pairs      <- 20           # minimum number of years to compute a correlation
wemoi_obs_only <- TRUE         # TRUE: WeMOi only with observed data (up to 2020)
cor_method     <- "spearman"   # "pearson" or "spearman"

# Pre-season windows for the multi-month predictors, defined by lags
# (months before the season starts). Their labels (e.g. "Dec-Feb") are built
# automatically for each season.
predictor_windows <- list(c(6, 5, 4),   # lags 6-4 (June-Sep season: Dec-Feb)
                          c(3, 2, 1),   # lags 3-1 (June-Sep season: Mar-May)
                          c(2, 1),      # lags 2-1 (June-Sep season: Apr-May)
                          6:1)          # lags 6-1 (June-Sep season: Dec-May)

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
# standardised table with columns year, month, index, value
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
# Each season is assigned to its central month (DJF -> 1, ..., NDJ -> 12)
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
wemoi <- read_csv(file.path(path_CliIdx, "wemoi_1821_2026.csv"),
                  comment = "#", show_col_types = FALSE)
names(wemoi) <- tolower(trimws(names(wemoi)))

wemoi <- wemoi %>%
  mutate(date  = as.Date(date),
         year  = as.integer(format(date, "%Y")),
         month = as.integer(format(date, "%m")))

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
# 3) Index anomalies: standardized by calendar month (+ optional detrending)
# ------------------------------------------------------------------------------
# Linear detrending: fit x ~ time and keep the residuals.
# Series with fewer than 10 valid values are returned unchanged.
remove_trend <- function(x, time_numeric) {
  valid <- !is.na(x)
  if (sum(valid) < 10) return(x)
  x[valid] <- resid(lm(x[valid] ~ time_numeric[valid]))
  x
}

# Standardised anomaly by calendar month: for each month (all Januaries, all
# Februaries, ...) subtract that month's mean and divide by its standard
# deviation. This removes the seasonal cycle of the index.
remove_seasonality <- function(df, col) {
  df %>%
    mutate(cal_month = month(date)) %>%
    group_by(cal_month) %>%
    mutate("{col}" := (.data[[col]] - mean(.data[[col]], na.rm = TRUE)) /
             sd(.data[[col]], na.rm = TRUE)) %>%
    ungroup() %>%
    select(-cal_month)
}

indices_anom <- indices_raw %>%
  group_by(index) %>%
  group_split() %>%
  map_dfr(function(d) {
    d <- remove_seasonality(d, "value")
    if (detrend) d$value <- remove_trend(d$value, as.numeric(d$date))
    d
  })

# ------------------------------------------------------------------------------
# 4) Helper functions used by every configuration
# ------------------------------------------------------------------------------

# Season label from its months, e.g. 6:9 -> "JJAS", 7:8 -> "JA"
make_season_label <- function(months) {
  paste0(substr(month.abb[months], 1, 1), collapse = "")
}

# Summarise the daily FWI of one season into one number
summarise_season <- function(x, stat) {
  switch(stat,
         mean = mean(x, na.rm = TRUE),
         p90  = unname(quantile(x, 0.9, na.rm = TRUE)),
         max  = max(x, na.rm = TRUE),
         stop("stat must be 'mean', 'p90' or 'max'"))
}

# Correlation between two vectors using only complete pairs.
# Returns r (correlation), p (p-value) and n (number of years used).
correlate_pairs <- function(x, y) {
  complete <- complete.cases(x, y)
  n <- sum(complete)
  if (n < min_pairs) return(tibble(r = NA_real_, p = NA_real_, n = n))
  test <- suppressWarnings(
    cor.test(x[complete], y[complete], method = cor_method, exact = FALSE)
  )
  tibble(r = unname(test$estimate), p = test$p.value, n = n)
}

# Multiple-testing correction (Benjamini-Hochberg) and significance labels.
# NOTE: the correction is applied within one configuration only.
add_significance <- function(df) {
  df %>%
    mutate(p_fdr = p.adjust(p, "BH"),
           signif_label = case_when(p_fdr < 0.05 ~ "**",   # significant after correction
                                    p     < 0.05 ~ "*",    # significant before correction
                                    TRUE          ~ ""))
}

# Number of days in each calendar month (non-leap year)
days_per_month <- c(31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31)

# ------------------------------------------------------------------------------
# 5) Analysis for ONE configuration (season months + statistic)
# ------------------------------------------------------------------------------
run_analysis <- function(season_months, season_stat) {
  
  season_label  <- make_season_label(season_months)
  config_label  <- paste0(season_label, "_", season_stat)
  season_start  <- min(season_months)               # first month of the season
  n_season_days <- sum(days_per_month[season_months])
  message("\n=== Configuration: ", config_label, " ===")
  
  # --- 5.1 Target: seasonal FWI, one value per year ----------------------------
  fwi_season <- fwi_daily %>%
    filter(month(date) %in% season_months) %>%
    mutate(target_year = year(date)) %>%
    group_by(target_year) %>%
    summarise(n_days = sum(!is.na(fwi)),
              fwi    = summarise_season(fwi, season_stat),
              .groups = "drop") %>%
    filter(n_days >= min_coverage * n_season_days)   # drop incomplete seasons
  
  # Standardize across years (z-score) and optionally remove the linear trend
  fwi_season_anom <- fwi_season %>%
    mutate(fwi = (fwi - mean(fwi)) / sd(fwi))
  if (detrend) {
    fwi_season_anom$fwi <- remove_trend(fwi_season_anom$fwi,
                                        fwi_season_anom$target_year)
  }
  
  # Sanity check: raw seasonal series
  plot_target <- ggplot(fwi_season, aes(target_year, fwi)) +
    geom_line() + geom_point() +
    labs(title = paste0("Spain-wide ", season_label, " FWI (", season_stat, "), raw values"),
         x = "Year", y = "FWI") +
    theme_bw()
  ggsave(file.path(out_dir, paste0("fwi_series_", config_label, ".png")),
         plot_target, width = 8, height = 4, dpi = 150)
  
  # --- 5.2 Single-month predictors ---------------------------------------------
  # Each index value at month 'date' is shifted forward by 'lag' months; we keep
  # only the rows that land exactly on day 1 of the season's first month, so
  # lag = number of months before the season starts.
  predictors_month <- indices_anom %>%
    crossing(lag = 1:max_lag) %>%
    mutate(date_season_start = date %m+% months(lag)) %>%
    filter(month(date_season_start) == season_start) %>%
    mutate(target_year = year(date_season_start)) %>%
    select(index, lag, target_year, value)
  
  # Readable labels for the lags (e.g. June-Sep season: 1 = May, ..., 6 = Dec)
  lag_labels <- month.abb[((season_start - 1 - 1:max_lag) %% 12) + 1]
  names(lag_labels) <- 1:max_lag
  
  predictors_month <- predictors_month %>%
    mutate(predictor = factor(lag_labels[as.character(lag)], levels = lag_labels))
  
  # --- 5.3 Multi-month predictors (window means) --------------------------------
  # Label of a window from its lags, e.g. lags 6:4 -> "Dec-Feb"
  window_name <- function(lags) {
    paste0(lag_labels[as.character(max(lags))], "-",
           lag_labels[as.character(min(lags))])
  }
  
  predictors_window <- map_dfr(predictor_windows, function(window_lags) {
    predictors_month %>%
      filter(lag %in% window_lags) %>%
      group_by(index, target_year) %>%
      # mean over the window; NA if any month of the window is missing
      summarise(value = if (n() == length(window_lags)) mean(value) else NA_real_,
                .groups = "drop") %>%
      mutate(predictor = window_name(window_lags))
  }) %>%
    mutate(predictor = factor(predictor,
                              levels = map_chr(predictor_windows, window_name)))
  
  # Attach the target (seasonal FWI anomaly) of the same year
  paired_month  <- inner_join(predictors_month,  fwi_season_anom, by = "target_year")
  paired_window <- inner_join(predictors_window, fwi_season_anom, by = "target_year")
  
  # --- 5.4 Correlations across years --------------------------------------------
  cor_month <- paired_month %>%
    group_by(index, lag, predictor) %>%
    reframe(correlate_pairs(value, fwi)) %>%
    add_significance()
  
  cor_window <- paired_window %>%
    group_by(index, predictor) %>%
    reframe(correlate_pairs(value, fwi)) %>%
    add_significance()
  
  write_csv(cor_month,  file.path(out_dir, paste0("cor_single_month_", config_label, ".csv")))
  write_csv(cor_window, file.path(out_dir, paste0("cor_window_",       config_label, ".csv")))
  
  # --- 5.5 Heatmaps -------------------------------------------------------------
  plot_subtitle <- paste0(tools::toTitleCase(cor_method),
                          " correlation of standardized anomalies",
                          if (detrend) " (detrended)" else "",
                          "; * p < 0.05, ** p < 0.05 after FDR correction")
  
  plot_month <- ggplot(cor_month, aes(predictor, index, fill = r)) +
    geom_tile(colour = "white") +
    geom_text(aes(label = sprintf("%.2f%s", r, signif_label)), size = 3) +
    scale_fill_gradient2(low = "blue", mid = "white", high = "red",
                         limits = c(-0.6, 0.6), oob = scales::squish, name = "r") +
    labs(title = paste0(season_label, " FWI (", season_stat,
                        ") vs climate index in the months before the season"),
         subtitle = plot_subtitle,
         x = "Month of the index (before the season)", y = NULL) +
    theme_bw()
  ggsave(file.path(out_dir, paste0("heatmap_single_month_", config_label, ".png")),
         plot_month, width = 9, height = 7, dpi = 150)
  
  plot_window <- ggplot(cor_window, aes(predictor, index, fill = r)) +
    geom_tile(colour = "white") +
    geom_text(aes(label = sprintf("%.2f%s", r, signif_label)), size = 3) +
    scale_fill_gradient2(low = "blue", mid = "white", high = "red",
                         limits = c(-0.6, 0.6), oob = scales::squish, name = "r") +
    labs(title = paste0(season_label, " FWI (", season_stat,
                        ") vs pre-season mean of climate indices"),
         subtitle = plot_subtitle,
         x = "Pre-season window", y = NULL) +
    theme_bw()
  ggsave(file.path(out_dir, paste0("heatmap_window_", config_label, ".png")),
         plot_window, width = 7, height = 7, dpi = 150)
  
  # --- 5.6 Return results with the configuration attached -----------------------
  bind_rows(
    cor_month  %>% mutate(type = "single month") %>% select(-lag),
    cor_window %>% mutate(type = "window")
  ) %>%
    mutate(season = season_label, stat = season_stat, .before = 1)
}

# ------------------------------------------------------------------------------
# 6) Run every combination: seasons x statistics
# ------------------------------------------------------------------------------
configs <- expand_grid(season_months = season_options, season_stat = stat_options)

# Safety check: the cached daily series must contain every month needed
needed_months <- sort(unique(unlist(season_options)))
if (!all(needed_months %in% unique(month(fwi_daily$date)))) {
  stop("The daily FWI cache does not contain all the months needed. ",
       "Add them to 'daily_months' and set recompute_daily <- TRUE.")
}

all_results <- pmap_dfr(configs, function(season_months, season_stat) {
  run_analysis(season_months, season_stat)
})

# Combined table with every configuration
write_csv(all_results, file.path(out_dir, "cor_ALL_configurations.csv"))

# ------------------------------------------------------------------------------
# 7) Summary across configurations
# ------------------------------------------------------------------------------
# Strongest predictors overall
best_overall <- all_results %>%
  filter(!is.na(r)) %>%
  arrange(desc(abs(r))) %>%
  select(season, stat, type, index, predictor, r, p, p_fdr, n)
print(head(best_overall, 25))

# Number of significant results per configuration (to compare configurations)
summary_by_config <- all_results %>%
  filter(!is.na(r)) %>%
  group_by(season, stat) %>%
  summarise(n_tests      = n(),
            n_p05        = sum(p < 0.05),
            n_fdr05      = sum(p_fdr < 0.05),
            expected_p05 = round(0.05 * n(), 1),   # false positives expected by chance
            max_abs_r    = round(max(abs(r)), 2),
            .groups = "drop")
print(summary_by_config)

