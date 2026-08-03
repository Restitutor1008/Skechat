from datetime import date, datetime, timedelta
from dataclasses import dataclass, field
import re
from typing import Any
from zoneinfo import ZoneInfo

from .llm_service import classify_schedule_command
from .mcp_client import call_mcp_tool
from .schemas import ScheduleCommand


SEOUL = ZoneInfo("Asia/Seoul")
CONFIRM_WORDS = {"yes", "y", "네", "예", "확인", "진행"}
CANCEL_WORDS = {"no", "n", "아니요", "취소"}
UNDO_PATTERN = re.compile(
    r"^(?:undo|되돌리기)\s+([0-9a-fA-F]{8}-[0-9a-fA-F-]{27,})$",
    re.IGNORECASE,
)
KOREAN_TIME_PATTERN = re.compile(
    r"(?:(오전|오후)\s*)?(\d{1,2})\s*시(?:\s*(\d{1,2})\s*분)?"
)
COLON_TIME_PATTERN = re.compile(
    r"(?:(오전|오후)\s*)?(?<!\d)(\d{1,2}):(\d{2})(?!\d)"
)


@dataclass
class CommandTrace:
    stage: str = "received"
    status: str = "completed"
    llm_action: str | None = None
    resolved_action: str | None = None
    operation_id: str | None = None
    error_code: str | None = None
    details: dict[str, Any] = field(default_factory=dict)
    preview: dict[str, Any] | None = None

    def blocked(self, code: str, stage: str) -> None:
        self.status = "blocked"
        self.error_code = code
        self.stage = stage


def _tool_message(result: Any, fallback: str) -> str:
    if isinstance(result, dict) and isinstance(result.get("message"), str):
        return result["message"]
    return fallback


def _extract_korean_time(message: str, target_date: date) -> datetime | None:
    match = KOREAN_TIME_PATTERN.search(message) or COLON_TIME_PATTERN.search(message)
    if match is None:
        return None
    period, hour_text, minute_text = match.groups()
    hour = int(hour_text)
    minute = int(minute_text or 0)
    if hour > 23 or minute > 59:
        return None
    if period == "오후" and hour < 12:
        hour += 12
    elif period == "오전" and hour == 12:
        hour = 0
    elif period is not None and hour > 12:
        return None
    return datetime(
        target_date.year,
        target_date.month,
        target_date.day,
        hour,
        minute,
        tzinfo=SEOUL,
    )


def _extract_create_description(message: str) -> str:
    value = KOREAN_TIME_PATTERN.sub(" ", message)
    value = COLON_TIME_PATTERN.sub(" ", value)
    value = re.sub(
        r"(?:오늘|내일|모레)|(?:(?:\d{4}\s*년\s*)?(?:\d{1,2}\s*월\s*)?\d{1,2}\s*일)",
        " ",
        value,
    )
    value = re.sub(r"\b(?:일정|스케줄)\b", " ", value)
    value = re.sub(r"(?:추가|생성|등록)(?:해|해줘|해주세요|할래)?", " ", value)
    return " ".join(value.split()).strip(" ,.")


def _schedule_date(schedule: dict) -> date | None:
    try:
        return datetime.fromisoformat(str(schedule["eta"])).astimezone(SEOUL).date()
    except (KeyError, TypeError, ValueError):
        return None


def _matches(schedule: dict, query: str) -> bool:
    needle = query.strip().casefold()
    if not needle:
        return False
    haystack = " ".join(
        str(value or "")
        for value in (
            schedule.get("description"),
            (schedule.get("alarm") or {}).get("alarm_text"),
            (schedule.get("location") or {}).get("name"),
        )
    ).casefold()
    return needle in haystack or any(token in haystack for token in needle.split())


def resolve_target(
    command: ScheduleCommand,
    schedules: list[dict],
    target_date: date,
) -> tuple[dict | None, str | None]:
    candidates = [item for item in schedules if _schedule_date(item) == target_date]
    if command.schedule_id is not None:
        exact = [item for item in candidates if item.get("id") == command.schedule_id]
        if len(exact) == 1:
            return exact[0], None
    if command.schedule_query:
        matched = [item for item in candidates if _matches(item, command.schedule_query)]
        if len(matched) == 1:
            return matched[0], None
        if len(matched) > 1:
            return None, "해당 날짜에 비슷한 일정이 여러 개라 대상을 확정할 수 없습니다."
    if len(candidates) == 1:
        return candidates[0], None
    if not candidates:
        return None, f"{target_date.isoformat()}에 해당하는 일정을 찾을 수 없습니다."
    return None, "수정할 일정 내용을 알 수 없습니다. 일정 이름을 더 구체적으로 알려주세요."


