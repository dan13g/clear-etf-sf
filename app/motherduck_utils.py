import os
from pathlib import Path

import duckdb

DEFAULT_DB_PATH = "md:clear_etf"
ENV_FILE = Path(__file__).resolve().parents[1] / ".env"
SECRETS_FILE = Path(__file__).resolve().parents[1] / ".streamlit" / "secrets.toml"
LOCAL_SETTINGS: dict[str, str] = {}


def load_repo_env(env_file: Path) -> None:
    try:
        from dotenv import load_dotenv

        load_dotenv(env_file)
        return
    except ImportError:
        pass

    if not env_file.exists():
        return

    for raw_line in env_file.read_text(encoding="utf-8").splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue

        key, value = line.split("=", 1)
        key = key.strip()
        value = value.strip().strip('"').strip("'")

        if key:
            os.environ.setdefault(key, value)


def load_local_settings(settings_file: Path) -> dict[str, str]:
    if not settings_file.exists():
        return {}

    settings: dict[str, str] = {}
    for raw_line in settings_file.read_text(encoding="utf-8").splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue

        key, value = line.split("=", 1)
        key = key.strip()
        value = value.strip().strip('"').strip("'")

        if key and value:
            settings[key] = value

    return settings


load_repo_env(ENV_FILE)
LOCAL_SETTINGS = load_local_settings(SECRETS_FILE)


def get_streamlit_secret(name: str) -> str | None:
    try:
        import streamlit as st

        secret_value = st.secrets.get(name)
        if secret_value:
            return str(secret_value)
    except Exception:
        return None

    return None


def get_setting(name: str) -> str | None:
    env_value = os.getenv(name)
    if env_value:
        return env_value

    local_value = LOCAL_SETTINGS.get(name)
    if local_value:
        return local_value

    return get_streamlit_secret(name)


def connect_md(database_path: str | None = None) -> duckdb.DuckDBPyConnection:
    token = get_setting("MOTHERDUCK_TOKEN")
    if not token:
        raise RuntimeError("MOTHERDUCK_TOKEN must be set in the environment or Streamlit secrets.")

    escaped_token = token.replace("'", "''")
    target_database = (
        database_path
        or get_setting("MOTHERDUCK_DATABASE")
        or DEFAULT_DB_PATH
    )

    connection = duckdb.connect(database=":memory:")
    connection.execute("INSTALL motherduck;")
    connection.execute("LOAD motherduck;")
    connection.execute(f"SET motherduck_token='{escaped_token}';")
    connection.execute(f"ATTACH '{target_database}' AS md (TYPE motherduck);")
    connection.execute("USE md;")
    return connection
