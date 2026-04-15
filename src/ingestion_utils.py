import os
import re

import duckdb
import pandas as pd

DEFAULT_DB_PATH = "md:market_intel"
DEFAULT_SCHEMA = "raw"


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

    for column_name in normalized.select_dtypes(include=["string", "str"]).columns:
        normalized[column_name] = normalized[column_name].astype("object")
        normalized[column_name] = normalized[column_name].where(
            normalized[column_name].notna(),
            None,
        )

    return normalized.where(pd.notna(normalized), None)


def connect_md(database_path: str = DEFAULT_DB_PATH) -> duckdb.DuckDBPyConnection:
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


def ensure_schema(connection: duckdb.DuckDBPyConnection, schema_name: str) -> str:
    sanitized_schema = sanitize_identifier(schema_name)
    connection.execute(f"CREATE SCHEMA IF NOT EXISTS {quote_identifier(sanitized_schema)}")
    return sanitized_schema
