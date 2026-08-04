import asyncio
from datetime import date, datetime, time, timedelta, timezone

import pytest
from fastapi import FastAPI
from fastapi.testclient import TestClient
from pydantic import ValidationError
from sqlalchemy import create_engine, select
from sqlalchemy.orm import Session, sessionmaker
from sqlalchemy.pool import StaticPool

from app.database import Base, get_db
from app import chat_service
from app.chat_service import _extract_create_description, _extract_korean_time
from app.llm_service import _mixed_action_hint
from app.command_log_service import (
    LOG_RETENTION_DAYS,
    finish_command_log,
    mask_command_text,
    start_command_log,
)
from app.models import Alarm, Holiday, Location, Routine, RoutineFrequency, Schedule, Source, SyncBatch, User
from app.occurrence_service import get_next_occurrence, get_occurrences
from app.operation_service import (
    OperationError,
    cancel_operation,
    confirm_operation,
    preview_operation,
    revise_operation,
    revise_operation_item,
    select_operation_items,
    undo_operation,
)
from app.routine_service import delete_routine
from app.routes import router
from app.schemas import (
    MixedScheduleOperationItem,
    RoutineCreate,
    ScheduleOperationChanges,
    ScheduleOperationPreviewRequest,
    ScheduleOperationRevision,
    ScheduleOperationItemRevision,
    ScheduleOperationSelection,
    ScheduleCommand,
    ScheduleCommandItem,
    ScheduleChatChanges,
    TodoCreate,
    TodoUpdate,
)
from app.todo_service import (
    assemble_todo,
    create_todo,
    delete_todo,
    list_deleted_todos,
    list_todos,
    restore_todo,
    update_todo,
    find_schedule,
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


def test_colon_time_description_keeps_korean_title():
    assert _extract_create_description("13:32 낮잠") == "낮잠"


def test_mixed_crud_hint_only_for_different_write_actions():
    assert _mixed_action_hint("회의 추가하고 운동 삭제해줘")
    assert _mixed_action_hint("회의를 바꾸고 운동을 지워줘")
    assert _mixed_action_hint("회의와 운동을 모두 추가해줘") == ""
    assert _mixed_action_hint("13시에 치과, 15시에 약국 일정 추가해줘")


def test_chat_context_reads_only_the_selected_date(monkeypatch):
    calls = []

    async def fake_tool(name, arguments):
        calls.append((name, arguments))
        return []

    async def fake_classify(message, schedules, reference_date):
        assert schedules == []
        assert reference_date == date(2026, 8, 4)
        return ScheduleCommand(action="list", confidence=1)

    monkeypatch.setattr(chat_service, "call_mcp_tool", fake_tool)
    monkeypatch.setattr(chat_service, "classify_schedule_command", fake_classify)
    asyncio.run(
        chat_service.handle_chat(
            "일정 보여줘",
            "owner",
            "selected-date",
            reference_date=date(2026, 8, 4),
        )
    )

    assert calls
    assert all(
        arguments.get("date") == "2026-08-04"
        for name, arguments in calls
        if name == "list_schedule"
    )


def test_chat_can_explicitly_clear_an_existing_location(monkeypatch):
    calls = []
    schedule = {
        "id": 3,
        "eta": "2026-08-04T10:00:00+09:00",
        "description": "공부",
        "alarm": {"alarm_text": "공부"},
        "location": {"name": "도서관"},
    }

    async def fake_tool(name, arguments):
        calls.append((name, arguments))
        if name == "list_schedule":
            return [schedule]
        return {
            "operation_id": "clear-location",
            "message": "장소를 제거할까요?",
        }

    async def fake_classify(message, schedules, reference_date):
        return ScheduleCommand(
            action="update",
            confidence=1,
            schedule_id=3,
            changes=ScheduleChatChanges(clear_location=True),
        )

    monkeypatch.setattr(chat_service, "call_mcp_tool", fake_tool)
    monkeypatch.setattr(chat_service, "classify_schedule_command", fake_classify)
    asyncio.run(
        chat_service.handle_chat(
            "공부 일정 장소 없애줘",
            "owner",
            "clear-location",
            reference_date=date(2026, 8, 4),
        )
    )

    preview_arguments = next(
        arguments
        for name, arguments in calls
        if name == "preview_update_schedule"
    )
    assert preview_arguments["clear_location"] is True


def test_chat_can_assign_a_location_by_name(monkeypatch):
    calls = []
    schedule = {
        "id": 3,
        "eta": "2026-08-04T10:00:00+09:00",
        "description": "공부",
        "alarm": {"alarm_text": "공부"},
        "location": None,
    }

    async def fake_tool(name, arguments):
        calls.append((name, arguments))
        if name == "list_schedule":
            return [schedule]
        if name == "list_locations":
            return [{"location_id": 9, "name": "도서관"}]
        return {
            "operation_id": "assign-location",
            "message": "장소를 지정할까요?",
        }

    async def fake_classify(message, schedules, reference_date):
        return ScheduleCommand(
            action="update",
            confidence=1,
            schedule_id=3,
            changes=ScheduleChatChanges(location_query="도서관"),
        )

    monkeypatch.setattr(chat_service, "call_mcp_tool", fake_tool)
    monkeypatch.setattr(chat_service, "classify_schedule_command", fake_classify)
    asyncio.run(
        chat_service.handle_chat(
            "공부 일정을 도서관으로 바꿔줘",
            "owner",
            "assign-location",
            reference_date=date(2026, 8, 4),
        )
    )

    preview_arguments = next(
        arguments
        for name, arguments in calls
        if name == "preview_update_schedule"
    )
    assert preview_arguments["location_id"] == 9
    assert "location_query" not in preview_arguments


def test_chat_builds_one_preview_for_mixed_create_update_delete(monkeypatch):
    calls = []
    schedules = [
        {
            "id": 3,
            "eta": "2026-08-04T10:00:00+09:00",
            "description": "주간 회의",
            "alarm": {"alarm_text": "주간 회의"},
            "location": None,
        },
        {
            "id": 4,
            "eta": "2026-08-04T19:00:00+09:00",
            "description": "저녁 운동",
            "alarm": {"alarm_text": "저녁 운동"},
            "location": None,
        },
    ]

    async def fake_tool(name, arguments):
        calls.append((name, arguments))
        if name == "list_schedule":
            return schedules
        if name == "preview_mixed_schedule":
            return {
                "operation_id": "mixed-operation",
                "message": "혼합 작업을 적용할까요?",
            }
        raise AssertionError(name)

    async def fake_classify(message, current_schedules, reference_date):
        assert "회의" in message and "운동" in message
        return ScheduleCommand(
            action="mixed",
            confidence=1,
            operations=[
                ScheduleCommandItem(
                    action="create",
                    confidence=1,
                    changes=ScheduleChatChanges(
                        eta=datetime.fromisoformat("2026-08-04T13:30:00+09:00"),
                        description="치과",
                    ),
                ),
                ScheduleCommandItem(
                    action="update",
                    confidence=1,
                    schedule_id=3,
                    changes=ScheduleChatChanges(description="월간 회의"),
                ),
                ScheduleCommandItem(
                    action="delete",
                    confidence=1,
                    schedule_id=4,
                ),
            ],
        )

    monkeypatch.setattr(chat_service, "call_mcp_tool", fake_tool)
    monkeypatch.setattr(chat_service, "classify_schedule_command", fake_classify)
    message = asyncio.run(
        chat_service.handle_chat(
            "13시 30분 치과를 만들고 회의는 월간 회의로 바꾸고 운동은 삭제해줘",
            "owner",
            "mixed-chat",
            reference_date=date(2026, 8, 4),
        )
    )

    assert message == "혼합 작업을 적용할까요?"
    preview = next(arguments for name, arguments in calls if name == "preview_mixed_schedule")
    assert preview["select_all"] is True
    assert [item["action"] for item in preview["items"]] == [
        "create",
        "update",
        "delete",
    ]
    assert preview["items"][1]["schedule_id"] == 3
    assert preview["items"][2]["schedule_id"] == 4


def test_chat_builds_one_preview_for_schedule_and_routine(monkeypatch):
    calls = []

    async def fake_tool(name, arguments):
        calls.append((name, arguments))
        if name == "list_schedule":
            return []
        if name == "preview_mixed_schedule":
            return {
                "operation_id": "schedule-routine-operation",
                "message": "일정과 루틴을 확인해 주세요.",
            }
        raise AssertionError(name)

    async def fake_classify(message, current_schedules, reference_date):
        return ScheduleCommand(
            action="mixed",
            confidence=1,
            operations=[
                ScheduleCommandItem(
                    action="create",
                    confidence=1,
                    changes=ScheduleChatChanges(
                        eta=datetime.fromisoformat("2026-08-04T15:00:00+09:00"),
                        description="치과",
                    ),
                ),
                ScheduleCommandItem(
                    entity_type="routine",
                    action="create",
                    confidence=1,
                    routine=RoutineCreate(
                        name="운동",
                        frequency="WEEKLY",
                        weekdays=["MON", "WED", "FRI"],
                        start_date=date(2026, 8, 4),
                        start_time=time(7, 0),
                    ),
                ),
            ],
        )

    monkeypatch.setattr(chat_service, "call_mcp_tool", fake_tool)
    monkeypatch.setattr(chat_service, "classify_schedule_command", fake_classify)
    message = asyncio.run(
        chat_service.handle_chat(
            "오늘 15시 치과, 매주 월수금 7시 운동",
            "owner",
            "schedule-routine-chat",
            reference_date=date(2026, 8, 4),
        )
    )

    assert message == "일정과 루틴을 확인해 주세요."
    preview = next(arguments for name, arguments in calls if name == "preview_mixed_schedule")
    assert [item["entity_type"] for item in preview["items"]] == [
        "schedule",
        "routine",
    ]
    assert preview["items"][1]["routine"]["frequency"] == "WEEKLY"
    assert preview["items"][1]["routine"]["weekdays"] == ["MON", "WED", "FRI"]


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
            eta=datetime.fromisoformat("2026-08-03T23:23:00+09:00"),
            description="Sleep",
            user_id="owner",
            alarm_id=alarm.alarm_id,
            location_id=location.location_id,
        ),
        schedule_id=2,
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


