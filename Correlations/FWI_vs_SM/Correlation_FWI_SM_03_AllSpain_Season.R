# =============================================================================
# Lagged correlations (0-6 months): soil moisture (swvl1-4) vs FWI, Jun-Sep
# Lag k means: soil moisture in month t-k vs FWI in month t.
# =============================================================================
# Path to Correlation_FWI_SM_00_prep_functions.R

source("~/Correlation_FWI_SM_00_prep_functions.R") 


library(ggplot2)

LAGS    <- 0:6
JJAS    <- 6:9
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


tab <- list()
for (l in layers_sm) {
  res_maps <- list()
  for (k in LAGS) {
    # Maps: pooled Jun-Sep
    rs <- lag_cor(SM_a[[l]], FWI_a, k, JJAS)
    res_maps[[as.character(k)]] <- rs
    r_map <- template; values(r_map) <- rs$r
    writeRaster(r_map, file.path(path_out, sprintf("r_JJAS_%s_lag%d.tif", l, k)),
                overwrite = TRUE)
    
    # Spatial-mean series: pooled Jun-Sep and each month separately
    for (m in list("JJAS", 6, 7, 8, 9)) {
      target_months <- if (identical(m, "JJAS")) JJAS else m
      res_m <- lag_cor(SM_s[[l]], FWI_s, k, target_months)
      tab[[length(tab) + 1]] <- data.frame(
        layer = l, lag = k, target = as.character(m),
        r = res_m$r, p = res_m$p, n = res_m$n,
        sm_month_for_Jun = ((6 - k - 1) %% 12) + 1,  # SM month preceding June
        frac_cells_sig = if (identical(m, "JJAS"))
          mean(rs$p[cell_ok] < ALPHA, na.rm = TRUE) else NA)
    }
  }
  plot_lag_maps(res_maps, paste0("r(", l, ", FWI JJAS)"),
                file.path(path_out, paste0("maps_JJAS_", l, ".png")), ALPHA)
}

tab <- do.call(rbind, tab)
write.csv(tab, file.path(path_out, "corr_JJAS_spatialmean.csv"), row.names = FALSE)

# ---- Heatmap: target (JJAS, Jun..Sep) x lag, one panel per soil layer -------
tab$target <- factor(tab$target, levels = c("JJAS", "6", "7", "8", "9"),
                     labels = c("JJAS", "Jun", "Jul", "Aug", "Sep"))
g <- ggplot(tab, aes(factor(lag), target, fill = r)) +
  geom_tile() +
  geom_text(aes(label = ifelse(p < ALPHA, "*", "")), size = 5) +
  scale_fill_gradientn(colours = hcl.colors(100, "RdBu"), limits = c(-1, 1)) +
  facet_wrap(~ layer) +
  labs(x = "Lag (months; soil moisture leads FWI)", y = "Target FWI",
       fill = "r",
       title = "Correlation between soil moisture and summer FWI (Spain mean)",
       caption = "* p < 0.05") +
  theme_bw(base_family = "serif")
ggsave(file.path(path_out, "heatmap_JJAS.png"), g,
       width = 10, height = 6, dpi = 150)

print(subset(tab, target == "JJAS", select = c(layer, lag, r, p, frac_cells_sig)))
