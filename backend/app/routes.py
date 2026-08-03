from datetime import date, datetime
from datetime import date
from typing import Annotated

import httpx
from fastapi import APIRouter, Depends, Header, HTTPException, Response, status
from sqlalchemy import select
from sqlalchemy.orm import Session

from .config import get_settings
from .database import get_db
from .models import Location
from .chat_service import CommandTrace, handle_chat
from .command_log_service import finish_command_log, start_command_log
from .operation_service import (
    OperationError,
    cancel_operation,
    confirm_operation,
    preview_operation,
    revise_operation,
    undo_operation,
)
from .occurrence_service import get_next_occurrence, get_occurrences
from .routine_service import (
    RoutineNotFoundError,
    UserNotFoundError,
    create_routine,
    delete_routine,
    get_routine,
    list_routines,
    update_routine,
)
from .schemas import (
    ChatRequest,
    ChatResponse,
    LocationRead,
    OccurrenceRead,
    RoutineCreate,
    RoutineRead,
    RoutineUpdate,
    ScheduleOperationPreviewRequest,
    ScheduleOperationRead,
    ScheduleOperationRevision,
    TodoCreate,
    TodoRead,
    TodoUpdate,
)
from .todo_service import (
    assemble_todo,
    create_todo,
    delete_todo,
    list_deleted_todos,
    list_todos,
    restore_todo,
    update_todo,
)


router = APIRouter(prefix="/api")


def current_user_id(
    x_user_id: Annotated[str, Header(alias="X-User-Id", min_length=1)],
) -> str:
    return x_user_id


def _routine_or_404(db: Session, routine_id: int, user_id: str):
    try:
        return get_routine(db, routine_id, user_id)
    except RoutineNotFoundError as exc:
        raise HTTPException(status_code=404, detail="Routine not found") from exc


@router.get("/health")
def health() -> dict[str, str]:
    return {"status": "ok", "database": get_settings().db_name}


@router.get("/todos", response_model=list[TodoRead])
def read_todos(
    date: date | None = None,
    user_id: str = Depends(current_user_id),
    db: Session = Depends(get_db),
):
    return [assemble_todo(schedule) for schedule in list_todos(db, date, user_id)]


@router.get("/todos/deleted", response_model=list[TodoRead])
def read_deleted_todos(
    user_id: str = Depends(current_user_id),
    db: Session = Depends(get_db),
):
    return [assemble_todo(schedule) for schedule in list_deleted_todos(db, user_id)]


@router.get("/locations", response_model=list[LocationRead])
def read_locations(
    _: str = Depends(current_user_id),
    db: Session = Depends(get_db),
):
    locations = db.scalars(
        select(Location)
        .where(Location.is_obsolete.is_(False))
        .order_by(Location.location_id)
    ).all()
    return [
        LocationRead(
            location_id=item.location_id,
            name=item.name,
            latitude=float(item.latitude),
            longitude=float(item.longitude),
            source_id=item.source_id,
        )
        for item in locations
    ]


@router.post("/todos", response_model=TodoRead, status_code=status.HTTP_201_CREATED)
def add_todo(
    data: TodoCreate,
    user_id: str = Depends(current_user_id),
    db: Session = Depends(get_db),
):
    if data.user_id != user_id:
        raise HTTPException(status_code=403, detail="Cannot create another user's schedule")
    try:
        return assemble_todo(create_todo(db, data))
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc


@router.patch("/todos/{todo_id}", response_model=TodoRead)
def edit_todo(
    todo_id: int,
    data: TodoUpdate,
    user_id: str = Depends(current_user_id),
    db: Session = Depends(get_db),
):
    try:
        todo = update_todo(db, todo_id, data, user_id)
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    if not todo:
        raise HTTPException(status_code=404, detail="Todo not found")
    return assemble_todo(todo)


