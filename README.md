# ClearETF

ClearETF is a small ETF research stack built on Python, MotherDuck, dbt, and Streamlit.
It combines curated ETF metadata with daily market prices, models that data into analytics-friendly tables, and serves a lightweight web app for exploring ETF details, exposures, and price history.

## What This Repo Does

The repo does three main jobs:

1. Loads source data into MotherDuck.
2. Transforms that raw data into reporting tables with dbt.
3. Exposes the modeled data through a Streamlit app.

The current app focuses on ETF lookup and review. You can search an ETF, inspect metadata, review geography and sector exposure, and view its historical price chart.

## Data Flow

The pipeline works like this:

1. `data/asset_master.csv` defines the tracked instrument universe.
2. `src/load_daily_prices.py` downloads historical prices for active tickers from `yfinance`.
3. Curated ETF metadata and exposure mappings come from a Google Sheet.
4. The Python loaders write these datasets into the `raw` schema in MotherDuck.
5. dbt builds staging, dimensions, intermediate models, marts, exports, and reports on top of the raw tables.
6. `app/Home.py` queries the modeled tables in MotherDuck and renders the Streamlit UI.

## Main Components

### Ingestion

The ingestion scripts live in `src/`:

- `src/load_asset_master.py`
  Loads `data/asset_master.csv` into `raw.asset_master`.
- `src/load_daily_prices.py`
  Pulls daily OHLCV history from `yfinance` for active tickers and loads `raw.asset_prices_yfinance`.
- `src/load_etf_metadata.py`
  Loads ETF metadata tabs from a configured Google Sheet into:
  `raw.etf_metadata`, `raw.etf_geography`, `raw.etf_sector`, `raw.equivalence_groups`, and `raw.equivalence_group_relationships`.
- `src/ingestion_utils.py`
  Shared MotherDuck connection, schema creation, identifier cleanup, and dataframe normalization helpers.

### Modeling

The dbt project lives in `dbt/` and materializes tables into these schemas:

- `stg`
- `dimensions`
- `int`
- `marts`
- `exports`
- `reports`

The Streamlit app mainly reads from the `marts` schema plus staged asset prices for the chart.

### App

The Streamlit app lives in `app/`:

- `app/Home.py`
  Main ETF search and analysis page.
- `app/motherduck_utils.py`
  Reads settings from environment variables, `.env`, or `.streamlit/secrets.toml`, then connects to MotherDuck.
- `app/app_auth.py`
  Adds a simple shared-password gate using `APP_PASSWORD`.

## Repo Layout

```text
.
|-- .github/workflows/       GitHub Actions automation
|-- app/                     Streamlit app
|-- data/                    Curated CSV/XLSX inputs
|-- dbt/                     dbt project and models
|-- src/                     Python ingestion scripts
|-- requirements.txt         Root Python dependencies
```

## Requirements

- Python 3.11 recommended
- A MotherDuck token
- Access to the local source files in `data/`

Environment variables used by the project:

- `MOTHERDUCK_TOKEN`
- `MOTHERDUCK_DATABASE` optional, defaults to `md:clear_etf`
- `MOTHERDUCK_SCHEMA` optional for loaders, defaults to `raw`
- `ETF_METADATA_GOOGLE_SHEET` required for `src/load_etf_metadata.py`; use the full Google Sheets share URL when possible
- `APP_PASSWORD` required for the Streamlit app

## Local Setup

Install dependencies from the repo root:

```bash
pip install -r requirements.txt
```

If you want to run the Streamlit app locally, create either:

- `.streamlit/secrets.toml`
- or a repo-root `.env`

Minimum local configuration:

```toml
MOTHERDUCK_TOKEN = "your-motherduck-token"
MOTHERDUCK_DATABASE = "md:clear_etf"
APP_PASSWORD = "choose-a-shared-password"
```

## Running The Ingestion Scripts

From the repo root:

```bash
python src/load_asset_master.py
python src/load_daily_prices.py
python src/load_etf_metadata.py
```

These scripts expect `MOTHERDUCK_TOKEN` to be available in the environment.

`src/load_etf_metadata.py` reads ETF metadata only from Google Sheets. Set
`ETF_METADATA_GOOGLE_SHEET` to the full share URL for the sheet:

```powershell
$env:ETF_METADATA_GOOGLE_SHEET = "https://docs.google.com/spreadsheets/d/your-sheet-id/edit?gid=0&resourcekey=your-resource-key#gid=0"
python src/load_etf_metadata.py
```

You can also pass it explicitly on the command line:

```powershell
python src/load_etf_metadata.py --google-sheet "https://docs.google.com/spreadsheets/d/your-sheet-id/edit?gid=0&resourcekey=your-resource-key#gid=0"
```

The loader downloads the Google Sheet as XLSX and reads the required tabs from that export. If
your Google share link includes a `resourcekey`, use the full URL rather than only the sheet ID.

## Running dbt

Create a dbt profile at `~/.dbt/profiles.yml` on Mac/Linux or `%USERPROFILE%\.dbt\profiles.yml` on Windows.

Example profile:

```yaml
clear_etf:
  target: dev
  outputs:
    dev:
      type: duckdb
      path: "md:clear_etf"
      token: "{{ env_var('MOTHERDUCK_TOKEN') }}"
      threads: 4
```

Then run dbt from the `dbt/` directory:

```bash
.\dbt.cmd debug
.\dbt.cmd deps
.\dbt.cmd run --profile clear_etf
```

If your environment resolves `dbt` differently, you can also use the virtualenv executable directly.

## Running The App

From the repo root:

```bash
streamlit run app/Home.py
```

The app shows:

- ETF metadata
- geography exposure
- sector exposure
- historical adjusted-close price chart

The app uses a shared password gate. This is useful for a lightweight private app, but it is not full user-level authentication

## Automation

GitHub Actions runs the ingestion and dbt pipeline with `.github/workflows/daily_runner.yml`.

That workflow currently:

- supports manual runs with `workflow_dispatch`
- runs automatically every Sunday at `22:00 UTC`
- installs Python dependencies
- validates `MOTHERDUCK_TOKEN`
- loads raw data
- creates a dbt profile
- runs `dbt debug`, `dbt deps`, and `dbt run`

For GitHub Actions, configure this repository secret:

- `MOTHERDUCK_TOKEN`
- `ETF_METADATA_GOOGLE_SHEET` required, so Actions can load ETF metadata from Google Sheets

## Notes

- `src/load_etf_metadata.py` requires `ETF_METADATA_GOOGLE_SHEET` or `--google-sheet`; it no longer reads ETF metadata from a local XLSX fallback.
- If you use Google Sheets for local runs or GitHub Actions, the sheet must be accessible to the runtime without interactive login. In practice, that usually means `Anyone with the link` plus `Viewer`, and using the full share URL if Google includes a `resourcekey`.
- `data/asset_master.csv` controls which tickers are loaded from `yfinance`.
- The app assumes the dbt models have already been built in MotherDuck.
- There is a more dbt-specific guide in `dbt/README.md`.
