from datetime import date, datetime, time, timedelta, timezone

import pytest
from fastapi import FastAPI
from fastapi.testclient import TestClient
from pydantic import ValidationError
from sqlalchemy import create_engine, select
from sqlalchemy.orm import Session, sessionmaker
from sqlalchemy.pool import StaticPool

from app.database import Base, get_db
from app.chat_service import _extract_create_description, _extract_korean_time
from app.command_log_service import (
    LOG_RETENTION_DAYS,
    finish_command_log,
    mask_command_text,
    start_command_log,
)
from app.models import Alarm, Location, Routine, RoutineFrequency, Schedule, Source, User
from app.occurrence_service import get_next_occurrence, get_occurrences
from app.operation_service import (
    OperationError,
    cancel_operation,
    confirm_operation,
    preview_operation,
    revise_operation,
    undo_operation,
)
from app.routine_service import delete_routine
from app.routes import router
from app.schemas import (
    RoutineCreate,
    ScheduleOperationChanges,
    ScheduleOperationPreviewRequest,
    ScheduleOperationRevision,
    TodoCreate,
    TodoUpdate,
)
from app.todo_service import (
    create_todo,
    delete_todo,
    list_deleted_todos,
    list_todos,
    restore_todo,
    update_todo,
)


def routine_data(**changes):
    values = {
        "name": "Morning workout",
        "description": "30 minutes",
        "frequency": "DAILY",
        "repeat_interval": 1,
        "start_date": "2026-08-03",
        "start_time": "08:00:00",
        "timezone": "Asia/Seoul",
        "is_active": True,
    }
    values.update(changes)
    return values


def make_routine(**changes) -> Routine:
    values = {
        "id": 1,
        "user_id": "owner",
        "name": "Routine",
        "frequency": RoutineFrequency.DAILY,
        "repeat_interval": 1,
        "start_date": date(2026, 8, 3),
        "end_date": None,
        "timezone": "Asia/Seoul",
        "weekdays": None,
        "day_of_month": None,
        "start_time": time(8),
        "repeat_count": None,
        "description": None,
        "is_active": True,
    }
    values.update(changes)
    return Routine(**values)