@router.delete("/todos/{todo_id}", status_code=status.HTTP_204_NO_CONTENT)
def remove_todo(
    todo_id: int,
    user_id: str = Depends(current_user_id),
    db: Session = Depends(get_db),
) -> Response:
    if not delete_todo(db, todo_id, user_id):
        raise HTTPException(status_code=404, detail="Todo not found")
    return Response(status_code=status.HTTP_204_NO_CONTENT)


@router.post("/todos/{todo_id}/restore", response_model=TodoRead)
def restore_deleted_todo(
    todo_id: int,
    user_id: str = Depends(current_user_id),
    db: Session = Depends(get_db),
):
    todo = restore_todo(db, todo_id, user_id)
    if todo is None:
        raise HTTPException(status_code=404, detail="Deleted todo not found")
    return assemble_todo(todo)


@router.post(
    "/schedule-operations/preview",
    response_model=ScheduleOperationRead,
    status_code=status.HTTP_201_CREATED,
)
def preview_schedule_operation(
    data: ScheduleOperationPreviewRequest,
    user_id: str = Depends(current_user_id),
    db: Session = Depends(get_db),
):
    try:
        return preview_operation(db, user_id, data)
    except OperationError as exc:
        raise HTTPException(status_code=409, detail=str(exc)) from exc


@router.patch(
    "/schedule-operations/{operation_id}",
    response_model=ScheduleOperationRead,
)
def revise_schedule_operation(
    operation_id: str,
    data: ScheduleOperationRevision,
    user_id: str = Depends(current_user_id),
    db: Session = Depends(get_db),
):
    try:
        return revise_operation(db, user_id, operation_id, data)
    except OperationError as exc:
        raise HTTPException(status_code=409, detail=str(exc)) from exc


@router.post("/schedule-operations/confirm", response_model=ScheduleOperationRead)
def confirm_schedule_operation(
    conversation_id: str,
    user_id: str = Depends(current_user_id),
    db: Session = Depends(get_db),
):
    try:
        return confirm_operation(db, user_id, conversation_id)
    except OperationError as exc:
        raise HTTPException(status_code=409, detail=str(exc)) from exc


@router.post("/schedule-operations/cancel", response_model=ScheduleOperationRead)
def cancel_schedule_operation(
    conversation_id: str,
    source: str = "mcp",
    user_id: str = Depends(current_user_id),
    db: Session = Depends(get_db),
):
    command_log = None
    if source == "ui":
        command_log = start_command_log(
            db,
            user_id=user_id,
            conversation_id=conversation_id,
            user_input="UI_PREVIEW_CANCEL",
            model_name=get_settings().llm_model,
        )
    try:
        result = cancel_operation(db, user_id, conversation_id)
    except OperationError as exc:
        if command_log is not None:
            finish_command_log(
                db,
                command_log,
                status="blocked",
                stage="ui_cancellation",
                resolved_action="cancel",
                error_code="NO_PENDING_OPERATION",
            )
        raise HTTPException(status_code=409, detail=str(exc)) from exc
    if command_log is not None:
        finish_command_log(
            db,
            command_log,
            status="completed",
            stage="ui_cancelled",
            resolved_action="cancel",
            operation_id=result.operation_id,
        )
    return result


@router.post(
    "/schedule-operations/{operation_id}/undo",
    response_model=ScheduleOperationRead,
)
def undo_schedule_operation(
    operation_id: str,
    user_id: str = Depends(current_user_id),
    db: Session = Depends(get_db),
):
    try:
        return undo_operation(db, user_id, operation_id)
    except OperationError as exc:
        raise HTTPException(status_code=409, detail=str(exc)) from exc


@router.post(
    "/routines", response_model=RoutineRead, status_code=status.HTTP_201_CREATED
)
def add_routine(
    data: RoutineCreate,
    user_id: str = Depends(current_user_id),
    db: Session = Depends(get_db),
):
    try:
        return create_routine(db, user_id, data)
    except UserNotFoundError as exc:
        raise HTTPException(status_code=404, detail="User not found") from exc


