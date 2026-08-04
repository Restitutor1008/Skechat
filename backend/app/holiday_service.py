from datetime import datetime

from sqlalchemy import select
from sqlalchemy.orm import Session

from .models import Holiday


def list_changed_holidays(
    db: Session,
    country_code: str,
    *,
    updated_after: datetime | None,
    updated_through: datetime,
) -> list[Holiday]:
    statement = (
        select(Holiday)
        .where(
            Holiday.country_code == country_code.upper(),
            Holiday.updated_at <= updated_through,
        )
        .order_by(Holiday.updated_at, Holiday.holiday_date)
    )
    if updated_after is not None:
        statement = statement.where(Holiday.updated_at > updated_after)
    return list(db.scalars(statement).all())
