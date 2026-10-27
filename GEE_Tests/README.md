# GEE validation scripts: ERA5-Land soil moisture and NOAA OISST SST

Two small Google Earth Engine (GEE) Code Editor scripts used as an **independent control** of the Python cloud-processing pipelines for soil moisture and sea surface temperature (SST). They pull the same variable, date and region from GEE so the values can be compared against the pipeline output.

They are **checks, not production code**: each one reads a single day or a short series, prints results to the Console, and is meant to be compared against the Python/R output by hand.

## Contents

| File | Dataset | Variable | Purpose |
|---|---|---|---|
| `ERA5-Land_SM_test.js` | `ECMWF/ERA5_LAND/DAILY_AGGR` | `volumetric_soil_water_layer_1` (`swvl1`, m³/m³) | Check soil moisture for one day, one point (Madrid), a 1-year series and the spatial mean over Spain |
| `NOAA_SST_Test.js` | `NOAA/CDR/OISST/V2_1` | `sst` (scale factor 0.01 → °C) | Check mean SST over eight rectangular regions for one day |

## How to run

GEE Code Editor scripts cannot be executed directly from GitHub.

1. Open the [GEE Code Editor](https://code.earthengine.google.com/) (requires a GEE-enabled account).
2. Create a new script and paste the contents of the `.js` file.
3. Edit the parameters (see below) and click **Run**.
4. Read the results in the **Console** tab (and the **Map** for the ERA5-Land layer).

## `ERA5-Land_SM_test.js`

Checks `swvl1` from ERA5-Land daily aggregates.

**What it does**

1. Loads one day (`1950-01-02`) and shows it as a map layer, clipped to the bounding box.
2. Extracts the value at a point (Madrid, `-3.7, 40.4`) to compare with the pipeline output.
3. Plots the daily time series at that point for 1950.
4. Plots the spatial mean over the bounding box for 1950.

**Parameters to edit**

- `spain`: bounding box `[-10, 36, 4, 44]` (lon min, lat min, lon max, lat max). At 0.1° this is 141 × 81 cells, matching the pipeline grid.
- Dates in `filterDate(...)`.
- `madrid`: control point.
- `scale: 11132`: native ERA5-Land resolution (~0.1°). Keep it so GEE does not resample.

**Notes**

- Band name in GEE is `volumetric_soil_water_layer_1`, equivalent to `swvl1` in the original ERA5-Land files.
- `filterDate` end date is exclusive.
- ERA5-Land daily aggregates in GEE start on 1950-01-02, so the 1950 series has no 1950-01-01 value.
- The map layer label (`swvl1 1950-01-15`) does not match the date loaded (`1950-01-02`). Update the label when you change the date.

## `NOAA_SST_Test.js`

Checks daily mean SST over rectangular regions from NOAA OISST v2.1.

**What it does**

Computes the spatial mean SST (°C) for one day over eight regions and prints a table (region, `sst_mean`) to the Console.

| Region | Lat (°N) | Lon (0–360) |
|---|---|---|
| Sole | 36–44 | 355–10 |
| Campos | 33–45 | 350–25 |
| Pastor WMED | 30–45 | 354.4–10 |
| Pastor CMED | 30–45 | 10–22 |
| Pastor EMED | 30–41 | 22–36 |
| Ossó NW | 42–52 | 308–320 |
| Ossó SE | 35–42 | 325–340 |
| Krüger | 45–60 | 320–345 |

**Parameters to edit**

- `DATE`: day to analyze (`YYYY-MM-DD`). OISST starts on 1981-09-01.
- `REGIONS`: `[minLat, maxLat, minLon, maxLon]`.

**Notes**

- Longitudes use NOAA's 0–360 convention. If `minLon > maxLon`, the box crosses the Greenwich meridian and the script splits it into two polygons.
- Polygons use planar edges (`geodesic = false`) so borders follow constant lat/lon lines.
- `scale: 27830` m is roughly the native 0.25° OISST resolution.
- The dataset scale factor (0.01) is applied in the script, so results are in °C.
- Land pixels are masked in the dataset and ignored in the mean.

## Comparing against the pipeline

For a valid comparison, match these between GEE and the Python/R output:

- Same date, variable and bounding box or region definition.
- Same longitude convention (−180–180 vs 0–360).
- Same units (m³/m³ for soil moisture, °C for SST, after scaling).
- Same spatial aggregation (mean over valid, unmasked cells).

Small differences are expected from resampling, masking and floating-point rounding. Large differences usually point to a mismatch in region, longitude convention, date or scale factor.

## Data sources

- ERA5-Land: Muñoz Sabater, J. (2019), Copernicus Climate Change Service (C3S) Climate Data Store.
- NOAA OISST v2.1: Huang et al. (2021), *Journal of Climate*; NOAA National Centers for Environmental Information.

## Licence

Add a licence of your choice (e.g. MIT) before making the repository public.
