import argparse
import os
from pathlib import Path

import pandas as pd

from ingestion_utils import (
    DEFAULT_DB_PATH,
    DEFAULT_SCHEMA,
    connect_md,
    ensure_schema,
    normalize_dataframe_for_duckdb,
    quote_identifier,
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
        description="Load the tracked asset master file into MotherDuck."
    )
    parser.add_argument(
        "--asset-master",
        default=str(DEFAULT_ASSET_MASTER),
        help="Path to the asset master CSV file.",
    )
    parser.add_argument(
        "--database",
        default=os.getenv("MOTHERDUCK_DATABASE", DEFAULT_DB_PATH),
        help="MotherDuck database path, for example md:clear_etf.",
    )
    parser.add_argument(
        "--schema",
        default=os.getenv("MOTHERDUCK_SCHEMA", DEFAULT_SCHEMA),
        help="Target schema in MotherDuck.",
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
    return normalize_dataframe_for_duckdb(dataframe)


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

    print(f"Connecting to MotherDuck database {args.database}...")
    connection = connect_md(args.database)
    schema_name = ensure_schema(connection, args.schema)

    connection.register("temp_asset_master", dataframe)
    connection.execute(
        f"""
        CREATE OR REPLACE TABLE {quote_identifier(schema_name)}.{quote_identifier(TABLE_NAME)} AS
        SELECT * FROM temp_asset_master
        """
    )
    connection.unregister("temp_asset_master")

    row_count = connection.execute(
        f"SELECT COUNT(*) FROM {quote_identifier(schema_name)}.{quote_identifier(TABLE_NAME)}"
    ).fetchone()[0]

    print(f"Loaded {row_count} rows into {schema_name}.{TABLE_NAME}")
    connection.close()
    print("\nAsset master load complete.")


if __name__ == "__main__":
    main()
