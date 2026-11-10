"""Download SPEIbase v2.11 scales and extract the Spain area for 1950-2024."""

import argparse
from pathlib import Path
import os
import sys
from urllib.request import urlopen

if sys.version_info < (3, 10):
    raise SystemExit("Python 3.10 or newer is required.")

import numpy as np
import pandas as pd
import xarray as xr


VERSION = "2_11"
BASE_URL = f"https://spei.csic.es/spei_database_{VERSION}/nc"
FIRST_YEAR = 1950
LAST_YEAR = 2024
DEFAULT_OUTPUT = Path(
    "/home/jose/Escritorio/UCM_Madrid/SPEIbase_Spain"
)
LATITUDE_BOUNDS = (35.8, 43.9)
LONGITUDE_BOUNDS = (-9.5, 4.5)
DOWNLOAD_CHUNK_BYTES = 1024 * 1024


def download_source(scale: int, temporary_path: Path) -> None:
    """Stream one global NetCDF source to disk and report transfer progress."""
    url = f"{BASE_URL}/spei{scale:02d}.nc"
    print(f"Downloading SPEI-{scale} from {url}", flush=True)
    partial_path = temporary_path.with_name(f"{temporary_path.name}.part")

    try:
        with urlopen(url, timeout=60) as response, partial_path.open("wb") as target:
            expected_size = response.headers.get("Content-Length")
            expected_bytes = int(expected_size) if expected_size else None
            downloaded_bytes = 0

            while chunk := response.read(DOWNLOAD_CHUNK_BYTES):
                target.write(chunk)
                downloaded_bytes += len(chunk)
                if expected_bytes:
                    percentage = downloaded_bytes / expected_bytes * 100
                    print(
                        f"\r  Downloaded {downloaded_bytes:,} of "
                        f"{expected_bytes:,} bytes ({percentage:.1f}%)",
                        end="",
                        flush=True,
                    )
                elif downloaded_bytes % (20 * DOWNLOAD_CHUNK_BYTES) < len(chunk):
                    print(
                        f"\r  Downloaded {downloaded_bytes:,} bytes",
                        end="",
                        flush=True,
                    )

        if expected_bytes is not None and downloaded_bytes != expected_bytes:
            raise OSError(
                f"Incomplete SPEI-{scale} download: received {downloaded_bytes} "
                f"of {expected_bytes} bytes."
            )
        os.replace(partial_path, temporary_path)
        print(f"\n  Download complete ({downloaded_bytes:,} bytes).", flush=True)
    finally:
        if partial_path.exists():
            partial_path.unlink()


def find_coordinate(dataset: xr.Dataset, choices: tuple[str, ...]) -> str:
    for name in choices:
        if name in dataset.coords:
            return name
    raise ValueError(
        f"Could not find any of the coordinates {', '.join(choices)}. "
        f"Dataset coordinates: {', '.join(dataset.coords)}"
    )


