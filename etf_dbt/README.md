# ClearETF

## Install (local)
pip install "dbt-core>=1.8" "dbt-duckdb>=1.5.2" duckdb

## profiles.yml (MotherDuck)
Create at:
- Windows: %USERPROFILE%\.dbt\profiles.yml
- Mac/Linux: ~/.dbt/profiles.yml

Example:

```yaml
etf_dbt:
  target: dev
  outputs:
    dev:
      type: duckdb
      path: "md:clear_etf"
      token: "{{ env_var('MOTHERDUCK_TOKEN') }}"
      threads: 4
```

## Env vars
- MOTHERDUCK_TOKEN

## Run
From this folder:

```bash
dbt debug
dbt run --select raw
dbt run --select staging
```

## Notes
- Raw models 