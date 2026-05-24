import os
import re
from datetime import date, datetime

import pandas as pd
import snowflake.connector
from dotenv import load_dotenv
from snowflake.connector.connection import SnowflakeConnection
from snowflake.connector.pandas_tools import write_pandas
from pandas.api.types import (
    is_object_dtype,
    is_bool_dtype,
    is_datetime64_any_dtype,
    is_float_dtype,
    is_integer_dtype,
    is_string_dtype,
)

load_dotenv()

DEFAULT_ACCOUNT = "CPRCYYC-FB19926"
DEFAULT_USER = "bgheoca"
DEFAULT_ROLE = "clearetf_role"
DEFAULT_WAREHOUSE = "clearetf_wh"
DEFAULT_DATABASE = "clearetf_db"
DEFAULT_SCHEMA = "RAW"
DEFAULT_AUTHENTICATOR = "username_password_mfa"
DEFAULT_PASSWORD_ENV_VAR = "SNOWFLAKE_PASSWORD"
DEFAULT_CA_BUNDLE_ENV_VAR = "SNOWFLAKE_CA_BUNDLE"
DEFAULT_PRIVATE_KEY_PATH_ENV_VAR = "SNOWFLAKE_PRIVATE_KEY_PATH"
DEFAULT_PRIVATE_KEY_PASSPHRASE_ENV_VAR = "SNOWFLAKE_PRIVATE_KEY_PASSPHRASE"


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

    for column_name in normalized.columns:
        column = normalized[column_name]
        if is_string_dtype(column) or is_object_dtype(column):
            normalized[column_name] = column.astype("object")
            normalized[column_name] = normalized[column_name].where(
                normalized[column_name].notna(),
                None,
            )

    return normalized.where(pd.notna(normalized), None)


def configure_ssl_environment() -> None:
    ca_bundle_path = os.getenv(DEFAULT_CA_BUNDLE_ENV_VAR)
    if not ca_bundle_path:
        return

    os.environ["REQUESTS_CA_BUNDLE"] = ca_bundle_path
    os.environ["SSL_CERT_FILE"] = ca_bundle_path
    os.environ["CURL_CA_BUNDLE"] = ca_bundle_path


def infer_snowflake_type(series: pd.Series) -> str:
    if is_bool_dtype(series):
        return "BOOLEAN"
    if is_integer_dtype(series):
        return "NUMBER(38,0)"
    if is_float_dtype(series):
        return "FLOAT"
    if is_datetime64_any_dtype(series):
        return "TIMESTAMP_NTZ"

    non_null_values = series.dropna()
    if non_null_values.empty:
        return "VARCHAR"

    sample_value = non_null_values.iloc[0]
    if isinstance(sample_value, bool):
        return "BOOLEAN"
    if isinstance(sample_value, int) and not isinstance(sample_value, bool):
        return "NUMBER(38,0)"
    if isinstance(sample_value, float):
        return "FLOAT"
    if isinstance(sample_value, datetime):
        return "TIMESTAMP_NTZ"
    if isinstance(sample_value, date):
        return "DATE"
    return "VARCHAR"


def connect_snowflake(
    database_name: str = DEFAULT_DATABASE,
    schema_name: str = DEFAULT_SCHEMA,
) -> SnowflakeConnection:
    configure_ssl_environment()

    connection_kwargs = {
        "account": os.getenv("SNOWFLAKE_ACCOUNT", DEFAULT_ACCOUNT),
        "user": os.getenv("SNOWFLAKE_USER", DEFAULT_USER),
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

    private_key_path = os.getenv(DEFAULT_PRIVATE_KEY_PATH_ENV_VAR)
    private_key_passphrase = os.getenv(DEFAULT_PRIVATE_KEY_PASSPHRASE_ENV_VAR)
    password = os.getenv(DEFAULT_PASSWORD_ENV_VAR)
    authenticator = os.getenv("SNOWFLAKE_AUTHENTICATOR")

    if private_key_path:
        connection_kwargs["private_key_file"] = private_key_path
        if private_key_passphrase:
            connection_kwargs["private_key_file_pwd"] = private_key_passphrase
    else:
        if authenticator is None:
            authenticator = DEFAULT_AUTHENTICATOR
        if not password:
            raise RuntimeError(
                f"{DEFAULT_PASSWORD_ENV_VAR} env var is required when "
                f"{DEFAULT_PRIVATE_KEY_PATH_ENV_VAR} is not set."
            )
        connection_kwargs["password"] = password

    if authenticator:
        connection_kwargs["authenticator"] = authenticator

    return snowflake.connector.connect(**connection_kwargs)


def ensure_schema(connection: SnowflakeConnection, schema_name: str) -> str:
    normalized_schema = normalize_relation_identifier(schema_name)
    with connection.cursor() as cursor:
        cursor.execute(f"CREATE SCHEMA IF NOT EXISTS {quote_identifier(normalized_schema)}")
    return normalized_schema


def create_table_for_dataframe(
    connection: SnowflakeConnection,
    dataframe: pd.DataFrame,
    schema_name: str,
    table_name: str,
    database_name: str = DEFAULT_DATABASE,
) -> tuple[str, str, str]:
    if dataframe.empty:
        raise ValueError(f"Cannot create {schema_name}.{table_name} from an empty dataframe.")

    normalized_schema = ensure_schema(connection, schema_name)
    normalized_table = normalize_relation_identifier(table_name)
    normalized_database = normalize_relation_identifier(database_name)

    column_definitions = []
    for column_name in dataframe.columns:
        snowflake_type = infer_snowflake_type(dataframe[column_name])
        column_definitions.append(
            f"{quote_identifier(column_name)} {snowflake_type}"
        )

    qualified_table_name = (
        f"{quote_identifier(normalized_database)}."
        f"{quote_identifier(normalized_schema)}."
        f"{quote_identifier(normalized_table)}"
    )
    create_table_sql = (
        f"CREATE OR REPLACE TABLE {qualified_table_name} "
        f"({', '.join(column_definitions)})"
    )

    with connection.cursor() as cursor:
        cursor.execute(create_table_sql)

    return normalized_database, normalized_schema, normalized_table


def replace_table(
    connection: SnowflakeConnection,
    dataframe: pd.DataFrame,
    schema_name: str,
    table_name: str,
    database_name: str = DEFAULT_DATABASE,
) -> tuple[str, str, int]:
    if dataframe.empty:
        raise ValueError(f"Cannot replace {schema_name}.{table_name} with an empty dataframe.")

    normalized_database, normalized_schema, normalized_table = create_table_for_dataframe(
        connection,
        dataframe,
        schema_name,
        table_name,
        database_name,
    )

    success, _, row_count, _ = write_pandas(
        connection,
        dataframe,
        table_name=normalized_table,
        schema=normalized_schema,
        database=normalized_database,
        auto_create_table=False,
        overwrite=False,
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