def test_direct_todo_crud_rejects_client_id_and_invalid_references(client: TestClient):
    headers = {"X-User-Id": "owner"}
    assert client.get("/api/todos", headers=headers).status_code == 422
    base = {
        "eta": "2026-08-04T10:00:00+09:00",
        "description": "Validated",
        "user_id": "owner",
        "alarm_id": "missing-alarm",
        "location_id": None,
    }

    assert client.post(
        "/api/todos",
        headers=headers,
        json={**base, "schedule_id": 999},
    ).status_code == 422
    response = client.post("/api/todos", headers=headers, json=base)
    assert response.status_code == 400
    assert response.json()["detail"] == "alarm_id is not available"
    assert client.post(
        "/api/todos",
        headers=headers,
        json={**base, "description": ""},
    ).status_code == 422


def test_offline_todo_create_and_update_assign_server_identity(
    client: TestClient,
    db: Session,
):
    headers = {"X-User-Id": "owner"}
    created = client.post(
        "/api/offline/todos",
        headers=headers,
        json={
            "eta": "2026-08-04T09:30:00+09:00",
            "description": "Offline draft",
            "alarm_minutes_before": 10,
            "location_id": None,
            "is_completed": False,
        },
    )
    assert created.status_code == 201
    body = created.json()
    assert body["id"] > 0
    assert body["user"]["user_id"] == "owner"
    assert body["alarm"]["minutes_before"] == 10

    updated = client.patch(
        f"/api/offline/todos/{body['id']}",
        headers=headers,
        json={
            "description": "Synced offline draft",
            "alarm_minutes_before": 20,
            "is_completed": True,
        },
    )
    assert updated.status_code == 200
    updated_body = updated.json()
    assert updated_body["description"] == "Synced offline draft"
    assert updated_body["alarm"]["minutes_before"] == 20
    assert updated_body["is_completed"] is True

    batch = client.post(
        "/api/offline/todos/batch",
        headers=headers,
        json={
            "batch_id": "11111111-1111-4111-8111-111111111111",
            "operations": [
                {
                    "operation_id": "22222222-2222-4222-8222-222222222222",
                    "client_id": 11,
                    "operation": "create",
                    "todo_id": -1,
                    "payload": {
                        "eta": "2026-08-04T13:00:00+09:00",
                        "description": "Batched draft",
                        "alarm_minutes_before": 5,
                        "location_id": None,
                        "is_completed": False,
                    },
                }
            ]
        },
    )
    assert batch.status_code == 200
    batch_result = batch.json()["results"][0]
    assert batch_result["client_id"] == 11
    assert batch_result["todo_id"] > 0

    repeated = client.post(
        "/api/offline/todos/batch",
        headers=headers,
        json={
            "batch_id": "11111111-1111-4111-8111-111111111111",
            "operations": [
                {
                    "operation_id": "22222222-2222-4222-8222-222222222222",
                    "client_id": 11,
                    "operation": "create",
                    "todo_id": -1,
                    "payload": {
                        "eta": "2026-08-04T13:00:00+09:00",
                        "description": "Batched draft",
                        "alarm_minutes_before": 5,
                        "location_id": None,
                        "is_completed": False,
                    },
                }
            ],
        },
    )
    assert repeated.status_code == 200
    assert repeated.json() == batch.json()

    status_response = client.get(
        "/api/offline/batches/11111111-1111-4111-8111-111111111111",
        headers=headers,
    )
    assert status_response.status_code == 200
    assert status_response.json()["status"] == "COMMITTED"
    assert status_response.json()["attempt_count"] == 1
    assert status_response.json()["results"][0]["todo_id"] == batch_result["todo_id"]

    conflicting = client.post(
        "/api/offline/todos/batch",
        headers=headers,
        json={
            "batch_id": "11111111-1111-4111-8111-111111111111",
            "operations": [
                {
                    "operation_id": "22222222-2222-4222-8222-222222222222",
                    "client_id": 11,
                    "operation": "create",
                    "todo_id": -1,
                    "payload": {
                        "eta": "2026-08-04T13:00:00+09:00",
                        "description": "Changed payload",
                        "alarm_minutes_before": 5,
                        "location_id": None,
                        "is_completed": False,
                    },
                }
            ],
        },
    )
    assert conflicting.status_code == 409
    assert db.scalar(
        select(Schedule).where(Schedule.description == "Batched draft")
    ).schedule_id == batch_result["todo_id"]
    receipt = db.get(SyncBatch, "11111111-1111-4111-8111-111111111111")
    assert receipt is not None
    assert receipt.status == "COMMITTED"


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


