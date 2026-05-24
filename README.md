# ClearETF Snowflake

This repo is a Snowflake version of the ClearETF example stack. It keeps the Python ingestion scripts and dbt models, but removes the Streamlit app layer.

The pipeline now does two jobs:

1. Loads raw ETF source data into Snowflake.
2. Builds staging, dimensions, marts, exports, and reports with dbt.

## Target Snowflake Account

This repo is configured around these defaults:

- Account: `CPRCYYC-FB19926`
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

- `ETF_METADATA_GOOGLE_SHEET`
- Local auth: `SNOWFLAKE_PASSWORD`
- CI auth alternative: `SNOWFLAKE_PRIVATE_KEY_PATH`

Optional overrides:

- `SNOWFLAKE_ACCOUNT`
- `SNOWFLAKE_USER`
- `SNOWFLAKE_PASSWORD`
- `SNOWFLAKE_ROLE`
- `SNOWFLAKE_WAREHOUSE`
- `SNOWFLAKE_DATABASE`
- `SNOWFLAKE_SCHEMA`
- `SNOWFLAKE_AUTHENTICATOR`
- `SNOWFLAKE_CA_BUNDLE`
- `SNOWFLAKE_PRIVATE_KEY_PATH`
- `SNOWFLAKE_PRIVATE_KEY_PASSPHRASE`
- `SNOWFLAKE_CI_USER`
- `SNOWFLAKE_CI_ROLE`
- `SNOWFLAKE_CI_WAREHOUSE`
- `SNOWFLAKE_CI_DATABASE`
- `SNOWFLAKE_CI_SCHEMA`

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

Or run the full raw-table sequence in one go:

```bash
python src/load_all_raw.py
```

`src/load_etf_metadata.py` reads ETF metadata from Google Sheets only. Set `ETF_METADATA_GOOGLE_SHEET` to the full share URL when Google includes a `resourcekey`.

If your network uses a corporate TLS inspection certificate, set `SNOWFLAKE_CA_BUNDLE` in `.env` to the PEM file path. The loaders will apply it automatically to Snowflake and related HTTPS requests.

## dbt Profile

Add `clear_etf_local` and optionally `clear_etf_ci` to `%USERPROFILE%\\.dbt\\profiles.yml` on Windows or `~/.dbt/profiles.yml` on Mac/Linux.

An example is included at [dbt/profiles.example.yml](/c:/Users/dan13/OneDrive/Documents/GitHub/clear-etf-sf/dbt/profiles.example.yml).

Then run dbt from [dbt](/c:/Users/dan13/OneDrive/Documents/GitHub/clear-etf-sf/dbt):

```bash
.\dbt.cmd debug --profile clear_etf_local
.\dbt.cmd deps --profile clear_etf_local
.\dbt.cmd run --profile clear_etf_local
```

## GitHub Actions

Two workflows are included:

- [.github/workflows/snowflake_smoke_test.yml](/c:/Users/dan13/OneDrive/Documents/GitHub/clear-etf-sf/.github/workflows/snowflake_smoke_test.yml)
  Runs only Python Snowflake connectivity plus `dbt debug`.
- [.github/workflows/daily_runner.yml](/c:/Users/dan13/OneDrive/Documents/GitHub/clear-etf-sf/.github/workflows/daily_runner.yml)
  Runs the smoke test steps, then loaders, then dbt.

Repository secrets needed:

- `SNOWFLAKE_CI_USER`
- `SNOWFLAKE_CI_ROLE`
- `SNOWFLAKE_CI_WAREHOUSE`
- `SNOWFLAKE_CI_DATABASE`
- `SNOWFLAKE_CI_SCHEMA`
- `SNOWFLAKE_PRIVATE_KEY`
- `SNOWFLAKE_PRIVATE_KEY_PASSPHRASE` optional
- `ETF_METADATA_GOOGLE_SHEET`

The `SNOWFLAKE_PRIVATE_KEY` secret should contain the PEM contents of the private key used for Snowflake key-pair authentication.

## Notes

- Raw tables are loaded into `clearetf_db.RAW`.
- dbt sources now read from the Snowflake `RAW` schema.
- The old Streamlit app is not part of this Snowflake version.
