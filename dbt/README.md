# dbt Setup

This dbt project now targets Snowflake.

## Install

```bash
pip install "dbt-core==1.8.0" "dbt-snowflake==1.8.0"
```

## profiles.yml

Create or update:

- Windows: `%USERPROFILE%\\.dbt\\profiles.yml`
- Mac/Linux: `~/.dbt/profiles.yml`

Use the example in [profiles.example.yml](/c:/Users/dan13/OneDrive/Documents/GitHub/clear-etf-sf/dbt/profiles.example.yml).

You can keep your existing `aw_dw_dbt` profile and add `clear_etf` alongside it as a separate top-level profile.

## Run

From [dbt](/c:/Users/dan13/OneDrive/Documents/GitHub/clear-etf-sf/dbt):

```bash
.\dbt.cmd debug --profile clear_etf
.\dbt.cmd deps
.\dbt.cmd run --profile clear_etf
```

## Notes

- The raw source name is `snowflake_raw`.
- Raw source tables are expected in `clearetf_db.RAW`.
- The date spine model was rewritten for Snowflake recursion instead of DuckDB `generate_series`.
