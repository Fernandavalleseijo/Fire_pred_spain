# GEE validation scripts: ERA5-Land soil moisture, NOAA OISST SST and SPEIbase

Three small Google Earth Engine (GEE) Code Editor scripts used as an **independent control** of the Python cloud-processing pipelines for soil moisture, sea surface temperature (SST) and the SPEI drought index. They pull the same variable, date and region from GEE so the values can be compared against the pipeline output.

They are **checks, not production code**: each one reads a single day or month (or a short series), prints results to the Console, and is meant to be compared against the Python/R output by hand.

## Contents

| File | Dataset | Variable | Purpose |
|---|---|---|---|
| `ERA5-Land_SM_test.js` | `ECMWF/ERA5_LAND/DAILY_AGGR` | `volumetric_soil_water_layer_1` (`swvl1`, m³/m³) | Check soil moisture for one day, one point (Madrid), a 1-year series and the spatial mean over Spain |
| `NOAA_SST_Test.js` | `NOAA/CDR/OISST/V2_1` | `sst` (scale factor 0.01 → °C) | Check mean SST over eight rectangular regions for one day |
| `CSIC-SPEIbasev2.11_SPEI_Test.js` | `CSIC/SPEI/2_11` | `SPEI_XX_month` (SPEI timescale XX, dimensionless) | Check the SPEI map of one month over Spain and the value at one grid-cell centre |

## How to run

GEE Code Editor scripts cannot be executed directly from GitHub.

1. Open the [GEE Code Editor](https://code.earthengine.google.com/) (requires a GEE-enabled account).
2. Create a new script and paste the contents of the `.js` file.
3. Edit the parameters (see below) and click **Run**.
4. Read the results in the **Console** tab (and the **Map** for the ERA5-Land and SPEI layers).

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

## `GEE_SPEI_map_test.js`

Checks the Standardized Precipitation-Evapotranspiration Index (SPEI) from SPEIbase v2.11 (CSIC), the same release downloaded and cropped by the Python script (`SPEIbase_v2_11_Spain_speiXX_1950-2024.nc`).

**What it does**

1. Loads one month of the chosen SPEI timescale (default: SPEI-12, August 2022).
2. Shows it as a map layer clipped to the Spain bounding box, with a diverging red–blue palette (`min: -3`, `max: 3`), country borders, Spain outline and a legend.
3. Prints the SPEI value at one grid-cell centre (`-3.75, 40.25`, near Madrid) to the Console to compare with the NetCDF.

**Parameters to edit**

- `SCALE`: SPEI timescale in months (1–48). The band name (`SPEI_01_month` … `SPEI_48_month`) is built from it.
- `DATE`: month to map (`YYYY-MM-01`). The collection is monthly, with one image per month.
- `bbox`: Spain bounding box `[-9.5, 35.8, 4.5, 43.9]` (lon min, lat min, lon max, lat max), the same as in the Python crop. At 0.5° this is expected to give 28 × 16 cells.
- `pt`: control point. Keep it at a cell centre (see notes).
- `scale: 55660` m in `reduceRegion`: native SPEIbase resolution (0.5°). Keep it so GEE does not resample.

**Notes**

- GEE asset `CSIC/SPEI/2_11` covers 1901-01 to 2024-12, so it includes the whole 1950–2024 period of the pipeline files. Older releases (`CSIC/SPEI/2_10`, `2_9`, `2_8`) are different versions: do not compare them against the v2.11 NetCDF.
- Band range in the catalog is about ±2.33, so the ±3 colour stretch leaves the extremes of the palette unused. It is kept to match the colours of the R map.
- SPEIbase cell centres lie at `.25` and `.75`. Using a point at a cell centre avoids picking a different cell than the NetCDF extraction at a cell edge.
- `filterDate` end date is exclusive (`DATE` + 1 month).
- Country borders come from `USDOS/LSIB_SIMPLE/2017` (simplified) and may differ slightly from the Natural Earth borders used in the R script. They are drawn only for display and do not affect the SPEI values.
- Unlike the other two scripts, the SPEI check is mostly visual (map) plus one point value. For a numeric check of the whole area, add a `reduceRegion` with `ee.Reducer.mean()` over `bbox` and compare it with the same mean in the NetCDF.

**Comparing the point value in R**

```r
r <- terra::rast("SPEIbase_v2_11_Spain_spei12_1950-2024.nc", subds = "spei12")
idx <- which(format(terra::time(r), "%Y-%m") == "2022-08")
terra::extract(r[[idx]], cbind(-3.75, 40.25))
```

## Comparing against the pipeline

For a valid comparison, match these between GEE and the Python/R output:

- Same date (or month), variable (or SPEI timescale) and bounding box or region definition.
- Same dataset version (e.g. SPEIbase v2.11 in both).
- Same longitude convention (−180–180 vs 0–360).
- Same units (m³/m³ for soil moisture, °C for SST after scaling, dimensionless for SPEI).
- Same spatial aggregation (mean over valid, unmasked cells) or the same grid-cell centre for point checks.

Small differences are expected from resampling, masking and floating-point rounding. Large differences usually point to a mismatch in region, longitude convention, date, timescale, dataset version or scale factor.

## Data sources

- ERA5-Land: Muñoz Sabater, J. (2019), Copernicus Climate Change Service (C3S) Climate Data Store.
- NOAA OISST v2.1: Huang et al. (2021), *Journal of Climate*; NOAA National Centers for Environmental Information.
- SPEIbase v2.11: Vicente-Serrano, S.M., Beguería, S., López-Moreno, J.I. (2010), *Journal of Climate*; Consejo Superior de Investigaciones Científicas (CSIC), https://spei.csic.es/database.html.
