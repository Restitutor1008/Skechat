from __future__ import annotations

from datetime import date as Date, datetime, time
from enum import Enum
from typing import Literal
from zoneinfo import ZoneInfo, ZoneInfoNotFoundError

from pydantic import BaseModel, ConfigDict, Field, model_validator

from .models import RoutineFrequency


class UserSummary(BaseModel):
    user_id: str
    user_name: str
    phone_number: str


class AlarmRead(BaseModel):
    alarm_id: str
    alarm_music: str | None
    alarm_text: str | None
    minutes_before: int


class LocationRead(BaseModel):
    location_id: int
    name: str
    latitude: float
    longitude: float
    source_id: int


class TodoCreate(BaseModel):
    model_config = ConfigDict(extra="forbid")

    eta: datetime | None = None
    scheduled_date: Date | None = None
    description: str = Field(min_length=1, max_length=200)
    user_id: str = Field(min_length=1, max_length=45)
    alarm_id: str = Field(min_length=1, max_length=45)
    location_id: int | None = None
    is_completed: bool = False
    routine_id: int | None = None
    original_scheduled_at: datetime | None = None
    is_exception: bool = False

    @model_validator(mode="after")
    def validate_exception(self):
        if self.scheduled_date is None:
            if self.eta is None:
                raise ValueError("scheduled_date is required when eta is null")
            self.scheduled_date = self.eta.date()
        self.description = self.description.strip()
        if not self.description:
            raise ValueError("description cannot be blank")
        if self.is_exception and (
            self.routine_id is None or self.original_scheduled_at is None
        ):
            raise ValueError(
                "A schedule exception requires routine_id and original_scheduled_at"
            )
        return self


class TodoUpdate(BaseModel):
    model_config = ConfigDict(extra="forbid")

    eta: datetime | None = None
    scheduled_date: Date | None = None
    description: str | None = Field(default=None, min_length=1, max_length=200)
    alarm_id: str | None = Field(default=None, min_length=1, max_length=45)
    location_id: int | None = None
    is_completed: bool | None = None
    routine_id: int | None = None
    original_scheduled_at: datetime | None = None
    is_exception: bool | None = None

    @model_validator(mode="after")
    def reject_null_required_values(self):
        if not self.model_fields_set:
            raise ValueError("At least one todo value is required")
        for field_name in (
            "description",
            "alarm_id",
            "is_completed",
            "is_exception",
        ):
            if field_name in self.model_fields_set and getattr(self, field_name) is None:
                raise ValueError(f"{field_name} cannot be null")
        if "description" in self.model_fields_set:
            assert self.description is not None
            self.description = self.description.strip()
            if not self.description:
                raise ValueError("description cannot be blank")
        return self


class TodoRead(BaseModel):
    id: int
    eta: datetime | None
    scheduled_date: Date
    description: str
    user: UserSummary
    alarm: AlarmRead
    location: LocationRead | None
    is_completed: bool = False
    routine_id: int | None = None
    original_scheduled_at: datetime | None = None
    is_exception: bool = False


class OfflineTodoCreate(BaseModel):
    model_config = ConfigDict(extra="forbid")

    eta: datetime | None = None
    scheduled_date: Date | None = None
    description: str = Field(min_length=1, max_length=200)
    alarm_minutes_before: int = Field(default=10, ge=0, le=10080)
    location_id: int | None = None
    is_completed: bool = False

    @model_validator(mode="after")
    def trim_description(self):
        if self.scheduled_date is None:
            if self.eta is None:
                raise ValueError("scheduled_date is required when eta is null")
            self.scheduled_date = self.eta.date()
        self.description = self.description.strip()
        if not self.description:
            raise ValueError("description cannot be blank")
        return self


class OfflineTodoUpdate(BaseModel):
    model_config = ConfigDict(extra="forbid")

    eta: datetime | None = None
    scheduled_date: Date | None = None
    description: str | None = Field(default=None, min_length=1, max_length=200)
    alarm_minutes_before: int | None = Field(default=None, ge=0, le=10080)
    location_id: int | None = None
    is_completed: bool | None = None

    @model_validator(mode="after")
    def validate_changes(self):
        if not self.model_fields_set:
            raise ValueError("At least one todo value is required")
        for field_name in ("description", "alarm_minutes_before", "is_completed"):
            if field_name in self.model_fields_set and getattr(self, field_name) is None:
                raise ValueError(f"{field_name} cannot be null")
        if "description" in self.model_fields_set:
            assert self.description is not None
            self.description = self.description.strip()
            if not self.description:
                raise ValueError("description cannot be blank")
        return self