def test_schedule_sync_returns_changes_deletions_and_isolates_users(
    client: TestClient,
    db: Session,
):
    _add_operation_schedule(db)
    owner_headers = {"X-User-Id": "owner"}

    initial = client.get("/api/sync", headers=owner_headers)
    assert initial.status_code == 200
    initial_body = initial.json()
    assert [item["todo"]["id"] for item in initial_body["items"]] == [3]
    assert initial_body["items"][0]["is_deleted"] is False

    other = client.get("/api/sync", headers={"X-User-Id": "other"})
    assert other.status_code == 200
    assert other.json()["items"] == []

    deleted = client.delete("/api/todos/3", headers=owner_headers)
    assert deleted.status_code == 204
    delta = client.get(
        "/api/sync",
        headers=owner_headers,
        params={"updated_after": initial_body["server_time"]},
    )
    assert delta.status_code == 200
    assert len(delta.json()["items"]) == 1
    assert delta.json()["items"][0]["todo"]["id"] == 3
    assert delta.json()["items"][0]["is_deleted"] is True


def test_holiday_sync_returns_reference_data_and_deletions(
    client: TestClient,
    db: Session,
):
    now = datetime(2026, 8, 4, 12, 0)
    db.add_all(
        [
            Holiday(
                country_code="KR",
                holiday_date=date(2026, 8, 15),
                name="Liberation Day",
                description_ko="광복절",
                description_en="Liberation Day",
                category="NATIONAL",
                is_substitute=False,
                source="TEST",
                is_obsolete=False,
                updated_at=now,
            ),
            Holiday(
                country_code="KR",
                holiday_date=date(2026, 10, 5),
                name="Removed holiday",
                category="NATIONAL",
                is_substitute=True,
                source="TEST",
                is_obsolete=True,
                updated_at=now,
            ),
        ]
    )
    db.commit()

    response = client.get(
        "/api/holidays/sync?country_code=KR",
        headers={"X-User-Id": "owner"},
    )

    assert response.status_code == 200
    items = response.json()["items"]
    assert [item["holiday"]["date"] for item in items] == [
        "2026-08-15",
        "2026-10-05",
    ]
    assert items[0]["holiday"]["description_ko"] == "광복절"
    assert items[0]["is_deleted"] is False
    assert items[1]["is_deleted"] is True

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
                description="After",
                alarm_minutes_before=15,
                location_id=None,
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
    assert schedule.location_id is None
    undone = undo_operation(db, "owner", executed.operation_id)
    db.refresh(schedule)
    assert undone.status == "undone"
    assert schedule.description == "Before"
    assert schedule.alarm.minutes_before == 10
    assert schedule.location_id == 3
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


