import argparse
import os
from pathlib import Path

import pandas as pd
import yfinance as yf

from ingestion_utils import (
    DEFAULT_DATABASE,
    DEFAULT_SCHEMA,
    connect_snowflake,
    normalize_dataframe_for_snowflake,
    quote_identifier,
    replace_table,
)
from load_asset_master import DEFAULT_ASSET_MASTER, load_asset_master_file

TABLE_NAME = "asset_prices_yfinance"
OUTPUT_COLUMNS = [
    "ticker",
    "date",
    "open",
    "high",
    "low",
    "close",
    "adj_close",
    "volume",
]


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Load daily yfinance prices for every tracked asset in Snowflake."
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
    parser.add_argument(
        "--period",
        default="max",
        help="yfinance history period to download for each ticker. Defaults to max.",
    )
    return parser.parse_args()


def normalize_download_frame(dataframe: pd.DataFrame) -> pd.DataFrame:
    if getattr(dataframe.columns, "nlevels", 1) > 1:
        dataframe.columns = [
            column[0] if isinstance(column, tuple) else column
            for column in dataframe.columns
        ]

    dataframe = dataframe.reset_index()
    dataframe.columns = [str(column).strip() for column in dataframe.columns]
    return dataframe


def load_ticker(ticker: str, period: str) -> pd.DataFrame:
    print(f"Refreshing {ticker}...")

    dataframe = yf.download(
        ticker,
        period=period,
        auto_adjust=False,
        progress=False,
    )

    if dataframe.empty:
        print(f"No data returned for {ticker}")
        return pd.DataFrame(columns=OUTPUT_COLUMNS)

    dataframe = normalize_download_frame(dataframe)
    dataframe = dataframe.rename(
        columns={
            "Date": "date",
            "Open": "open",
            "High": "high",
            "Low": "low",
            "Close": "close",
            "Adj Close": "adj_close",
            "Volume": "volume",
        }
    )
    dataframe["ticker"] = ticker
    dataframe["date"] = pd.to_datetime(dataframe["date"]).dt.date
    dataframe = dataframe[OUTPUT_COLUMNS]
    return normalize_dataframe_for_snowflake(dataframe)


def validate_load(connection, schema_name: str) -> None:
    with connection.cursor() as cursor:
        cursor.execute(
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
        )
        rows = cursor.fetchall()

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

    loaded_frames: list[pd.DataFrame] = []
    loaded_counts: list[tuple[str, int]] = []
    for ticker in tickers:
        ticker_frame = load_ticker(ticker, args.period)
        loaded_counts.append((ticker, len(ticker_frame.index)))
        if not ticker_frame.empty:
            loaded_frames.append(ticker_frame)

    if not loaded_frames:
        raise RuntimeError("No price history was returned for any active ticker.")

    all_prices = pd.concat(loaded_frames, ignore_index=True)

    print(f"\nConnecting to Snowflake database {args.database}...")
    connection = connect_snowflake(args.database, args.schema)

    try:
        schema_name, table_name, row_count = replace_table(
            connection,
            all_prices,
            args.schema,
            TABLE_NAME,
            args.database,
        )

        print("\nTicker summary:")
        for ticker, ticker_row_count in loaded_counts:
            print(f"- {ticker}: {ticker_row_count} rows")

        validate_load(connection, schema_name)
    finally:
        connection.close()

    print(f"\nLoaded {row_count} rows into {schema_name}.{table_name}")
    print("\nDaily price load complete.")


if __name__ == "__main__":
    main()
