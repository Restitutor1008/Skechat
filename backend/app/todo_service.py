from datetime import date, datetime, time, timedelta
from uuid import uuid4
from zoneinfo import ZoneInfo

from sqlalchemy import select
from sqlalchemy.orm import Session

from .models import Alarm, Location, Routine, Schedule, User
from .schemas import (
    AlarmRead,
    LocationRead,
    OfflineTodoCreate,
    OfflineTodoUpdate,
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
        scheduled_date=schedule.scheduled_date,
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


def _validate_references(
    db: Session,
    *,
    user_id: str,
    alarm_id: str,
    location_id: int | None,
) -> None:
    if db.get(User, user_id) is None:
        raise ValueError("user_id does not exist")
    alarm = db.get(Alarm, alarm_id)
    if alarm is None or alarm.is_obsolete:
        raise ValueError("alarm_id is not available")
    if location_id is not None:
        location = db.get(Location, location_id)
        if location is None or location.is_obsolete:
            raise ValueError("location_id is not available")


def list_todos(
    db: Session,
    target_date: date | None = None,
    user_id: str | None = None,
) -> list[Schedule]:
    query = select(Schedule).where(Schedule.is_obsolete.is_(False))
    if user_id is not None:
        query = query.where(Schedule.user_id == user_id)
    if target_date:
        query = query.where(Schedule.scheduled_date == target_date)
    return list(
        db.scalars(
            query.order_by(Schedule.scheduled_at.is_(None), Schedule.scheduled_at)
        ).unique()
    )


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


def list_changed_todos(
    db: Session,
    user_id: str,
    *,
    updated_after: datetime | None,
    updated_through: datetime,
) -> list[Schedule]:
    query = select(Schedule).where(
        Schedule.user_id == user_id,
        Schedule.updated_at <= updated_through,
    )
    if updated_after is not None:
        query = query.where(Schedule.updated_at > updated_after)
    return list(
        db.scalars(query.order_by(Schedule.updated_at, Schedule.schedule_id)).unique()
    )


def create_todo(
    db: Session,
    data: TodoCreate,
    *,
    schedule_id: int | None = None,
    commit: bool = True,
) -> Schedule:
    _validate_routine_owner(db, data.routine_id, data.user_id)
    _validate_references(
        db,
        user_id=data.user_id,
        alarm_id=data.alarm_id,
        location_id=data.location_id,
    )
    schedule = Schedule(
        schedule_id=schedule_id,
        scheduled_date=data.scheduled_date,
        scheduled_at=_to_storage(data.eta) if data.eta is not None else None,
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


def create_offline_todo(
    db: Session,
    data: OfflineTodoCreate,
    user_id: str,
    *,
    commit: bool = True,
) -> Schedule:
    alarm = Alarm(
        alarm_id=f"offline-{uuid4()}",
        alarm_music=None,
        alarm_text=data.description,
        minutes_before=data.alarm_minutes_before,
    )
    db.add(alarm)
    db.flush()
    schedule = create_todo(
        db,
        TodoCreate(
            eta=data.eta,
            scheduled_date=data.scheduled_date,
            description=data.description,
            user_id=user_id,
            alarm_id=alarm.alarm_id,
            location_id=data.location_id,
            is_completed=data.is_completed,
        ),
        commit=False,
    )
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
    target_alarm_id = changes.get("alarm_id", schedule.alarm_id)
    target_location_id = changes.get("location_id", schedule.location_id)
    _validate_references(
        db,
        user_id=schedule.user_id,
        alarm_id=target_alarm_id,
        location_id=target_location_id,
    )
    if "eta" in changes:
        eta = changes.pop("eta")
        changes["scheduled_at"] = (
            _to_storage(eta, schedule.timezone) if eta is not None else None
        )
        if eta is not None and "scheduled_date" not in changes:
            changes["scheduled_date"] = eta.date()
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


def update_offline_todo(
    db: Session,
    todo_id: int,
    data: OfflineTodoUpdate,
    user_id: str,
    *,
    commit: bool = True,
) -> Schedule | None:
    schedule = find_schedule(db, todo_id, user_id)
    if schedule is None:
        return None
    changes = data.model_dump(exclude_unset=True)
    alarm_minutes = changes.pop("alarm_minutes_before", None)
    update_todo(
        db,
        todo_id,
        TodoUpdate.model_validate(changes),
        user_id,
        commit=False,
    ) if changes else None
    if alarm_minutes is not None:
        alarm = Alarm(
            alarm_id=f"offline-{uuid4()}",
            alarm_music=schedule.alarm.alarm_music,
            alarm_text=changes.get("description", schedule.description),
            minutes_before=alarm_minutes,
        )
        db.add(alarm)
        db.flush()
        schedule.alarm_id = alarm.alarm_id
        schedule.alarm = alarm
        schedule.updated_at = datetime.now()
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


def restore_todo(
    db: Session,
    todo_id: int,
    user_id: str,
    *,
    commit: bool = True,
) -> Schedule | None:
    schedule = find_schedule(db, todo_id, user_id)
    if schedule is None or not schedule.is_obsolete:
        return None
    schedule.is_obsolete = False
    if schedule.alarm is not None:
        schedule.alarm.is_obsolete = False
    if commit:
        db.commit()
        db.refresh(schedule)
    else:
        db.flush()
    return schedule
