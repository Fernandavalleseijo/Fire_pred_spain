"""Save daily ERA5-Land soil-moisture maps for mainland Spain as NetCDF files."""

import argparse
from datetime import date
from getpass import getpass
import json
import os
from pathlib import Path
import sys

if sys.version_info < (3, 10):
    raise SystemExit("Python 3.10 or newer is required.")

import numpy as np
import pandas as pd
import xarray as xr


# The configured ARCO soil-water store first returned hourly data on this date.
START_DATE = "1950-01-02"
END_DATE = "2025-12-31"
# Default local destination for the daily NetCDF files.
DEFAULT_OUTPUT = Path(
    "/home/jose/Escritorio/UCM_Madrid/Soil_Mositure"
)
# The time-chunked store is suited to downloading spatial maps.
CHUNK_LAYOUT = "time"
DEFAULT_ZARR_URL = (
    "https://arco.datastores.ecmwf.int/"
    f"cadl-arco-{CHUNK_LAYOUT}-005/arco/reanalysis_era5_land/"
    f"sfc-soil-water/{CHUNK_LAYOUT}Chunked.zarr"
)
# Geographic bounds of the requested Spain-area rectangle.
LATITUDE_BOUNDS = (35.8, 43.9)
LONGITUDE_BOUNDS = (-9.5, 4.5)
# Keep each remote read to one day to minimize peak memory use.
BATCH_DAYS = 1

# Map output variable names to the possible names used by the source dataset.
SOIL_WATER_VARIABLES = {
    "swvl1": ("swvl1", "volumetric_soil_water_layer_1"),
    "swvl2": ("swvl2", "volumetric_soil_water_layer_2"),
    "swvl3": ("swvl3", "volumetric_soil_water_layer_3"),
    "swvl4": ("swvl4", "volumetric_soil_water_layer_4"),
}

# Add non-secret, snippet-specific xarray.open_zarr options here if needed.
OPEN_ZARR_OPTIONS: dict[str, object] = {}


