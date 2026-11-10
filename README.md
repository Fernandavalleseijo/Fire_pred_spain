# Wildfire prediction in Spain

This project prepares climate datasets for analysis alongside wildfire records in Spain. The
goal is to predict the **Fire Weather Index (FWI)**, from sea surface
temperature (SST), soil moisture (SM), drought (SPEI), and large-scale climate indices.

## Prediction target: Fire Weather Index (FWI)

Script: [`fwi.R`](../Scripts/fwi.R).

The FWI (Van Wagner, 1987) is the variable to be predicted. The project uses the monthly FWI
for the Iberian Peninsula (`fwi_month_Iberia.nc`, CSIC):

- Resolution: 0.025° (545 × 342 cells), EPSG:4326.
- Period: 1961-01 to 2025-12 (780 monthly layers).
- The FWI is **dimensionless**. The `units: celsius` attribute in the file is a metadata
  error, so axes should not be labelled in °C.

`fwi.R` is an exploratory script. It inspects the NetCDF with `ncdf4`, loads it with `terra`,
and produces:

- Spatial-mean monthly series with a 12-month moving average.
- Seasonal cycle (boxplots by month) and a year × month heatmap.
- JJA fire-season trend, with Mann-Kendall and Sen's slope tests.
- August distributions (density and ECDF) for 1961–1990 versus 1991–2025.
- Maps: August climatology, August 2022 anomaly, and a per-pixel JJA trend (units/decade).

The per-pixel trend is descriptive only. Spatial significance would need a per-pixel
Mann-Kendall test with a multiple-comparison correction (e.g. FDR).

## Predictors

### Sea surface temperature (SST)

Scripts: [`NOAA_SST_Mediterranean.py`](../Scripts/NOAA_SST_Mediterranean.py) and
[`NOAA_SST_NorthAtlantic.py`](../Scripts/NOAA_SST_NorthAtlantic.py).

Both scripts access the public NOAA OISST v2.1 daily dataset and export area-weighted SST and
NOAA SST-anomaly means to CSV. Their default date range is 1981-09-01 to 2025-12-31, and both
accept custom start dates, end dates, and output paths.

- The Mediterranean script covers five regions: Sole, Campos, and Pastor's western, central,
  and eastern Mediterranean.
- The North Atlantic script covers the Ossó NW, Ossó SE, and Krüger regions.

### Soil moisture

Script: [`ERA5Land_Soil_Moisture_Daily.py`](../Scripts/ERA5Land_Soil_Moisture_Daily.py).

The script reads ERA5-Land soil-water data and writes daily-mean NetCDF maps for four
soil-water layers (`swvl1`–`swvl4`) over a Spain bounding box (35.8–43.9°N, 9.5°W–4.5°E). Its
default date range is 1950-01-02 to 2025-12-31. It requests a CDS API key, skips existing daily
files to allow resuming, and defaults to `~/Escritorio/UCM_Madrid/Soil_Mositure`.

### Drought: SPEI

Scripts: [`SPEIbase_Spain_Download.py`](../Scripts/SPEIbase_Spain_Download.py) and
[`SPEI_preview.R`](../Scripts/SPEI_preview.R).

The Standardized Precipitation Evapotranspiration Index (SPEI) is added as a drought predictor,
using SPEIbase v2.11 (CSIC, https://spei.csic.es).

- **Download:** `SPEIbase_Spain_Download.py` downloads the global monthly NetCDF for each
  timescale, crops it to the same Spain bounding box used for soil moisture (35.8–43.9°N,
  9.5°W–4.5°E) and to 1950-01 – 2024-12, and writes one compact NetCDF per scale
  (`SPEIbase_v2_11_Spain_speiXX_1950-2024.nc`, variable `speiXX`). Options:
  - `--scales`: comma-separated timescales from 1 to 48 months (default: all 48).
  - `--output`: output directory.
  - Existing outputs are skipped, so interrupted runs can resume.
- **Preview:** `SPEI_preview.R` reads the cropped files and saves three figures: a map for one
  month (default SPEI-12, August 2022), the area-weighted Spain-mean time series, and a
  timescale × time heatmap (scales 1, 3, 6, 12, 24, 48).

SPEIbase v2.11 ends in 2024, so SPEI does not yet cover 2025, while FWI, SST, and soil moisture
extend to 2025-12. Any joint analysis must either stop at 2024 or handle 2025 as missing for SPEI.

### Climate indices

Scripts: [`ENSO_data_to_csv.R`](../Scripts/ENSO_data_to_csv.R) and
[`ENSO_data_plots.R`](../Scripts/ENSO_data_plots.R).

The data-preparation script reads local NOAA text/ASCII files from
`~/Escritorio/UCM_Madrid/NOAA_ClimateIndex/`, reshapes the monthly or seasonal records, and
writes CSV files to its `CSV/` subdirectory. It handles SST (Niño regions), SOI, OLR, RONI,
MEI, AMO, NAO, AAO, SCAND, EA, and WeMOi data. The plotting script reads those CSVs and saves
index plots. See [`Climate_Indices/README.md`](../Climate_Indices/README.md) for details.

These scripts implement CSV preparation and plotting; the required local source files must be
present.

## Validation

[`GEE_Tests/`](../GEE_Tests/README.md) holds two Google Earth Engine scripts used as an
independent check of the soil-moisture and SST pipelines. They are checks, not production code.

## Data coverage at a glance

| Variable | Role | Source | Period | Resolution |
|---|---|---|---|---|
| FWI | Target | CSIC (`fwi_month_Iberia.nc`) | 1961–2025 | Monthly, 0.025° |
| SST (regional means) | Predictor | NOAA OISST v2.1 | 1981-09 – 2025 | Daily, regional means |
| Soil moisture (`swvl1`–`swvl4`) | Predictor | ERA5-Land | 1950-01-02 – 2025 | Daily, 0.1° |
| SPEI (scales 1–48) | Predictor | SPEIbase v2.11 (CSIC) | 1950–2024 | Monthly, 0.5° |
| Climate indices (ENSO, NAO, AMO, etc.) | Predictor | NOAA PSL, WeMOi | Varies by index | Monthly / seasonal |

## Current status

Data preparation is in place for all predictors, and the FWI target has been explored. The
modelling step, which links the predictors to FWI (including lagged relationships), is not yet
implemented in this repository.
