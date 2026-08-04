"""Provision and rotate the least-privilege SkeChat database credential."""

from __future__ import annotations

import argparse
import getpass
import os
from pathlib import Path
import re
import secrets
import subprocess
import sys
import tempfile
from urllib.parse import quote_plus

import pymysql
from dotenv import dotenv_values
from sqlalchemy import create_engine, text


ACCOUNT_PATTERN = re.compile(r"[A-Za-z0-9_]+")
DEFAULT_DATABASE = "todolistresti"
DEFAULT_HOST = "127.0.0.1"
DEFAULT_PORT = 3306


def _validate_identifier(value: str, label: str) -> str:
    if not ACCOUNT_PATTERN.fullmatch(value):
        raise ValueError(f"{label} contains unsupported characters")
    return value


def _random_password() -> str:
    return secrets.token_urlsafe(36)


def _restrict_permissions(path: Path) -> None:
    if os.name != "nt":
        path.chmod(0o600)
        return

    domain = os.getenv("USERDOMAIN")
    username = os.getenv("USERNAME") or getpass.getuser()
    principal = f"{domain}\\{username}" if domain else username
    subprocess.run(
        [
            "icacls",
            str(path),
            "/inheritance:r",
            "/grant:r",
            f"{principal}:(F)",
            "*S-1-5-18:(F)",
            "*S-1-5-32-544:(F)",
        ],
        check=True,
        capture_output=True,
        text=True,
    )