class OfflineTodoBatchOperation(BaseModel):
    model_config = ConfigDict(extra="forbid")

    operation_id: str = Field(min_length=36, max_length=36)
    client_id: int
    operation: Literal["create", "update", "delete", "restore"]
    todo_id: int
    payload: dict = Field(default_factory=dict)


class OfflineTodoBatchRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    batch_id: str = Field(min_length=36, max_length=36)
    operations: list[OfflineTodoBatchOperation] = Field(min_length=1, max_length=100)


class OfflineTodoBatchResult(BaseModel):
    operation_id: str
    client_id: int
    operation: Literal["create", "update", "delete", "restore"]
    todo_id: int | None = None


class OfflineTodoBatchResponse(BaseModel):
    batch_id: str
    status: Literal["COMMITTED"]
    operation_count: int
    results: list[OfflineTodoBatchResult]
    committed_at: datetime


class OfflineTodoBatchStatus(BaseModel):
    batch_id: str
    status: Literal["PROCESSING", "COMMITTED", "FAILED"]
    operation_count: int
    attempt_count: int
    created_at: datetime
    updated_at: datetime
    committed_at: datetime | None = None
    error_code: str | None = None
    results: list[OfflineTodoBatchResult] | None = None


class ScheduleSyncItem(BaseModel):
    todo: TodoRead
    updated_at: datetime
    is_deleted: bool


class ScheduleSyncResponse(BaseModel):
    server_time: datetime
    items: list[ScheduleSyncItem]


class HolidayRead(BaseModel):
    country_code: str
    date: Date
    name: str
    description_ko: str | None = None
    description_en: str | None = None
    category: str
    is_substitute: bool
    source: str


class HolidaySyncItem(BaseModel):
    holiday: HolidayRead
    updated_at: datetime
    is_deleted: bool


class HolidaySyncResponse(BaseModel):
    server_time: datetime
    items: list[HolidaySyncItem]


class Weekday(str, Enum):
    MON = "MON"
    TUE = "TUE"
    WED = "WED"
    THU = "THU"
    FRI = "FRI"
    SAT = "SAT"
    SUN = "SUN"


class RoutineCreate(BaseModel):
    name: str = Field(min_length=1, max_length=100)
    description: str | None = None
    frequency: RoutineFrequency
    repeat_interval: int = Field(default=1, ge=1)
    weekdays: list[Weekday] | None = None
    day_of_month: int | None = Field(default=None, ge=1, le=31)
    start_date: Date
    end_date: Date | None = None
    repeat_count: int | None = Field(default=None, ge=1)
    start_time: time | None = None
    timezone: str = "Asia/Seoul"
    is_active: bool = True

    @model_validator(mode="after")
    def validate_rule(self):
        if self.end_date is not None and self.end_date < self.start_date:
            raise ValueError("end_date cannot be before start_date")
        if self.end_date is not None and self.repeat_count is not None:
            raise ValueError("end_date and repeat_count cannot both be set")
        if self.frequency == RoutineFrequency.WEEKLY:
            if not self.weekdays:
                raise ValueError("WEEKLY routines require at least one weekday")
            self.weekdays = list(dict.fromkeys(self.weekdays))
        else:
            self.weekdays = None
        if self.frequency == RoutineFrequency.MONTHLY:
            if self.day_of_month is None:
                raise ValueError("MONTHLY routines require day_of_month")
        else:
            self.day_of_month = None
        try:
            ZoneInfo(self.timezone)
        except ZoneInfoNotFoundError as exc:
            raise ValueError("timezone must be a valid IANA timezone") from exc
        return self


