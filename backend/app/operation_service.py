from datetime import datetime, timedelta
from uuid import uuid4

from sqlalchemy import func, select
from sqlalchemy.orm import Session

from .models import Alarm, Schedule, ScheduleOperation
from .schemas import (
    ScheduleOperationPreviewRequest,
    ScheduleOperationRead,
    ScheduleOperationRevision,
    TodoCreate,
    TodoUpdate,
)
from .todo_service import (
    assemble_todo,
    create_todo,
    delete_todo,
    find_schedule,
    update_todo,
)


class OperationError(ValueError):
    pass


def _snapshot(schedule: Schedule) -> dict:
    data = assemble_todo(schedule).model_dump(mode="json")
    data["is_obsolete"] = schedule.is_obsolete
    data["updated_at"] = schedule.updated_at.isoformat(timespec="seconds")
    return data


def _same_version(stored: str, current: datetime) -> bool:
    return datetime.fromisoformat(stored).replace(microsecond=0) == current.replace(
        microsecond=0
    )


def _message(action: str, before: dict, proposed: dict) -> str:
    if action == "create":
        location_text = (
            f"장소 ID {proposed['location_id']}"
            if proposed.get("location_id") is not None
            else "장소 없음"
        )
        return (
            f"'{proposed['description']}' 일정을 {proposed['eta']}에 추가할까요? "
            f"{location_text}, 알람 {proposed.get('alarm_minutes_before', 10)}분 전입니다. "
            "실행하려면 YES, 취소하려면 NO라고 입력해 주세요."
        )
    if action == "delete":
        return (
            f"일정 #{before['id']} '{before['description']}'을 삭제(soft delete)할까요? "
            "실행하려면 YES, 취소하려면 NO라고 입력해 주세요."
        )
    changes = []
    if "eta" in proposed:
        changes.append(f"시간 → {proposed['eta']}")
    if "description" in proposed:
        changes.append(f"내용 → {proposed['description']}")
    if "alarm_id" in proposed:
        changes.append(f"알람 → {proposed['alarm_id']}")
    if "alarm_minutes_before" in proposed:
        changes.append(f"알람 → {proposed['alarm_minutes_before']}분 전")
    if "location_id" in proposed:
        changes.append(f"장소 ID → {proposed['location_id']}")
    return (
        f"일정 #{before['id']} '{before['description']}'의 변경 내용: "
        + ", ".join(changes)
        + ". 수정할까요? 실행하려면 YES, 취소하려면 NO라고 입력해 주세요."
    )


def _read(operation: ScheduleOperation) -> ScheduleOperationRead:
    return ScheduleOperationRead(
        operation_id=operation.operation_id,
        action=operation.action,
        schedule_id=operation.schedule_id,
        status=operation.status,
        before_values=operation.before_values,
        proposed_values=operation.payload,
        after_values=operation.after_values,
        message=_message(operation.action, operation.before_values, operation.payload),
    )


def preview_operation(
    db: Session, user_id: str, request: ScheduleOperationPreviewRequest
) -> ScheduleOperationRead:
    payload = (
        request.changes.model_dump(exclude_unset=True, mode="json")
        if request.changes is not None
        else {}
    )
    schedule = None
    before_values = {}
    if request.action == "create":
        location_id = payload.get("location_id")
        if location_id is not None:
            from .models import Location

            location = db.get(Location, location_id)
            if location is None or location.is_obsolete:
                raise OperationError("사용할 수 있는 장소를 찾지 못했습니다.")
        payload.setdefault("alarm_minutes_before", 10)
    else:
        assert request.schedule_id is not None
        schedule = find_schedule(db, request.schedule_id, user_id)
        if schedule is None or schedule.is_obsolete:
            raise OperationError("수정할 일정을 찾을 수 없습니다.")
        before_values = _snapshot(schedule)
    operation = ScheduleOperation(
        operation_id=str(uuid4()),
        user_id=user_id,
        conversation_id=request.conversation_id,
        action=request.action,
        schedule_id=schedule.schedule_id if schedule is not None else None,
        payload=payload,
        before_values=before_values,
        status="pending",
        expires_at=datetime.now() + timedelta(minutes=5),
    )
    db.add(operation)
    db.commit()
    return _read(operation)


