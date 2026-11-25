# =============================================================================
# Lagged correlations (0-6 months): soil moisture (swvl1-4) vs FWI, all months
# Lag k means: soil moisture in month t-k vs FWI in month t.
# =============================================================================

# Path to Correlation_FWI_SM_00_prep_functions.R

source("~/Correlation_FWI_SM_00_prep_functions.R") 

library(ggplot2)

LAGS    <- 0:6
DETREND <- TRUE   # TRUE to remove linear trends before correlating
ALPHA   <- 0.05
ref_fwi <- rep(TRUE, length(fwi_mon))
ref_sm  <- sm_idx >= ym2idx("1961-01")

# Cell-wise: seasonal cycle + trend removed on the common 1961-2025 period
FWI_a <- process_series(FWI_mat, fwi_mon, fwi_idx, DETREND)
SM_a  <- lapply(SM_mat, process_series, mon = sm_mon, idx = sm_idx, detrend = DETREND)

# Spatial-mean series, same processing
FWI_s <- spatial_mean_series(FWI_mat, fwi_mon, fwi_idx, DETREND)
SM_s  <- lapply(SM_mat, spatial_mean_series, mon = sm_mon, idx = sm_idx, detrend = DETREND)

tab_all   <- list()
tab_month <- list()

for (l in layers_sm) {
  res_maps <- list()
  for (k in LAGS) {
    # (a) Maps: per-cell correlation, all months pooled
    rs <- lag_cor(SM_a[[l]], FWI_a, k, 1:12)
    res_maps[[as.character(k)]] <- rs
    r_map <- template; values(r_map) <- rs$r
    writeRaster(r_map, file.path(path_out, sprintf("r_all_%s_lag%d.tif", l, k)),
                overwrite = TRUE)
    
    # (b) Spatial-mean series, all months pooled
    ra <- lag_cor(SM_s[[l]], FWI_s, k, 1:12)
    tab_all[[length(tab_all) + 1]] <- data.frame(
      layer = l, lag = k, r = ra$r, p = ra$p, n = ra$n,
      frac_cells_sig = mean(rs$p[cell_ok] < ALPHA, na.rm = TRUE),
      r_median_cells = median(rs$r[cell_ok], na.rm = TRUE))
    
    # (c) Spatial-mean series, by target month of the FWI
    for (m in 1:12) {
      res_m <- lag_cor(SM_s[[l]], FWI_s, k, m)
      tab_month[[length(tab_month) + 1]] <- data.frame(
        layer = l, lag = k, target_month = m,
        r = res_m$r, p = res_m$p, n = res_m$n)
    }
  }
  plot_lag_maps(res_maps, paste0("r(", l, ", FWI) all months"),
                file.path(path_out, paste0("maps_all_", l, ".png")), ALPHA)
}

tab_all   <- do.call(rbind, tab_all)
tab_month <- do.call(rbind, tab_month)
write.csv(tab_all,   file.path(path_out, "corr_all_months_spatialmean.csv"),
          row.names = FALSE)
write.csv(tab_month, file.path(path_out, "corr_by_target_month_spatialmean.csv"),
          row.names = FALSE)

# ---- Heatmaps: target month x lag, one panel per soil layer -----------------
tab_month$target_month <- factor(tab_month$target_month, levels = 1:12,
                                 labels = month.abb)
g <- ggplot(tab_month, aes(factor(lag), target_month, fill = r)) +
  geom_tile() +
  geom_text(aes(label = ifelse(p < ALPHA, "*", "")), size = 5) +
  scale_fill_gradientn(colours = hcl.colors(100, "RdBu"), limits = c(-1, 1)) +
  facet_wrap(~ layer) +
  labs(x = "Lag (months; soil moisture leads FWI)", y = "FWI month",
       fill = "r",
       title = "Correlation between soil moisture and FWI (Spain mean, anomalies)",
       caption = "* p < 0.05") +
  theme_bw(base_family = "serif")
ggsave(file.path(path_out, "heatmap_all_months.png"), g,
       width = 10, height = 7, dpi = 150)

print(subset(tab_all, select = c(layer, lag, r, p, frac_cells_sig)))