class RoutineUpdate(BaseModel):
    name: str | None = Field(default=None, min_length=1, max_length=100)
    description: str | None = None
    frequency: RoutineFrequency | None = None
    repeat_interval: int | None = Field(default=None, ge=1)
    weekdays: list[Weekday] | None = None
    day_of_month: int | None = Field(default=None, ge=1, le=31)
    start_date: Date | None = None
    end_date: Date | None = None
    repeat_count: int | None = Field(default=None, ge=1)
    start_time: time | None = None
    timezone: str | None = None
    is_active: bool | None = None


class RoutineRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    user_id: str
    name: str
    description: str | None
    frequency: RoutineFrequency
    repeat_interval: int
    weekdays: list[Weekday] | None
    day_of_month: int | None
    start_date: Date
    end_date: Date | None
    repeat_count: int | None
    start_time: time | None
    timezone: str
    is_active: bool
    created_at: datetime
    updated_at: datetime


class OccurrenceRead(BaseModel):
    routine_id: int
    scheduled_at: datetime


class ChatRequest(BaseModel):
    message: str = Field(min_length=1, max_length=4000)
    conversation_id: str = Field(min_length=1, max_length=64)
    context_date: Date | None = None
    pipeline_revision: int = Field(default=1, ge=1)
    pipeline_operation_id: str | None = Field(default=None, max_length=36)


class ChatOperationPreview(BaseModel):
    operation_id: str
    action: Literal["create", "update", "delete", "mixed"]
    before_values: dict
    proposed_values: dict
    items: list[dict] = Field(default_factory=list)
    pipeline_revision: int = 1


class ChatResponse(BaseModel):
    message: str
    model: str
    preview: ChatOperationPreview | None = None
    error_code: str | None = None


class ScheduleOperationChanges(TodoUpdate):
    alarm_minutes_before: int | None = Field(default=None, ge=0, le=10080)
    time_delta_minutes: int | None = Field(default=None, ge=-10080, le=10080)


class MixedScheduleOperationItem(BaseModel):
    item_id: str = Field(min_length=1, max_length=64)
    entity_type: Literal["schedule", "routine"] = "schedule"
    action: Literal["create", "update", "delete"]
    schedule_id: int | None = None
    changes: ScheduleOperationChanges | None = None
    confidence: float = Field(default=1.0, ge=0, le=1)
    warning: str | None = Field(default=None, max_length=300)
    confirmation_question: str | None = Field(default=None, max_length=300)
    requires_confirmation: bool = False
    routine: RoutineCreate | None = None

    @model_validator(mode="after")
    def validate_item(self):
        if self.entity_type == "routine":
            if self.action != "create" or self.routine is None:
                raise ValueError("routine items currently support create only")
            if self.schedule_id is not None:
                raise ValueError("routine create does not accept schedule_id")
            return self
        if self.routine is not None:
            raise ValueError("schedule items do not accept routine values")
        if self.action == "create":
            if self.schedule_id is not None:
                raise ValueError("create does not accept schedule_id")
            if self.changes is None:
                raise ValueError("create requires values")
            if self.changes.eta is None and self.changes.scheduled_date is None:
                raise ValueError("create requires schedule date")
        elif self.schedule_id is None:
            raise ValueError(f"{self.action} requires schedule_id")
        if self.action == "update" and (
            self.changes is None or not self.changes.model_fields_set
        ):
            raise ValueError("update requires values")
        if self.action == "delete" and self.changes is not None:
            raise ValueError("delete does not accept changes")
        return self


