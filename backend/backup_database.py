"""Create a logical MySQL backup with the dedicated read-only account."""

from __future__ import annotations

import argparse
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

from manage_app_db_credentials import (
    _read_secret_file,
    _restrict_permissions,
    _validate_identifier,
)


DEFAULT_MYSQLDUMP = Path(
    r"C:\Program Files\MySQL\MySQL Server 8.0\bin\mysqldump.exe"
)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--secret-file", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    secret_file = args.secret_file.resolve()
    output_file = args.output.resolve()
    if output_file.exists():
        raise FileExistsError(output_file)

    values = _read_secret_file(secret_file)
    database = _validate_identifier(values["database"], "database name")
    executable = shutil.which("mysqldump")
    if executable is None and DEFAULT_MYSQLDUMP.is_file():
        executable = str(DEFAULT_MYSQLDUMP)
    if executable is None:
        raise FileNotFoundError("mysqldump executable was not found")

    output_file.parent.mkdir(parents=True, exist_ok=True)
    client_descriptor, client_name = tempfile.mkstemp(suffix=".cnf")
    dump_descriptor, dump_name = tempfile.mkstemp(
        prefix=f".{output_file.name}.", suffix=".tmp", dir=output_file.parent
    )
    client_file = Path(client_name)
    dump_file = Path(dump_name)
    try:
        with os.fdopen(
            client_descriptor, "w", encoding="utf-8", newline="\n"
        ) as file:
            file.write("[client]\n")
            file.write(f"user={values['username']}\n")
            file.write(f"password={values['password']}\n")
            file.write(f"host={values['host']}\n")
            file.write(f"port={values['port']}\n")
        _restrict_permissions(client_file)

        with os.fdopen(dump_descriptor, "wb") as output:
            subprocess.run(
                [
                    executable,
                    f"--defaults-extra-file={client_file}",
                    "--single-transaction",
                    "--quick",
                    "--events",
                    "--triggers",
                    "--no-tablespaces",
                    "--set-gtid-purged=OFF",
                    "--databases",
                    database,
                ],
                check=True,
                stdout=output,
                stderr=subprocess.PIPE,
            )
            output.flush()
            os.fsync(output.fileno())

        _restrict_permissions(dump_file)
        os.replace(dump_file, output_file)
        _restrict_permissions(output_file)
    finally:
        client_file.unlink(missing_ok=True)
        dump_file.unlink(missing_ok=True)

    print(f"Backup created: {output_file}")


if __name__ == "__main__":
    main()
