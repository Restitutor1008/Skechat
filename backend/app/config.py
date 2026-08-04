from dataclasses import dataclass
from functools import lru_cache
import os
from pathlib import Path
from urllib.parse import quote_plus

from dotenv import dotenv_values, load_dotenv


ROOT_DIR = Path(__file__).resolve().parents[2]
DEFAULT_ENV_FILE = ROOT_DIR.parent / ".env"


def _configured_env_file() -> Path:
    configured = os.getenv("SKECHAT_ENV_FILE")
    if not configured:
        return DEFAULT_ENV_FILE
    path = Path(configured).expanduser()
    return path if path.is_absolute() else (ROOT_DIR / path).resolve()


ENV_FILE = _configured_env_file()
load_dotenv(ENV_FILE, override=True)


def read_database_password() -> str:
    """Read the current DB password without caching it in the API process."""
    value = dotenv_values(ENV_FILE).get("DB_PASSWORD")
    password = str(value or os.getenv("DB_PASSWORD") or "")
    if not password:
        raise RuntimeError(f"DB_PASSWORD is missing from {ENV_FILE}")
    return password


@dataclass(frozen=True)
class Settings:
    db_username: str
    db_password: str
    db_driver: str
    db_host: str
    db_port: int
    db_name: str
    ollama_base_url: str
    llm_model: str
    api_host: str
    api_port: int
    internal_api_base_url: str
    run_db_migrations: bool

    @property
    def database_url(self) -> str:
        username = quote_plus(self.db_username)
        password = quote_plus(self.db_password)
        return (
            f"{self.db_driver}://{username}:{password}@"
            f"{self.db_host}:{self.db_port}/{self.db_name}?charset=utf8mb4"
        )

    @property
    def server_database_url(self) -> str:
        username = quote_plus(self.db_username)
        password = quote_plus(self.db_password)
        return f"{self.db_driver}://{username}:{password}@{self.db_host}:{self.db_port}/"


@lru_cache
def get_settings() -> Settings:
    required = ("DB_USERNAME", "DB_PASSWORD")
    missing = [name for name in required if not os.getenv(name)]
    if missing:
        raise RuntimeError(f"Missing environment variables: {', '.join(missing)}")
    return Settings(
        db_username=os.environ["DB_USERNAME"],
        db_password=read_database_password(),
        db_driver=os.getenv("DB_DRIVER", "mysql+pymysql"),
        db_host=os.getenv("DB_HOST", "127.0.0.1"),
        db_port=int(os.getenv("DB_PORT", "3306")),
        db_name=os.getenv("DB_NAME", "todolistresti"),
        ollama_base_url=os.getenv("OLLAMA_BASE_URL", "http://127.0.0.1:11434"),
        llm_model=os.getenv("LLM_MODEL", "gemma4:e4b"),
        api_host=os.getenv("API_HOST", "0.0.0.0"),
        api_port=int(os.getenv("API_PORT", "8000")),
        internal_api_base_url=os.getenv(
            "INTERNAL_API_BASE_URL", "http://127.0.0.1:8000"
        ),
        run_db_migrations=os.getenv("RUN_DB_MIGRATIONS", "false").lower()
        in {"1", "true", "yes"},
    )
