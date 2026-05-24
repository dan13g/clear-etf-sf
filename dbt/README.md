# dbt Setup

This dbt project now supports separate local and CI Snowflake profiles.

## Profile Names

- `clear_etf_local`: local username/password/MFA workflow
- `clear_etf_ci`: GitHub Actions or other automation using a Snowflake private key

## Install

```bash
pip install "dbt-core==1.8.0" "dbt-snowflake==1.8.0"
```

## profiles.yml

Create or update:

- Windows: `%USERPROFILE%\\.dbt\\profiles.yml`
- Mac/Linux: `~/.dbt/profiles.yml`

Use the example in [profiles.example.yml](/c:/Users/dan13/OneDrive/Documents/GitHub/clear-etf-sf/dbt/profiles.example.yml).

## Local Run

From [dbt](/c:/Users/dan13/OneDrive/Documents/GitHub/clear-etf-sf/dbt):

```bash
.\dbt.cmd debug --profile clear_etf_local
.\dbt.cmd deps --profile clear_etf_local
.\dbt.cmd run --profile clear_etf_local
```

## CI Run

GitHub Actions uses `clear_etf_ci` with:

- `private_key_path`
- optional `private_key_passphrase`
- secret-driven `user`, `role`, `warehouse`, `database`, and `schema`

The CI smoke test runs:

```bash
dbt debug --profile clear_etf_ci
```

## Notes

- The raw source name is `snowflake_raw`.
- Raw source tables are expected in `clearetf_db.RAW`.
- The date spine model was rewritten for Snowflake recursion instead of DuckDB `generate_series`.