def revise_operation(
    db: Session,
    user_id: str,
    operation_id: str,
    revision: ScheduleOperationRevision,
) -> ScheduleOperationRead:
    operation = db.get(ScheduleOperation, operation_id)
    if operation is None or operation.user_id != user_id:
        raise OperationError("수정할 미리보기를 찾을 수 없습니다.")
    if operation.status != "pending":
        raise OperationError("대기 중인 미리보기만 수정할 수 있습니다.")
    if operation.expires_at < datetime.now():
        operation.status = "expired"
        db.commit()
        raise OperationError("작업 확인 시간이 만료되었습니다. 다시 요청해 주세요.")
    if operation.action not in {"create", "update"}:
        raise OperationError("삭제 미리보기는 수정할 수 없습니다.")

    payload = dict(operation.payload)
    payload.update(revision.model_dump(exclude_unset=True, mode="json"))
    if operation.action == "create" and (
        not payload.get("eta") or not str(payload.get("description") or "").strip()
    ):
        raise OperationError("생성 미리보기에는 시각과 내용이 필요합니다.")
    operation.payload = payload
    db.commit()
    return _read(operation)


def _pending(
    db: Session, user_id: str, conversation_id: str
) -> ScheduleOperation | None:
    return db.scalar(
        select(ScheduleOperation)
        .where(
            ScheduleOperation.user_id == user_id,
            ScheduleOperation.conversation_id == conversation_id,
            ScheduleOperation.status == "pending",
        )
        .order_by(ScheduleOperation.created_at.desc())
    )


def confirm_operation(
    db: Session, user_id: str, conversation_id: str
) -> ScheduleOperationRead:
    operation = _pending(db, user_id, conversation_id)
    if operation is None:
        raise OperationError("확인 대기 중인 일정 작업이 없습니다.")
    if operation.expires_at < datetime.now():
        operation.status = "expired"
        db.commit()
        raise OperationError("작업 확인 시간이 만료되었습니다. 다시 요청해 주세요.")
    schedule = None
    if operation.action != "create":
        assert operation.schedule_id is not None
        schedule = find_schedule(db, operation.schedule_id, user_id)
        if schedule is None:
            raise OperationError("일정이 더 이상 존재하지 않습니다.")
        if not _same_version(operation.before_values["updated_at"], schedule.updated_at):
            operation.status = "conflicted"
            db.commit()
            raise OperationError("미리보기 이후 일정이 변경되어 작업을 중단했습니다.")
    if operation.action == "create":
        payload = dict(operation.payload)
        alarm_minutes = int(payload.pop("alarm_minutes_before", 10))
        alarm = Alarm(
            alarm_id=f"chat-{uuid4()}",
            alarm_music=None,
            alarm_text=payload.get("description"),
            minutes_before=alarm_minutes,
        )
        db.add(alarm)
        db.flush()
        schedule = create_todo(
            db,
            TodoCreate(
                eta=datetime.fromisoformat(payload["eta"]),
                description=payload["description"],
                user_id=user_id,
                alarm_id=alarm.alarm_id,
                location_id=payload.get("location_id"),
            ),
            commit=False,
        )
        operation.schedule_id = schedule.schedule_id
    elif operation.action == "update":
        assert schedule is not None
        payload = dict(operation.payload)
        alarm_minutes = payload.pop("alarm_minutes_before", None)
        update_todo(
            db,
            schedule.schedule_id,
            TodoUpdate.model_validate(payload),
            user_id,
            commit=False,
        )
        if alarm_minutes is not None:
            reference_count = db.scalar(
                select(func.count(Schedule.schedule_id)).where(
                    Schedule.alarm_id == schedule.alarm_id,
                    Schedule.is_obsolete.is_(False),
                )
            )
            if (reference_count or 0) > 1:
                old_alarm = schedule.alarm
                new_alarm = Alarm(
                    alarm_id=f"chat-{uuid4()}",
                    alarm_music=old_alarm.alarm_music,
                    alarm_text=old_alarm.alarm_text or schedule.description,
                    minutes_before=alarm_minutes,
                )
                db.add(new_alarm)
                db.flush()
                schedule.alarm_id = new_alarm.alarm_id
                schedule.alarm = new_alarm
            else:
                schedule.alarm.minutes_before = alarm_minutes
            schedule.updated_at = datetime.now()
            db.flush()
    elif operation.action == "delete":
        assert schedule is not None
        delete_todo(db, schedule.schedule_id, user_id, commit=False)
    else:
        raise OperationError("허용되지 않은 일정 작업입니다.")
    assert schedule is not None
    db.flush()
    db.refresh(schedule)
    operation.after_values = _snapshot(schedule)
    operation.status = "executed"
    operation.executed_at = datetime.now()
    db.commit()
    result = _read(operation)
    result.message = (
        f"일정 변경이 완료되었습니다. 작업 ID: {operation.operation_id}. "
        f"되돌리려면 '되돌리기 {operation.operation_id}'라고 입력해 주세요."
    )
    return result


