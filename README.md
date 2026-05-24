# ClearETF Snowflake

This repo is a Snowflake version of the ClearETF example stack. It keeps the Python ingestion scripts and dbt models, but removes the Streamlit app layer.

The pipeline now does two jobs:

1. Loads raw ETF source data into Snowflake.
2. Builds staging, dimensions, marts, exports, and reports with dbt.

## Target Snowflake Account

This repo is configured around these defaults:

- Account: `FB19926.eu-west-2.aws`
- User: `bgheoca`
- Role: `clearetf_role`
- Warehouse: `clearetf_wh`
- Database: `clearetf_db`
- Schema: `RAW`
- Authenticator: `username_password_mfa`

Only the password is intentionally left out of the repo. Set it with `SNOWFLAKE_PASSWORD`.

## Repo Layout

```text
.
|-- .github/workflows/       GitHub Actions automation
|-- data/                    Curated CSV inputs
|-- dbt/                     dbt project and Snowflake profile example
|-- src/                     Python ingestion scripts
|-- requirements.txt         Root Python dependencies
```

## Environment Variables

Required:

- `SNOWFLAKE_PASSWORD`
- `ETF_METADATA_GOOGLE_SHEET`

Optional overrides:

- `SNOWFLAKE_ACCOUNT`
- `SNOWFLAKE_USER`
- `SNOWFLAKE_ROLE`
- `SNOWFLAKE_WAREHOUSE`
- `SNOWFLAKE_DATABASE`
- `SNOWFLAKE_SCHEMA`
- `SNOWFLAKE_AUTHENTICATOR`

## Install

```bash
pip install -r requirements.txt
```

## Python Loads

From the repo root:

```bash
python src/load_asset_master.py
python src/load_daily_prices.py
python src/load_etf_metadata.py
```

`src/load_etf_metadata.py` reads ETF metadata from Google Sheets only. Set `ETF_METADATA_GOOGLE_SHEET` to the full share URL when Google includes a `resourcekey`.

## dbt Profile

Add a `clear_etf` profile block to `%USERPROFILE%\\.dbt\\profiles.yml` on Windows or `~/.dbt/profiles.yml` on Mac/Linux.

An example is included at [dbt/profiles.example.yml](/c:/Users/dan13/OneDrive/Documents/GitHub/clear-etf-sf/dbt/profiles.example.yml).

Then run dbt from [dbt](/c:/Users/dan13/OneDrive/Documents/GitHub/clear-etf-sf/dbt):

```bash
.\dbt.cmd debug --profile clear_etf
.\dbt.cmd deps
.\dbt.cmd run --profile clear_etf
```

## GitHub Actions

The workflow in [.github/workflows/daily_runner.yml](/c:/Users/dan13/OneDrive/Documents/GitHub/clear-etf-sf/.github/workflows/daily_runner.yml) now targets Snowflake instead of MotherDuck.

Repository secrets needed:

- `SNOWFLAKE_PASSWORD`
- `ETF_METADATA_GOOGLE_SHEET`

## Notes

- Raw tables are loaded into `clearetf_db.RAW`.
- dbt sources now read from the Snowflake `RAW` schema.
- The old Streamlit app is not part of this Snowflake version.