def main() -> None:
    # Let users override the data URL, output directory, and date range
    # from the command line without editing the script.
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--zarr-url",
        default=os.environ.get("ERA5LAND_ZARR_URL", DEFAULT_ZARR_URL),
        help="CDS Zarr URL (defaults to the ERA5-Land soil-water store).",
    )
    parser.add_argument(
        "--output",
        type=Path,
        default=DEFAULT_OUTPUT,
        help=f"Output directory (default: {DEFAULT_OUTPUT}).",
    )
    parser.add_argument("--start-date", default=START_DATE, help="YYYY-MM-DD")
    parser.add_argument("--end-date", default=END_DATE, help="YYYY-MM-DD")
    arguments = parser.parse_args()

    # Validate the date range before opening the remote dataset.
    try:
        start_date = date.fromisoformat(arguments.start_date)
        end_date = date.fromisoformat(arguments.end_date)
    except ValueError:
        parser.error("start-date and end-date must use the YYYY-MM-DD format")
    if start_date.isoformat() < START_DATE or end_date.isoformat() > END_DATE:
        parser.error(f"The supported date range is {START_DATE} through {END_DATE}.")
    if start_date > end_date:
        parser.error("start-date must be on or before end-date")

    # Load optional fsspec settings from JSON; the API key is kept separate.
    storage_options_text = os.environ.get("ERA5LAND_ZARR_STORAGE_OPTIONS", "{}")
    try:
        storage_options = json.loads(storage_options_text)
    except json.JSONDecodeError as error:
        parser.error(f"ERA5LAND_ZARR_STORAGE_OPTIONS must be valid JSON: {error}")
    if not isinstance(storage_options, dict):
        parser.error("ERA5LAND_ZARR_STORAGE_OPTIONS must contain a JSON object")

    cds_api_key = os.environ.get("CDS_API_KEY")
    if not cds_api_key:
        cds_api_key = getpass("Introduce tu clave API de CDS: ").strip()
    if not cds_api_key:
        parser.error("La clave API de CDS no puede estar vacía.")
    if cds_api_key:
        # The CDS Zarr endpoint expects its API key in a bearer-token header.
        headers = storage_options.get("headers", {})
        if not isinstance(headers, dict):
            parser.error(
                "The headers setting in ERA5LAND_ZARR_STORAGE_OPTIONS "
                "must be a JSON object"
            )
        storage_options["headers"] = {
            **headers,
            "Authorization": f"Bearer {cds_api_key}",
        }

    open_options = dict(OPEN_ZARR_OPTIONS)
    if storage_options:
        open_options["storage_options"] = storage_options

    # Create the destination folder if it does not already exist.
    output_dir: Path = arguments.output
    output_dir.mkdir(parents=True, exist_ok=True)

    # Open the remote store lazily; xarray reads values only when requested.
    print("Opening ERA5-Land Zarr dataset...", flush=True)
    dataset = xr.open_zarr(
        arguments.zarr_url,
        chunks={},
        **open_options,
    )
    try:
        # Accept the coordinate labels used by common ERA5/ARCO dataset views.
        print(
            f"Zarr opened. Dataset dimensions: {dict(dataset.sizes)}. "
            "Identifying coordinates...",
            flush=True,
        )
        time_name = next(
            (name for name in ("time", "valid_time") if name in dataset.coords),
            None,
        )
        latitude_name = next(
            (name for name in ("latitude", "lat") if name in dataset.coords),
            None,
        )
        longitude_name = next(
            (name for name in ("longitude", "lon") if name in dataset.coords),
            None,
        )
        if time_name is None or latitude_name is None or longitude_name is None:
            raise ValueError(
                "Could not find time/valid_time and latitude/longitude "
                "coordinates in the Zarr dataset."
            )

        if time_name != "time":
            dataset = dataset.rename({time_name: "time"})
        coordinate_renames = {}
        if latitude_name != "latitude":
            coordinate_renames[latitude_name] = "latitude"
        if longitude_name != "longitude":
            coordinate_renames[longitude_name] = "longitude"
        if coordinate_renames:
            dataset = dataset.rename(coordinate_renames)

        # Convert the longitude coordinate to -180..180 for the Spain bounds.
        # These are small coordinate arrays, not the much larger data variables.
        latitude_values = np.asarray(dataset.latitude.values)
        longitude_values = np.asarray(dataset.longitude.values)
        normalized_longitudes = (
            (longitude_values + 180) % 360
        ) - 180
        latitude_indices = np.flatnonzero(
            (latitude_values >= LATITUDE_BOUNDS[0])
            & (latitude_values <= LATITUDE_BOUNDS[1])
        )
        longitude_indices = np.flatnonzero(
            (normalized_longitudes >= LONGITUDE_BOUNDS[0])
            & (normalized_longitudes <= LONGITUDE_BOUNDS[1])
        )
        if latitude_indices.size == 0 or longitude_indices.size == 0:
            raise ValueError("The selected Spain bounding box contains no grid cells.")
        if not np.all(np.diff(latitude_indices) == 1):
            raise ValueError("Spain latitude cells are not contiguous in the source grid.")

        # A -180..180 region can cross the source grid's 0/360 seam.
        # Separate its selected indices into contiguous ranges for efficient reads.
        longitude_runs = np.split(
            longitude_indices,
            np.flatnonzero(np.diff(longitude_indices) != 1) + 1,
        )
        longitude_segments: list[tuple[slice, np.ndarray, bool]] = []
        for run in longitude_runs:
            selected_longitudes = normalized_longitudes[run]
            reverse = (
                selected_longitudes.size > 1
                and selected_longitudes[0] > selected_longitudes[-1]
            )
            if reverse:
                selected_longitudes = selected_longitudes[::-1]
            longitude_segments.append(
                (
                    slice(int(run[0]), int(run[-1]) + 1),
                    selected_longitudes,
                    reverse,
                )
            )
        longitude_segments.sort(key=lambda segment: segment[1][0])

        # Latitude cells occupy one contiguous range in this regular grid.
        latitude_slice = slice(
            int(latitude_indices[0]),
            int(latitude_indices[-1]) + 1,
        )
        print(
            "Spain grid selection prepared without sorting the full dataset "
            f"({latitude_indices.size} latitude x "
            f"{longitude_indices.size} longitude cells in "
            f"{len(longitude_segments)} longitude block(s)).",
            flush=True,
        )
        # Check time ordering once; later selections must follow its direction.
        source_times = pd.DatetimeIndex(dataset.time.values)
        if not (
            source_times.is_monotonic_increasing
            or source_times.is_monotonic_decreasing
        ):
            raise ValueError("The source time coordinate is not monotonic.")
        time_descending = source_times.is_monotonic_decreasing
        print(
            "Spain subset ready. Resolving the four soil-water layers...",
            flush=True,
        )

        # Resolve each requested soil-water layer to a variable in the source.
        resolved_variables: dict[str, str] = {}
        missing_variables: list[str] = []
        for output_name, candidates in SOIL_WATER_VARIABLES.items():
            source_name = next(
                (candidate for candidate in candidates if candidate in dataset.data_vars),
                None,
            )
            if source_name is None:
                missing_variables.append(" or ".join(candidates))
            else:
                resolved_variables[output_name] = source_name
        if missing_variables:
            raise ValueError(
                "Missing soil-water variables: "
                f"{', '.join(missing_variables)}. "
                f"Available data variables: {', '.join(dataset.data_vars)}"
            )

        print(
            f"Using layers {', '.join(resolved_variables.values())}; "
            "processing the requested years...",
            flush=True,
        )

        for year in range(start_date.year, end_date.year + 1):
            # Clip this calendar year to the user-selected date range.
            period_start = max(start_date, date(year, 1, 1))
            period_end = min(end_date, date(year, 12, 31))
            expected_days = pd.date_range(period_start, period_end, freq="D")
            # Existing daily files are skipped, allowing interrupted runs to resume.
            missing_paths = [
                (day, output_dir / f"ERA5Land_SM_Spain_{day:%Y%m%d}.nc")
                for day in expected_days
                if not (output_dir / f"ERA5Land_SM_Spain_{day:%Y%m%d}.nc").exists()
            ]
            if not missing_paths:
                print(
                    f"Year {year}: all daily files already exist; skipping.",
                    flush=True,
                )
                continue

            print(
                f"Year {year}: {len(missing_paths)} of {len(expected_days)} "
                "daily maps remain.",
                flush=True,
            )
            days_saved = 0
            month_starts = pd.date_range(
                period_start.strftime("%Y-%m-01"),
                period_end,
                freq="MS",
            )
            for month_index, month_start in enumerate(month_starts, start=1):
                # Limit this iteration to the requested portion of this month.
                month_end = min(
                    period_end,
                    (month_start + pd.offsets.MonthEnd(0)).date(),
                )
                month_start_date = max(period_start, month_start.date())
                month_days = pd.date_range(
                    month_start_date,
                    month_end,
                    freq="D",
                )
                month_missing_paths = [
                    (day, output_dir / f"ERA5Land_SM_Spain_{day:%Y%m%d}.nc")
                    for day in month_days
                    if not (
                        output_dir / f"ERA5Land_SM_Spain_{day:%Y%m%d}.nc"
                    ).exists()
                ]
                if not month_missing_paths:
                    print(
                        f"  {month_start:%Y-%m}: already complete "
                        f"({month_index}/{len(month_starts)} months).",
                        flush=True,
                    )
                    continue

                for batch_offset in range(0, len(month_days), BATCH_DAYS):
                    # Read and compute only a small day batch to limit memory.
                    batch_days = month_days[
                        batch_offset : batch_offset + BATCH_DAYS
                    ]
                    batch_start = batch_days[0]
                    batch_end = batch_days[-1]
                    batch_missing_paths = [
                        (
                            day,
                            output_dir
                            / f"ERA5Land_SM_Spain_{day:%Y%m%d}.nc",
                        )
                        for day in batch_days
                        if not (
                            output_dir
                            / f"ERA5Land_SM_Spain_{day:%Y%m%d}.nc"
                        ).exists()
                    ]
                    if not batch_missing_paths:
                        continue

                    print(
                        f"  {month_start:%Y-%m}: reading "
                        f"{batch_start:%Y-%m-%d} to {batch_end:%Y-%m-%d} "
                        f"({month_index}/{len(month_starts)} months)...",
                        flush=True,
                    )
                    slice_start = pd.Timestamp(batch_start)
                    slice_end = (
                        pd.Timestamp(batch_end)
                        + pd.Timedelta(days=1)
                        - pd.Timedelta(nanoseconds=1)
                    )
                    # Include the full final day, even though slice endpoints
                    # are inclusive, and respect the source time ordering.
                    time_slice = (
                        slice(slice_end, slice_start)
                        if time_descending
                        else slice(slice_start, slice_end)
                    )
                    batch_parts: list[xr.Dataset] = []
                    for segment_index, (
                        longitude_slice,
                        segment_longitudes,
                        reverse_longitudes,
                    ) in enumerate(longitude_segments, start=1):
                        # Select only the needed variables, Spain latitudes,
                        # this longitude block, and this time batch.
                        print(
                            f"    Reading longitude block "
                            f"{segment_index}/{len(longitude_segments)} "
                            f"({segment_longitudes[0]:.2f}° to "
                            f"{segment_longitudes[-1]:.2f}°)...",
                            flush=True,
                        )
                        batch_source = dataset[
                            list(resolved_variables.values())
                        ].isel(
                            latitude=latitude_slice,
                            longitude=longitude_slice,
                        )
                        if reverse_longitudes:
                            batch_source = batch_source.isel(
                                longitude=slice(None, None, -1)
                            )
                        batch_source = batch_source.assign_coords(
                            longitude=segment_longitudes
                        ).rename(
                            {
                                source_name: output_name
                                for output_name, source_name
                                in resolved_variables.items()
                            }
                        )
                        batch_source = batch_source.sel(time=time_slice)
                        if batch_source.sizes.get("time", 0) == 0:
                            raise ValueError(
                                f"No source data found for "
                                f"{batch_start:%Y-%m-%d} to "
                                f"{batch_end:%Y-%m-%d}."
                            )
                        if time_descending:
                            batch_source = batch_source.sortby("time")
                        # Average hourly samples into daily maps and compute
                        # only the current small batch.
                        print(
                            f"      Computing daily means for "
                            f"{batch_source.sizes['time']} source time steps...",
                            flush=True,
                        )
                        batch_parts.append(
                            batch_source.resample(time="1D").mean().compute()
                        )

                    # Join longitude sections if the region crossed the
                    # source coordinate's longitude seam.
                    batch_data = (
                        xr.concat(batch_parts, dim="longitude")
                        if len(batch_parts) > 1
                        else batch_parts[0]
                    )
                    returned_days = pd.DatetimeIndex(
                        batch_data.time.values
                    ).normalize()
                    # Stop instead of writing a batch with missing calendar days.
                    if not returned_days.equals(batch_days):
                        missing_dates = batch_days.difference(returned_days)
                        source_times = pd.DatetimeIndex(
                            batch_source.time.values
                        )
                        source_range = (
                            f"{source_times.min()} to {source_times.max()}"
                            if not source_times.empty
                            else "no timestamps"
                        )
                        raise ValueError(
                            "The Zarr source did not produce a daily result "
                            f"for every date from {batch_start:%Y-%m-%d} "
                            f"through {batch_end:%Y-%m-%d}. "
                            f"Source timestamps: {source_range} "
                            f"({len(source_times)} steps); "
                            f"missing daily bins: "
                            f"{', '.join(day.strftime('%Y-%m-%d') for day in missing_dates)}."
                        )

                    for day, target in batch_missing_paths:
                        # Store all four layers for one date in a single NetCDF.
                        day_map = batch_data.sel(time=[pd.Timestamp(day)])
                        day_map.attrs.update(
                            {
                                "title": "ERA5-Land daily volumetric soil water",
                                "region": "Spain bounding box",
                                "temporal_aggregation": "daily mean",
                            }
                        )
                        temporary_target = target.with_name(
                            f".{target.name}.tmp"
                        )
                        try:
                            # Write to a temporary file and rename only after
                            # success, so partial files are not treated as complete.
                            day_map.to_netcdf(
                                temporary_target,
                                engine="netcdf4",
                            )
                            os.replace(temporary_target, target)
                        finally:
                            if temporary_target.exists():
                                temporary_target.unlink()

                        days_saved += 1
                        # Count previously existing files in resumed-run progress.
                        completed_days = (
                            len(expected_days) - len(missing_paths) + days_saved
                        )
                        if (
                            days_saved % 10 == 0
                            or days_saved == len(missing_paths)
                        ):
                            percentage = completed_days / len(expected_days) * 100
                            print(
                                f"    Saved {completed_days}/"
                                f"{len(expected_days)} days for {year} "
                                f"({percentage:.1f}%). "
                                f"Latest: {day:%Y-%m-%d}",
                                flush=True,
                            )

            print(
                f"Year {year}: saved {days_saved} daily maps to {output_dir}",
                flush=True,
            )
    finally:
        # Release the remote dataset even if processing or writing raises.
        dataset.close()

    print(f"Finished. Daily files are in {output_dir}")


if __name__ == "__main__":
    main()
