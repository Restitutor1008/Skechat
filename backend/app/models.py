from datetime import date, datetime, time
from enum import Enum as PythonEnum
from decimal import Decimal

from sqlalchemy import (
    JSON,
    BigInteger,
    Boolean,
    CheckConstraint,
    Date,
    DateTime,
    Enum,
    ForeignKey,
    Index,
    Integer,
    LargeBinary,
    Numeric,
    String,
    Text,
    Time,
)
from sqlalchemy.orm import Mapped, mapped_column, relationship

from .database import Base


class User(Base):
    __tablename__ = "users"

    user_id: Mapped[str] = mapped_column(String(45), primary_key=True)
    password_hash: Mapped[str] = mapped_column(String(255), nullable=False)
    user_name: Mapped[str] = mapped_column(String(100), nullable=False)
    phone_number: Mapped[str] = mapped_column(String(20), nullable=False, unique=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.now, nullable=False)
    updated_at: Mapped[datetime] = mapped_column(
        DateTime, default=datetime.now, onupdate=datetime.now, nullable=False
    )


class Alarm(Base):
    __tablename__ = "alarms"
    __table_args__ = (
        CheckConstraint("minutes_before >= 0", name="ck_alarms_minutes_before"),
    )

    alarm_id: Mapped[str] = mapped_column(String(45), primary_key=True)
    alarm_music: Mapped[str | None] = mapped_column(String(255))
    alarm_text: Mapped[str | None] = mapped_column(String(255))
    minutes_before: Mapped[int] = mapped_column(Integer, nullable=False)
    is_obsolete: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.now, nullable=False)
    updated_at: Mapped[datetime] = mapped_column(
        DateTime, default=datetime.now, onupdate=datetime.now, nullable=False
    )


class Source(Base):
    __tablename__ = "sources"

    source_id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    name: Mapped[str | None] = mapped_column(String(100))
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.now, nullable=False)


class Location(Base):
    __tablename__ = "locations"
    __table_args__ = (
        CheckConstraint("latitude BETWEEN -90 AND 90", name="ck_locations_latitude"),
        CheckConstraint(
            "longitude BETWEEN -180 AND 180", name="ck_locations_longitude"
        ),
        Index("ix_locations_coordinates", "latitude", "longitude"),
    )

    location_id: Mapped[int] = mapped_column(BigInteger, primary_key=True, autoincrement=True)
    name: Mapped[str] = mapped_column(String(100), nullable=False)
    latitude: Mapped[Decimal] = mapped_column(Numeric(9, 6), nullable=False)
    longitude: Mapped[Decimal] = mapped_column(Numeric(10, 6), nullable=False)
    source_id: Mapped[int] = mapped_column(ForeignKey("sources.source_id"), nullable=False)
    is_obsolete: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.now, nullable=False)
    updated_at: Mapped[datetime] = mapped_column(
        DateTime, default=datetime.now, onupdate=datetime.now, nullable=False
    )

    source: Mapped[Source] = relationship()


class LoginHistory(Base):
    __tablename__ = "login_histories"

    login_id: Mapped[int] = mapped_column(BigInteger, primary_key=True, autoincrement=True)
    logged_in_at: Mapped[datetime] = mapped_column(DateTime, nullable=False, index=True)
    version: Mapped[str] = mapped_column(String(45), nullable=False)
    ip_address: Mapped[bytes] = mapped_column(LargeBinary(16), nullable=False)
    hardware: Mapped[str] = mapped_column(String(255), nullable=False)
    user_id: Mapped[str] = mapped_column(ForeignKey("users.user_id"), nullable=False, index=True)

    user: Mapped[User] = relationship()


class RoutineFrequency(str, PythonEnum):
    DAILY = "DAILY"
    WEEKLY = "WEEKLY"
    MONTHLY = "MONTHLY"
    YEARLY = "YEARLY"


