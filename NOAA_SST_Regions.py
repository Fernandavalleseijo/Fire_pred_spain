"""Export daily NOAA OISST means and anomalies for three North Atlantic regions."""

# This script reads the public NOAA OISST Icechunk store and writes a CSV.
# It requires Python 3.12 or newer because Icechunk 2.x requires that version.
# pip install "icechunk>=2.0" xarray zarr "dask[array]" pandas

import argparse
from datetime import date
from pathlib import Path
import sys

if sys.version_info < (3, 12):
    raise SystemExit(
        "Python 3.12 or newer is required. "
        'Install the dependencies with: pip install "icechunk>=2.0" '
        'xarray zarr "dask[array]" pandas'
    )

import icechunk
import numpy as np
import pandas as pd
import xarray as xr
import zarr


STORE_BUCKET = "us-east-1.opendata.source.coop"
STORE_PREFIX = "ocean-icechunks/noaa-oisst/oisst.icechunk"
NOAA_CONTAINER = (
    "s3://noaa-cdr-sea-surface-temp-optimum-interpolation-pds/"
)

# NOAA OISST v2.1 daily data begin on 1981-09-01.
START_DATE = "1981-09-01"
END_DATE = "2025-12-31"

# Bounds are (minimum latitude, maximum latitude, minimum longitude,
# maximum longitude), with longitude expressed in the dataset's 0–360 system.
REGIONS = {
    "Ossó NW": (42.0, 52.0, 308.0, 320.0),
    "Ossó SE": (35.0, 42.0, 325.0, 340.0),
    "Krüger": (45.0, 60.0, 320.0, 345.0),
}
OUTPUT_COLUMNS = [
    "date",
    *(f"SST {name}" for name in REGIONS),
    *(f"Anomalía SST {name}" for name in REGIONS),
]


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--start-date", default=START_DATE, help="YYYY-MM-DD")
    parser.add_argument("--end-date", default=END_DATE, help="YYYY-MM-DD")
    parser.add_argument(
        "--output",
        type=Path,
        help="Output CSV path (defaults to a date-named CSV beside this script).",
    )
    arguments = parser.parse_args()
    try:
        start_date = date.fromisoformat(arguments.start_date).isoformat()
        end_date = date.fromisoformat(arguments.end_date).isoformat()
    except ValueError:
        parser.error("start-date and end-date must use the YYYY-MM-DD format")
    if start_date > end_date:
        parser.error("start-date must be on or before end-date")

    output_csv = arguments.output or Path(__file__).with_name(
        f"NOAA_OISST_Regions_{start_date}_to_{end_date}.csv"
    )

    if not hasattr(icechunk, "s3_storage"):
        raise RuntimeError(
            'This script requires icechunk >= 2.0. '
            'Install it with: pip install "icechunk>=2.0"'
        )

    zarr.config.set({"async.concurrency": 8})
    config = icechunk.RepositoryConfig.default()
    config.set_virtual_chunk_container(
        icechunk.VirtualChunkContainer(
            url_prefix=NOAA_CONTAINER,
            store=icechunk.s3_store(region="us-east-1", anonymous=True),
        )
    )
    repository = icechunk.Repository.open(
        icechunk.s3_storage(
            bucket=STORE_BUCKET,
            prefix=STORE_PREFIX,
            region="us-east-1",
            anonymous=True,
        ),
        config=config,
        authorize_virtual_chunk_access=icechunk.containers_credentials(
            {NOAA_CONTAINER: icechunk.s3_anonymous_credentials()}
        ),
    )
    store = repository.readonly_session("main").store
    print("Opening NOAA OISST daily data...", flush=True)
    daily = xr.open_dataset(
        store,
        group="daily",
        engine="zarr",
        consolidated=False,
        zarr_format=3,
    )
    print("Opened daily data; preparing the regional subsets...", flush=True)

    try:
        missing_variables = {"sst", "anom"} - set(daily.data_vars)
        if missing_variables:
            raise ValueError(
                f"Daily dataset is missing required variables: "
                f"{', '.join(sorted(missing_variables))}"
            )

        if start_date < START_DATE or end_date > END_DATE:
            raise ValueError(
                f"The requested range must be within {START_DATE} "
                f"and {END_DATE}."
            )

        monthly_tables: list[pd.DataFrame] = []
        first_month = pd.Timestamp(start_date).to_period("M").start_time
        months = pd.date_range(first_month, end_date, freq="MS")
        for index, month_start in enumerate(months, start=1):
            batch_start = max(month_start, pd.Timestamp(start_date))
            batch_end = min(
                month_start + pd.offsets.MonthEnd(0),
                pd.Timestamp(end_date),
            )
            monthly_source = daily[["sst", "anom"]].sel(
                time=slice(
                    batch_start.strftime("%Y-%m-%d"),
                    batch_end.strftime("%Y-%m-%d"),
                )
            )
            if monthly_source.sizes.get("time", 0) == 0:
                raise ValueError(
                    "No daily data found between "
                    f"{batch_start:%Y-%m-%d} and {batch_end:%Y-%m-%d}."
                )

            month_table = pd.DataFrame(
                {
                    "date": pd.to_datetime(monthly_source.time.values).strftime(
                        "%d/%m/%Y"
                    )
                }
            )
            for name, (lat_min, lat_max, lon_min, lon_max) in REGIONS.items():
                region = monthly_source.where(
                    (monthly_source.lat >= lat_min)
                    & (monthly_source.lat <= lat_max)
                    & (monthly_source.lon >= lon_min)
                    & (monthly_source.lon <= lon_max),
                    drop=True,
                ).squeeze("zlev", drop=True)
                latitude_weights = xr.DataArray(
                    np.cos(np.deg2rad(region.lat)),
                    coords={"lat": region.lat},
                    dims=("lat",),
                )
                daily_means = (
                    region.weighted(latitude_weights)
                    .mean(dim=("lat", "lon"), skipna=True)
                    .compute()
                )
                month_table[f"SST {name}"] = daily_means["sst"].values
                month_table[f"Anomalía SST {name}"] = daily_means["anom"].values

            monthly_tables.append(month_table[OUTPUT_COLUMNS])
            if index % 12 == 0 or index == len(months):
                print(f"Processed {index}/{len(months)} months", flush=True)

        table = pd.concat(monthly_tables, ignore_index=True)
        expected_dates = pd.date_range(
            start_date, end_date, freq="D"
        ).strftime("%d/%m/%Y")
        if table["date"].tolist() != expected_dates.tolist():
            raise ValueError(
                "The source did not return one row for every requested day; "
                "CSV was not written."
            )

        table.to_csv(output_csv, index=False)
    finally:
        daily.close()

    print(f"Saved {len(table)} daily rows to {output_csv}")


if __name__ == "__main__":
    main()
