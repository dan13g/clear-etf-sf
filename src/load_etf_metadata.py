import argparse
import os
from pathlib import Path

import pandas as pd

from ingestion_utils import (
    DEFAULT_DB_PATH,
    DEFAULT_SCHEMA,
    connect_md,
    ensure_schema,
    make_unique_identifiers,
    normalize_dataframe_for_duckdb,
    quote_identifier,
)

DEFAULT_WORKBOOK = Path(__file__).resolve().parents[1] / "data" / "clear_etf_metadata.xlsx"
SHEET_TABLE_MAP = {
    "etf": "etf_metadata",
    "geography": "etf_geography",
    "sector": "etf_sector",
    "equivalence_groups": "equivalence_groups",
    "equivalence_group_relationships": "equivalence_group_relationships",
}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Load curated ETF metadata workbook sheets into MotherDuck."
    )
    parser.add_argument(
        "--workbook",
        default=str(DEFAULT_WORKBOOK),
        help="Path to the XLSX workbook to load.",
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


def load_sheet(
    connection,
    workbook: Path,
    schema_name: str,
    sheet_name: str,
    table_name: str,
) -> tuple[str, int]:
    dataframe = pd.read_excel(workbook, sheet_name=sheet_name)
    dataframe = dataframe.dropna(axis=0, how="all").dropna(axis=1, how="all")
    dataframe.columns = make_unique_identifiers(dataframe.columns)
    dataframe = normalize_dataframe_for_duckdb(dataframe)

    temp_name = f"temp_{table_name}"
    connection.register(temp_name, dataframe)
    connection.execute(
        f"""
        CREATE OR REPLACE TABLE {quote_identifier(schema_name)}.{quote_identifier(table_name)} AS
        SELECT * FROM {quote_identifier(temp_name)}
        """
    )
    connection.unregister(temp_name)

    row_count = connection.execute(
        f"SELECT COUNT(*) FROM {quote_identifier(schema_name)}.{quote_identifier(table_name)}"
    ).fetchone()[0]
    return table_name, row_count


def main() -> None:
    args = parse_args()
    workbook = Path(args.workbook).expanduser().resolve()

    if not workbook.exists():
        raise FileNotFoundError(
            f"Workbook not found: {workbook}. "
            "For GitHub Actions, make sure data/clear_etf_metadata.xlsx is committed to the repository."
        )

    print(f"Connecting to MotherDuck database {args.database}...")
    connection = connect_md(args.database)
    schema_name = ensure_schema(connection, args.schema)

    workbook_sheets = set(pd.ExcelFile(workbook).sheet_names)
    missing_sheets = [sheet for sheet in SHEET_TABLE_MAP if sheet not in workbook_sheets]
    if missing_sheets:
        raise ValueError(
            f"Workbook is missing required ETF metadata sheets: {', '.join(missing_sheets)}"
        )

    print(f"Loading ETF metadata workbook {workbook}")

    loaded_tables: list[tuple[str, int]] = []
    for sheet_name, table_name in SHEET_TABLE_MAP.items():
        loaded_table, row_count = load_sheet(
            connection,
            workbook,
            schema_name,
            sheet_name,
            table_name,
        )
        loaded_tables.append((loaded_table, row_count))
        print(f"Loaded sheet '{sheet_name}' into {schema_name}.{loaded_table} ({row_count} rows)")

    print("\nSummary:")
    for table_name, row_count in loaded_tables:
        print(f"- {schema_name}.{table_name}: {row_count} rows")

    connection.close()
    print("\nETF metadata load complete.")


if __name__ == "__main__":
    main()