def test_batch_operation_only_updates_selected_schedules(db: Session):
    first = _add_operation_schedule(db)
    second_alarm = Alarm(
        alarm_id="op-alarm-2", alarm_text="Second", minutes_before=10
    )
    second = Schedule(
        schedule_id=4,
        scheduled_at=datetime(2026, 8, 3, 18, 0),
        timezone="Asia/Seoul",
        description="Second",
        user_id="owner",
        alarm=second_alarm,
    )
    db.add_all([second_alarm, second])
    db.commit()

    preview = preview_operation(
        db,
        "owner",
        ScheduleOperationPreviewRequest(
            action="update",
            schedule_ids=[3, 4],
            conversation_id="chat-batch",
            changes=ScheduleOperationChanges(time_delta_minutes=30),
        ),
    )
    assert [item["selected"] for item in preview.items] == [False, False]
    select_operation_items(
        db,
        "owner",
        preview.operation_id,
        ScheduleOperationSelection(selected_schedule_ids=[4]),
    )
    confirm_operation(db, "owner", "chat-batch")
    db.refresh(first)
    db.refresh(second)
    assert first.scheduled_at == datetime(2026, 8, 3, 23, 23)
    assert second.scheduled_at == datetime(2026, 8, 3, 18, 30)


def test_mixed_operation_atomically_creates_updates_and_deletes(db: Session):
    first = _add_operation_schedule(db)
    second_alarm = Alarm(
        alarm_id="mixed-delete-alarm", alarm_text="저녁 운동", minutes_before=10
    )
    second = Schedule(
        schedule_id=4,
        scheduled_at=datetime(2026, 8, 4, 19, 0),
        timezone="Asia/Seoul",
        description="저녁 운동",
        user_id="owner",
        alarm=second_alarm,
    )
    db.add_all([second_alarm, second])
    db.commit()

    preview = preview_operation(
        db,
        "owner",
        ScheduleOperationPreviewRequest(
            action="mixed",
            conversation_id="mixed-crud",
            pipeline_revision=42,
            select_all=True,
            items=[
                MixedScheduleOperationItem(
                    item_id="create-dentist",
                    action="create",
                    changes=ScheduleOperationChanges(
                        eta=datetime.fromisoformat("2026-08-04T13:30:00+09:00"),
                        description="치과",
                        alarm_minutes_before=20,
                    ),
                ),
                MixedScheduleOperationItem(
                    item_id="update-meeting",
                    action="update",
                    schedule_id=3,
                    changes=ScheduleOperationChanges(description="월간 회의"),
                ),
                MixedScheduleOperationItem(
                    item_id="delete-workout",
                    action="delete",
                    schedule_id=4,
                ),
            ],
        ),
    )

    assert preview.action == "mixed"
    assert [item["action"] for item in preview.items] == [
        "create",
        "update",
        "delete",
    ]
    assert all(item["selected"] for item in preview.items)
    assert first.description == "Before"
    assert second.is_obsolete is False

    executed = confirm_operation(
        db,
        "owner",
        "mixed-crud",
        expected_operation_id=preview.operation_id,
        expected_revision=42,
    )
    db.refresh(first)
    db.refresh(second)
    created = db.scalar(
        select(Schedule).where(
            Schedule.user_id == "owner",
            Schedule.description == "치과",
        )
    )

    assert executed.status == "executed"
    assert len(executed.after_values["mixed_items"]) == 3
    assert created is not None
    assert created.scheduled_at == datetime(2026, 8, 4, 13, 30)
    assert created.alarm.minutes_before == 20
    assert first.description == "월간 회의"
    assert second.is_obsolete is True