def _write_secret_file(path: Path, username: str, password: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    content = f"DB_USERNAME={username}\nDB_PASSWORD={password}\n"
    descriptor, temporary_name = tempfile.mkstemp(
        prefix=f".{path.name}.", suffix=".tmp", dir=path.parent
    )
    temporary_path = Path(temporary_name)
    try:
        with os.fdopen(descriptor, "w", encoding="utf-8", newline="\n") as file:
            file.write(content)
            file.flush()
            os.fsync(file.fileno())
        _restrict_permissions(temporary_path)
        os.replace(temporary_path, path)
        _restrict_permissions(path)
    finally:
        temporary_path.unlink(missing_ok=True)


def _read_secret_file(path: Path) -> dict[str, str]:
    values = dotenv_values(path)
    username = str(values.get("DB_USERNAME") or "")
    password = str(values.get("DB_PASSWORD") or "")
    if not username or not password:
        raise RuntimeError(f"DB_USERNAME or DB_PASSWORD is missing from {path}")
    return {
        "username": username,
        "password": password,
        "host": str(values.get("DB_HOST") or DEFAULT_HOST),
        "port": str(values.get("DB_PORT") or DEFAULT_PORT),
        "database": str(values.get("DB_NAME") or DEFAULT_DATABASE),
    }


def _connection_url(values: dict[str, str], *, include_database: bool) -> str:
    username = quote_plus(values["username"])
    password = quote_plus(values["password"])
    database = f"/{values['database']}" if include_database else "/"
    return (
        f"mysql+pymysql://{username}:{password}@"
        f"{values['host']}:{values['port']}{database}?charset=utf8mb4"
    )


def _verify_connection(
    *, username: str, password: str, host: str, port: int, database: str
) -> None:
    connection = pymysql.connect(
        host=host,
        port=port,
        user=username,
        password=password,
        database=database,
        connect_timeout=10,
    )
    try:
        with connection.cursor() as cursor:
            cursor.execute("SELECT 1")
            cursor.fetchone()
    finally:
        connection.close()


def provision(secret_file: Path, app_user: str, account_host: str) -> None:
    from app.config import get_settings

    settings = get_settings()
    app_user = _validate_identifier(app_user, "app user")
    account_host = _validate_identifier(account_host, "account host")
    database = _validate_identifier(settings.db_name, "database name")
    password = _random_password()
    admin_engine = create_engine(settings.server_database_url, pool_pre_ping=True)
    account = f"'{app_user}'@'{account_host}'"

    try:
        with admin_engine.connect() as connection:
            exists = connection.execute(
                text(
                    "SELECT COUNT(*) FROM mysql.user "
                    "WHERE User = :user AND Host = :host"
                ),
                {"user": app_user, "host": account_host},
            ).scalar_one()
            if exists:
                raise RuntimeError(f"Database account {account} already exists")

        with admin_engine.begin() as connection:
            connection.execute(
                text(
                    f"CREATE USER {account} IDENTIFIED BY :password "
                    "PASSWORD EXPIRE NEVER"
                ),
                {"password": password},
            )
            connection.execute(
                text(
                    f"GRANT SELECT, INSERT, UPDATE, DELETE "
                    f"ON `{database}`.* TO {account}"
                )
            )
            connection.execute(
                text(f"GRANT APPLICATION_PASSWORD_ADMIN ON *.* TO {account}")
            )

        _verify_connection(
            username=app_user,
            password=password,
            host=settings.db_host,
            port=settings.db_port,
            database=database,
        )
        _write_secret_file(secret_file, app_user, password)
    finally:
        admin_engine.dispose()

    print(f"Provisioned {account}; secret saved without displaying it.")


def provision_support_accounts(
    admin_secret_file: Path | None,
    secret_directory: Path,
    account_host: str,
    *,
    prompt_admin_password: bool = False,
) -> None:
    if prompt_admin_password:
        admin_values = {
            "username": "root",
            "password": getpass.getpass("MySQL root password: "),
            "host": DEFAULT_HOST,
            "port": str(DEFAULT_PORT),
            "database": DEFAULT_DATABASE,
        }
    elif admin_secret_file is not None:
        admin_values = _read_secret_file(admin_secret_file)
    else:
        raise ValueError("An admin Secret file or password prompt is required")
    database = _validate_identifier(admin_values["database"], "database name")
    account_host = _validate_identifier(account_host, "account host")
    admin_engine = create_engine(
        _connection_url(admin_values, include_database=False), pool_pre_ping=True
    )
    account_specs = (
        (
            "skechat_migration",
            "SELECT, INSERT, UPDATE, DELETE, CREATE, ALTER, DROP, INDEX, REFERENCES",
            secret_directory / ".env.migration",
        ),
        (
            "skechat_backup",
            "SELECT, SHOW VIEW, TRIGGER, EVENT, LOCK TABLES",
            secret_directory / ".env.backup",
        ),
    )

    try:
        for username, privileges, secret_file in account_specs:
            username = _validate_identifier(username, "support user")
            account = f"'{username}'@'{account_host}'"
            with admin_engine.connect() as connection:
                exists = connection.execute(
                    text(
                        "SELECT COUNT(*) FROM mysql.user "
                        "WHERE User = :user AND Host = :host"
                    ),
                    {"user": username, "host": account_host},
                ).scalar_one()
            if exists:
                if secret_file.exists():
                    print(f"Kept existing {account}; matching Secret already exists.")
                    continue
                raise RuntimeError(
                    f"Database account {account} exists without {secret_file}"
                )

            password = _random_password()
            with admin_engine.begin() as connection:
                connection.execute(
                    text(
                        f"CREATE USER {account} IDENTIFIED BY :password "
                        "PASSWORD EXPIRE NEVER"
                    ),
                    {"password": password},
                )
                connection.execute(
                    text(f"GRANT {privileges} ON `{database}`.* TO {account}")
                )
                connection.execute(
                    text(f"GRANT APPLICATION_PASSWORD_ADMIN ON *.* TO {account}")
                )

            _verify_connection(
                username=username,
                password=password,
                host=admin_values["host"],
                port=int(admin_values["port"]),
                database=database,
            )
            _write_secret_file(secret_file, username, password)
            print(f"Provisioned {account}; secret saved without displaying it.")
    finally:
        admin_engine.dispose()


def rotate(secret_file: Path, account_host: str) -> None:
    values = _read_secret_file(secret_file)
    app_user = _validate_identifier(values["username"], "app user")
    account_host = _validate_identifier(account_host, "account host")
    database = _validate_identifier(values["database"], "database name")
    port = int(values["port"])
    old_password = values["password"]
    new_password = _random_password()
    connection = pymysql.connect(
        host=values["host"],
        port=port,
        user=app_user,
        password=old_password,
        database=database,
        connect_timeout=10,
        autocommit=True,
    )
    try:
        with connection.cursor() as cursor:
            cursor.execute(
                "ALTER USER USER() IDENTIFIED BY %s "
                "RETAIN CURRENT PASSWORD",
                (new_password,),
            )
    finally:
        connection.close()

    _verify_connection(
        username=app_user,
        password=new_password,
        host=values["host"],
        port=port,
        database=database,
    )
    _write_secret_file(secret_file, app_user, new_password)
    print("Database credential rotated; the previous password remains secondary.")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    subparsers = parser.add_subparsers(dest="command", required=True)
    for command in ("provision", "rotate"):
        subparser = subparsers.add_parser(command)
        subparser.add_argument("--secret-file", type=Path, required=True)
        subparser.add_argument("--account-host", default="localhost")
        if command == "provision":
            subparser.add_argument("--app-user", default="skechat_app")
    support_parser = subparsers.add_parser("provision-support")
    admin_source = support_parser.add_mutually_exclusive_group(required=True)
    admin_source.add_argument("--admin-secret-file", type=Path)
    admin_source.add_argument("--prompt-admin-password", action="store_true")
    support_parser.add_argument("--secret-directory", type=Path, required=True)
    support_parser.add_argument("--account-host", default="localhost")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    try:
        if args.command == "provision":
            provision(args.secret_file.resolve(), args.app_user, args.account_host)
        elif args.command == "rotate":
            rotate(args.secret_file.resolve(), args.account_host)
        else:
            provision_support_accounts(
                args.admin_secret_file.resolve() if args.admin_secret_file else None,
                args.secret_directory.resolve(),
                args.account_host,
                prompt_admin_password=args.prompt_admin_password,
            )
    except Exception as error:
        print(f"Credential operation failed: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
