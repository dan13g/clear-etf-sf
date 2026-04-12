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

Minimum local config:

```toml
MOTHERDUCK_TOKEN = "your-motherduck-token"
MOTHERDUCK_DATABASE = "md:clear_etf"
APP_PASSWORD = "choose-a-shared-password"
```

The app now requires a single shared password for every user. Store it in `.streamlit/secrets.toml` for local development or set `APP_PASSWORD` as an environment variable.

For Streamlit Community Cloud, set:
- Main file path: `app/Home.py`
- App dependency file: `app/requirements.txt`
- Secret `MOTHERDUCK_TOKEN`
- Optional secret `MOTHERDUCK_DATABASE=md:clear_etf`
- Secret `APP_PASSWORD`

## Deployment Checklist
1. Push the repo to GitHub.
2. In Streamlit Community Cloud, create a new app from the repo.
3. Set the main file path to `app/Home.py`.
4. If prompted for dependencies, point Streamlit at `app/requirements.txt`.
5. In the app settings, add these secrets:

```toml
MOTHERDUCK_TOKEN = "your-motherduck-token"
MOTHERDUCK_DATABASE = "md:clear_etf"
APP_PASSWORD = "choose-a-shared-password"
```

6. Deploy the app and confirm you see the password screen before the ETF search form.

This is a lightweight shared-password gate, which is useful for small private apps but is not a substitute for full user authentication.