def crop_source(source_path: Path, target_path: Path, scale: int) -> None:
    """Write the selected dates and Spain bounding box to a compact NetCDF."""
    with xr.open_dataset(source_path, engine="netcdf4") as dataset:
        time_name = find_coordinate(dataset, ("time", "date"))
        latitude_name = find_coordinate(dataset, ("latitude", "lat"))
        longitude_name = find_coordinate(dataset, ("longitude", "lon"))
        source_variable_name = "spei"
        output_variable_name = f"spei{scale:02d}"
        if source_variable_name not in dataset.data_vars:
            raise ValueError(
                f"Expected source variable {source_variable_name!r} in "
                f"SPEI-{scale} file; "
                f"available variables: {', '.join(dataset.data_vars)}"
            )

        times = pd.DatetimeIndex(dataset[time_name].values)
        time_indices = np.flatnonzero(
            (times >= pd.Timestamp(f"{FIRST_YEAR}-01-01"))
            & (times < pd.Timestamp(f"{LAST_YEAR + 1}-01-01"))
        )
        latitudes = np.asarray(dataset[latitude_name].values)
        longitudes = np.asarray(dataset[longitude_name].values)
        latitude_indices = np.flatnonzero(
            (latitudes >= LATITUDE_BOUNDS[0])
            & (latitudes <= LATITUDE_BOUNDS[1])
        )
        longitude_indices = np.flatnonzero(
            (longitudes >= LONGITUDE_BOUNDS[0])
            & (longitudes <= LONGITUDE_BOUNDS[1])
        )
        if not time_indices.size:
            raise ValueError(
                f"SPEI-{scale} contains no data for "
                f"{FIRST_YEAR}-{LAST_YEAR}."
            )
        if not latitude_indices.size or not longitude_indices.size:
            raise ValueError("The Spain bounding box contains no grid cells.")

        subset = dataset[[source_variable_name]].isel(
            {
                time_name: time_indices,
                latitude_name: latitude_indices,
                longitude_name: longitude_indices,
            }
        ).rename({source_variable_name: output_variable_name}).load()
        subset.attrs.update(
            {
                "title": f"SPEIbase v{VERSION.replace('_', '.')} for Spain",
                "spei_timescale_months": scale,
                "source": f"{BASE_URL}/spei{scale:02d}.nc",
                "region": "Spain bounding box",
                "latitude_bounds": f"{LATITUDE_BOUNDS[0]} to {LATITUDE_BOUNDS[1]}",
                "longitude_bounds": (
                    f"{LONGITUDE_BOUNDS[0]} to {LONGITUDE_BOUNDS[1]}"
                ),
                "period": f"{FIRST_YEAR}-01 through {LAST_YEAR}-12",
            }
        )
        subset.to_netcdf(
            target_path,
            engine="netcdf4",
            encoding={
                output_variable_name: {
                    "zlib": True,
                    "complevel": 4,
                }
            },
        )

    print(
        f"  Saved {target_path.name}: {len(time_indices)} months, "
        f"{len(latitude_indices)} latitude x {len(longitude_indices)} "
        "longitude cells.",
        flush=True,
    )


def parse_scales(text: str, parser: argparse.ArgumentParser) -> list[int]:
    try:
        scales = sorted({int(item.strip()) for item in text.split(",")})
    except ValueError:
        parser.error("--scales must be comma-separated integers from 1 to 48")
    if not scales or any(scale < 1 or scale > 48 for scale in scales):
        parser.error("--scales must contain integers from 1 to 48")
    return scales


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--output",
        type=Path,
        default=DEFAULT_OUTPUT,
        help=f"Output directory (default: {DEFAULT_OUTPUT}).",
    )
    parser.add_argument(
        "--scales",
        default=",".join(str(scale) for scale in range(1, 49)),
        help=(
            "Comma-separated SPEI timescales from 1 to 48 months "
            "(default: all 48)."
        ),
    )
    parser.add_argument(
        "--end-year",
        type=int,
        default=LAST_YEAR,
        help=f"Last available year: {LAST_YEAR}.",
    )
    arguments = parser.parse_args()
    if arguments.end_year != LAST_YEAR:
        parser.error(
            f"SPEIbase v{VERSION.replace('_', '.')} currently ends in "
            f"{LAST_YEAR}; 2025 data is not available in this release."
        )
    scales = parse_scales(arguments.scales, parser)
    arguments.output.mkdir(parents=True, exist_ok=True)

    for scale in scales:
        target = arguments.output / (
            f"SPEIbase_v{VERSION}_Spain_spei{scale:02d}_"
            f"{FIRST_YEAR}-{LAST_YEAR}.nc"
        )
        if target.exists():
            print(f"Skipping existing file: {target}", flush=True)
            continue

        temporary_source = arguments.output / f".spei{scale:02d}.download.nc"
        temporary_target = target.with_name(f".{target.name}.tmp")
        try:
            if temporary_source.exists():
                print(
                    f"Reusing previously downloaded SPEI-{scale} source.",
                    flush=True,
                )
            else:
                download_source(scale, temporary_source)
            crop_source(temporary_source, temporary_target, scale)
            os.replace(temporary_target, target)
            temporary_source.unlink()
        finally:
            if temporary_target.exists():
                temporary_target.unlink()

    print(f"Finished. Cropped files are in {arguments.output}", flush=True)


if __name__ == "__main__":
    main()
