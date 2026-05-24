import os
import re

import pandas as pd
import snowflake.connector
from snowflake.connector.connection import SnowflakeConnection
from snowflake.connector.pandas_tools import write_pandas

DEFAULT_ACCOUNT = "FB19926.eu-west-2.aws"
DEFAULT_USER = "bgheoca"
DEFAULT_ROLE = "clearetf_role"
DEFAULT_WAREHOUSE = "clearetf_wh"
DEFAULT_DATABASE = "clearetf_db"
DEFAULT_SCHEMA = "RAW"
DEFAULT_AUTHENTICATOR = "username_password_mfa"
DEFAULT_PASSWORD_ENV_VAR = "SNOWFLAKE_PASSWORD"


def sanitize_identifier(value: str) -> str:
    value = re.sub(r"[^0-9a-zA-Z]+", "_", str(value).strip().lower())
    value = re.sub(r"_+", "_", value).strip("_")
    if not value:
        value = "unnamed"
    if value[0].isdigit():
        value = f"_{value}"
    return value


def normalize_relation_identifier(value: str) -> str:
    return sanitize_identifier(value).upper()


def quote_identifier(identifier: str) -> str:
    normalized = normalize_relation_identifier(identifier)
    escaped = normalized.replace('"', '""')
    return f'"{escaped}"'


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


def normalize_dataframe_for_snowflake(dataframe: pd.DataFrame) -> pd.DataFrame:
    normalized = dataframe.copy()

    for column_name in normalized.select_dtypes(include=["string", "str"]).columns:
        normalized[column_name] = normalized[column_name].astype("object")
        normalized[column_name] = normalized[column_name].where(
            normalized[column_name].notna(),
            None,
        )

    return normalized.where(pd.notna(normalized), None)


def connect_snowflake(
    database_name: str = DEFAULT_DATABASE,
    schema_name: str = DEFAULT_SCHEMA,
) -> SnowflakeConnection:
    password = os.getenv(DEFAULT_PASSWORD_ENV_VAR)
    if not password:
        raise RuntimeError(f"{DEFAULT_PASSWORD_ENV_VAR} env var is required.")

    connection_kwargs = {
        "account": os.getenv("SNOWFLAKE_ACCOUNT", DEFAULT_ACCOUNT),
        "user": os.getenv("SNOWFLAKE_USER", DEFAULT_USER),
        "password": password,
        "database": normalize_relation_identifier(
            os.getenv("SNOWFLAKE_DATABASE", database_name)
        ),
        "schema": normalize_relation_identifier(os.getenv("SNOWFLAKE_SCHEMA", schema_name)),
        "warehouse": normalize_relation_identifier(
            os.getenv("SNOWFLAKE_WAREHOUSE", DEFAULT_WAREHOUSE)
        ),
        "role": normalize_relation_identifier(os.getenv("SNOWFLAKE_ROLE", DEFAULT_ROLE)),
        "autocommit": True,
    }

    authenticator = os.getenv("SNOWFLAKE_AUTHENTICATOR", DEFAULT_AUTHENTICATOR)
    if authenticator:
        connection_kwargs["authenticator"] = authenticator

    return snowflake.connector.connect(**connection_kwargs)


def ensure_schema(connection: SnowflakeConnection, schema_name: str) -> str:
    normalized_schema = normalize_relation_identifier(schema_name)
    with connection.cursor() as cursor:
        cursor.execute(f"CREATE SCHEMA IF NOT EXISTS {quote_identifier(normalized_schema)}")
    return normalized_schema


def replace_table(
    connection: SnowflakeConnection,
    dataframe: pd.DataFrame,
    schema_name: str,
    table_name: str,
    database_name: str = DEFAULT_DATABASE,
) -> tuple[str, str, int]:
    if dataframe.empty:
        raise ValueError(f"Cannot replace {schema_name}.{table_name} with an empty dataframe.")

    normalized_schema = ensure_schema(connection, schema_name)
    normalized_table = normalize_relation_identifier(table_name)
    normalized_database = normalize_relation_identifier(database_name)

    with connection.cursor() as cursor:
        cursor.execute(
            f"DROP TABLE IF EXISTS {quote_identifier(normalized_schema)}.{quote_identifier(normalized_table)}"
        )

    success, _, row_count, _ = write_pandas(
        connection,
        dataframe,
        table_name=normalized_table,
        schema=normalized_schema,
        database=normalized_database,
        auto_create_table=True,
        overwrite=True,
        quote_identifiers=False,
    )
    if not success:
        raise RuntimeError(
            f"write_pandas reported failure while loading {normalized_schema}.{normalized_table}."
        )

    return normalized_schema, normalized_table, int(row_count)


def fetch_row_count(
    connection: SnowflakeConnection,
    schema_name: str,
    table_name: str,
) -> int:
    with connection.cursor() as cursor:
        cursor.execute(
            f"SELECT COUNT(*) FROM {quote_identifier(schema_name)}.{quote_identifier(table_name)}"
        )
        return int(cursor.fetchone()[0])
