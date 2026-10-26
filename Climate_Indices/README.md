# Climate Indices and Wildfire Data Analysis

## Overview

This repository provides a reproducible workflow to collect, organize, explore, and prepare large-scale climate indices for comparison with wildfire data.

The project builds on NOAA climate-index datasets and R scripts for data preparation and visualization.

## Research objectives

1. Organize climate-index datasets into consistent, documented formats.
2. Explore temporal trends, variability, anomalies, and missing observations.
3. Prepare datasets suitable for statistical analysis of climate–fire relationships.
5. Provide reproducible visualizations and data-quality checks.

## Climate indices

| Index | Temporal coverage (Temporal resolution) | Description | Reference |
|---|---|---|---|
| **SOI (Southern Oscillation Index)** | 1951–2026 (Monthly) | Standardized index based on sea level pressure differences between Tahiti and Darwin. Negative (positive) values indicate El Niño (La Niña) conditions and are associated with anomalously warm (cold) eastern equatorial Pacific SSTs. | Troup (1965) |
| **Niño 3.4 SST Anomalies** | 1982–2026 (Monthly) | Sea surface temperature anomalies in the Niño 3.4 region. Positive anomalies ≥ 0.5°C indicate El Niño conditions, while negative anomalies indicate La Niña conditions. | Trenberth (1997) |
| **ONI / RONI** | 1950–2026 (3-month running mean) | ONI identifies ENSO events based on sustained SST anomalies in the Niño 3.4 region. RONI refines this metric by normalizing SST anomalies relative to tropical mean ocean temperatures (20°N–20°S). | Trenberth (1997); van Oldenborgh et al. (2021) |
| **OLR (Outgoing Longwave Radiation)** | 1974–2026 (Monthly) | Satellite-derived anomaly index representing tropical convection. Area averages over the central equatorial Pacific (160°E–160°W). Negative anomalies indicate enhanced convection and cloudiness (El Niño-like conditions), while positive anomalies indicate suppressed convection. | Chelliah & Arkin (1992) |
| **MEI (Multivariate ENSO Index)** | 1979–2026 (Monthly) | Composite index based on six atmospheric and oceanic variables (SST, SLP, surface air temperature, zonal and meridional winds, and cloudiness) describing ENSO variability. | Wolter & Timlin (2011) |
| **AMO (Atlantic Multidecadal Oscillation)** | 1856–2022 (Monthly) | Long-term variability in North Atlantic sea surface temperatures associated with multidecadal changes in hydroclimate, including drought frequency and intensity. | Schlesinger & Ramankutty (1994) |
| **NAO (North Atlantic Oscillation)** | 1950–2026 (Monthly) | It combines parts of the East-Atlantic and West Atlantic patterns. It consists of a north–south dipole of anomalies, with one center located over Greenland and the other center of opposite sign spanning the central latitudes of the North Atlantic between 35°N and 40°N. | Hurrell (1995) |
| **AAO (Antarctic Oscillation)** | 1979–2026 (Monthly) | The loading pattern of the AAO is defined as the leading mode of Empirical Orthogonal Function (EOF) analysis of monthly mean 700 hPa height during the 1979–2000 period. | Kingtse C. Mo (year and publication details to be verified) |


## Data sources

The initial source for the climate data is NOAA Physical Sciences Laboratory:

- NOAA monthly climate time series: https://psl.noaa.gov/data/timeseries/month/
- NOAA Climate Prediction Center ENSO information: https://www.cpc.ncep.noaa.gov/products/analysis_monitoring/ensostuff/

## Reproducibility

The workflow uses R and the packages `dplyr`, `tidyr`, `ggplot2`, `readr`, and `lubridate`.

## License and attribution

Cite NOAA and the original wildfire-data providers when using their data. Add an explicit repository license after deciding how the code and any redistributed data may be shared.
