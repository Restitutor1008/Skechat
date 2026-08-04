"""Run Alembic with the dedicated migration database credential."""

from __future__ import annotations

import argparse
import os
from pathlib import Path


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--secret-file", type=Path, required=True)
    parser.add_argument("--revision", default="head")
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    secret_file = args.secret_file.resolve()
    if not secret_file.is_file():
        raise FileNotFoundError(secret_file)

    os.environ["SKECHAT_ENV_FILE"] = str(secret_file)
    os.environ["RUN_DB_MIGRATIONS"] = "false"

    from alembic import command
    from alembic.config import Config

    backend_directory = Path(__file__).resolve().parent
    config = Config(str(backend_directory / "alembic.ini"))
    command.upgrade(config, args.revision)


if __name__ == "__main__":
    main()