class Routine(Base):
    __tablename__ = "routines"
    __table_args__ = (
        Index("ix_routines_user_active_start", "user_id", "is_active", "start_date"),
        CheckConstraint("repeat_interval >= 1", name="ck_routines_repeat_interval"),
        CheckConstraint(
            "repeat_count IS NULL OR repeat_count >= 1",
            name="ck_routines_repeat_count",
        ),
        CheckConstraint(
            "day_of_month IS NULL OR day_of_month BETWEEN 1 AND 31",
            name="ck_routines_day_of_month",
        ),
        CheckConstraint(
            "end_date IS NULL OR end_date >= start_date",
            name="ck_routines_end_date",
        ),
        CheckConstraint(
            "end_date IS NULL OR repeat_count IS NULL",
            name="ck_routines_single_termination",
        ),
        CheckConstraint(
            "frequency IN ('DAILY','WEEKLY','MONTHLY','YEARLY')",
            name="ck_routines_frequency",
        ),
        CheckConstraint(
            "frequency = 'WEEKLY' OR weekdays IS NULL",
            name="ck_routines_weekdays_scope",
        ),
        CheckConstraint(
            "frequency <> 'WEEKLY' OR weekdays IS NOT NULL",
            name="ck_routines_weekdays_required",
        ),
        CheckConstraint(
            "frequency = 'MONTHLY' OR day_of_month IS NULL",
            name="ck_routines_month_day_scope",
        ),
        CheckConstraint(
            "frequency <> 'MONTHLY' OR day_of_month IS NOT NULL",
            name="ck_routines_month_day_required",
        ),
    )

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    user_id: Mapped[str] = mapped_column(ForeignKey("users.user_id"), nullable=False)
    name: Mapped[str] = mapped_column(String(100), nullable=False)
    frequency: Mapped[RoutineFrequency] = mapped_column(
        Enum(RoutineFrequency, native_enum=False, length=16), nullable=False
    )
    repeat_interval: Mapped[int] = mapped_column(Integer, default=1, nullable=False)
    start_date: Mapped[date] = mapped_column(Date, nullable=False)
    end_date: Mapped[date | None] = mapped_column(Date)
    timezone: Mapped[str] = mapped_column(String(64), default="Asia/Seoul", nullable=False)
    weekdays: Mapped[list[str] | None] = mapped_column(JSON(none_as_null=True))
    day_of_month: Mapped[int | None] = mapped_column(Integer)
    start_time: Mapped[time | None] = mapped_column(Time)
    repeat_count: Mapped[int | None] = mapped_column(Integer)
    description: Mapped[str | None] = mapped_column(Text)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.now, nullable=False)
    updated_at: Mapped[datetime] = mapped_column(
        DateTime, default=datetime.now, onupdate=datetime.now, nullable=False
    )

    user: Mapped[User] = relationship()
    schedules: Mapped[list["Schedule"]] = relationship(
        back_populates="routine", passive_deletes=True
    )


class Schedule(Base):
    __tablename__ = "schedules"
    __table_args__ = (
        Index("ix_schedules_obsolete_scheduled", "is_obsolete", "scheduled_at"),
        Index(
            "ix_schedules_user_obsolete_scheduled",
            "user_id",
            "is_obsolete",
            "scheduled_at",
        ),
        Index(
            "ix_schedules_user_completed_scheduled",
            "user_id",
            "is_completed",
            "scheduled_at",
        ),
        CheckConstraint(
            "is_exception = 0 OR "
            "(routine_id IS NOT NULL AND original_scheduled_at IS NOT NULL)",
            name="ck_schedules_exception_metadata",
        ),
    )

    schedule_id: Mapped[int] = mapped_column(
        BigInteger().with_variant(Integer, "sqlite"),
        primary_key=True,
        autoincrement=True,
    )
    scheduled_at: Mapped[datetime] = mapped_column(DateTime, nullable=False)
    timezone: Mapped[str] = mapped_column(String(64), default="Asia/Seoul", nullable=False)
    description: Mapped[str | None] = mapped_column(Text)
    user_id: Mapped[str] = mapped_column(ForeignKey("users.user_id"), nullable=False)
    alarm_id: Mapped[str] = mapped_column(ForeignKey("alarms.alarm_id"), nullable=False)
    location_id: Mapped[int | None] = mapped_column(
        ForeignKey("locations.location_id"), nullable=True
    )
    is_completed: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    is_obsolete: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    routine_id: Mapped[int | None] = mapped_column(
        ForeignKey("routines.id"), nullable=True, index=True
    )
    original_scheduled_at: Mapped[datetime | None] = mapped_column(DateTime)
    is_exception: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.now, nullable=False)
    updated_at: Mapped[datetime] = mapped_column(
        DateTime, default=datetime.now, onupdate=datetime.now, nullable=False
    )

    user: Mapped[User] = relationship(lazy="joined")
    alarm: Mapped[Alarm] = relationship(lazy="joined")
    location: Mapped[Location | None] = relationship(lazy="joined")
    routine: Mapped[Routine | None] = relationship(back_populates="schedules")


