# FWI vs large-scale climate indices (Spain)

Lagged correlation analysis between the **Spain-wide Fire Weather Index (FWI)** and large-scale climate indices. The goal is to explore whether climate variability in the months before, or during, the fire season is related to fire weather danger over Spain, and at which lags.

The folder contains three R scripts:

| Script | Purpose | Input | Main output |
|---|---|---|---|
| `FWI_nc_to_csv_daily-mean-JJAS-All-Spain.R` | Extracts the Spain-wide **daily** mean FWI for June–September | Daily FWI NetCDF | CSV with `date`, `fwi` |
| `Correlation_FWI_CliIdx_AllSpain_Month.R` | Correlates the **monthly** FWI with the indices at lags of 0–6 months | Monthly FWI NetCDF + index CSVs | Correlation tables and heatmaps |
| `Correlation_FWI_CliIdx_AllSpain_Season.R` | Correlates the **fire-season** FWI with pre-season indices | Daily mean FWI CSV (from script 1) + index CSVs | Correlation tables and heatmaps per season and statistic |

## Workflow

```
Daily FWI (.nc) ──► FWI_nc_to_csv_daily-mean-JJAS-All-Spain.R ──► daily mean FWI (.csv) ──┐
                                                                                          ├─► Correlation_FWI_CliIdx_AllSpain_Season.R
Climate indices (CSV) ────────────────────────────────────────────────────────────────────┤
                                                                                          └─► Correlation_FWI_CliIdx_AllSpain_Month.R  (also reads the monthly FWI .nc)
```

1. Run `FWI_nc_to_csv_daily-mean-JJAS-All-Spain.R` **once**. It is the slow step (a long daily record at high resolution), so its CSV is reused afterwards.
2. Run `Correlation_FWI_CliIdx_AllSpain_Season.R`, which reads that CSV.
3. `Correlation_FWI_CliIdx_AllSpain_Month.R` is independent of step 1. It reads the monthly FWI NetCDF directly.

> The seasonal script reads the daily CSV by file name. Make sure the name written by script 1 (`path_daily_output`) is exactly the name read by script 3 (`fwi_daily <- read_csv(...)`).


## Common methodology

Both correlation scripts apply the same preprocessing, so that only interannual variability is correlated:

1. **Standardized anomalies by calendar month.** For each calendar month (all Januaries, all Februaries, …) the mean is subtracted and the result is divided by the standard deviation. This removes the seasonal cycle. This matters because the FWI has a very strong seasonal cycle.
2. **Linear detrending** (`detrend <- TRUE`). A straight line is fitted against time and removed. This avoids spurious correlations caused by shared trends (for example, warming).
3. **Spearman rank correlation** (`cor_method`; can be set to `"pearson"`). Pairs with missing values are dropped, and correlations with fewer than `min_pairs` pairs are not computed.
4. **Multiple-testing correction.** The Benjamini–Hochberg false discovery rate (FDR) correction is applied to the p-values (`p_fdr`).

In all heatmaps: `*` means p < 0.05 without correction, and `**` means p < 0.05 after FDR correction.

## Script 1: `FWI_nc_to_csv_daily-mean-JJAS-All-Spain.R`

1. Reads the daily FWI raster.
2. Keeps only the layers (days) of June–September (`daily_months <- 6:9`).
3. Computes the area-weighted Spain-wide mean for each day.
4. Writes a CSV with two columns: `date` and `fwi`.

Edit `path_fwi_daily` (input) and `path_daily_output` (output) at the top of the script.

## Script 2: `Correlation_FWI_CliIdx_AllSpain_Month.R`

Correlates the **monthly** FWI with each index at lags of 0 to `max_lag` (default 6) months.

**Lag convention:** the index always leads the FWI. The index at month *t* is paired with the FWI at month *t + lag*. For example, lag 2 and target month July means the index of May against the FWI of July.

Two analyses are run:

- **A) All months pooled.** One correlation per index and lag. It answers whether there is a general relationship regardless of the season.
- **B) By target month of the FWI.** One correlation per index, lag and calendar month (about 65 years per correlation). The relationship is often seasonal and can change sign between months, which would cancel out in A.

**Outputs** (folder `out_dir`):

| File | Content |
|---|---|
| `cor_FWI_indices_all_months.csv` | Analysis A: `index`, `lag`, `r`, `p`, `n`, `p_fdr` |
| `cor_FWI_indices_by_target_month.csv` | Analysis B: same columns plus `target_month` and `signif_label` |
| `heatmap_all_months.png` | Index × lag heatmap (the number in each tile is `r`) |
| `heatmap_by_target_month.png` | One panel per index; FWI target month × lag |

## Script 3: `Correlation_FWI_CliIdx_AllSpain_Season.R`

The target is **one FWI value per year** for the fire season, and the predictors are climate indices from the months **before** the season starts.

**Configurations.** The script runs every combination of:

- **Season** (`season_options`): June–September (JJAS) and July–August (JA).
- **Statistic** (`stat_options`) that summarizes the daily FWI of the season into one number per year: `mean`, `max` (seasonal maximum) or `p90` (90th percentile).

Years with less than `min_coverage` (default 90 %) of the season's days are dropped.

**Lag convention.** Lags are counted from the start of each season, and lag 0 is not used because it lies inside the season.

| Lag | JJAS season | JA season |
|---|---|---|
| 1 | May | June |
| 2 | April | May |
| 3 | March | April |
| 4 | February | March |
| 5 | January | February |
| 6 | December (previous year) | January |

**Two kinds of predictors:**

- **Single month:** the index value at each lag.
- **Window:** the mean of the index over several pre-season months, defined by lags in `predictor_windows`. For JJAS they are Dec–Feb, Mar–May, Apr–May and Dec–May. For JA they are Jan–Mar, Apr–Jun, May–Jun and Jan–Jun. The mean is `NA` if any month of the window is missing.

Each correlation is computed across years (n ≈ 40–65).

**Outputs** (folder `out_dir`), where `<config>` is for example `JJAS_mean` or `JA_max`:

| File | Content |
|---|---|
| `cor_single_month_<config>.csv` | Correlations for single-month predictors |
| `cor_window_<config>.csv` | Correlations for window predictors |
| `heatmap_single_month_<config>.png` | Index × month heatmap |
| `heatmap_window_<config>.png` | Index × window heatmap |
| `fwi_series_<config>.png` | Raw seasonal FWI series (sanity check of the target) |
| `cor_ALL_configurations.csv` | All results of all configurations in one table |

The script also prints the 25 strongest predictors and a summary per configuration: number of tests, number with p < 0.05, number with `p_fdr` < 0.05, and the number of p < 0.05 results expected by chance.

## How to run

1. Edit the paths at the top of each script (`path_fwi_daily`, `path_fwi`, `path_csv`, output folders).
2. Run script 1, then script 3. Script 2 can be run at any time.

**R packages:** `terra`, `dplyr`, `tidyr`, `tibble`, `lubridate`, `readr`, `purrr`, `ggplot2`.