def test_mixed_operation_supports_multiple_creates(db: Session):
    preview = preview_operation(
        db,
        "owner",
        ScheduleOperationPreviewRequest(
            action="mixed",
            conversation_id="multiple-creates",
            select_all=True,
            items=[
                MixedScheduleOperationItem(
                    item_id="dentist",
                    action="create",
                    changes=ScheduleOperationChanges(
                        eta=datetime.fromisoformat("2026-08-04T13:00:00+09:00"),
                        description="치과",
                    ),
                ),
                MixedScheduleOperationItem(
                    item_id="pharmacy",
                    action="create",
                    changes=ScheduleOperationChanges(
                        eta=datetime.fromisoformat("2026-08-04T15:00:00+09:00"),
                        description="약국",
                    ),
                ),
            ],
        ),
    )
    executed = confirm_operation(db, "owner", "multiple-creates")
    descriptions = {
        item["after_values"]["description"]
        for item in executed.after_values["mixed_items"]
    }
    assert descriptions == {"치과", "약국"}


def test_preview_pipeline_reuses_id_and_ignores_stale_revision(db: Session):
    schedule = _add_operation_schedule(db)
    first = preview_operation(
        db,
        "owner",
        ScheduleOperationPreviewRequest(
            action="update",
            schedule_id=3,
            conversation_id="chat-pipeline",
            pipeline_revision=10,
            changes=ScheduleOperationChanges(description="First draft"),
        ),
    )
    latest = preview_operation(
        db,
        "owner",
        ScheduleOperationPreviewRequest(
            action="update",
            schedule_id=3,
            conversation_id="chat-pipeline",
            pipeline_revision=12,
            changes=ScheduleOperationChanges(description="Latest draft"),
        ),
    )
    stale = preview_operation(
        db,
        "owner",
        ScheduleOperationPreviewRequest(
            action="update",
            schedule_id=3,
            conversation_id="chat-pipeline",
            pipeline_revision=11,
            changes=ScheduleOperationChanges(description="Stale draft"),
        ),
    )

    assert first.operation_id == latest.operation_id == stale.operation_id
    assert stale.pipeline_revision == 12
    assert stale.proposed_values["description"] == "Latest draft"
    with pytest.raises(OperationError):
        confirm_operation(
            db,
            "owner",
            "chat-pipeline",
            expected_operation_id=latest.operation_id,
            expected_revision=11,
        )
    confirm_operation(
        db,
        "owner",
        "chat-pipeline",
        expected_operation_id=latest.operation_id,
        expected_revision=12,
    )
    db.refresh(schedule)
    assert schedule.description == "Latest draft"


