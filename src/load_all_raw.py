import argparse
import os
import sys

from load_asset_master import main as load_asset_master_main
from load_daily_prices import main as load_daily_prices_main
from load_etf_metadata import main as load_etf_metadata_main


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Create and populate all raw Snowflake tables for the ClearETF project."
    )
    parser.add_argument(
        "--asset-master",
        help="Optional path to the asset master CSV file.",
    )
    parser.add_argument(
        "--google-sheet",
        help="Optional Google Sheets URL or sheet ID for ETF metadata.",
    )
    parser.add_argument(
        "--database",
        help="Optional Snowflake database override.",
    )
    parser.add_argument(
        "--schema",
        help="Optional Snowflake schema override.",
    )
    parser.add_argument(
        "--period",
        default="max",
        help="yfinance history period to download for the daily price load. Defaults to max.",
    )
    return parser.parse_args()


def apply_optional_env(var_name: str, value: str | None) -> None:
    if value:
        os.environ[var_name] = value


def main() -> None:
    args = parse_args()

    apply_optional_env("SNOWFLAKE_DATABASE", args.database)
    apply_optional_env("SNOWFLAKE_SCHEMA", args.schema)
    apply_optional_env("ETF_METADATA_GOOGLE_SHEET", args.google_sheet)

    print("Starting raw table creation and load sequence...")

    original_argv = list(sys.argv)
    try:
        sys.argv = ["load_asset_master.py"]
        if args.asset_master:
            sys.argv.extend(["--asset-master", args.asset_master])
        load_asset_master_main()

        sys.argv = ["load_daily_prices.py", "--period", args.period]
        if args.asset_master:
            sys.argv.extend(["--asset-master", args.asset_master])
        load_daily_prices_main()

        sys.argv = ["load_etf_metadata.py"]
        if args.google_sheet:
            sys.argv.extend(["--google-sheet", args.google_sheet])
        load_etf_metadata_main()
    finally:
        sys.argv = original_argv

    print("\nAll raw tables created and populated.")


if __name__ == "__main__":
    main()