def cancel_operation(
    db: Session, user_id: str, conversation_id: str
) -> ScheduleOperationRead:
    operation = _pending(db, user_id, conversation_id)
    if operation is None:
        raise OperationError("취소할 대기 작업이 없습니다.")
    operation.status = "cancelled"
    db.commit()
    result = _read(operation)
    result.message = "일정 변경을 취소했습니다."
    return result


def undo_operation(
    db: Session, user_id: str, operation_id: str
) -> ScheduleOperationRead:
    operation = db.get(ScheduleOperation, operation_id)
    if operation is None or operation.user_id != user_id:
        raise OperationError("되돌릴 작업을 찾을 수 없습니다.")
    if operation.status != "executed" or operation.after_values is None:
        raise OperationError("이 작업은 되돌릴 수 있는 상태가 아닙니다.")
    assert operation.schedule_id is not None
    schedule = find_schedule(db, operation.schedule_id, user_id)
    if schedule is None:
        raise OperationError("대상 일정이 더 이상 존재하지 않습니다.")
    if not _same_version(operation.after_values["updated_at"], schedule.updated_at):
        raise OperationError("작업 이후 일정이 다시 변경되어 안전하게 되돌릴 수 없습니다.")
    if operation.action == "create":
        schedule.is_obsolete = True
        schedule.alarm.is_obsolete = True
        schedule.updated_at = datetime.now()
        operation.status = "undone"
        operation.undone_at = datetime.now()
        db.commit()
        result = _read(operation)
        result.message = "생성한 일정을 soft delete하여 되돌렸습니다."
        return result
    before = operation.before_values
    current_alarm = schedule.alarm
    original = before.get("original_scheduled_at")
    update_todo(
        db,
        schedule.schedule_id,
        TodoUpdate(
            eta=datetime.fromisoformat(before["eta"]),
            description=before.get("description"),
            alarm_id=before["alarm"]["alarm_id"],
            location_id=(
                before["location"]["location_id"]
                if before.get("location") is not None
                else None
            ),
            routine_id=before.get("routine_id"),
            original_scheduled_at=(
                datetime.fromisoformat(original) if original is not None else None
            ),
            is_exception=bool(before.get("is_exception", False)),
            is_completed=bool(before.get("is_completed", False)),
        ),
        user_id,
        commit=False,
    )
    schedule.is_obsolete = bool(before.get("is_obsolete", False))
    original_alarm_id = before["alarm"]["alarm_id"]
    if current_alarm.alarm_id != original_alarm_id:
        current_alarm.is_obsolete = True
        schedule.alarm_id = original_alarm_id
    original_alarm = db.get(Alarm, original_alarm_id)
    if original_alarm is not None:
        original_alarm.minutes_before = before["alarm"]["minutes_before"]
        original_alarm.is_obsolete = False
    db.flush()
    operation.status = "undone"
    operation.undone_at = datetime.now()
    db.commit()
    result = _read(operation)
    result.message = "일정 변경을 안전하게 되돌렸습니다."
    return result