def test_manual_create_pipeline_allows_blank_preview_but_not_blank_commit(
    db: Session,
):
    _add_operation_schedule(db)
    preview = preview_operation(
        db,
        "owner",
        ScheduleOperationPreviewRequest(
            action="create",
            conversation_id="manual-create",
            pipeline_revision=20,
            allow_empty_description=True,
            changes=ScheduleOperationChanges(
                eta=datetime.fromisoformat("2026-08-04T00:00:00+09:00"),
                location_id=None,
                alarm_minutes_before=10,
            ),
        ),
    )
    assert preview.proposed_values.get("description", "") == ""
    with pytest.raises(OperationError):
        confirm_operation(
            db,
            "owner",
            "manual-create",
            expected_operation_id=preview.operation_id,
            expected_revision=20,
        )
    location_revised = revise_operation(
        db,
        "owner",
        preview.operation_id,
        ScheduleOperationRevision(location_id=3),
    )
    assert location_revised.proposed_values["description"] == ""
    assert location_revised.proposed_values["location_id"] == 3
    revised = revise_operation(
        db,
        "owner",
        preview.operation_id,
        ScheduleOperationRevision(description="Manual"),
    )
    assert revised.proposed_values["description"] == "Manual"
    executed = confirm_operation(
        db,
        "owner",
        "manual-create",
        expected_operation_id=preview.operation_id,
        expected_revision=20,
    )
    assert executed.status == "executed"
    assert executed.after_values["description"] == "Manual"
    assert executed.after_values["location"]["location_id"] == 3


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


