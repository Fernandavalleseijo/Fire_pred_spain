"""Export daily North Atlantic SST and anomaly means from NOAA OISST v2.1."""

# This script reads the public NOAA OISST Icechunk store and writes a CSV.
# It requires Python 3.12 or newer because Icechunk 2.x requires that version.
# pip install "icechunk>=2.0" xarray zarr "dask[array]" pandas

# argparse reads optional command-line settings such as the date range.
import argparse
# date validates dates entered as YYYY-MM-DD.
from datetime import date
# Path builds the output file path in a platform-independent way.
from pathlib import Path
# sys provides the Python version check below.
import sys

# Stop early with an installation hint if the interpreter is too old.
if sys.version_info < (3, 12):
    raise SystemExit(
        "Python 3.12 or newer is required. "
        'Install the dependencies with: pip install "icechunk>=2.0" '
        'xarray zarr "dask[array]" pandas'
    )

# icechunk connects to the public Icechunk repository.
import icechunk
# NumPy calculates cosine-based latitude weights.
import numpy as np
# pandas formats dates and assembles the final CSV table.
import pandas as pd
# xarray opens and processes the multidimensional daily dataset.
import xarray as xr
# zarr configures concurrent cloud requests used to read the data.
import zarr


# Source Cooperative bucket containing the Icechunk repository.
STORE_BUCKET = "us-east-1.opendata.source.coop"
# Path to the NOAA OISST repository within that bucket.
STORE_PREFIX = "ocean-icechunks/noaa-oisst/oisst.icechunk"
# NOAA's public S3 bucket holding the source data referenced by the store.
NOAA_CONTAINER = (
    "s3://noaa-cdr-sea-surface-temp-optimum-interpolation-pds/"
)

# Default inclusive date range for the export.
START_DATE = "2000-01-01"
END_DATE = "2025-12-31"
# North Atlantic latitude bounds, in degrees north.
LATITUDE_MIN = 0.0
LATITUDE_MAX = 70.0
# Longitude bounds in the dataset's 0–360 degree convention:
# 280° is 80°W and 360° is 0° (Greenwich).
LONGITUDE_MIN = 280.0
LONGITUDE_MAX = 360.0


