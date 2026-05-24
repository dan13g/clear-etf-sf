import argparse
import os
from pathlib import Path

import pandas as pd

from ingestion_utils import (
    DEFAULT_DATABASE,
    DEFAULT_SCHEMA,
    connect_snowflake,
    normalize_dataframe_for_snowflake,
    replace_table,
)

DEFAULT_ASSET_MASTER = Path(__file__).resolve().parents[1] / "data" / "asset_master.csv"
TABLE_NAME = "asset_master"
REQUIRED_COLUMNS = [
    "ticker",
    "asset_name",
    "asset_type",
    "asset_subtype",
    "region",
    "country",
    "currency",
    "provider_name",
    "exchange",
    "is_active",
]
TRUE_VALUES = {"true", "1", "yes", "y", "t"}
FALSE_VALUES = {"false", "0", "no", "n", "f"}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Load the tracked asset master file into Snowflake."
    )
    parser.add_argument(
        "--asset-master",
        default=str(DEFAULT_ASSET_MASTER),
        help="Path to the asset master CSV file.",
    )
    parser.add_argument(
        "--database",
        default=os.getenv("SNOWFLAKE_DATABASE", DEFAULT_DATABASE),
        help="Target Snowflake database.",
    )
    parser.add_argument(
        "--schema",
        default=os.getenv("SNOWFLAKE_SCHEMA", DEFAULT_SCHEMA),
        help="Target schema in Snowflake.",
    )
    return parser.parse_args()


def load_asset_master_file(asset_master_path: Path) -> pd.DataFrame:
    dataframe = pd.read_csv(asset_master_path)
    dataframe.columns = [str(column).strip().lower() for column in dataframe.columns]

    missing_columns = [column for column in REQUIRED_COLUMNS if column not in dataframe.columns]
    if missing_columns:
        raise ValueError(
            f"Asset master is missing required columns: {', '.join(missing_columns)}"
        )

    dataframe = dataframe.copy()
    dataframe["ticker"] = dataframe["ticker"].astype("string").str.strip().str.upper()
    dataframe = dataframe[dataframe["ticker"].notna()]
    dataframe = dataframe[dataframe["ticker"] != ""]
    dataframe = dataframe.drop_duplicates(subset=["ticker"], keep="last")
    dataframe["is_active"] = dataframe["is_active"].apply(parse_boolean).fillna(True)

    ordered_columns = REQUIRED_COLUMNS + [
        column for column in dataframe.columns if column not in REQUIRED_COLUMNS
    ]
    dataframe = dataframe[ordered_columns]
    return normalize_dataframe_for_snowflake(dataframe)


def parse_boolean(value):
    if pd.isna(value):
        return None
    if isinstance(value, bool):
        return value

    normalized = str(value).strip().lower()
    if normalized in TRUE_VALUES:
        return True
    if normalized in FALSE_VALUES:
        return False

    raise ValueError(
        f"Unsupported is_active value '{value}'. Use one of: "
        f"{', '.join(sorted(TRUE_VALUES | FALSE_VALUES))}"
    )


def main() -> None:
    args = parse_args()
    asset_master_path = Path(args.asset_master).expanduser().resolve()

    if not asset_master_path.exists():
        raise FileNotFoundError(f"Asset master file not found: {asset_master_path}")

    dataframe = load_asset_master_file(asset_master_path)

    print(f"Connecting to Snowflake database {args.database}...")
    connection = connect_snowflake(args.database, args.schema)

    try:
        schema_name, table_name, row_count = replace_table(
            connection,
            dataframe,
            args.schema,
            TABLE_NAME,
            args.database,
        )
    finally:
        connection.close()

    print(f"Loaded {row_count} rows into {schema_name}.{table_name}")
    print("\nAsset master load complete.")


if __name__ == "__main__":
    main()
