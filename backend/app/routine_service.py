from sqlalchemy import select, update
from sqlalchemy.orm import Session

from .models import Routine, Schedule, User
from .schemas import RoutineCreate, RoutineUpdate


class RoutineNotFoundError(LookupError):
    pass


class UserNotFoundError(LookupError):
    pass


def _values(data: RoutineCreate) -> dict:
    values = data.model_dump()
    values["weekdays"] = (
        [weekday.value for weekday in data.weekdays] if data.weekdays else None
    )
    return values


def list_routines(db: Session, user_id: str) -> list[Routine]:
    return list(
        db.scalars(
            select(Routine)
            .where(Routine.user_id == user_id)
            .order_by(Routine.created_at, Routine.id)
        )
    )


def get_routine(db: Session, routine_id: int, user_id: str) -> Routine:
    routine = db.scalar(
        select(Routine).where(
            Routine.id == routine_id,
            Routine.user_id == user_id,
        )
    )
    if not routine:
        raise RoutineNotFoundError
    return routine


def create_routine(db: Session, user_id: str, data: RoutineCreate) -> Routine:
    if db.get(User, user_id) is None:
        raise UserNotFoundError
    routine = Routine(user_id=user_id, **_values(data))
    db.add(routine)
    db.commit()
    db.refresh(routine)
    return routine


def update_routine(
    db: Session,
    routine_id: int,
    user_id: str,
    data: RoutineUpdate,
) -> Routine:
    routine = get_routine(db, routine_id, user_id)
    merged = {
        "name": routine.name,
        "description": routine.description,
        "frequency": routine.frequency,
        "repeat_interval": routine.repeat_interval,
        "weekdays": routine.weekdays,
        "day_of_month": routine.day_of_month,
        "start_date": routine.start_date,
        "end_date": routine.end_date,
        "repeat_count": routine.repeat_count,
        "start_time": routine.start_time,
        "timezone": routine.timezone,
        "is_active": routine.is_active,
    }
    merged.update(data.model_dump(exclude_unset=True))
    validated = RoutineCreate.model_validate(merged)
    for field, value in _values(validated).items():
        setattr(routine, field, value)
    db.commit()
    db.refresh(routine)
    return routine


def delete_routine(db: Session, routine_id: int, user_id: str) -> None:
    routine = get_routine(db, routine_id, user_id)
    db.execute(
        update(Schedule)
        .where(Schedule.routine_id == routine.id)
        .values(
            routine_id=None,
            is_exception=False,
            original_scheduled_at=None,
        )
    )
    db.delete(routine)
    db.commit()