@router.get("/routines", response_model=list[RoutineRead])
def read_routines(
    user_id: str = Depends(current_user_id),
    db: Session = Depends(get_db),
):
    return list_routines(db, user_id)


@router.get("/routines/{routine_id}", response_model=RoutineRead)
def read_routine(
    routine_id: int,
    user_id: str = Depends(current_user_id),
    db: Session = Depends(get_db),
):
    return _routine_or_404(db, routine_id, user_id)


@router.patch("/routines/{routine_id}", response_model=RoutineRead)
def edit_routine(
    routine_id: int,
    data: RoutineUpdate,
    user_id: str = Depends(current_user_id),
    db: Session = Depends(get_db),
):
    try:
        return update_routine(db, routine_id, user_id, data)
    except RoutineNotFoundError as exc:
        raise HTTPException(status_code=404, detail="Routine not found") from exc
    except ValueError as exc:
        raise HTTPException(status_code=422, detail=str(exc)) from exc


@router.delete("/routines/{routine_id}", status_code=status.HTTP_204_NO_CONTENT)
def remove_routine(
    routine_id: int,
    user_id: str = Depends(current_user_id),
    db: Session = Depends(get_db),
) -> Response:
    try:
        delete_routine(db, routine_id, user_id)
    except RoutineNotFoundError as exc:
        raise HTTPException(status_code=404, detail="Routine not found") from exc
    return Response(status_code=status.HTTP_204_NO_CONTENT)


@router.get(
    "/routines/{routine_id}/next-occurrence",
    response_model=OccurrenceRead | None,
)
def read_next_occurrence(
    routine_id: int,
    after: datetime,
    user_id: str = Depends(current_user_id),
    db: Session = Depends(get_db),
):
    routine = _routine_or_404(db, routine_id, user_id)
    occurrence = get_next_occurrence(routine, after)
    return (
        OccurrenceRead(routine_id=routine.id, scheduled_at=occurrence)
        if occurrence
        else None
    )


@router.get(
    "/routines/{routine_id}/occurrences",
    response_model=list[OccurrenceRead],
)
def read_occurrences(
    routine_id: int,
    range_start: datetime,
    range_end: datetime,
    user_id: str = Depends(current_user_id),
    db: Session = Depends(get_db),
):
    routine = _routine_or_404(db, routine_id, user_id)
    try:
        occurrences = get_occurrences(routine, range_start, range_end)
    except ValueError as exc:
        raise HTTPException(status_code=422, detail=str(exc)) from exc
    return [
        OccurrenceRead(routine_id=routine.id, scheduled_at=item)
        for item in occurrences
    ]


@router.post("/chat", response_model=ChatResponse)
async def chat(
    data: ChatRequest,
    user_id: str = Depends(current_user_id),
    db: Session = Depends(get_db),
) -> ChatResponse:
    settings = get_settings()
    command_log = start_command_log(
        db,
        user_id=user_id,
        conversation_id=data.conversation_id,
        user_input=data.message,
        model_name=settings.llm_model,
    )
    trace = CommandTrace()
    try:
        message = await handle_chat(
            data.message,
            user_id,
            data.conversation_id,
            trace,
        )
    except Exception as exc:
        finish_command_log(
            db,
            command_log,
            status="failed",
            stage=trace.stage,
            llm_action=trace.llm_action,
            resolved_action=trace.resolved_action,
            details=trace.details,
            error_code=type(exc).__name__,
            operation_id=trace.operation_id,
        )
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="LLM/MCP service is unavailable. Check Ollama, MCP, and REST API.",
        ) from exc
    finish_command_log(
        db,
        command_log,
        status=trace.status,
        stage=trace.stage,
        llm_action=trace.llm_action,
        resolved_action=trace.resolved_action,
        details=trace.details,
        error_code=trace.error_code,
        operation_id=trace.operation_id,
    )
    return ChatResponse(
        message=message,
        model=settings.llm_model,
        preview=trace.preview,
        error_code=trace.error_code,
    )
