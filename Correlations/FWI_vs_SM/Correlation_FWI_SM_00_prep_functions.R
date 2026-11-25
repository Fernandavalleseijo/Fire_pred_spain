# =============================================================================
# Prepares: (1) ERA5-Land daily soil moisture -> monthly (swvl1-4)
#           (2) CSIC monthly FWI aggregate to the 0.1° grid of soil moisture
# and defines the lagged-correlation functions.
# Run once; intermediate results are cached to disk.
# =============================================================================

library(terra)

# ---- Paths (EDIT) -----------------------------------------------------------
path_sm  <- ""   # daily NetCDF files
path_fwi <- ""  # CSIC FWI file
path_out <- "Lag_Correlations"                         # output and cache folder
dir.create(path_out, showWarnings = FALSE, recursive = TRUE)

layers_sm <- paste0("swvl", 1:4)

# ---- 1. Soil moisture: daily -> monthly -------------------------------------

sm_tif <- function(l) file.path(path_out, paste0("SM_monthly_", l, ".tif"))

if (!all(file.exists(sapply(layers_sm, sm_tif)))) {
  files <- list.files(path.expand(path_sm),
                      pattern = "^ERA5Land_SM_Spain_\\d{8}\\.nc$",
                      full.names = TRUE)
  stopifnot(length(files) > 0)
  d    <- as.Date(sub(".*_(\\d{8})\\.nc$", "\\1", files), "%Y%m%d")
  ym   <- format(d, "%Y-%m")
  ym_u <- sort(unique(ym))
  monthly <- setNames(vector("list", 4), layers_sm)
  
  for (m in ym_u) {
    fm  <- files[ym == m]
    lst <- lapply(fm, function(f) {
      r  <- rast(f)
      nm <- names(r)
      # one layer per variable (swvl1..swvl4)
      sapply(layers_sm, function(v) r[[grep(paste0("^", v), nm)[1]]])
    })
    for (l in layers_sm) {
      stk <- rast(lapply(lst, function(x) x[[l]]))
      mm  <- mean(stk, na.rm = TRUE)
      names(mm) <- m
      monthly[[l]][[m]] <- mm
    }
    if (substr(m, 6, 7) == "12") message("Monthly SM done: ", substr(m, 1, 4))
  }
  for (l in layers_sm) {
    r <- rast(monthly[[l]])
    if (crs(r) == "") crs(r) <- "EPSG:4326"
    writeRaster(r, sm_tif(l), overwrite = TRUE)
  }
}

SM <- lapply(setNames(layers_sm, layers_sm), function(l) rast(sm_tif(l)))

# ---- 2. Monthly FWI -> 0.1° grid --------------------------------------------

fwi_tif <- file.path(path_out, "FWI_monthly_0.1deg.tif")

if (!file.exists(fwi_tif)) {
  fwi <- rast(path_fwi)
  tt  <- time(fwi)
  if (all(is.na(tt)))   # in case the NetCDF has no readable time axis
    tt <- seq(as.Date("1961-01-01"), by = "month", length.out = nlyr(fwi))
  stopifnot(nlyr(fwi) == 780)
  names(fwi) <- format(tt, "%Y-%m")
  crs(fwi) <- "EPSG:4326"
  # Crop to the soil-moisture box and aggregate to 0.1° (mean)
  fwi <- crop(fwi, ext(SM[[1]]))
  fwi <- resample(fwi, SM[[1]][[1]], method = "average")
  writeRaster(fwi, fwi_tif, overwrite = TRUE)
}
FWI <- rast(fwi_tif)

# ---- 3. Common period, matrices and date indices ----------------------------

# Month index: year * 12 + month - 1 (allows simple lag arithmetic)
ym2idx <- function(ym) as.integer(substr(ym, 1, 4)) * 12 + as.integer(substr(ym, 6, 7)) - 1

# ONE common period for every variable (the FWI period)
PERIOD_START <- ym2idx("1961-01")
PERIOD_END   <- ym2idx("2025-12")

fwi_ym  <- names(FWI)
fwi_idx <- ym2idx(fwi_ym)
fwi_mon <- as.integer(substr(fwi_ym, 6, 7))
FWI_mat <- values(FWI)

# Soil moisture: clipped to the SAME period (no 1960 buffer)
sm_ym   <- names(SM[[1]])
keep    <- ym2idx(sm_ym) >= PERIOD_START & ym2idx(sm_ym) <= PERIOD_END
sm_idx  <- ym2idx(sm_ym)[keep]
sm_mon  <- as.integer(substr(sm_ym, 6, 7))[keep]
SM_mat  <- lapply(SM, function(r) values(r)[, keep])