@pytest.fixture()
def db():
    engine = create_engine(
        "sqlite://",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    Base.metadata.create_all(engine)
    session_factory = sessionmaker(bind=engine, expire_on_commit=False)
    session = session_factory()
    session.add_all(
        [
            User(
                user_id="owner",
                password_hash="x" * 64,
                user_name="Owner",
                phone_number="010-0000-0000",
            ),
            User(
                user_id="other",
                password_hash="x" * 64,
                user_name="Other",
                phone_number="010-0000-0001",
            ),
        ]
    )
    session.commit()
    try:
        yield session
    finally:
        session.close()
        Base.metadata.drop_all(engine)
        engine.dispose()


@pytest.fixture()
def client(db: Session):
    app = FastAPI()
    app.include_router(router)

    def override_db():
        yield db

    app.dependency_overrides[get_db] = override_db
    with TestClient(app) as test_client:
        yield test_client


def test_daily_routine_creation_schema():
    routine = RoutineCreate.model_validate(routine_data())
    assert routine.frequency == RoutineFrequency.DAILY
    assert routine.repeat_interval == 1
    assert routine.timezone == "Asia/Seoul"


def test_korean_create_fallback_extracts_time_and_content():
    parsed = _extract_korean_time("11시 25분 공부하기", date(2026, 8, 3))
    assert parsed is not None
    assert parsed.isoformat() == "2026-08-03T11:25:00+09:00"
    assert _extract_create_description("11시 25분 공부하기") == "공부하기"
    colon_time = _extract_korean_time("15:30 공부하기", date(2026, 8, 3))
    assert colon_time is not None
    assert colon_time.isoformat() == "2026-08-03T15:30:00+09:00"
    assert _extract_create_description("15:30 공부하기") == "공부하기"


def test_command_logs_are_masked_and_expire_after_thirty_days(db: Session):
    assert mask_command_text(
        "010-3120-1319 test@example.com 비밀번호=secret Bearer abc.def"
    ) == "010-****-1319 t***@example.com 비밀번호=[MASKED] Bearer [MASKED]"
    old = start_command_log(
        db,
        user_id="owner",
        conversation_id="old",
        user_input="old",
        model_name="test",
    )
    old.expires_at = datetime.now() - timedelta(seconds=1)
    db.commit()
    current = start_command_log(
        db,
        user_id="owner",
        conversation_id="current",
        user_input="전화 010-3120-1319 token=abc",
        model_name="test",
    )
    remaining_conversations = db.scalars(
        select(type(old).conversation_id).order_by(type(old).conversation_id)
    ).all()
    assert remaining_conversations == ["current"]
    assert current.masked_input == "전화 010-****-1319 token=[MASKED]"
    assert current.expires_at - current.created_at == timedelta(
        days=LOG_RETENTION_DAYS
    )
    finish_command_log(
        db,
        current,
        status="blocked",
        stage="classification",
        details={"email": "test@example.com", "password": "secret"},
        error_code="UNKNOWN_COMMAND",
    )
    assert current.details == {
        "email": "t***@example.com",
        "password": "[MASKED]",
    }


def test_weekly_routine_with_multiple_weekdays():
    routine = RoutineCreate.model_validate(
        routine_data(frequency="WEEKLY", weekdays=["MON", "WED", "FRI"])
    )
    assert [item.value for item in routine.weekdays or []] == ["MON", "WED", "FRI"]


def test_monthly_routine_creation():
    routine = RoutineCreate.model_validate(
        routine_data(frequency="MONTHLY", day_of_month=31)
    )
    assert routine.day_of_month == 31


@pytest.mark.parametrize("value", [0, -1])
def test_invalid_repeat_interval_rejected(value):
    with pytest.raises(ValidationError):
        RoutineCreate.model_validate(routine_data(repeat_interval=value))


def test_weekly_without_weekdays_rejected():
    with pytest.raises(ValidationError, match="weekday"):
        RoutineCreate.model_validate(routine_data(frequency="WEEKLY"))


def test_monthly_without_day_rejected():
    with pytest.raises(ValidationError, match="day_of_month"):
        RoutineCreate.model_validate(routine_data(frequency="MONTHLY"))


def test_end_date_and_repeat_count_rejected_together():
    with pytest.raises(ValidationError, match="cannot both"):
        RoutineCreate.model_validate(
            routine_data(end_date="2026-12-31", repeat_count=10)
        )


def test_irrelevant_rule_fields_are_normalized():
    routine = RoutineCreate.model_validate(
        routine_data(frequency="DAILY", weekdays=["MON"], day_of_month=10)
    )
    assert routine.weekdays is None
    assert routine.day_of_month is None


def test_daily_occurrences_and_repeat_count():
    routine = make_routine(repeat_interval=2, repeat_count=3)
    occurrences = get_occurrences(
        routine,
        datetime(2026, 8, 1, tzinfo=timezone.utc),
        datetime(2026, 9, 1, tzinfo=timezone.utc),
    )
    assert [item.date() for item in occurrences] == [
        date(2026, 8, 3),
        date(2026, 8, 5),
        date(2026, 8, 7),
    ]


def test_biweekly_occurrences_with_multiple_weekdays():
    routine = make_routine(
        frequency=RoutineFrequency.WEEKLY,
        repeat_interval=2,
        weekdays=["MON", "WED", "FRI"],
    )
    occurrences = get_occurrences(
        routine,
        datetime(2026, 8, 3),
        datetime(2026, 9, 1),
    )
    assert [item.date() for item in occurrences] == [
        date(2026, 8, 3),
        date(2026, 8, 5),
        date(2026, 8, 7),
        date(2026, 8, 17),
        date(2026, 8, 19),
        date(2026, 8, 21),
        date(2026, 8, 31),
    ]


def test_monthly_day_is_clamped_to_last_day():
    routine = make_routine(
        frequency=RoutineFrequency.MONTHLY,
        start_date=date(2026, 1, 31),
        day_of_month=31,
    )
    occurrences = get_occurrences(
        routine,
        datetime(2026, 1, 1),
        datetime(2026, 5, 1),
    )
    assert [item.date() for item in occurrences] == [
        date(2026, 1, 31),
        date(2026, 2, 28),
        date(2026, 3, 31),
        date(2026, 4, 30),
    ]


def test_yearly_leap_day_is_clamped():
    routine = make_routine(
        frequency=RoutineFrequency.YEARLY,
        start_date=date(2028, 2, 29),
    )
    occurrences = get_occurrences(
        routine,
        datetime(2028, 1, 1),
        datetime(2031, 1, 1),
    )
    assert [item.date() for item in occurrences] == [
        date(2028, 2, 29),
        date(2029, 2, 28),
        date(2030, 2, 28),
    ]


def test_timezone_and_next_occurrence():
    routine = make_routine()
    occurrence = get_next_occurrence(
        routine, datetime(2026, 8, 2, 22, 30, tzinfo=timezone.utc)
    )
    assert occurrence == datetime.fromisoformat("2026-08-03T08:00:00+09:00")
    assert occurrence.utcoffset().total_seconds() == 9 * 3600


def test_routine_crud_and_owner_isolation(client: TestClient):
    created = client.post(
        "/api/routines",
        headers={"X-User-Id": "owner"},
        json=routine_data(),
    )
    assert created.status_code == 201
    routine_id = created.json()["id"]

    assert client.get(
        f"/api/routines/{routine_id}", headers={"X-User-Id": "other"}
    ).status_code == 404
    assert client.get(
        "/api/routines", headers={"X-User-Id": "owner"}
    ).json()[0]["name"] == "Morning workout"

    updated = client.patch(
        f"/api/routines/{routine_id}",
        headers={"X-User-Id": "owner"},
        json={"is_active": False},
    )
    assert updated.status_code == 200
    assert updated.json()["is_active"] is False


def test_general_schedule_allows_null_routine():
    data = TodoCreate(
        schedule_id=1,
        eta=datetime(2026, 8, 3, 10),
        description="One-off",
        user_id="owner",
        alarm_id="alarm",
        location_id=1,
    )
    assert data.routine_id is None
    assert data.is_exception is False


def test_exception_requires_original_time_and_routine():
    with pytest.raises(ValidationError, match="exception"):
        TodoCreate(
            schedule_id=1,
            eta=datetime(2026, 8, 3, 10),
            description="Moved",
            user_id="owner",
            alarm_id="alarm",
            location_id=1,
            is_exception=True,
        )


def test_routine_schedule_relation_and_delete_sets_null(db: Session):
    routine = Routine(
        user_id="owner",
        name="Linked",
        frequency=RoutineFrequency.DAILY,
        repeat_interval=1,
        start_date=date(2026, 8, 3),
        timezone="Asia/Seoul",
        start_time=time(8),
        is_active=True,
    )
    alarm = Alarm(
        alarm_id="a1",
        alarm_music=None,
        alarm_text="Wake",
        minutes_before=10,
        is_obsolete=False,
    )
    source = Source(source_id=1, name="Test")
    location = Location(
        location_id=1,
        name="home",
        latitude=37.0,
        longitude=127.0,
        source_id=1,
        is_obsolete=False,
    )
    db.add_all([routine, alarm, source])
    db.flush()
    db.add(location)
    db.flush()
    schedule = Schedule(
        schedule_id=1,
        scheduled_at=datetime(2026, 8, 3, 9),
        timezone="Asia/Seoul",
        description="Exception",
        user_id="owner",
        alarm_id="a1",
        location_id=1,
        is_obsolete=False,
        routine_id=routine.id,
        original_scheduled_at=datetime(2026, 8, 3, 8),
        is_exception=True,
    )
    db.add(schedule)
    db.commit()
    routine_id = routine.id

    assert schedule.routine_id == routine_id
    assert schedule.is_exception is True
    delete_routine(db, routine_id, "owner")
    db.refresh(schedule)
    assert schedule.routine_id is None
    assert db.get(Schedule, schedule.__mapper__.primary_key_from_instance(schedule)) is schedule


def test_todo_crud_uses_datetime_index_filter_and_soft_delete(db: Session):
    alarm = Alarm(
        alarm_id="crud-alarm",
        alarm_text="Test",
        minutes_before=10,
    )
    source = Source(source_id=2, name="Test")
    db.add_all([alarm, source])
    db.flush()
    location = Location(
        location_id=2,
        name="Test place",
        latitude=37.5,
        longitude=127.0,
        source_id=source.source_id,
    )
    db.add(location)
    db.commit()

    created = create_todo(
        db,
        TodoCreate(
            schedule_id=2,
            eta=datetime.fromisoformat("2026-08-03T23:23:00+09:00"),
            description="Sleep",
            user_id="owner",
            alarm_id=alarm.alarm_id,
            location_id=location.location_id,
        ),
    )
    assert created.scheduled_at == datetime(2026, 8, 3, 23, 23)
    assert [item.schedule_id for item in list_todos(db, date(2026, 8, 3))] == [2]
    assert list_todos(db, date(2026, 8, 4)) == []

    updated = update_todo(
        db,
        2,
        TodoUpdate(description="Updated", is_completed=True),
    )
    assert updated is not None and updated.description == "Updated"
    assert updated.is_completed is True
    assert delete_todo(db, 2) is True
    assert created.is_obsolete is True
    assert list_todos(db, date(2026, 8, 3)) == []
    assert [item.schedule_id for item in list_deleted_todos(db, "owner")] == [2]

    restored = restore_todo(db, 2, "owner")
    assert restored is not None and restored.is_obsolete is False
    assert [item.schedule_id for item in list_todos(db, date(2026, 8, 3))] == [2]
    assert list_deleted_todos(db, "owner") == []


def _add_operation_schedule(db: Session) -> Schedule:
    alarm = Alarm(alarm_id="op-alarm", alarm_text="Test", minutes_before=10)
    source = Source(source_id=3, name="Test")
    db.add_all([alarm, source])
    db.flush()
    location = Location(
        location_id=3,
        name="Operation place",
        latitude=37.5,
        longitude=127.0,
        source_id=3,
    )
    db.add(location)
    db.flush()
    schedule = Schedule(
        schedule_id=3,
        scheduled_at=datetime(2026, 8, 3, 23, 23),
        timezone="Asia/Seoul",
        description="Before",
        user_id="owner",
        alarm_id="op-alarm",
        location_id=3,
    )
    db.add(schedule)
    db.commit()
    return schedule


def test_schedule_operation_requires_preview_then_confirmation(db: Session):
    schedule = _add_operation_schedule(db)
    preview = preview_operation(
        db,
        "owner",
        ScheduleOperationPreviewRequest(
            action="update",
            schedule_id=3,
            conversation_id="chat-1",
            changes=ScheduleOperationChanges(
                description="After", alarm_minutes_before=15
            ),
        ),
    )
    assert preview.status == "pending"
    assert schedule.description == "Before"

    executed = confirm_operation(db, "owner", "chat-1")
    db.refresh(schedule)
    assert executed.status == "executed"
    assert schedule.description == "After"
    assert schedule.alarm.minutes_before == 15
    undone = undo_operation(db, "owner", executed.operation_id)
    db.refresh(schedule)
    assert undone.status == "undone"
    assert schedule.description == "Before"
    assert schedule.alarm.minutes_before == 10
    with pytest.raises(OperationError):
        confirm_operation(db, "other", "chat-1")


def test_schedule_operation_cancel_does_not_modify_schedule(db: Session):
    schedule = _add_operation_schedule(db)
    preview_operation(
        db,
        "owner",
        ScheduleOperationPreviewRequest(
            action="delete",
            schedule_id=3,
            conversation_id="chat-2",
        ),
    )
    cancelled = cancel_operation(db, "owner", "chat-2")
    db.refresh(schedule)
    assert cancelled.status == "cancelled"
    assert schedule.is_obsolete is False


def test_create_operation_is_pending_until_confirmed_and_undo_is_soft_delete(
    db: Session,
):
    preview = preview_operation(
        db,
        "owner",
        ScheduleOperationPreviewRequest(
            action="create",
            conversation_id="chat-create",
            changes=ScheduleOperationChanges(
                eta=datetime.fromisoformat("2026-08-03T11:25:00+09:00"),
                description="Study",
                alarm_minutes_before=10,
            ),
        ),
    )
    assert preview.status == "pending"
    assert preview.schedule_id is None

    revised = revise_operation(
        db,
        "owner",
        preview.operation_id,
        ScheduleOperationRevision(
            description="Deep study",
            alarm_minutes_before=30,
        ),
    )
    assert revised.proposed_values["description"] == "Deep study"
    assert revised.proposed_values["alarm_minutes_before"] == 30

    executed = confirm_operation(db, "owner", "chat-create")
    assert executed.schedule_id is not None
    schedule = db.get(Schedule, executed.schedule_id)
    assert schedule is not None
    assert schedule.description == "Deep study"
    assert schedule.alarm.minutes_before == 30
    assert schedule.location_id is None

    undone = undo_operation(db, "owner", executed.operation_id)
    db.refresh(schedule)
    assert undone.status == "undone"
    assert schedule.is_obsolete is True


def test_preview_alarm_revision_is_limited_to_thirty_minutes():
    with pytest.raises(ValidationError):
        ScheduleOperationRevision(alarm_minutes_before=31)
