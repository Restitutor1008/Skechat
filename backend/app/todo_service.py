from datetime import date, datetime, time, timedelta
from zoneinfo import ZoneInfo

from sqlalchemy import select
from sqlalchemy.orm import Session

from .models import Routine, Schedule
from .schemas import (
    AlarmRead,
    LocationRead,
    TodoCreate,
    TodoRead,
    TodoUpdate,
    UserSummary,
)


DEFAULT_TIMEZONE = "Asia/Seoul"


def _to_storage(value: datetime, timezone: str = DEFAULT_TIMEZONE) -> datetime:
    """Store local wall-clock time; timezone is kept in a separate column."""
    if value.tzinfo is not None:
        value = value.astimezone(ZoneInfo(timezone))
    return value.replace(tzinfo=None)


def _to_api(value: datetime | None, timezone: str) -> datetime | None:
    if value is None:
        return None
    return value.replace(tzinfo=ZoneInfo(timezone)) if value.tzinfo is None else value


def assemble_todo(schedule: Schedule) -> TodoRead:
    """Assemble schedule, user, alarm, and location rows for the client."""
    return TodoRead(
        id=schedule.schedule_id,
        eta=_to_api(schedule.scheduled_at, schedule.timezone),
        description=schedule.description or "",
        user=UserSummary(
            user_id=schedule.user.user_id,
            user_name=schedule.user.user_name,
            phone_number=schedule.user.phone_number,
        ),
        alarm=AlarmRead(
            alarm_id=schedule.alarm.alarm_id,
            alarm_music=schedule.alarm.alarm_music,
            alarm_text=schedule.alarm.alarm_text,
            minutes_before=schedule.alarm.minutes_before,
        ),
        location=(
            LocationRead(
                location_id=schedule.location.location_id,
                name=schedule.location.name,
                latitude=float(schedule.location.latitude),
                longitude=float(schedule.location.longitude),
                source_id=schedule.location.source_id,
            )
            if schedule.location is not None
            else None
        ),
        is_completed=schedule.is_completed,
        routine_id=schedule.routine_id,
        original_scheduled_at=(
            _to_api(schedule.original_scheduled_at, schedule.timezone)
            if schedule.original_scheduled_at
            else None
        ),
        is_exception=schedule.is_exception,
    )


def _validate_routine_owner(
    db: Session, routine_id: int | None, user_id: str
) -> None:
    if routine_id is None:
        return
    routine = db.get(Routine, routine_id)
    if not routine or routine.user_id != user_id:
        raise ValueError("routine_id must belong to the schedule user")


def list_todos(
    db: Session,
    target_date: date | None = None,
    user_id: str | None = None,
) -> list[Schedule]:
    query = select(Schedule).where(Schedule.is_obsolete.is_(False))
    if user_id is not None:
        query = query.where(Schedule.user_id == user_id)
    if target_date:
        start = datetime.combine(target_date, time.min)
        query = query.where(
            Schedule.scheduled_at >= start,
            Schedule.scheduled_at < start + timedelta(days=1),
        )
    return list(db.scalars(query.order_by(Schedule.scheduled_at)).unique())


def list_deleted_todos(db: Session, user_id: str) -> list[Schedule]:
    query = (
        select(Schedule)
        .where(
            Schedule.user_id == user_id,
            Schedule.is_obsolete.is_(True),
        )
        .order_by(Schedule.updated_at.desc(), Schedule.scheduled_at.desc())
    )
    return list(db.scalars(query).unique())


def create_todo(
    db: Session, data: TodoCreate, *, commit: bool = True
) -> Schedule:
    _validate_routine_owner(db, data.routine_id, data.user_id)
    schedule = Schedule(
        schedule_id=data.schedule_id,
        scheduled_at=_to_storage(data.eta),
        timezone=DEFAULT_TIMEZONE,
        description=data.description,
        user_id=data.user_id,
        alarm_id=data.alarm_id,
        location_id=data.location_id,
        is_completed=data.is_completed,
        is_obsolete=False,
        routine_id=data.routine_id,
        original_scheduled_at=(
            _to_storage(data.original_scheduled_at)
            if data.original_scheduled_at
            else None
        ),
        is_exception=data.is_exception,
    )
    db.add(schedule)
    if commit:
        db.commit()
        db.refresh(schedule)
    else:
        db.flush()
    return schedule


def find_schedule(
    db: Session, schedule_id: int, user_id: str | None = None
) -> Schedule | None:
    query = select(Schedule).where(Schedule.schedule_id == schedule_id)
    if user_id is not None:
        query = query.where(Schedule.user_id == user_id)
    return db.scalar(query)


def update_todo(
    db: Session,
    todo_id: int,
    data: TodoUpdate,
    user_id: str | None = None,
    *,
    commit: bool = True,
) -> Schedule | None:
    schedule = find_schedule(db, todo_id, user_id)
    if not schedule:
        return None
    changes = data.model_dump(exclude_unset=True)
    target_routine_id = changes.get("routine_id", schedule.routine_id)
    _validate_routine_owner(db, target_routine_id, schedule.user_id)
    if "eta" in changes:
        eta = changes.pop("eta")
        if eta is not None:
            changes["scheduled_at"] = _to_storage(eta, schedule.timezone)
    if (
        "original_scheduled_at" in changes
        and changes["original_scheduled_at"] is not None
    ):
        changes["original_scheduled_at"] = _to_storage(
            changes["original_scheduled_at"], schedule.timezone
        )
    final_is_exception = changes.get("is_exception", schedule.is_exception)
    final_original = changes.get(
        "original_scheduled_at", schedule.original_scheduled_at
    )
    if final_is_exception and (target_routine_id is None or final_original is None):
        raise ValueError(
            "A schedule exception requires routine_id and original_scheduled_at"
        )
    for field, value in changes.items():
        setattr(schedule, field, value)
    if commit:
        db.commit()
        db.refresh(schedule)
    else:
        db.flush()
    return schedule


def delete_todo(
    db: Session,
    todo_id: int,
    user_id: str | None = None,
    *,
    commit: bool = True,
) -> bool:
    schedule = find_schedule(db, todo_id, user_id)
    if not schedule:
        return False
    schedule.is_obsolete = True
    if commit:
        db.commit()
    else:
        db.flush()
    return True


def restore_todo(db: Session, todo_id: int, user_id: str) -> Schedule | None:
    schedule = find_schedule(db, todo_id, user_id)
    if schedule is None or not schedule.is_obsolete:
        return None
    schedule.is_obsolete = False
    if schedule.alarm is not None:
        schedule.alarm.is_obsolete = False
    db.commit()
    db.refresh(schedule)
    return schedule
