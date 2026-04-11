import os
import duckdb
import yfinance as yf

TICKERS = [
    "VWRP.L",
    "VUAG.L",
    "VUSA.L",
    "SSAC.L",
    "EIMI.L",
    "AGGG.L",
]

DB_PATH = "md:clear_etf"
SCHEMA = "raw"
TABLE = "prices_yfinance"


def connect_md() -> duckdb.DuckDBPyConnection:
    token = os.getenv("MOTHERDUCK_TOKEN")
    if not token:
        raise RuntimeError("MOTHERDUCK_TOKEN env var is required.")
    con = duckdb.connect(database=":memory:")
    con.execute(f"INSTALL motherduck; LOAD motherduck;")
    con.execute(f"SET motherduck_token='{token}';")
    con.execute(f"ATTACH '{DB_PATH}' AS md (TYPE motherduck);")
    con.execute("USE md;")
    return con


def create_table(con):
    con.execute(f"CREATE SCHEMA IF NOT EXISTS {SCHEMA}")

    con.execute(f"""
    CREATE TABLE IF NOT EXISTS {SCHEMA}.{TABLE} (
        ticker TEXT,
        date DATE,
        open DOUBLE,
        high DOUBLE,
        low DOUBLE,
        close DOUBLE,
        adj_close DOUBLE,
        volume DOUBLE
    )
    """)


def load_ticker(con, ticker):
    print(f"Refreshing {ticker}...")

    df = yf.download(
        ticker,
        period="max",
        auto_adjust=False,
        progress=False
    )

    if df.empty:
        print(f"No data returned for {ticker}")
        return

    # yfinance returns Date as the index, and newer versions may use
    # a MultiIndex for columns even for a single ticker.
    if getattr(df.columns, "nlevels", 1) > 1:
        df.columns = [
            col[0] if isinstance(col, tuple) else col
            for col in df.columns
        ]
    df = df.reset_index()

    # Delete existing rows for this ticker (MVP approach)
    con.execute(
        f"DELETE FROM {SCHEMA}.{TABLE} WHERE ticker = ?",
        [ticker]
    )

    # Register temp table
    con.register("temp_prices", df)

    # Insert into MotherDuck
    con.execute(f"""
        INSERT INTO {SCHEMA}.{TABLE}
        SELECT
            '{ticker}' AS ticker,
            CAST(Date AS DATE) AS date,
            Open AS open,
            High AS high,
            Low AS low,
            Close AS close,
            "Adj Close" AS adj_close,
            Volume AS volume
        FROM temp_prices
    """)

    con.unregister("temp_prices")


def validate_load(con):
    rows = con.execute(f"""
    SELECT
        ticker,
        MIN(date) AS min_date,
        MAX(date) AS max_date,
        COUNT(*) AS row_count
    FROM {SCHEMA}.{TABLE}
    GROUP BY ticker
    ORDER BY ticker
    """).fetchall()

    print("\nLoaded:")
    for row in rows:
        print(row)


def main():
    print("Connecting to MotherDuck...")
    con = connect_md()

    create_table(con)

    for ticker in TICKERS:
        load_ticker(con, ticker)

    validate_load(con)

    con.close()
    print("\nDone.")


if __name__ == "__main__":
    main()
