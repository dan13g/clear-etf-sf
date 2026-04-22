import argparse
import os
from pathlib import Path

import pandas as pd
import yfinance as yf

from ingestion_utils import (
    DEFAULT_DB_PATH,
    DEFAULT_SCHEMA,
    connect_md,
    ensure_schema,
    normalize_dataframe_for_duckdb,
    quote_identifier,
)
from load_asset_master import DEFAULT_ASSET_MASTER, load_asset_master_file

TABLE_NAME = "asset_prices_yfinance"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Load daily yfinance prices for every tracked asset in the asset master."
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
    parser.add_argument(
        "--period",
        default="max",
        help="yfinance history period to download for each ticker. Defaults to max.",
    )
    return parser.parse_args()


def create_table(connection, schema_name: str) -> None:
    connection.execute(
        f"""
        CREATE TABLE IF NOT EXISTS {quote_identifier(schema_name)}.{quote_identifier(TABLE_NAME)} (
            ticker TEXT,
            date DATE,
            open DOUBLE,
            high DOUBLE,
            low DOUBLE,
            close DOUBLE,
            adj_close DOUBLE,
            volume DOUBLE
        )
        """
    )


def purge_stale_tickers(connection, schema_name: str, tickers: list[str]) -> None:
    if not tickers:
        return

    placeholders = ", ".join(["?"] * len(tickers))
    connection.execute(
        f"""
        DELETE FROM {quote_identifier(schema_name)}.{quote_identifier(TABLE_NAME)}
        WHERE ticker NOT IN ({placeholders})
        """,
        tickers,
    )


def normalize_download_frame(dataframe: pd.DataFrame) -> pd.DataFrame:
    if getattr(dataframe.columns, "nlevels", 1) > 1:
        dataframe.columns = [
            column[0] if isinstance(column, tuple) else column
            for column in dataframe.columns
        ]

    dataframe = dataframe.reset_index()
    dataframe.columns = [str(column).strip() for column in dataframe.columns]
    return dataframe


def load_ticker(connection, schema_name: str, ticker: str, period: str) -> int:
    print(f"Refreshing {ticker}...")

    dataframe = yf.download(
        ticker,
        period=period,
        auto_adjust=False,
        progress=False,
    )

    if dataframe.empty:
        print(f"No data returned for {ticker}")
        return 0

    dataframe = normalize_download_frame(dataframe)
    dataframe = normalize_dataframe_for_duckdb(dataframe)

    connection.execute(
        f"""
        DELETE FROM {quote_identifier(schema_name)}.{quote_identifier(TABLE_NAME)}
        WHERE ticker = ?
        """,
        [ticker],
    )

    connection.register("temp_prices", dataframe)
    connection.execute(
        f"""
        INSERT INTO {quote_identifier(schema_name)}.{quote_identifier(TABLE_NAME)}
        SELECT
            ? AS ticker,
            CAST(Date AS DATE) AS date,
            Open AS open,
            High AS high,
            Low AS low,
            Close AS close,
            "Adj Close" AS adj_close,
            Volume AS volume
        FROM temp_prices
        """,
        [ticker],
    )
    connection.unregister("temp_prices")

    row_count = connection.execute(
        f"""
        SELECT COUNT(*)
        FROM {quote_identifier(schema_name)}.{quote_identifier(TABLE_NAME)}
        WHERE ticker = ?
        """,
        [ticker],
    ).fetchone()[0]
    return row_count


def validate_load(connection, schema_name: str) -> None:
    rows = connection.execute(
        f"""
        SELECT
            ticker,
            MIN(date) AS min_date,
            MAX(date) AS max_date,
            COUNT(*) AS row_count
        FROM {quote_identifier(schema_name)}.{quote_identifier(TABLE_NAME)}
        GROUP BY ticker
        ORDER BY ticker
        """
    ).fetchall()

    print("\nLoaded:")
    for row in rows:
        print(row)


def main() -> None:
    args = parse_args()
    asset_master_path = Path(args.asset_master).expanduser().resolve()

    if not asset_master_path.exists():
        raise FileNotFoundError(f"Asset master file not found: {asset_master_path}")

    asset_master = load_asset_master_file(asset_master_path)
    active_assets = asset_master[asset_master["is_active"].fillna(True)]
    tickers = active_assets["ticker"].dropna().astype(str).tolist()
    if not tickers:
        raise ValueError("Asset master does not contain any active tickers to load.")

    print(f"Connecting to MotherDuck database {args.database}...")
    connection = connect_md(args.database)
    schema_name = ensure_schema(connection, args.schema)

    create_table(connection, schema_name)
    purge_stale_tickers(connection, schema_name, tickers)

    loaded_counts: list[tuple[str, int]] = []
    for ticker in tickers:
        row_count = load_ticker(connection, schema_name, ticker, args.period)
        loaded_counts.append((ticker, row_count))

    print("\nTicker summary:")
    for ticker, row_count in loaded_counts:
        print(f"- {ticker}: {row_count} rows")

    validate_load(connection, schema_name)
    connection.close()
    print("\nDaily price load complete.")


if __name__ == "__main__":
    main()