class ScheduleOperation(Base):
    __tablename__ = "schedule_operations"
    __table_args__ = (
        Index(
            "ix_schedule_operations_pending",
            "user_id",
            "conversation_id",
            "status",
            "created_at",
        ),
    )

    operation_id: Mapped[str] = mapped_column(String(36), primary_key=True)
    user_id: Mapped[str] = mapped_column(ForeignKey("users.user_id"), nullable=False)
    conversation_id: Mapped[str] = mapped_column(String(64), nullable=False)
    action: Mapped[str] = mapped_column(String(16), nullable=False)
    schedule_id: Mapped[int | None] = mapped_column(
        ForeignKey("schedules.schedule_id"), nullable=True
    )
    payload: Mapped[dict] = mapped_column(JSON, nullable=False)
    before_values: Mapped[dict] = mapped_column(JSON, nullable=False)
    after_values: Mapped[dict | None] = mapped_column(JSON)
    status: Mapped[str] = mapped_column(String(16), default="pending", nullable=False)
    expires_at: Mapped[datetime] = mapped_column(DateTime, nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.now, nullable=False)
    executed_at: Mapped[datetime | None] = mapped_column(DateTime)
    undone_at: Mapped[datetime | None] = mapped_column(DateTime)

    user: Mapped[User] = relationship()
    schedule: Mapped[Schedule | None] = relationship()


class ScheduleCommandLog(Base):
    __tablename__ = "schedule_command_logs"
    __table_args__ = (
        Index("ix_schedule_command_logs_expires_at", "expires_at"),
        Index(
            "ix_schedule_command_logs_user_created",
            "user_id",
            "created_at",
        ),
    )

    log_id: Mapped[int] = mapped_column(
        BigInteger().with_variant(Integer, "sqlite"),
        primary_key=True,
        autoincrement=True,
    )
    user_id: Mapped[str] = mapped_column(ForeignKey("users.user_id"), nullable=False)
    conversation_id: Mapped[str] = mapped_column(String(64), nullable=False)
    masked_input: Mapped[str] = mapped_column(Text, nullable=False)
    input_hash: Mapped[str] = mapped_column(String(64), nullable=False)
    llm_action: Mapped[str | None] = mapped_column(String(16))
    resolved_action: Mapped[str | None] = mapped_column(String(16))
    stage: Mapped[str] = mapped_column(String(32), nullable=False)
    status: Mapped[str] = mapped_column(String(16), nullable=False)
    details: Mapped[dict | None] = mapped_column(JSON)
    error_code: Mapped[str | None] = mapped_column(String(64))
    operation_id: Mapped[str | None] = mapped_column(String(36))
    model_name: Mapped[str | None] = mapped_column(String(100))
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.now, nullable=False)
    completed_at: Mapped[datetime | None] = mapped_column(DateTime)
    expires_at: Mapped[datetime] = mapped_column(DateTime, nullable=False)

    user: Mapped[User] = relationship()