def test_mixed_warning_requires_explicit_answer(db: Session):
    _add_operation_schedule(db)
    preview = preview_operation(
        db,
        "owner",
        ScheduleOperationPreviewRequest(
            action="mixed",
            conversation_id="warning-confirmation",
            select_all=True,
            items=[
                MixedScheduleOperationItem(
                    item_id="ambiguous-update",
                    action="update",
                    schedule_id=3,
                    changes=ScheduleOperationChanges(description="Confirmed"),
                    confidence=0.62,
                    warning="정정 표현을 감지했습니다.",
                    confirmation_question="이 내용으로 변경할까요?",
                    requires_confirmation=True,
                ),
                MixedScheduleOperationItem(
                    item_id="safe-create",
                    action="create",
                    changes=ScheduleOperationChanges(
                        eta=datetime(2026, 8, 4, 15, 0),
                        description="Safe create",
                    ),
                ),
            ],
        ),
    )
    warning_item = next(
        item for item in preview.items if item["item_id"] == "ambiguous-update"
    )
    assert warning_item["selected"] is False
    assert warning_item["confirmed"] is False
    with pytest.raises(OperationError):
        select_operation_items(
            db,
            "owner",
            preview.operation_id,
            ScheduleOperationSelection(
                selected_item_ids=["ambiguous-update", "safe-create"]
            ),
        )
    select_operation_items(
        db,
        "owner",
        preview.operation_id,
        ScheduleOperationSelection(
            selected_item_ids=["ambiguous-update", "safe-create"],
            confirmed_item_ids=["ambiguous-update"],
        ),
    )
    assert confirm_operation(db, "owner", "warning-confirmation").status == "executed"


