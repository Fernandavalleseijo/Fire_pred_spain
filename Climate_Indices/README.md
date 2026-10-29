## Overview

Provides a reproducible R workflow to collect, reformat, and prepare large-scale climate indices for comparison with wildfire data.

The script `ENSO_data_to_csv.R` reads the raw index files (NOAA Physical Sciences Laboratory and the WeMO index monitoring service), converts them into a consistent tidy format, and writes one CSV per index.

## Research objectives

1. Organize climate-index datasets into consistent, documented formats.
2. Standardize temporal fields (`year`, `month`) so every index can be joined directly with wildfire data.
3. Prepare datasets suitable for statistical analysis of climate–fire relationships.
4. Document data coverage and quality (missing values, observed vs. extended records).

## Climate indices

| Index | Temporal coverage (resolution) | Description | Reference |
|---|---|---|---|
| **SOI (Southern Oscillation Index)** | 1951–2026 (Monthly) | Standardized index based on sea level pressure differences between Tahiti and Darwin. Negative (positive) values indicate El Niño (La Niña) conditions. Both the standardized and anomaly versions are provided. | Troup (1965) |
| **Niño 3.4 SST Anomalies** | 1982–2026 (Monthly) | Sea surface temperature anomalies in the Niño 3.4 region. Positive anomalies ≥ 0.5 °C indicate El Niño conditions, negative anomalies indicate La Niña conditions. | Trenberth (1997) |
| **RONI (Relative Oceanic Niño Index)** | 1950–2026 (3-month running mean, seasonal) | Identifies ENSO events from sustained SST anomalies in the Niño 3.4 region, normalized relative to tropical mean ocean temperatures (20°N–20°S). | Trenberth (1997); van Oldenborgh et al. (2021) |
| **OLR (Outgoing Longwave Radiation)** | 1974–2026 (Monthly) | Satellite-derived index of tropical convection averaged over the central equatorial Pacific (160°E–160°W). Negative anomalies indicate enhanced convection (El Niño-like), positive anomalies indicate suppressed convection. Both standard and anomaly versions are provided. | Chelliah & Arkin (1992) |
| **MEI.v2 (Multivariate ENSO Index)** | 1979–2026 (Bimonthly) | Composite index based on atmospheric and oceanic variables (SST, SLP, surface winds, outgoing longwave radiation) describing ENSO variability. Data are organized in overlapping two-month seasons. | Wolter & Timlin (2011) |
| **AMO (Atlantic Multidecadal Oscillation)** | 1856–2022 (Monthly) | Multidecadal variability of North Atlantic sea surface temperatures, associated with changes in hydroclimate, including drought frequency and intensity. | Schlesinger & Ramankutty (1994) |
| **NAO (North Atlantic Oscillation)** | 1950–2026 (Monthly) | North–south dipole of pressure anomalies, with one center over Greenland and the other, of opposite sign, over the central North Atlantic (35°N–40°N). | Hurrell (1995) |
| **AAO (Antarctic Oscillation)** | 1979–2026 (Monthly) | Leading mode of Empirical Orthogonal Function (EOF) analysis of monthly mean 700 hPa height over the Southern Hemisphere extratropics (loading pattern defined for 1979–2000). | Mo (year and publication details to be verified) |
| **SCAND (Scandinavian pattern)** | 1950–2026 (Monthly) | Teleconnection pattern with a main center over Scandinavia and weaker centers of opposite sign over western Europe and eastern Russia/western Mongolia. | Barnston & Livezey (1987) |
| **EA (East Atlantic pattern)** | 1950–2026 (Monthly) | North–south dipole of anomaly centers spanning the North Atlantic from east to west, structurally similar to the NAO but displaced southeastward. | Barnston & Livezey (1987) |
| **WeMOi (Western Mediterranean Oscillation index)** | 1821–2026 (Monthly) | Pressure-based index for the western Mediterranean, linked to rainfall in the Iberian Peninsula. Observed values run to December 2020; later values are a machine-learning extension. Includes `source` and `reliability` flags. | Martín-Vide & López-Bustins (2006); Stachnik et al. (2026, preprint) |

## Data sources

Uploaded in the "Data" folder or search for updated data at: 

- NOAA Physical Sciences Laboratory, monthly climate time series: https://psl.noaa.gov/data/timeseries/month/
- NOAA Climate Prediction Center, ENSO information: https://www.cpc.ncep.noaa.gov/products/analysis_monitoring/ensostuff/
- WeMO index monitoring (Centro Andaluz de Estudios Ambientales / Grup de Climatologia, Universitat de Barcelona): https://centroandaluzengloba.org/en/wemo-index-monitoring/

## Workflow

`ENSO_data_to_csv.R` runs in four steps for each index:

1. **Read** the raw file (`.ascii` or `.txt`) from the input folder.
2. **Reshape** wide tables (one column per month) to long format with `pivot_longer()`, and convert month names (JAN–DEC) to numbers (1–12).
3. **Standardize** the column names to `year`, `month`, and the index name (e.g. `aao`, `nao`, `soi_st`, `soi_ano`, `olr_st`, `olr_ano`).
4. **Write** one CSV per index to the output folder.

Missing values coded as `-999.9` are converted to `NA`.

### Index-specific handling

- **SOI and OLR:** the standard and anomaly files are joined by `year` and `month` into a single CSV.
- **RONI:** kept as a seasonal dataset (`season`, `year`, `roni`).
- **MEI.v2:** kept in two-month season format (`year`, `months`, `mei`).
- **WeMOi:** metadata lines starting with `#` are skipped, the separator (tab or comma) is detected automatically, and `date` is split into `year` and `month` and then removed. The `source` (`observed`, `extended`, `gap`) and `reliability` (`reliable`, `moderate`, `model`) columns are kept. Months with no value remain as `NA`, so the monthly series stays continuous.

### Output files

All CSVs are written to the output folder (`path_csv`):

| File | Columns |
|---|---|
| `aao_NOAA_1979_2026.csv` | year, month, aao |
| `nao_NOAA_1950_2026.csv` | year, month, nao |
| `sst_NOAA_1982_2026.csv` | year, month, SST columns |
| `soi_NOAA_1951_2026.csv` | year, month, soi_st, soi_ano |
| `olr_NOAA_1974_2026.csv` | year, month, olr_st, olr_ano |
| `RONI_NOAA_1950_2026.csv` | season, year, roni |
| `MEI_NOAA_1950_2026.csv` | year, months, mei |
| `amo_NOAA_1856_2022.csv` | year, month, amo |
| `scand_NOAA_1850_2026.csv` | year, month, scand |
| `ea_NOAA_1950_2026.csv` | year, month, ea |
| `wemoi_1821_2026.csv` | year, month, wemoi, source, reliability |

## Reproducibility

The workflow uses R and the packages `dplyr`, `tidyr`, and `ggplot2`.

To run it:

1. Download the raw files from the sources above into one folder.
2. Edit `path` (raw files) and `path_csv` (output) at the top of `ENSO_data_to_csv.R`.
3. Run the script. The output CSVs are written to `path_csv`.

Raw file names must match those in the script. If you download a newer version of a file, update the name (including the year range) in both the file name and the script.

## License and attribution

Cite NOAA and the original data providers when using their data.

The WeMOi data are distributed under the Open Database License (ODbL) v1.0 (https://opendatacommons.org/licenses/odbl/1-0/). Attribution: Climatic Research Unit, University of East Anglia, and Grup de Climatologia, Universitat de Barcelona.

Add an explicit repository license after deciding how the code and any redistributed data may be shared.