class ScheduleOperationPreviewRequest(BaseModel):
    action: Literal["create", "update", "delete", "mixed"]
    schedule_id: int | None = None
    schedule_ids: list[int] | None = None
    select_all: bool = False
    pipeline_revision: int = Field(default=1, ge=1)
    allow_empty_description: bool = False
    conversation_id: str = Field(min_length=1, max_length=64)
    changes: ScheduleOperationChanges | None = None
    items: list[MixedScheduleOperationItem] | None = None

    @model_validator(mode="after")
    def validate_changes(self):
        if self.action == "mixed":
            if not self.items:
                raise ValueError("mixed requires at least one operation")
            if self.schedule_id is not None or self.schedule_ids or self.changes is not None:
                raise ValueError("mixed accepts items only")
            item_ids = [item.item_id for item in self.items]
            if len(item_ids) != len(set(item_ids)):
                raise ValueError("mixed item_id values must be unique")
            return self
        if self.items:
            raise ValueError("items are only accepted for mixed operations")
        if self.action in {"create", "update"} and (
            self.changes is None or not self.changes.model_fields_set
        ):
            raise ValueError(f"{self.action} requires values")
        if self.action == "create":
            assert self.changes is not None
            if self.changes.eta is None and self.changes.scheduled_date is None:
                raise ValueError("create requires schedule date")
            if not self.allow_empty_description and not (
                self.changes.description or ""
            ).strip():
                raise ValueError("create requires schedule content")
        if self.action in {"update", "delete"} and self.schedule_id is None and not self.schedule_ids:
            raise ValueError(f"{self.action} requires schedule_id or schedule_ids")
        if self.schedule_id is not None and self.schedule_ids:
            raise ValueError("Use schedule_id or schedule_ids, not both")
        if self.action == "delete" and self.changes is not None:
            raise ValueError("delete does not accept changes")
        return self


class ScheduleOperationRead(BaseModel):
    operation_id: str
    action: str
    schedule_id: int | None
    status: str
    before_values: dict
    proposed_values: dict
    after_values: dict | None = None
    message: str
    items: list[dict] = Field(default_factory=list)
    pipeline_revision: int = 1


class ScheduleOperationSelection(BaseModel):
    selected_schedule_ids: list[int] = Field(default_factory=list)
    selected_item_ids: list[str] = Field(default_factory=list)
    confirmed_item_ids: list[str] = Field(default_factory=list)

    @model_validator(mode="after")
    def validate_selection(self):
        if self.selected_schedule_ids and self.selected_item_ids:
            raise ValueError("Use schedule IDs or item IDs, not both")
        return self


class ScheduleOperationRevision(BaseModel):
    eta: datetime | None = None
    description: str | None = Field(default=None, min_length=1, max_length=200)
    alarm_minutes_before: int | None = Field(default=None, ge=0, le=30)
    location_id: int | None = None

    @model_validator(mode="after")
    def validate_revision(self):
        if not self.model_fields_set:
            raise ValueError("At least one preview value is required")
        if "description" in self.model_fields_set and not (
            self.description or ""
        ).strip():
            raise ValueError("description cannot be empty")
        return self


class ScheduleOperationItemRevision(ScheduleOperationRevision):
    refresh_target: bool = False
    routine: RoutineCreate | None = None
    clear_routine: bool = False

    @model_validator(mode="after")
    def validate_item_revision(self):
        editable = set(self.model_fields_set) - {"refresh_target", "clear_routine"}
        if not editable and not self.refresh_target and not self.clear_routine:
            raise ValueError("At least one item value or refresh_target is required")
        return self


class ScheduleChatChanges(BaseModel):
    eta: datetime | None = None
    time_delta_minutes: int | None = Field(default=None, ge=-10080, le=10080)
    description: str | None = None
    alarm_id: str | None = None
    alarm_minutes_before: int | None = Field(default=None, ge=0, le=10080)
    location_id: int | None = None
    location_query: str | None = None
    clear_location: bool = False


class ScheduleCommandItem(BaseModel):
    entity_type: Literal["schedule", "routine"] = "schedule"
    action: Literal["create", "update", "delete"]
    confidence: float = Field(ge=0, le=1)
    schedule_id: int | None = None
    schedule_query: str | None = None
    date: Date | None = None
    changes: ScheduleChatChanges | None = None
    routine: RoutineCreate | None = None


class ScheduleCommand(BaseModel):
    action: Literal["chat", "list", "create", "update", "delete", "mixed", "unknown"]
    confidence: float = Field(ge=0, le=1)
    schedule_id: int | None = None
    schedule_query: str | None = None
    date: Date | None = None
    changes: ScheduleChatChanges | None = None
    response: str | None = None
    operations: list[ScheduleCommandItem] = Field(default_factory=list)

    @model_validator(mode="after")
    def validate_operations(self):
        if self.action == "mixed" and not self.operations:
            raise ValueError("mixed requires at least one operation")
        if self.action != "mixed" and self.operations:
            raise ValueError("operations are only accepted for mixed commands")
        return self