def test_mixed_conflict_refresh_and_atomic_undo(db: Session):
    schedule = _add_operation_schedule(db)
    preview = preview_operation(
        db,
        "owner",
        ScheduleOperationPreviewRequest(
            action="mixed",
            conversation_id="mixed-conflict",
            select_all=True,
            items=[
                MixedScheduleOperationItem(
                    item_id="update",
                    action="update",
                    schedule_id=3,
                    changes=ScheduleOperationChanges(description="After conflict"),
                ),
                MixedScheduleOperationItem(
                    item_id="create",
                    action="create",
                    changes=ScheduleOperationChanges(
                        eta=datetime(2026, 8, 4, 16, 0),
                        description="Independent",
                    ),
                ),
            ],
        ),
    )
    schedule.description = "Concurrent change"
    schedule.updated_at = schedule.updated_at + timedelta(seconds=2)
    db.commit()
    conflicted = confirm_operation(db, "owner", "mixed-conflict")
    conflict_item = next(
        item for item in conflicted.items if item["item_id"] == "update"
    )
    assert conflicted.status == "pending"
    assert conflict_item["conflicted"] is True
    assert conflict_item["selected"] is False

    refreshed = revise_operation_item(
        db,
        "owner",
        preview.operation_id,
        "update",
        ScheduleOperationItemRevision(refresh_target=True),
    )
    assert next(
        item for item in refreshed.items if item["item_id"] == "update"
    )["conflicted"] is False
    select_operation_items(
        db,
        "owner",
        preview.operation_id,
        ScheduleOperationSelection(selected_item_ids=["update", "create"]),
    )
    executed = confirm_operation(db, "owner", "mixed-conflict")
    created_id = next(
        item["schedule_id"]
        for item in executed.after_values["mixed_items"]
        if item["item_id"] == "create"
    )
    undone = undo_operation(db, "owner", preview.operation_id)
    db.refresh(schedule)
    created = find_schedule(db, created_id, "owner")
    assert undone.status == "undone"
    assert schedule.description == "Concurrent change"
    assert created is not None and created.is_obsolete is True


def test_schedule_can_store_date_without_time(db: Session):
    _add_operation_schedule(db)
    alarm = Alarm(
        alarm_id="date-only-alarm",
        alarm_text="오늘 안에",
        minutes_before=10,
    )
    db.add(alarm)
    db.flush()
    created = create_todo(
        db,
        TodoCreate(
            eta=None,
            scheduled_date=date(2026, 8, 4),
            description="오늘 안에",
            user_id="owner",
            alarm_id=alarm.alarm_id,
        ),
    )
    read = assemble_todo(created)
    assert created.scheduled_at is None
    assert read.eta is None
    assert read.scheduled_date == date(2026, 8, 4)
    assert created in list_todos(db, date(2026, 8, 4), "owner")


def test_mixed_pipeline_can_create_schedule_and_weekday_routine(db: Session):
    _add_operation_schedule(db)
    preview = preview_operation(
        db,
        "owner",
        ScheduleOperationPreviewRequest(
            action="mixed",
            conversation_id="schedule-and-routine",
            select_all=True,
            items=[
                MixedScheduleOperationItem(
                    item_id="schedule",
                    action="create",
                    changes=ScheduleOperationChanges(
                        eta=datetime(2026, 8, 4, 13, 0),
                        description="점심 약속",
                    ),
                ),
                MixedScheduleOperationItem(
                    item_id="routine",
                    entity_type="routine",
                    action="create",
                    routine=RoutineCreate(
                        name="운동",
                        frequency="WEEKLY",
                        weekdays=["MON", "WED", "FRI"],
                        start_date=date(2026, 8, 4),
                        start_time=time(7, 0),
                    ),
                ),
            ],
        ),
    )
    assert [item["entity_type"] for item in preview.items] == [
        "schedule",
        "routine",
    ]
    executed = confirm_operation(db, "owner", "schedule-and-routine")
    assert executed.status == "executed"
    assert db.scalar(select(Routine).where(Routine.name == "운동")) is not None
    generated = db.scalars(
        select(Schedule).where(
            Schedule.description == "운동",
            Schedule.routine_id.is_not(None),
        )
    ).all()
    assert generated
    assert {item.scheduled_at.weekday() for item in generated[:6]} <= {0, 2, 4}
