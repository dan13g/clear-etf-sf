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

## Streamlit App
From the repo root:

```bash
pip install -r requirements.txt
streamlit run app/Home.py
```

For local secrets, create `.streamlit/secrets.toml` from `.streamlit/secrets.toml.example` or use a repo-root `.env`.

For Streamlit Community Cloud, set:
- Main file path: `app/Home.py`
- Secret `MOTHERDUCK_TOKEN`
- Optional secret `MOTHERDUCK_DATABASE=md:clear_etf`
