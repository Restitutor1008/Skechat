from datetime import datetime, timedelta
from uuid import uuid4

from sqlalchemy import func, select
from sqlalchemy.orm import Session

from .models import Alarm, Routine, Schedule, ScheduleOperation
from .schemas import (
    ScheduleOperationPreviewRequest,
    ScheduleOperationItemRevision,
    ScheduleOperationRead,
    ScheduleOperationRevision,
    ScheduleOperationSelection,
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
from .routine_service import create_routine, delete_routine
from .schemas import RoutineCreate


class OperationError(ValueError):
    pass


def _pipeline_revision(operation: ScheduleOperation) -> int:
    return int(operation.payload.get("_pipeline_revision", 1))


def _public_payload(operation: ScheduleOperation) -> dict:
    payload = dict(operation.payload)
    payload.pop("_pipeline_revision", None)
    return payload


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
    batch_items = []
    if operation.action == "mixed":
        selected = set(operation.payload.get("selected_item_ids", []))
        confirmed = set(operation.payload.get("confirmed_item_ids", []))
        conflicts = set(operation.payload.get("conflicted_item_ids", []))
        batch_items = [
            {
                **item,
                "selected": item["item_id"] in selected,
                "confirmed": item["item_id"] in confirmed,
                "conflicted": item["item_id"] in conflicts,
            }
            for item in operation.payload.get("mixed_items", [])
        ]
    elif "items" in operation.before_values:
        selected = set(operation.payload.get("selected_schedule_ids", []))
        changes = operation.payload.get("changes", {})
        batch_items = [
            {
                "item_id": str(item["id"]),
                "action": operation.action,
                "schedule_id": item["id"],
                "before_values": item,
                "proposed_values": changes,
                "selected": item["id"] in selected,
            }
            for item in operation.before_values["items"]
        ]
    return ScheduleOperationRead(
        operation_id=operation.operation_id,
        action=operation.action,
        schedule_id=operation.schedule_id,
        status=operation.status,
        before_values=operation.before_values,
        proposed_values=_public_payload(operation),
        after_values=operation.after_values,
        message=(
            f"{len(batch_items)}개의 일정 작업을 확인하고 적용할 항목을 선택해 주세요."
            if operation.action == "mixed"
            else f"{len(batch_items)}개의 일정 중 적용할 항목을 선택해 주세요."
            if batch_items
            else _message(operation.action, operation.before_values, _public_payload(operation))
        ),
        items=batch_items,
        pipeline_revision=_pipeline_revision(operation),
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
    if request.action == "mixed":
        assert request.items is not None
        mixed_items = []
        for requested_item in request.items:
            item_changes = (
                requested_item.changes.model_dump(exclude_unset=True, mode="json")
                if requested_item.changes is not None
                else {}
            )
            item_before = {}
            if requested_item.entity_type == "routine":
                assert requested_item.routine is not None
                routine_values = requested_item.routine.model_dump(mode="json")
                item_changes.setdefault("description", requested_item.routine.name)
                item_changes.setdefault(
                    "scheduled_date", requested_item.routine.start_date.isoformat()
                )
                if requested_item.routine.start_time is not None:
                    item_changes.setdefault(
                        "eta",
                        datetime.combine(
                            requested_item.routine.start_date,
                            requested_item.routine.start_time,
                        ).isoformat(),
                    )
            elif requested_item.action == "create":
                routine_values = None
                item_changes.setdefault("alarm_minutes_before", 10)
                item_changes.setdefault("description", "")
                location_id = item_changes.get("location_id")
                if location_id is not None:
                    from .models import Location

                    location = db.get(Location, location_id)
                    if location is None or location.is_obsolete:
                        raise OperationError("사용할 수 있는 장소를 찾지 못했습니다.")
            else:
                routine_values = None
                assert requested_item.schedule_id is not None
                item_schedule = find_schedule(db, requested_item.schedule_id, user_id)
                if item_schedule is None or item_schedule.is_obsolete:
                    raise OperationError("혼합 작업의 대상 일정을 찾을 수 없습니다.")
                item_before = _snapshot(item_schedule)
            mixed_items.append(
                {
                    "item_id": requested_item.item_id,
                    "entity_type": requested_item.entity_type,
                    "action": requested_item.action,
                    "schedule_id": requested_item.schedule_id,
                    "before_values": item_before,
                    "proposed_values": item_changes,
                    "confidence": requested_item.confidence,
                    "warning": requested_item.warning,
                    "confirmation_question": requested_item.confirmation_question,
                    "requires_confirmation": requested_item.requires_confirmation,
                    "routine_values": routine_values,
                }
            )
        before_values = {
            "mixed_items": [
                {
                    "item_id": item["item_id"],
                    "action": item["action"],
                    "schedule_id": item["schedule_id"],
                    "before_values": item["before_values"],
                }
                for item in mixed_items
            ]
        }
        payload = {
            "mixed_items": mixed_items,
            "selected_item_ids": (
                [
                    item["item_id"]
                    for item in mixed_items
                    if not item.get("requires_confirmation")
                ]
                if request.select_all
                else []
            ),
            "confirmed_item_ids": [],
            "conflicted_item_ids": [],
        }
    elif request.action == "create":
        if request.allow_empty_description:
            payload.setdefault("description", "")
        location_id = payload.get("location_id")
        if location_id is not None:
            from .models import Location

            location = db.get(Location, location_id)
            if location is None or location.is_obsolete:
                raise OperationError("사용할 수 있는 장소를 찾지 못했습니다.")
        payload.setdefault("alarm_minutes_before", 10)
    elif request.schedule_ids:
        unique_ids = list(dict.fromkeys(request.schedule_ids))
        schedules = [find_schedule(db, schedule_id, user_id) for schedule_id in unique_ids]
        if any(item is None or item.is_obsolete for item in schedules):
            raise OperationError("선택한 일정 중 찾을 수 없는 일정이 있습니다.")
        before_values = {"items": [_snapshot(item) for item in schedules if item is not None]}
        payload = {
            "changes": payload,
            "selected_schedule_ids": unique_ids if request.select_all else [],
        }
    else:
        assert request.schedule_id is not None
        schedule = find_schedule(db, request.schedule_id, user_id)
        if schedule is None or schedule.is_obsolete:
            raise OperationError("수정할 일정을 찾을 수 없습니다.")
        before_values = _snapshot(schedule)
    active = _pending(db, user_id, request.conversation_id)
    if active is not None and active.expires_at < datetime.now():
        active.status = "expired"
        active = None
    if active is not None and request.pipeline_revision < _pipeline_revision(active):
        db.commit()
        return _read(active)

    payload["_pipeline_revision"] = request.pipeline_revision
    if active is None:
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
    else:
        operation = active
        operation.action = request.action
        operation.schedule_id = schedule.schedule_id if schedule is not None else None
        operation.payload = payload
        operation.before_values = before_values
        operation.after_values = None
        operation.expires_at = datetime.now() + timedelta(minutes=5)
    db.commit()
    return _read(operation)


def select_operation_items(
    db: Session,
    user_id: str,
    operation_id: str,
    selection: ScheduleOperationSelection,
) -> ScheduleOperationRead:
    operation = db.get(ScheduleOperation, operation_id)
    if operation is None or operation.user_id != user_id:
        raise OperationError("일정 미리보기를 찾을 수 없습니다.")
    if operation.status != "pending":
        raise OperationError("선택 가능한 일괄 미리보기가 아닙니다.")
    if operation.action == "mixed":
        allowed = {
            item["item_id"] for item in operation.payload.get("mixed_items", [])
        }
        selected_items = list(dict.fromkeys(selection.selected_item_ids))
        confirmed_items = list(dict.fromkeys(selection.confirmed_item_ids))
        if any(item_id not in allowed for item_id in selected_items):
            raise OperationError("미리보기에 없는 작업은 선택할 수 없습니다.")
        if any(item_id not in allowed for item_id in confirmed_items):
            raise OperationError("미리보기에 없는 작업은 확인할 수 없습니다.")
        required = {
            item["item_id"]
            for item in operation.payload.get("mixed_items", [])
            if item.get("requires_confirmation")
        }
        if any(item_id in required and item_id not in confirmed_items for item_id in selected_items):
            raise OperationError("경고가 있는 작업은 확인 질문에 먼저 답해 주세요.")
        payload = dict(operation.payload)
        payload["selected_item_ids"] = selected_items
        payload["confirmed_item_ids"] = confirmed_items
        operation.payload = payload
        db.commit()
        return _read(operation)
    if "items" not in operation.before_values:
        raise OperationError("선택 가능한 일괄 미리보기가 아닙니다.")
    allowed = {item["id"] for item in operation.before_values["items"]}
    selected = list(dict.fromkeys(selection.selected_schedule_ids))
    if selection.selected_item_ids:
        try:
            selected = list(dict.fromkeys(int(item_id) for item_id in selection.selected_item_ids))
        except ValueError as exc:
            raise OperationError("일정 선택값이 올바르지 않습니다.") from exc
    if any(schedule_id not in allowed for schedule_id in selected):
        raise OperationError("미리보기에 없는 일정은 선택할 수 없습니다.")
    payload = dict(operation.payload)
    payload["selected_schedule_ids"] = selected
    operation.payload = payload
    db.commit()
    return _read(operation)


def revise_operation_item(
    db: Session,
    user_id: str,
    operation_id: str,
    item_id: str,
    revision: ScheduleOperationItemRevision,
) -> ScheduleOperationRead:
    operation = db.get(ScheduleOperation, operation_id)
    if operation is None or operation.user_id != user_id:
        raise OperationError("일정 미리보기를 찾을 수 없습니다.")
    if operation.status != "pending" or operation.action != "mixed":
        raise OperationError("대기 중인 혼합 미리보기만 항목별로 수정할 수 있습니다.")
    payload = dict(operation.payload)
    items = [dict(item) for item in payload.get("mixed_items", [])]
    target = next((item for item in items if item["item_id"] == item_id), None)
    if target is None:
        raise OperationError("수정할 미리보기 항목을 찾을 수 없습니다.")

    if revision.refresh_target:
        if target["action"] == "create":
            raise OperationError("생성 항목에는 최신 대상 새로고침이 필요하지 않습니다.")
        schedule = find_schedule(db, int(target["schedule_id"]), user_id)
        if schedule is None or schedule.is_obsolete:
            raise OperationError("최신 일정을 다시 불러올 수 없습니다.")
        target["before_values"] = _snapshot(schedule)
        conflicts = set(payload.get("conflicted_item_ids", []))
        conflicts.discard(item_id)
        payload["conflicted_item_ids"] = list(conflicts)
        target.pop("conflict_message", None)

    values = revision.model_dump(
        exclude_unset=True,
        exclude={"refresh_target", "routine", "clear_routine"},
        mode="json",
    )
    if revision.clear_routine:
        if target["action"] != "create":
            raise OperationError("생성 항목만 일반 일정으로 전환할 수 있습니다.")
        target["entity_type"] = "schedule"
        target["routine_values"] = None
    if revision.routine is not None:
        if target["action"] != "create":
            raise OperationError("생성 항목만 루틴으로 전환할 수 있습니다.")
        target["entity_type"] = "routine"
        target["schedule_id"] = None
        target["routine_values"] = revision.routine.model_dump(mode="json")
        values["description"] = revision.routine.name
        values["scheduled_date"] = revision.routine.start_date.isoformat()
        values["eta"] = (
            datetime.combine(
                revision.routine.start_date, revision.routine.start_time
            ).isoformat()
            if revision.routine.start_time is not None
            else None
        )
    if values:
        if target["action"] == "delete":
            raise OperationError("삭제 항목은 값을 수정할 수 없습니다.")
        target_changes = dict(target.get("proposed_values", {}))
        target_changes.update(values)
        if target["action"] == "create" and not str(
            target_changes.get("description") or ""
        ).strip():
            raise OperationError("생성 일정의 내용은 비워둘 수 없습니다.")
        target["proposed_values"] = target_changes
        if target.get("entity_type") == "routine":
            routine_values = dict(target.get("routine_values") or {})
            if "description" in values:
                routine_values["name"] = values["description"]
                routine_values["description"] = values["description"]
            if "scheduled_date" in values:
                routine_values["start_date"] = values["scheduled_date"]
            if "eta" in values:
                eta = values["eta"]
                routine_values["start_time"] = (
                    datetime.fromisoformat(eta).time().isoformat(timespec="minutes")
                    if eta
                    else None
                )
            target["routine_values"] = routine_values
        if target.get("requires_confirmation"):
            confirmed = set(payload.get("confirmed_item_ids", []))
            confirmed.discard(item_id)
            payload["confirmed_item_ids"] = list(confirmed)
            selected = set(payload.get("selected_item_ids", []))
            selected.discard(item_id)
            payload["selected_item_ids"] = list(selected)

    payload["mixed_items"] = items
    operation.payload = payload
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

    if "items" in operation.before_values:
        raise OperationError("일괄 미리보기는 항목 선택만 변경할 수 있습니다.")
    values = revision.model_dump(exclude_unset=True, mode="json")
    if values.get("location_id") is not None:
        from .models import Location

        location = db.get(Location, values["location_id"])
        if location is None or location.is_obsolete:
            raise OperationError("사용할 수 없는 장소입니다.")
    payload = dict(operation.payload)
    payload.update(values)
    if operation.action == "create" and not payload.get("eta"):
        raise OperationError("생성 미리보기에는 시각이 필요합니다.")
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
    db: Session,
    user_id: str,
    conversation_id: str,
    expected_operation_id: str | None = None,
    expected_revision: int | None = None,
) -> ScheduleOperationRead:
    operation = _pending(db, user_id, conversation_id)
    if (
        operation is not None
        and expected_operation_id is not None
        and operation.operation_id != expected_operation_id
    ):
        raise OperationError("화면의 미리보기와 현재 파이프라인이 다릅니다. 최신 미리보기를 확인해 주세요.")
    if (
        operation is not None
        and expected_revision is not None
        and _pipeline_revision(operation) != expected_revision
    ):
        raise OperationError("미리보기가 갱신되었습니다. 최신 내용을 확인한 뒤 다시 실행해 주세요.")
    if operation is None:
        raise OperationError("확인 대기 중인 일정 작업이 없습니다.")
    if operation.expires_at < datetime.now():
        operation.status = "expired"
        db.commit()
        raise OperationError("작업 확인 시간이 만료되었습니다. 다시 요청해 주세요.")
    if operation.action == "mixed":
        selected_ids = set(operation.payload.get("selected_item_ids", []))
        if not selected_ids:
            raise OperationError("적용할 작업을 하나 이상 선택해 주세요.")
        mixed_items = [
            item
            for item in operation.payload.get("mixed_items", [])
            if item["item_id"] in selected_ids
        ]
        if len(mixed_items) != len(selected_ids):
            raise OperationError("선택한 작업 중 미리보기에 없는 항목이 있습니다.")

        required_confirmation = {
            item["item_id"]
            for item in mixed_items
            if item.get("requires_confirmation")
        }
        confirmed_ids = set(operation.payload.get("confirmed_item_ids", []))
        if required_confirmation - confirmed_ids:
            raise OperationError("경고가 있는 작업의 확인 질문에 먼저 답해 주세요.")

        conflicted_ids: set[str] = set()
        for item in mixed_items:
            if item["action"] == "create":
                continue
            current = find_schedule(db, int(item["schedule_id"]), user_id)
            if current is None or current.is_obsolete:
                item["conflict_message"] = "대상 일정이 삭제되었거나 더 이상 존재하지 않습니다."
                conflicted_ids.add(item["item_id"])
            elif not _same_version(item["before_values"]["updated_at"], current.updated_at):
                item["conflict_message"] = "미리보기 이후 일정이 변경되었습니다."
                conflicted_ids.add(item["item_id"])
        if conflicted_ids:
            payload = dict(operation.payload)
            changed = {item["item_id"]: item for item in mixed_items}
            payload["mixed_items"] = [
                changed.get(item["item_id"], item)
                for item in payload.get("mixed_items", [])
            ]
            payload["conflicted_item_ids"] = sorted(conflicted_ids)
            payload["selected_item_ids"] = sorted(selected_ids - conflicted_ids)
            operation.payload = payload
            db.commit()
            result = _read(operation)
            result.message = (
                f"{len(conflicted_ids)}개 항목이 서버의 최신 일정과 충돌했습니다. "
                "충돌 항목을 새로고침하거나 제외한 뒤 다시 실행해 주세요."
            )
            return result

        schedules: dict[str, Schedule] = {}
        for item in mixed_items:
            if item["action"] == "create":
                continue
            schedule_id = int(item["schedule_id"])
            schedule = find_schedule(db, schedule_id, user_id)
            if schedule is None or schedule.is_obsolete:
                raise OperationError("혼합 작업의 대상 일정이 더 이상 존재하지 않습니다.")
            before = item["before_values"]
            if not _same_version(before["updated_at"], schedule.updated_at):
                operation.status = "conflicted"
                db.commit()
                raise OperationError("미리보기 이후 변경된 일정이 있어 혼합 작업을 중단했습니다.")
            schedules[item["item_id"]] = schedule

        after_items = []
        try:
            for item in mixed_items:
                action = item["action"]
                changes = dict(item.get("proposed_values", {}))
                entity_type = item.get("entity_type", "schedule")
                routine = None
                if entity_type == "routine":
                    routine = create_routine(
                        db,
                        user_id,
                        RoutineCreate.model_validate(item["routine_values"]),
                        commit=False,
                    )
                    schedule = None
                elif action == "create":
                    if not str(changes.get("description") or "").strip():
                        raise OperationError("생성할 일정의 내용이 비어 있습니다.")
                    alarm_minutes = int(changes.pop("alarm_minutes_before", 10))
                    alarm = Alarm(
                        alarm_id=f"chat-{uuid4()}",
                        alarm_music=None,
                        alarm_text=changes["description"],
                        minutes_before=alarm_minutes,
                    )
                    db.add(alarm)
                    db.flush()
                    schedule = create_todo(
                        db,
                        TodoCreate(
                            eta=(
                                datetime.fromisoformat(changes["eta"])
                                if changes.get("eta")
                                else None
                            ),
                            scheduled_date=changes.get("scheduled_date"),
                            description=changes["description"],
                            user_id=user_id,
                            alarm_id=alarm.alarm_id,
                            location_id=changes.get("location_id"),
                        ),
                        commit=False,
                    )
                else:
                    schedule = schedules[item["item_id"]]
                    if action == "delete":
                        delete_todo(db, schedule.schedule_id, user_id, commit=False)
                    elif action == "update":
                        delta = changes.pop("time_delta_minutes", None)
                        if delta is not None:
                            if schedule.scheduled_at is None:
                                raise OperationError(
                                    "시간이 없는 일정에는 상대 시간 변경을 적용할 수 없습니다."
                                )
                            changes["eta"] = (
                                schedule.scheduled_at + timedelta(minutes=int(delta))
                            ).isoformat()
                        alarm_minutes = changes.pop("alarm_minutes_before", None)
                        update_todo(
                            db,
                            schedule.schedule_id,
                            TodoUpdate.model_validate(changes),
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
                                    minutes_before=int(alarm_minutes),
                                )
                                db.add(new_alarm)
                                db.flush()
                                schedule.alarm_id = new_alarm.alarm_id
                                schedule.alarm = new_alarm
                            else:
                                schedule.alarm.minutes_before = int(alarm_minutes)
                            schedule.updated_at = datetime.now()
                    else:
                        raise OperationError("지원하지 않는 혼합 작업입니다.")
                db.flush()
                if routine is not None:
                    after_items.append(
                        {
                            "item_id": item["item_id"],
                            "entity_type": "routine",
                            "action": action,
                            "routine_id": routine.id,
                            "schedule_id": None,
                            "after_values": {
                                **item["routine_values"],
                                "id": routine.id,
                                "user_id": user_id,
                                "updated_at": routine.updated_at.isoformat(timespec="seconds"),
                            },
                        }
                    )
                else:
                    after_items.append(
                        {
                            "item_id": item["item_id"],
                            "entity_type": "schedule",
                            "action": action,
                            "schedule_id": schedule.schedule_id,
                            "after_values": _snapshot(schedule),
                        }
                    )
        except Exception:
            db.rollback()
            raise
        operation.after_values = {"mixed_items": after_items}
        operation.status = "executed"
        operation.executed_at = datetime.now()
        db.commit()
        result = _read(operation)
        result.message = (
            f"선택한 혼합 일정 작업 {len(after_items)}개를 완료했습니다. "
            f"전체를 되돌리려면 '되돌리기 {operation.operation_id}'라고 입력해 주세요."
        )
        return result
    if "items" in operation.before_values:
        selected_ids = operation.payload.get("selected_schedule_ids", [])
        if not selected_ids:
            raise OperationError("적용할 일정을 하나 이상 선택해 주세요.")
        snapshots = {
            item["id"]: item for item in operation.before_values["items"]
        }
        schedules = []
        for schedule_id in selected_ids:
            schedule = find_schedule(db, schedule_id, user_id)
            if schedule is None or schedule.is_obsolete:
                raise OperationError("선택한 일정 중 더 이상 존재하지 않는 일정이 있습니다.")
            if not _same_version(snapshots[schedule_id]["updated_at"], schedule.updated_at):
                operation.status = "conflicted"
                db.commit()
                raise OperationError("미리보기 이후 변경된 일정이 있어 일괄 작업을 중단했습니다.")
            schedules.append(schedule)
        changes = dict(operation.payload.get("changes", {}))
        after_items = []
        for schedule in schedules:
            if operation.action == "delete":
                delete_todo(db, schedule.schedule_id, user_id, commit=False)
            elif operation.action == "update":
                item_changes = dict(changes)
                delta = item_changes.pop("time_delta_minutes", None)
                if delta is not None:
                    if schedule.scheduled_at is None:
                        raise OperationError(
                            "시간이 없는 일정에는 상대 시간 변경을 적용할 수 없습니다."
                        )
                    item_changes["eta"] = (
                        schedule.scheduled_at + timedelta(minutes=int(delta))
                    ).isoformat()
                alarm_minutes = item_changes.pop("alarm_minutes_before", None)
                update_todo(
                    db,
                    schedule.schedule_id,
                    TodoUpdate.model_validate(item_changes),
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
            else:
                raise OperationError("지원하지 않는 일괄 작업입니다.")
            db.flush()
            after_items.append(_snapshot(schedule))
        operation.after_values = {"items": after_items}
        operation.status = "executed"
        operation.executed_at = datetime.now()
        db.commit()
        result = _read(operation)
        result.message = f"선택한 일정 {len(schedules)}개를 변경했습니다."
        return result

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
        payload.pop("_pipeline_revision", None)
        if not str(payload.get("description") or "").strip():
            raise OperationError("일정 내용을 입력해 주세요.")
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
                eta=(
                    datetime.fromisoformat(payload["eta"])
                    if payload.get("eta")
                    else None
                ),
                scheduled_date=payload.get("scheduled_date"),
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
        payload.pop("_pipeline_revision", None)
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
    db: Session,
    user_id: str,
    conversation_id: str,
    expected_operation_id: str | None = None,
) -> ScheduleOperationRead:
    operation = _pending(db, user_id, conversation_id)
    if operation is None:
        raise OperationError("취소할 대기 작업이 없습니다.")
    if expected_operation_id is not None and operation.operation_id != expected_operation_id:
        raise OperationError("화면의 미리보기와 현재 파이프라인이 다릅니다.")
    operation.status = "cancelled"
    db.commit()
    result = _read(operation)
    result.message = "일정 변경을 취소했습니다."
    return result


def _restore_schedule_snapshot(
    db: Session, schedule: Schedule, before: dict, user_id: str
) -> None:
    current_alarm = schedule.alarm
    original = before.get("original_scheduled_at")
    update_todo(
        db,
        schedule.schedule_id,
        TodoUpdate(
            eta=(datetime.fromisoformat(before["eta"]) if before.get("eta") else None),
            scheduled_date=before.get("scheduled_date"),
            description=before.get("description"),
            alarm_id=before["alarm"]["alarm_id"],
            location_id=(before["location"]["location_id"] if before.get("location") else None),
            routine_id=before.get("routine_id"),
            original_scheduled_at=(datetime.fromisoformat(original) if original else None),
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
    schedule.updated_at = datetime.now()


def undo_operation(
    db: Session, user_id: str, operation_id: str
) -> ScheduleOperationRead:
    operation = db.get(ScheduleOperation, operation_id)
    if (
        operation is not None
        and operation.user_id == user_id
        and operation.action == "mixed"
    ):
        if operation.status != "executed" or operation.after_values is None:
            raise OperationError("이 혼합 작업은 되돌릴 수 있는 상태가 아닙니다.")
        after_items = operation.after_values.get("mixed_items", [])
        source_items = {
            item["item_id"]: item
            for item in operation.payload.get("mixed_items", [])
        }
        schedules: dict[str, Schedule] = {}
        routines: dict[str, Routine] = {}
        for after in after_items:
            if after.get("entity_type") == "routine":
                routine = db.get(Routine, int(after["routine_id"]))
                if routine is None or routine.user_id != user_id:
                    raise OperationError("되돌릴 루틴을 찾을 수 없습니다.")
                routines[after["item_id"]] = routine
                continue
            schedule = find_schedule(db, int(after["schedule_id"]), user_id)
            if schedule is None or not _same_version(
                after["after_values"]["updated_at"], schedule.updated_at
            ):
                raise OperationError(
                    "혼합 작업 이후 변경된 일정이 있어 전체를 안전하게 되돌릴 수 없습니다."
                )
            schedules[after["item_id"]] = schedule
        try:
            for after in reversed(after_items):
                item_id = after["item_id"]
                source = source_items[item_id]
                if after.get("entity_type") == "routine":
                    delete_routine(
                        db,
                        routines[item_id].id,
                        user_id,
                        commit=False,
                    )
                    continue
                schedule = schedules[item_id]
                if source["action"] == "create":
                    schedule.is_obsolete = True
                    schedule.alarm.is_obsolete = True
                    schedule.updated_at = datetime.now()
                else:
                    _restore_schedule_snapshot(
                        db, schedule, source["before_values"], user_id
                    )
            operation.status = "undone"
            operation.undone_at = datetime.now()
            db.commit()
        except Exception:
            db.rollback()
            raise
        result = _read(operation)
        result.message = f"혼합 일정 작업 {len(after_items)}개를 모두 되돌렸습니다."
        return result
    if operation is None or operation.user_id != user_id:
        raise OperationError("되돌릴 작업을 찾을 수 없습니다.")
    if operation.status != "executed" or operation.after_values is None:
        raise OperationError("이 작업은 되돌릴 수 있는 상태가 아닙니다.")
    if operation.action == "mixed":
        raise OperationError("혼합 작업은 아직 한 번에 되돌릴 수 없습니다.")
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
            eta=(datetime.fromisoformat(before["eta"]) if before.get("eta") else None),
            scheduled_date=before.get("scheduled_date"),
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
