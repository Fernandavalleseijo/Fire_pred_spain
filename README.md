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
- [`NOAA_SST_Regions.py`](./NOAA_SST_Regions.py) exports the daily area-weighted
  SST and NOAA anomaly means for three literature-defined regions:
  Ossó NW (42–52°N, 52–40°W), Ossó SE (35–42°N, 35–20°W), and Krüger
  (45–60°N, 40–15°W). Its CSV contains a date plus six value columns: one SST
  and one anomaly series for each region.

This script is a data-preparation step; it does not yet train or evaluate a
wildfire prediction model, and it does not yet process SLP, soil moisture, or
wildfire records.

## ERA5-Land daily soil moisture

[`ERA5Land_Soil_Moisture_Daily.py`](./ERA5Land_Soil_Moisture_Daily.py) saves
one NetCDF file per day with the four volumetric soil-water layers (`swvl1`–
`swvl4`) for the Spain bounding box. It defaults to 1950-01-02 through
2025-12-31 and writes files to
`/home/jose/Escritorio/UCM_Madrid/Soil_Mositure`.

Install the required packages in the project environment:

```bash
python -m pip install xarray zarr "dask[array]" pandas netCDF4 requests aiohttp
```

The script uses the ECMWF soil-water Zarr URL by default, with the `time`
chunked store recommended for spatial maps. Run it and enter your CDS API key
when prompted; the key will not be shown as you type:

```bash
python ERA5Land_Soil_Moisture_Daily.py
```

Alternatively, set `CDS_API_KEY` in the environment to avoid the prompt. Keep
the key private and do not put it in the script. To use a different Zarr URL,
set `ERA5LAND_ZARR_URL` or pass `--zarr-url`. Additional Zarr storage options
can be supplied as a JSON object through `ERA5LAND_ZARR_STORAGE_OPTIONS`. Use
`--start-date`, `--end-date`, and `--output` to select a shorter test period
or a different local output directory. Existing daily files are skipped so
an interrupted run can be resumed. Progress is printed while opening the
dataset and preparing the Spain subset, then for each batch of up to seven
days while data are read and periodically as daily files are saved.

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

Run the three-region extraction for the default 1981-09-01–2025 period:

```bash
python NOAA_SST_Regions.py
```

The new script accepts the same `--start-date`, `--end-date`, and `--output`
options as `NOAA_SST_Cloud.py`.

The CSV is written beside the script by default. Use `--output PATH` to choose
a different output path.

## Data source

The SST data come from NOAA's Optimum Interpolation Sea Surface Temperature
(OISST) v2.1 dataset, accessed through the public
[Source Cooperative Icechunk store](https://source.coop/ocean-icechunks/noaa-oisst).
The anomaly is NOAA's published daily SST anomaly relative to its 1971–2000
climatology.