def _list_message(schedules: list[dict], defaulted_today: bool = False) -> str:
    prefix = "날짜가 없어 오늘 일정으로 판단했습니다.\n" if defaulted_today else ""
    if not schedules:
        return prefix + "조건에 맞는 일정이 없습니다."
    lines = []
    for item in schedules:
        location = item.get("location") or {}
        lines.append(
            f"#{item['id']} {item.get('eta')} · {item.get('description') or '(내용 없음)'}"
            f" · {location.get('name', '장소 없음')}"
        )
    return prefix + "현재 일정입니다.\n" + "\n".join(lines)


async def handle_chat(
    message: str,
    user_id: str,
    conversation_id: str,
    trace: CommandTrace | None = None,
) -> str:
    trace = trace or CommandTrace()
    normalized = message.strip().casefold()
    base = {"user_id": user_id, "conversation_id": conversation_id}
    if normalized in CONFIRM_WORDS:
        trace.resolved_action = "confirm"
        trace.stage = "confirmation"
        try:
            result = await call_mcp_tool("confirm_schedule_operation", base)
        except ValueError:
            trace.blocked("NO_PENDING_OPERATION", "confirmation")
            return "확인 대기 중인 일정 작업이 없습니다. 먼저 일정을 요청해 주세요."
        if isinstance(result, dict):
            trace.operation_id = result.get("operation_id")
        trace.stage = "executed"
        return _tool_message(result, "일정 변경이 완료되었습니다.")
    if normalized in CANCEL_WORDS:
        trace.resolved_action = "cancel"
        trace.stage = "cancellation"
        try:
            result = await call_mcp_tool("cancel_schedule_operation", base)
        except ValueError:
            trace.blocked("NO_PENDING_OPERATION", "cancellation")
            return "취소할 일정 작업이 없습니다."
        if isinstance(result, dict):
            trace.operation_id = result.get("operation_id")
        trace.stage = "cancelled"
        return _tool_message(result, "일정 변경을 취소했습니다.")
    undo_match = UNDO_PATTERN.fullmatch(message.strip())
    if undo_match:
        trace.resolved_action = "undo"
        trace.stage = "undo"
        result = await call_mcp_tool(
            "undo_schedule_operation",
            {"user_id": user_id, "operation_id": undo_match.group(1)},
        )
        trace.operation_id = undo_match.group(1)
        trace.stage = "undone"
        return _tool_message(result, "일정 변경을 되돌렸습니다.")

    today = datetime.now(SEOUL).date()
    schedules = await call_mcp_tool("list_schedule", {"user_id": user_id})
    if not isinstance(schedules, list):
        raise ValueError("MCP 일정 조회 결과가 올바르지 않습니다.")
    command = await classify_schedule_command(message, schedules, today)
    trace.llm_action = command.action
    trace.stage = "classified"
    trace.details = {
        "confidence": command.confidence,
        "date": command.date.isoformat() if command.date else None,
        "schedule_id": command.schedule_id,
        "schedule_query": command.schedule_query,
        "changes": (
            command.changes.model_dump(exclude_unset=True, mode="json")
            if command.changes is not None
            else None
        ),
    }
    inferred_create = command.action == "unknown"
    if inferred_create:
        command.action = "create"
    trace.resolved_action = command.action
    if command.confidence < 0.85 and not inferred_create:
        trace.blocked("LOW_CONFIDENCE", "classification")
        return "명령 종류를 확실하게 판단할 수 없습니다. 원하는 작업을 더 구체적으로 알려주세요."

    target_date = command.date or today
    defaulted_today = command.date is None
    if command.action == "list":
        trace.stage = "read_completed"
        daily = await call_mcp_tool(
            "list_schedule",
            {"user_id": user_id, "date": target_date.isoformat()},
        )
        return _list_message(daily, defaulted_today)
    if command.action == "create":
        changes = (
            command.changes.model_dump(exclude_unset=True, mode="json")
            if command.changes is not None
            else {}
        )
        eta_value = changes.get("eta")
        eta = (
            datetime.fromisoformat(str(eta_value))
            if eta_value is not None
            else _extract_korean_time(message, target_date)
        )
        if eta is None:
            trace.blocked("MISSING_SCHEDULE_TIME", "slot_resolution")
            return "스케줄 시각을 알 수 없어 일정을 생성할 수 없습니다."
        description = str(
            changes.get("description")
            or command.schedule_query
            or _extract_create_description(message)
        ).strip()
        if not description:
            trace.blocked("MISSING_SCHEDULE_CONTENT", "slot_resolution")
            return "스케줄 내용을 알 수 없어 일정을 생성할 수 없습니다."
        if defaulted_today:
            eta = eta.replace(
                year=target_date.year,
                month=target_date.month,
                day=target_date.day,
            )
        location_id = changes.get("location_id")
        location_name = None
        if location_id is not None:
            locations = await call_mcp_tool("list_locations", {"user_id": user_id})
            location = (
                next(
                    (
                        item
                        for item in locations
                        if item.get("location_id") == location_id
                    ),
                    None,
                )
                if isinstance(locations, list)
                else None
            )
            if location is None:
                return "지정한 장소를 DB에서 찾을 수 없습니다."
            location_name = location.get("name")
        alarm_minutes = changes.get("alarm_minutes_before")
        if alarm_minutes is None:
            alarm_minutes = 10
        result = await call_mcp_tool(
            "preview_create_schedule",
            {
                **base,
                "eta": eta.isoformat(),
                "description": description,
                "alarm_minutes_before": int(alarm_minutes),
                **(
                    {"location_id": int(location_id)}
                    if location_id is not None
                    else {}
                ),
            },
        )
        if isinstance(result, dict):
            trace.operation_id = result.get("operation_id")
            if location_name is not None:
                result.setdefault("proposed_values", {})[
                    "location_name"
                ] = location_name
            trace.preview = result
        trace.stage = "awaiting_confirmation"
        reasons = []
        if inferred_create:
            reasons.append("명령 종류를 확정할 수 없어 일정 생성으로 판단했습니다.")
        if defaulted_today:
            reasons.append(f"날짜가 없어 오늘({target_date.isoformat()})로 판단했습니다.")
        if changes.get("location_id") is None:
            reasons.append("장소 정보가 없어 장소 없음으로 생성합니다.")
        if changes.get("alarm_minutes_before") is None:
            reasons.append("알람 정보가 없어 일정 10분 전으로 설정합니다.")
        return " ".join(reasons) + " " + _tool_message(
            result, "생성 미리보기를 만들었습니다. YES 또는 NO로 답해 주세요."
        )
    if command.action in {"update", "delete"}:
        schedule, error = resolve_target(command, schedules, target_date)
        if error:
            trace.blocked("TARGET_NOT_RESOLVED", "target_resolution")
            return error
        assert schedule is not None
        if not schedule.get("eta"):
            trace.blocked("MISSING_SCHEDULE_TIME", "target_resolution")
            return "스케줄 시각을 알 수 없어 작업을 진행할 수 없습니다."
        if not str(schedule.get("description") or "").strip():
            trace.blocked("MISSING_SCHEDULE_CONTENT", "target_resolution")
            return "스케줄 내용을 알 수 없어 작업을 진행할 수 없습니다."
        schedule_id = int(schedule["id"])
        if command.action == "delete":
            result = await call_mcp_tool(
                "preview_delete_schedule", {**base, "schedule_id": schedule_id}
            )
            if isinstance(result, dict):
                trace.operation_id = result.get("operation_id")
                trace.preview = result
            trace.stage = "awaiting_confirmation"
            return _tool_message(result, "삭제 미리보기를 만들었습니다. YES 또는 NO로 답해 주세요.")

        if command.changes is None:
            trace.blocked("MISSING_CHANGES", "slot_resolution")
            return "변경할 스케줄 시각이나 내용을 알 수 없습니다."
        changes = command.changes.model_dump(exclude_unset=True, mode="json")
        delta = changes.pop("time_delta_minutes", None)
        explicit_alarm = "alarm_id" in changes or "alarm_minutes_before" in changes
        meaningful_changes = {key: value for key, value in changes.items() if value is not None}
        if delta is not None:
            current_eta = datetime.fromisoformat(str(schedule["eta"]))
            meaningful_changes["eta"] = (current_eta + timedelta(minutes=delta)).isoformat()
        if not meaningful_changes:
            trace.blocked("MISSING_CHANGES", "slot_resolution")
            return "변경할 스케줄 시각이나 내용을 알 수 없습니다."
        if not explicit_alarm:
            meaningful_changes["alarm_minutes_before"] = 10
        location_name = None
        if meaningful_changes.get("location_id") is not None:
            locations = await call_mcp_tool("list_locations", {"user_id": user_id})
            location = (
                next(
                    (
                        item
                        for item in locations
                        if item.get("location_id")
                        == meaningful_changes["location_id"]
                    ),
                    None,
                )
                if isinstance(locations, list)
                else None
            )
            if location is None:
                return "지정한 장소를 DB에서 찾을 수 없습니다."
            location_name = location.get("name")
        result = await call_mcp_tool(
            "preview_update_schedule",
            {**base, "schedule_id": schedule_id, **meaningful_changes},
        )
        if isinstance(result, dict):
            trace.operation_id = result.get("operation_id")
            if location_name is not None:
                result.setdefault("proposed_values", {})[
                    "location_name"
                ] = location_name
            trace.preview = result
        trace.stage = "awaiting_confirmation"
        prefix = (
            f"날짜가 없어 오늘({target_date.isoformat()}) 일정으로 판단했습니다. "
            if defaulted_today
            else ""
        )
        if not explicit_alarm:
            prefix += "알람 정보가 없어 일정 10분 전으로 설정합니다. "
        return prefix + _tool_message(
            result, "수정 미리보기를 만들었습니다. YES 또는 NO로 답해 주세요."
        )
    if command.action == "chat":
        trace.stage = "chat_completed"
        return command.response or "일정에 관해 무엇을 도와드릴까요?"
    trace.blocked("UNKNOWN_COMMAND", "classification")
    return "명령 종류를 알 수 없습니다."
