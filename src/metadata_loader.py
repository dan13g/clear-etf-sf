import argparse
import os
import re
from pathlib import Path

import duckdb
import pandas as pd

DEFAULT_DB_PATH = "md:clear_etf"
DEFAULT_SCHEMA = "raw"
DEFAULT_WORKBOOK = Path(__file__).resolve().parents[1] / "data" / "clear_etf_metadata.xlsx"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Load every sheet from the Clear ETF metadata workbook into MotherDuck."
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


def quote_identifier(identifier: str) -> str:
    escaped = identifier.replace('"', '""')
    return f'"{escaped}"'


def sanitize_identifier(value: str) -> str:
    value = re.sub(r"[^0-9a-zA-Z]+", "_", str(value).strip().lower())
    value = re.sub(r"_+", "_", value).strip("_")
    if not value:
        value = "unnamed"
    if value[0].isdigit():
        value = f"_{value}"
    return value


def make_unique_identifiers(values) -> list[str]:
    counts: dict[str, int] = {}
    unique_values: list[str] = []

    for value in values:
        base_value = sanitize_identifier(value)
        count = counts.get(base_value, 0)
        unique_value = base_value if count == 0 else f"{base_value}_{count + 1}"
        counts[base_value] = count + 1
        unique_values.append(unique_value)

    return unique_values


def normalize_dataframe_for_duckdb(dataframe: pd.DataFrame) -> pd.DataFrame:
    normalized = dataframe.copy()

    # MotherDuck-compatible DuckDB builds can reject pandas' newer "str" extension dtype.
    for column_name in normalized.select_dtypes(include=["string", "str"]).columns:
        normalized[column_name] = normalized[column_name].astype("object")
        normalized[column_name] = normalized[column_name].where(
            normalized[column_name].notna(),
            None,
        )

    return normalized


def connect_md(database_path: str) -> duckdb.DuckDBPyConnection:
    token = os.getenv("MOTHERDUCK_TOKEN")
    if not token:
        raise RuntimeError("MOTHERDUCK_TOKEN env var is required.")

    escaped_token = token.replace("'", "''")
    connection = duckdb.connect(database=":memory:")
    connection.execute("INSTALL motherduck; LOAD motherduck;")
    connection.execute(f"SET motherduck_token='{escaped_token}';")
    connection.execute(f"ATTACH '{database_path}' AS md (TYPE motherduck);")
    connection.execute("USE md;")
    return connection


def load_sheet(
    connection: duckdb.DuckDBPyConnection,
    workbook: Path,
    schema_name: str,
    sheet_name: str,
) -> tuple[str, int]:
    table_name = sanitize_identifier(sheet_name)
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
    schema_name = sanitize_identifier(args.schema)
    connection.execute(f"CREATE SCHEMA IF NOT EXISTS {quote_identifier(schema_name)}")

    sheet_names = pd.ExcelFile(workbook).sheet_names
    print(f"Loading workbook {workbook} with sheets: {', '.join(sheet_names)}")

    loaded_tables: list[tuple[str, int]] = []
    for sheet_name in sheet_names:
        table_name, row_count = load_sheet(connection, workbook, schema_name, sheet_name)
        loaded_tables.append((table_name, row_count))
        print(f"Loaded sheet '{sheet_name}' into {schema_name}.{table_name} ({row_count} rows)")

    print("\nSummary:")
    for table_name, row_count in loaded_tables:
        print(f"- {schema_name}.{table_name}: {row_count} rows")

    connection.close()
    print("\nMetadata workbook load complete.")


if __name__ == "__main__":
    main()
