import os
from pathlib import Path

import duckdb

DEFAULT_DB_PATH = "md:clear_etf"
ENV_FILE = Path(__file__).resolve().parents[1] / ".env"


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


load_repo_env(ENV_FILE)


def connect_md(database_path: str | None = None) -> duckdb.DuckDBPyConnection:
    token = os.getenv("MOTHERDUCK_TOKEN")
    if not token:
        raise RuntimeError("MOTHERDUCK_TOKEN env var is required.")

    escaped_token = token.replace("'", "''")
    target_database = database_path or os.getenv("MOTHERDUCK_DATABASE", DEFAULT_DB_PATH)

    connection = duckdb.connect(database=":memory:")
    connection.execute("INSTALL motherduck;")
    connection.execute("LOAD motherduck;")
    connection.execute(f"SET motherduck_token='{escaped_token}';")
    connection.execute(f"ATTACH '{target_database}' AS md (TYPE motherduck);")
    connection.execute("USE md;")
    return connection
