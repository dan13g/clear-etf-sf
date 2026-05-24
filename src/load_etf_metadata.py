import argparse
import os
import re
from io import BytesIO
from urllib.error import HTTPError, URLError
from urllib.parse import parse_qs, urlencode, urlparse
from urllib.request import urlopen

import pandas as pd

from ingestion_utils import (
    DEFAULT_DATABASE,
    DEFAULT_SCHEMA,
    connect_snowflake,
    make_unique_identifiers,
    normalize_dataframe_for_snowflake,
    replace_table,
)

GOOGLE_SHEET_ENV_VAR = "ETF_METADATA_GOOGLE_SHEET"
GOOGLE_SHEETS_URL_PATTERN = re.compile(r"/spreadsheets/d/([a-zA-Z0-9-_]+)")
SHEET_TABLE_MAP = {
    "etf": "etf_metadata",
    "geography": "etf_geography",
    "sector": "etf_sector",
    "equivalence_groups": "equivalence_groups",
    "equivalence_group_relationships": "equivalence_group_relationships",
}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Load curated ETF metadata from Google Sheets into Snowflake."
    )
    parser.add_argument(
        "--google-sheet",
        default=os.getenv(GOOGLE_SHEET_ENV_VAR),
        help=(
            "Google Sheets URL or sheet ID to load. "
            f"Defaults to the {GOOGLE_SHEET_ENV_VAR} environment variable when set."
        ),
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


def extract_google_sheet_id(sheet_reference: str) -> str:
    reference = sheet_reference.strip()
    match = GOOGLE_SHEETS_URL_PATTERN.search(reference)
    if match:
        return match.group(1)
    if not reference:
        raise ValueError("Google Sheet reference cannot be empty.")
    return reference


def extract_google_sheet_resourcekey(sheet_reference: str) -> str | None:
    reference = sheet_reference.strip()
    if not reference.startswith("http"):
        return None

    parsed = urlparse(reference)
    query = parse_qs(parsed.query)
    resourcekey = query.get("resourcekey", [None])[0]
    if resourcekey:
        return resourcekey
    return None


def download_google_sheet_workbook(sheet_reference: str) -> tuple[bytes, str]:
    sheet_id = extract_google_sheet_id(sheet_reference)
    resourcekey = extract_google_sheet_resourcekey(sheet_reference)
    query_params = {"format": "xlsx"}
    if resourcekey:
        query_params["resourcekey"] = resourcekey

    export_url = (
        f"https://docs.google.com/spreadsheets/d/{sheet_id}/export?{urlencode(query_params)}"
    )

    try:
        with urlopen(export_url) as response:
            workbook_bytes = response.read()
    except HTTPError as exc:
        raise RuntimeError(
            "Failed to download the Google Sheets workbook. "
            "Make sure the sheet exists, that the current runtime can access it, and if you are "
            "using a Google share link with a resource key, pass the full URL rather than only "
            "the sheet ID "
            f"(HTTP {exc.code})."
        ) from exc
    except URLError as exc:
        raise RuntimeError(
            "Failed to reach Google Sheets while downloading ETF metadata workbook."
        ) from exc

    if not workbook_bytes:
        raise RuntimeError("Downloaded Google Sheets workbook was empty.")

    return workbook_bytes, f"Google Sheet {sheet_id}"


def resolve_workbook_source(args: argparse.Namespace) -> tuple[bytes, str]:
    if not args.google_sheet:
        raise ValueError(
            "Google Sheets source is required. "
            f"Set {GOOGLE_SHEET_ENV_VAR} or pass --google-sheet."
        )
    return download_google_sheet_workbook(args.google_sheet)


def read_excel_file(workbook_source: bytes) -> pd.ExcelFile:
    return pd.ExcelFile(BytesIO(workbook_source))


def read_sheet(workbook_source: bytes, sheet_name: str) -> pd.DataFrame:
    return pd.read_excel(BytesIO(workbook_source), sheet_name=sheet_name)


def load_sheet(
    connection,
    workbook_source: bytes,
    schema_name: str,
    database_name: str,
    sheet_name: str,
    table_name: str,
) -> tuple[str, int]:
    dataframe = read_sheet(workbook_source, sheet_name)
    dataframe = dataframe.dropna(axis=0, how="all").dropna(axis=1, how="all")
    dataframe.columns = make_unique_identifiers(dataframe.columns)
    dataframe = normalize_dataframe_for_snowflake(dataframe)

    _, loaded_table_name, row_count = replace_table(
        connection,
        dataframe,
        schema_name,
        table_name,
        database_name,
    )
    return loaded_table_name, row_count


def main() -> None:
    args = parse_args()
    workbook_source, workbook_description = resolve_workbook_source(args)

    print(f"Connecting to Snowflake database {args.database}...")
    connection = connect_snowflake(args.database, args.schema)
    schema_name = args.schema

    try:
        workbook_sheets = set(read_excel_file(workbook_source).sheet_names)
        missing_sheets = [sheet for sheet in SHEET_TABLE_MAP if sheet not in workbook_sheets]
        if missing_sheets:
            raise ValueError(
                f"Workbook is missing required ETF metadata sheets: {', '.join(missing_sheets)}"
            )

        print(f"Loading ETF metadata from {workbook_description}")

        loaded_tables: list[tuple[str, int]] = []
        for sheet_name, table_name in SHEET_TABLE_MAP.items():
            loaded_table, row_count = load_sheet(
                connection,
                workbook_source,
                schema_name,
                args.database,
                sheet_name,
                table_name,
            )
            loaded_tables.append((loaded_table, row_count))
            print(
                f"Loaded sheet '{sheet_name}' into {schema_name}.{loaded_table} ({row_count} rows)"
            )

        print("\nSummary:")
        for table_name, row_count in loaded_tables:
            print(f"- {schema_name}.{table_name}: {row_count} rows")
    finally:
        connection.close()

    print("\nETF metadata load complete.")


if __name__ == "__main__":
    main()
