# Wildfire prediction in Spain using climate teleconnections

This project prepares climate datasets for analysis alongside wildfire-event
records in Spain. The current work covers sea surface temperature, soil
moisture, and climate indices.

## Current status

## Sea surface temperature

Scripts: [`NOAA_SST_Mediterranean.py`](../Scripts/NOAA_SST_Mediterranean.py) and
[`NOAA_SST_NorthAtlantic.py`](../Scripts/NOAA_SST_NorthAtlantic.py).

Both scripts access the public NOAA OISST v2.1 daily dataset and export
area-weighted SST and NOAA SST-anomaly means to CSV. Their default date range
is 1981-09-01 to 2025-12-31, and both accept custom start dates, end dates,
and output paths.

- The Mediterranean script covers five regions: Sole, Campos, and Pastor's
  western, central, and eastern Mediterranean.
- The North Atlantic script covers the Ossó NW, Ossó SE, and Krüger regions.


## Soil moisture

Script: [`ERA5Land_Soil_Moisture_Daily.py`](../Scripts/ERA5Land_Soil_Moisture_Daily.py).

The script reads ERA5-Land soil-water data and writes daily-mean NetCDF maps
for four soil-water layers (`swvl1`–`swvl4`) over a Spain bounding box
(35.8–43.9°N, 9.5°W–4.5°E). Its default date range is 1950-01-02 to
2025-12-31. It requests a CDS API key, skips existing daily files to allow
resuming, and defaults to `~/Escritorio/UCM_Madrid/Soil_Mositure`.

The script implements the daily extraction and file-writing workflow.

## Climate indices

Scripts: [`ENSO_data_to_csv.R`](../Scripts/ENSO_data_to_csv.R) and
[`ENSO_data_plots.R`](../Scripts/ENSO_data_plots.R).

The data-preparation script reads local NOAA text/ASCII files from
`~/Escritorio/UCM_Madrid/NOAA_ClimateIndex/`, reshapes the monthly or seasonal
records, and writes CSV files to its `CSV/` subdirectory. It handles SST, SOI,
OLR, RONI, MEI, AMO, NAO, and AAO data. The plotting script reads those CSVs
and saves index plots to `~/Escritorio/UCM_Madrid/PLOTS/Climate_Indices/`.

These scripts implement CSV preparation and plotting; the required local
source files must be present.
