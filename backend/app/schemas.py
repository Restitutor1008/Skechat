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
    schedule_id: int | None = None
    eta: datetime
    description: str | None = None
    user_id: str
    alarm_id: str
    location_id: int | None = None
    is_completed: bool = False
    routine_id: int | None = None
    original_scheduled_at: datetime | None = None
    is_exception: bool = False

    @model_validator(mode="after")
    def validate_exception(self):
        if self.is_exception and (
            self.routine_id is None or self.original_scheduled_at is None
        ):
            raise ValueError(
                "A schedule exception requires routine_id and original_scheduled_at"
            )
        return self


class TodoUpdate(BaseModel):
    eta: datetime | None = None
    description: str | None = None
    alarm_id: str | None = None
    location_id: int | None = None
    is_completed: bool | None = None
    routine_id: int | None = None
    original_scheduled_at: datetime | None = None
    is_exception: bool | None = None


class TodoRead(BaseModel):
    id: int
    eta: datetime
    description: str
    user: UserSummary
    alarm: AlarmRead
    location: LocationRead | None
    is_completed: bool = False
    routine_id: int | None = None
    original_scheduled_at: datetime | None = None
    is_exception: bool = False


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


class ChatOperationPreview(BaseModel):
    operation_id: str
    action: Literal["create", "update", "delete"]
    before_values: dict
    proposed_values: dict


class ChatResponse(BaseModel):
    message: str
    model: str
    preview: ChatOperationPreview | None = None
    error_code: str | None = None


class ScheduleOperationChanges(TodoUpdate):
    alarm_minutes_before: int | None = Field(default=None, ge=0, le=10080)


class ScheduleOperationPreviewRequest(BaseModel):
    action: Literal["create", "update", "delete"]
    schedule_id: int | None = None
    conversation_id: str = Field(min_length=1, max_length=64)
    changes: ScheduleOperationChanges | None = None

    @model_validator(mode="after")
    def validate_changes(self):
        if self.action in {"create", "update"} and (
            self.changes is None or not self.changes.model_fields_set
        ):
            raise ValueError(f"{self.action} requires values")
        if self.action == "create":
            assert self.changes is not None
            if self.changes.eta is None:
                raise ValueError("create requires schedule time")
            if not (self.changes.description or "").strip():
                raise ValueError("create requires schedule content")
        if self.action in {"update", "delete"} and self.schedule_id is None:
            raise ValueError(f"{self.action} requires schedule_id")
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


class ScheduleOperationRevision(BaseModel):
    eta: datetime | None = None
    description: str | None = Field(default=None, min_length=1, max_length=200)
    alarm_minutes_before: int | None = Field(default=None, ge=0, le=30)

    @model_validator(mode="after")
    def validate_revision(self):
        if not self.model_fields_set:
            raise ValueError("At least one preview value is required")
        if "description" in self.model_fields_set and not (
            self.description or ""
        ).strip():
            raise ValueError("description cannot be empty")
        return self


class ScheduleChatChanges(BaseModel):
    eta: datetime | None = None
    time_delta_minutes: int | None = Field(default=None, ge=-10080, le=10080)
    description: str | None = None
    alarm_id: str | None = None
    alarm_minutes_before: int | None = Field(default=None, ge=0, le=10080)
    location_id: int | None = None


class ScheduleCommand(BaseModel):
    action: Literal["chat", "list", "create", "update", "delete", "unknown"]
    confidence: float = Field(ge=0, le=1)
    schedule_id: int | None = None
    schedule_query: str | None = None
    date: Date | None = None
    changes: ScheduleChatChanges | None = None
    response: str | None = None
