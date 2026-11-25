# Lagged correlations between soil moisture and FWI (Spain)

R workflow to quantify how well **soil moisture** (ERA5-Land, four soil layers) anticipates the **Fire Weather Index (FWI)** over the Iberian Peninsula, using lags of 0–6 months. 
It is part of the wildfire-prediction work in Spain, where the FWI is the target variable.

## Scripts

| Script | Purpose |
|---|---|
| [`Correlation_FWI_SM_00_prep_functions.R`](Correlation_FWI_SM_00_prep_functions.R) | Data preparation (cached) and shared functions. It is sourced by the two analysis scripts and is not run on its own. |
| [`Correlation_FWI_SM_01_AllSpain_Month.R`](Correlation_FWI_SM_01_AllSpain_Month.R) | Lagged correlations using **all months** of the FWI (pooled and month by month). |
| [`Correlation_FWI_SM_03_AllSpain_Season.R`](Correlation_FWI_SM_03_AllSpain_Season.R) | Lagged correlations using the **summer FWI (June–September, JJAS)**, pooled and for each month. |

## Input data

| Variable | Source | Period | Resolution | Role |
|---|---|---|---|---|
| FWI (`fwi_month_Iberia.nc`) | CSIC | 1961-01 to 2025-12 (780 monthly layers) | 0.025° (545 × 342 cells), EPSG:4326 | Target |
| Soil moisture `swvl1`–`swvl4` | ERA5-Land, daily maps produced by [`ERA5Land_Soil_Moisture_Daily.py`](ERA5Land_Soil_Moisture_Daily.py) | 1950-01-02 to 2025-12-31 | 0.1° | Predictor |

- The four ERA5-Land layers are 0–7 cm (`swvl1`), 7–28 cm (`swvl2`), 28–100 cm (`swvl3`) and 100–289 cm (`swvl4`).
- Daily soil-moisture files must be named `ERA5Land_SM_Spain_YYYYMMDD.nc`, as produced by the Python script.

## Method

**Lag definition.** Lag *k* pairs the soil moisture of month *t − k* with the FWI of month *t*. Lag 0 is contemporaneous, so for prediction the relevant lags are ≥ 1.

**Processing chain** (identical for every variable and applied on the common period 1961-01 to 2025-12):

1. Soil moisture: daily maps → monthly means (per layer).
2. FWI: cropped to the soil-moisture bounding box (35.8–43.9°N, 9.5°W–4.5°E) and averaged from 0.025° to the 0.1° ERA5-Land grid.
3. Seasonal cycle removal: z-score anomaly per calendar month (`anom_z`).
4. Optional linear detrending (`DETREND`, `TRUE` by default) over the same period (`detrend_rows`).
5. Pearson correlation with its p-value, computed per cell and on the spatial-mean series (`lag_cor`, `cor_rows`).

Variables are clipped to the same period *before* removing the cycle and trend, so the climatology and trend are estimated only on the years that enter the correlation.

**Pooled vs. by target month.**

- *Pooled*: all FWI months of the selection (all 12 months, or Jun–Sep) are stacked, each paired with the soil moisture `lag` months earlier, and a single correlation is computed (about 780 − *k* pairs for all months, about 260 for JJAS).
- *By target month*: only the pairs whose FWI falls in one calendar month are used (about 65 pairs, one per year), giving one correlation per month.

## Usage

1. Install the packages: `install.packages(c("terra", "ggplot2"))`.
2. Edit the paths at the top of `Correlation_FWI_SM_00_prep_functions.R`:
   - `path_sm`: folder with the daily ERA5-Land NetCDF files.
   - `path_fwi`: path to `fwi_month_Iberia.nc`.
   - `path_out`: output and cache folder (default `Lag_Correlations`).
3. Make sure the `source(...)` line at the top of scripts `01` and `03` points to the location of `Correlation_FWI_SM_00_prep_functions.R`.
4. Run `Correlation_FWI_SM_01_AllSpain_Month.R` and/or `Correlation_FWI_SM_03_AllSpain_Season.R`.

The first run reads about 27,700 daily NetCDF files and is slow. Monthly soil moisture and the resampled FWI are then cached in `path_out`, so later runs are fast. Delete the cached `.tif` files to force a rebuild.

Main settings in the analysis scripts: `LAGS` (default `0:6`), `DETREND` (default `TRUE`), `ALPHA` (default `0.05`) and, in the seasonal script, `JJAS` (default `6:9`).

## Outputs

All files are written to `path_out`.

**Preparation** (script `00`)

| File | Content |
|---|---|
| `SM_monthly_swvl1.tif` … `SM_monthly_swvl4.tif` | Monthly mean soil moisture, one layer per month (1950-01 to 2025-12), named `YYYY-MM` |
| `FWI_monthly_0.1deg.tif` | Monthly FWI on the 0.1° grid, 780 layers named `YYYY-MM` |

**All months** (script `01`)

| File | Content |
|---|---|
| `r_all_<layer>_lag<k>.tif` | Per-cell correlation map (not masked by significance), 28 files |
| `maps_all_<layer>.png` | One panel per lag; only cells with p < `ALPHA` are shown |
| `corr_all_months_spatialmean.csv` | Spatial-mean series, all months pooled: `layer`, `lag`, `r`, `p`, `n`, `frac_cells_sig`, `r_median_cells` |
| `corr_by_target_month_spatialmean.csv` | Spatial-mean series by FWI month: `layer`, `lag`, `target_month`, `r`, `p`, `n` |
| `heatmap_all_months.png` | FWI month × lag, one panel per soil layer (`*` = p < `ALPHA`) |

**Summer, JJAS** (script `03`)

| File | Content |
|---|---|
| `r_JJAS_<layer>_lag<k>.tif` | Per-cell correlation map for pooled Jun–Sep (not masked by significance) |
| `maps_JJAS_<layer>.png` | One panel per lag; only cells with p < `ALPHA` are shown |
| `corr_JJAS_spatialmean.csv` | Spatial-mean series for JJAS pooled and for Jun, Jul, Aug and Sep separately: `layer`, `lag`, `target`, `r`, `p`, `n`, `sm_month_for_Jun`, `frac_cells_sig` |
| `heatmap_JJAS.png` | Target (JJAS, Jun–Sep) × lag, one panel per soil layer |

`frac_cells_sig` is the fraction of valid cells with p < `ALPHA`; it is only reported for the pooled correlation. `sm_month_for_Jun` is the calendar month of the soil moisture that precedes June at each lag.
