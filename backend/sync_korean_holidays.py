"""Import the package-compatible Korean holiday feed into the central DB."""

from __future__ import annotations

import argparse
import json
import os
import subprocess
from datetime import date, datetime
from pathlib import Path
from urllib.parse import urlparse

import httpx


DEFAULT_SOURCE_URL = (
    "https://beomq.github.io/world_holidays/api/holidays/kr.json"
)
SOURCE_NAME = "WORLD_HOLIDAYS"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--secret-file", type=Path, required=True)
    parser.add_argument("--source-url", default=DEFAULT_SOURCE_URL)
    return parser.parse_args()


def download_payload(source_url: str) -> dict:
    parsed = urlparse(source_url)
    if parsed.scheme != "https" or parsed.hostname != "beomq.github.io":
        raise ValueError("Holiday source must use the approved HTTPS host")
    try:
        response = httpx.get(source_url, timeout=30, follow_redirects=True)
        response.raise_for_status()
        return response.json()
    except httpx.ConnectError:
        process_environment = os.environ.copy()
        process_environment["SKECHAT_HOLIDAY_SOURCE_URL"] = source_url
        completed = subprocess.run(
            [
                "powershell.exe",
                "-NoProfile",
                "-NonInteractive",
                "-Command",
                "$ProgressPreference='SilentlyContinue'; "
                "(Invoke-WebRequest -UseBasicParsing "
                "-Uri $env:SKECHAT_HOLIDAY_SOURCE_URL).Content",
            ],
            check=True,
            capture_output=True,
            text=True,
            encoding="utf-8-sig",
            env=process_environment,
        )
        return json.loads(completed.stdout)


def main() -> None:
    args = parse_args()
    secret_file = args.secret_file.resolve()
    if not secret_file.is_file():
        raise FileNotFoundError(secret_file)
    os.environ["SKECHAT_ENV_FILE"] = str(secret_file)

    from sqlalchemy import select

    from app.database import SessionLocal
    from app.models import Holiday

    payload = download_payload(args.source_url)
    incoming = payload.get("holidays")
    if not isinstance(incoming, list) or not incoming:
        raise RuntimeError("Holiday source returned no records")

    now = datetime.now()
    received_dates: set[date] = set()
    with SessionLocal() as db:
        for raw in incoming:
            holiday_date = date.fromisoformat(str(raw["date"]))
            received_dates.add(holiday_date)
            descriptions = raw.get("description") or {}
            description_ko = descriptions.get("ko") if isinstance(descriptions, dict) else None
            description_en = descriptions.get("en") if isinstance(descriptions, dict) else None
            name = str(raw.get("name") or description_ko or description_en or "공휴일")
            combined_name = " ".join(
                value for value in (name, description_ko, description_en) if value
            ).lower()
            item = db.get(Holiday, {"country_code": "KR", "holiday_date": holiday_date})
            if item is None:
                item = Holiday(country_code="KR", holiday_date=holiday_date)
                db.add(item)
            item.name = name
            item.description_ko = description_ko
            item.description_en = description_en
            item.category = str(raw.get("type") or "NATIONAL")[:20]
            item.is_substitute = "대체" in combined_name or "substitute" in combined_name
            item.source = SOURCE_NAME
            item.is_obsolete = False
            item.updated_at = now

        existing = db.scalars(
            select(Holiday).where(
                Holiday.country_code == "KR",
                Holiday.source == SOURCE_NAME,
            )
        ).all()
        for item in existing:
            if item.holiday_date not in received_dates:
                item.is_obsolete = True
                item.updated_at = now
        db.commit()

    print(f"Synchronized {len(received_dates)} Korean holidays.")


if __name__ == "__main__":
    main()
