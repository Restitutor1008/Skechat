from datetime import datetime, timedelta
import hashlib
import re
from typing import Any

from sqlalchemy import delete
from sqlalchemy.orm import Session

from .models import ScheduleCommandLog


LOG_RETENTION_DAYS = 30

PHONE_PATTERN = re.compile(r"\b(01[016789])[- ]?(\d{3,4})[- ]?(\d{4})\b")
EMAIL_PATTERN = re.compile(
    r"\b([A-Za-z0-9._%+-])([A-Za-z0-9._%+-]*)@([A-Za-z0-9.-]+\.[A-Za-z]{2,})\b"
)
SECRET_PATTERN = re.compile(
    r"(?i)\b(password|passwd|비밀번호|token|토큰|api[_ -]?key)\b\s*[:=]?\s*([^\s,;]+)"
)
BEARER_PATTERN = re.compile(r"(?i)\bBearer\s+[A-Za-z0-9._~+/=-]+")
SECRET_KEY_PATTERN = re.compile(
    r"(?i)^(password|passwd|password_hash|비밀번호|token|토큰|api[_ -]?key|authorization)$"
)


def mask_command_text(value: str) -> str:
    masked = PHONE_PATTERN.sub(lambda item: f"{item.group(1)}-****-{item.group(3)}", value)
    masked = EMAIL_PATTERN.sub(
        lambda item: f"{item.group(1)}***@{item.group(3)}", masked
    )
    masked = SECRET_PATTERN.sub(lambda item: f"{item.group(1)}=[MASKED]", masked)
    return BEARER_PATTERN.sub("Bearer [MASKED]", masked)


def _mask_details(value: Any) -> Any:
    if isinstance(value, str):
        return mask_command_text(value)
    if isinstance(value, dict):
        return {
            str(key): (
                "[MASKED]"
                if SECRET_KEY_PATTERN.fullmatch(str(key))
                else _mask_details(item)
            )
            for key, item in value.items()
        }
    if isinstance(value, list):
        return [_mask_details(item) for item in value]
    return value


def purge_expired_command_logs(
    db: Session, *, now: datetime | None = None
) -> int:
    result = db.execute(
        delete(ScheduleCommandLog)
        .where(ScheduleCommandLog.expires_at <= (now or datetime.now()))
        .execution_options(synchronize_session="fetch")
    )
    db.commit()
    db.expire_all()
    return result.rowcount or 0


def start_command_log(
    db: Session,
    *,
    user_id: str,
    conversation_id: str,
    user_input: str,
    model_name: str,
) -> ScheduleCommandLog:
    now = datetime.now()
    purge_expired_command_logs(db, now=now)
    command_log = ScheduleCommandLog(
        user_id=user_id,
        conversation_id=conversation_id,
        masked_input=mask_command_text(user_input),
        input_hash=hashlib.sha256(user_input.encode("utf-8")).hexdigest(),
        stage="received",
        status="processing",
        model_name=model_name,
        created_at=now,
        expires_at=now + timedelta(days=LOG_RETENTION_DAYS),
    )
    db.add(command_log)
    db.commit()
    db.refresh(command_log)
    return command_log


def finish_command_log(
    db: Session,
    command_log: ScheduleCommandLog,
    *,
    status: str,
    stage: str,
    llm_action: str | None = None,
    resolved_action: str | None = None,
    details: dict | None = None,
    error_code: str | None = None,
    operation_id: str | None = None,
) -> None:
    command_log.status = status
    command_log.stage = stage
    command_log.llm_action = llm_action
    command_log.resolved_action = resolved_action
    command_log.details = _mask_details(details) if details is not None else None
    command_log.error_code = error_code
    command_log.operation_id = operation_id
    command_log.completed_at = datetime.now()
    db.commit()
