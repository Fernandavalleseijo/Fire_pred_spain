# Wildfire prediction in Spain using climate teleconnections

This project aims to investigate whether large-scale climate conditions and
teleconnections can help predict wildfire events in Spain. Planned predictors
include:

- Sea-surface temperature (SST)
- Sea-level pressure (SLP)
- Soil moisture

The goal is to prepare these environmental datasets for analysis alongside
wildfire-event records. The prediction approach, study period, spatial
resolution, and evaluation methods will be described here as the project
develops.

## Current status

The repository currently includes a script for extracting daily North Atlantic
SST and SST-anomaly regional means from NOAA OISST v2.1:

- [`NOAA_SST_Cloud.py`](./NOAA_SST_Cloud.py) reads the public NOAA OISST
  Icechunk store and exports a CSV.
- By default, it covers 2000-01-01 through 2025-12-31.
- Its current region is 0–70°N and 80°W–0° (280°–360° in the dataset's
  longitude convention).
- The CSV contains the date, area-weighted mean SST, and area-weighted mean
  NOAA SST anomaly.

This script is a data-preparation step; it does not yet train or evaluate a
wildfire prediction model, and it does not yet process SLP, soil moisture, or
wildfire records.

## Running the SST extraction

The script requires Python 3.12 or newer. Install its dependencies with:

```bash
python -m pip install "icechunk>=2.0" xarray zarr "dask[array]" pandas
```

Run the default 2000–2025 extraction:

```bash
python NOAA_SST_Cloud.py
```

To process a shorter date range, for example January 2000:

```bash
python NOAA_SST_Cloud.py --start-date 2000-01-01 --end-date 2000-01-31
```

The CSV is written beside the script by default. Use `--output PATH` to choose
a different output path.

## Data source

The SST data come from NOAA's Optimum Interpolation Sea Surface Temperature
(OISST) v2.1 dataset, accessed through the public
[Source Cooperative Icechunk store](https://source.coop/ocean-icechunks/noaa-oisst).
The anomaly is NOAA's published daily SST anomaly relative to its 1971–2000
climatology.