stopifnot(identical(range(fwi_idx), c(PERIOD_START, PERIOD_END)),
          identical(range(sm_idx),  c(PERIOD_START, PERIOD_END)))

# Common mask (cells with data in both FWI and SM)
cell_ok  <- rowSums(!is.na(FWI_mat)) > 100 & rowSums(!is.na(SM_mat[[1]])) > 100
template <- SM[[1]][[1]]; values(template) <- NA

# ---- 4. Functions -----------------------------------------------------------

# Standardized anomaly by calendar month (removes the seasonal cycle).
# The climatology is computed over the full (already clipped) period.

anom_z <- function(M, mon) {
  for (m in 1:12) {
    i  <- which(mon == m)
    mu <- rowMeans(M[, i, drop = FALSE], na.rm = TRUE)
    s  <- apply(M[, i, drop = FALSE], 1, sd, na.rm = TRUE)
    s[s == 0] <- NA
    M[, i] <- (M[, i] - mu) / s
  }
  M
}

# Vectorized linear detrending per row (NA-aware, closed-form OLS)
detrend_rows <- function(M, tt, min_n = 20) {
  ok <- !is.na(M)
  n  <- rowSums(ok)
  M0 <- M; M0[!ok] <- 0
  TT <- matrix(tt, nrow(M), ncol(M), byrow = TRUE); TT[!ok] <- 0
  st <- rowSums(TT); sy <- rowSums(M0)
  b  <- (rowSums(TT * M0) - st * sy / n) / (rowSums(TT^2) - st^2 / n)
  a  <- (sy - b * st) / n
  R  <- M - (a + b * matrix(tt, nrow(M), ncol(M), byrow = TRUE))
  R[n < min_n, ] <- NA
  R
}

# Full processing chain, always on the common period:
# seasonal cycle removal -> (optional) linear detrend
process_series <- function(M, mon, idx, detrend = FALSE) {
  M <- anom_z(M, mon)
  if (detrend) M <- detrend_rows(M, idx)
  M
}

# Spatial-mean series: mean over valid cells of the RAW field, then processed
# exactly like the cell series (so DETREND also applies here)
spatial_mean_series <- function(M, mon, idx, detrend = FALSE) {
  v <- matrix(colMeans(M[cell_ok, , drop = FALSE], na.rm = TRUE), nrow = 1)
  process_series(v, mon, idx, detrend)
}

# Row-wise Pearson correlation (NA-aware) with p-value
cor_rows <- function(X, Y, min_n = 20) {
  ok <- !is.na(X) & !is.na(Y)
  X[!ok] <- 0; Y[!ok] <- 0
  n  <- rowSums(ok)
  sx <- rowSums(X); sy <- rowSums(Y)
  r  <- (rowSums(X * Y) - sx * sy / n) /
    sqrt((rowSums(X^2) - sx^2 / n) * (rowSums(Y^2) - sy^2 / n))
  r[n < min_n] <- NA
  p  <- 2 * pt(-abs(r * sqrt((n - 2) / (1 - r^2))), n - 2)
  list(r = r, p = p, n = n)
}

# Correlation of SM(t - lag) vs FWI(t) for the selected target months.
# Pairs without a predictor value at t - lag are dropped (first `lag` months of 1961).
lag_cor <- function(SMa, FWIa, lag, target_months = 1:12) {
  tc <- which(fwi_mon %in% target_months)
  pc <- match(fwi_idx[tc] - lag, sm_idx)
  ok <- !is.na(pc)
  cor_rows(SMa[, pc[ok], drop = FALSE], FWIa[, tc[ok], drop = FALSE])
}

# Map of r (only p < alpha) for a set of lags
plot_lag_maps <- function(res_list, title, file, alpha = 0.05) {
  png(file, width = 1800, height = 1000, res = 150)
  par(mfrow = c(2, 4), mar = c(2, 2, 3, 4))
  for (k in names(res_list)) {
    r  <- template
    rr <- res_list[[k]]$r
    rr[res_list[[k]]$p >= alpha] <- NA
    values(r) <- rr
    plot(r, range = c(-1, 1), col = hcl.colors(100, "RdBu"),
         main = paste0(title, " | lag ", k))
  }
  dev.off()
}