def main() -> None:
    # Allow the user to override the dates or output location when running
    # the script from a terminal.
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--start-date", default=START_DATE, help="YYYY-MM-DD")
    parser.add_argument("--end-date", default=END_DATE, help="YYYY-MM-DD")
    parser.add_argument(
        "--output",
        type=Path,
        help="Output CSV path (defaults to a date-named CSV beside this script).",
    )
    # Read and validate the supplied command-line arguments.
    arguments = parser.parse_args()
    try:
        start_date = date.fromisoformat(arguments.start_date).isoformat()
        end_date = date.fromisoformat(arguments.end_date).isoformat()
    except ValueError:
        parser.error("start-date and end-date must use the YYYY-MM-DD format")
    if start_date > end_date:
        parser.error("start-date must be on or before end-date")
    # By default, save beside this script and include the selected dates in
    # the filename so exports for different ranges do not overwrite each other.
    output_csv = arguments.output or Path(__file__).with_name(
        f"NOAA_OISST_North_Atlantic_{start_date}_to_{end_date}.csv"
    )

    # Confirm the installed Icechunk version exposes the v2 S3 API this
    # script uses, and give an actionable error if it does not.
    if not hasattr(icechunk, "s3_storage"):
        raise RuntimeError(
            'This script requires icechunk >= 2.0. '
            'Install it with: pip install "icechunk>=2.0"'
        )

    # Limit simultaneous Zarr requests to reduce the load while reading.
    zarr.config.set({"async.concurrency": 8})
    # Start with Icechunk's default repository configuration.
    config = icechunk.RepositoryConfig.default()
    # Tell Icechunk that references into NOAA's bucket should be read
    # anonymously from the specified AWS region.
    config.set_virtual_chunk_container(
        icechunk.VirtualChunkContainer(
            url_prefix=NOAA_CONTAINER,
            store=icechunk.s3_store(region="us-east-1", anonymous=True),
        )
    )
    # Open the Source Cooperative repository and authorize its NOAA
    # virtual references using anonymous public S3 access.
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
    # Open a read-only snapshot of the main branch; no remote data is changed.
    store = repository.readonly_session("main").store
    print("Opening NOAA OISST daily data...", flush=True)
    # Read only the daily group; xarray keeps the data lazy until calculations
    # are requested, and uses the Zarr v3 format of this store.
    daily = xr.open_dataset(
        store,
        group="daily",
        engine="zarr",
        consolidated=False,
        zarr_format=3,
    )
    print("Opened daily data; preparing the North Atlantic subset...", flush=True)

    try:
        # Check that both requested data variables exist before processing.
        missing_variables = {"sst", "anom"} - set(daily.data_vars)
        if missing_variables:
            raise ValueError(
                f"Daily dataset is missing required variables: "
                f"{', '.join(sorted(missing_variables))}"
            )

        # Keep requested dates within the historical period this script
        # is intended to export.
        if start_date < START_DATE or end_date > END_DATE:
            raise ValueError(
                f"The requested range must be within {START_DATE} "
                f"and {END_DATE}."
            )

        # Process one calendar month at a time to avoid loading the entire
        # multi-decade dataset into memory at once.
        monthly_tables: list[pd.DataFrame] = []
        # Find the first month boundary on or before the requested start date.
        first_month = pd.Timestamp(start_date).to_period("M").start_time
        # Generate the sequence of months through the requested end date.
        months = pd.date_range(first_month, end_date, freq="MS")
        # For each month, select its overlap with the requested date range.
        for index, month_start in enumerate(months, start=1):
            batch_start = max(month_start, pd.Timestamp(start_date))
            batch_end = min(
                month_start + pd.offsets.MonthEnd(0),
                pd.Timestamp(end_date),
            )
            # Select SST and anomaly for this month's dates before applying
            # the spatial filter, minimizing unnecessary reads.
            monthly_source = daily[["sst", "anom"]].sel(
                time=slice(
                    batch_start.strftime("%Y-%m-%d"),
                    batch_end.strftime("%Y-%m-%d"),
                )
            )
            # Stop rather than silently producing an incomplete CSV if the
            # source has no data for this requested month.
            if monthly_source.sizes.get("time", 0) == 0:
                raise ValueError(
                    "No daily data found between "
                    f"{batch_start:%Y-%m-%d} and {batch_end:%Y-%m-%d}."
                )
            # Keep grid cells inside the chosen latitude-longitude box.
            # squeeze removes the one-element zlev (depth) dimension.
            region = monthly_source.where(
                (monthly_source.lat >= LATITUDE_MIN)
                & (monthly_source.lat <= LATITUDE_MAX)
                & (monthly_source.lon >= LONGITUDE_MIN)
                & (monthly_source.lon <= LONGITUDE_MAX),
                drop=True,
            ).squeeze("zlev", drop=True)
            # A regular latitude-longitude grid has smaller physical cells
            # toward the poles; cosine(latitude) approximates cell area.
            latitude_weights = xr.DataArray(
                np.cos(np.deg2rad(region.lat)),
                coords={"lat": region.lat},
                dims=("lat",),
            )
            # Calculate each date's area-weighted spatial mean for both
            # variables, ignoring land/missing cells, and execute the reads.
            daily_means = (
                region.weighted(latitude_weights)
                .mean(dim=("lat", "lon"), skipna=True)
                .compute()
            )
            # Convert this month's results into a regular table.
            month_table = daily_means.to_dataframe().reset_index()
            # Format dates as day/month/year for the requested CSV.
            month_table["date"] = pd.to_datetime(
                month_table["time"]
            ).dt.strftime("%d/%m/%Y")
            # Rename the columns and keep exactly the three requested fields.
            monthly_tables.append(
                month_table.rename(
                    columns={"sst": "mean T", "anom": "anomaly T"}
                )[["date", "mean T", "anomaly T"]]
            )
            # Print progress once per year of processed data and at completion.
            if index % 12 == 0 or index == len(months):
                print(f"Processed {index}/{len(months)} months", flush=True)

        # Combine the monthly pieces into one chronological table.
        table = pd.concat(monthly_tables, ignore_index=True)
        # Compare output dates to every expected day, including leap days.
        expected_dates = pd.date_range(
            start_date, end_date, freq="D"
        ).strftime("%d/%m/%Y")
        # Refuse to write a success-shaped partial result if any day is absent.
        if table["date"].tolist() != expected_dates.tolist():
            raise ValueError(
                "The source did not return one row for every requested day; "
                "CSV was not written."
            )

        # Write the final CSV without pandas' extra row-number column.
        table.to_csv(output_csv, index=False)
    finally:
        # Close the dataset even if an error occurs during processing.
        daily.close()

    # Report the number of exported days and the full output path.
    print(f"Saved {len(table)} daily rows to {output_csv}")


# Run the export only when this file is executed as a script, not imported.
if __name__ == "__main__":
    main()
