"""Normalize the core schema and preserve legacy data.

Revision ID: 20260803_03
Revises: 20260803_02
"""

from alembic import op
import sqlalchemy as sa
from sqlalchemy import inspect, text


revision = "20260803_03"
down_revision = "20260803_02"
branch_labels = None
depends_on = None


FINAL_TABLES = [
    "schedules",
    "login_histories",
    "routines",
    "locations",
    "sources",
    "alarms",
    "users",
]


def _create_final_schema() -> None:
    table_options = {"mysql_charset": "utf8mb4", "mysql_collate": "utf8mb4_0900_ai_ci"}

    op.create_table(
        "users",
        sa.Column("user_id", sa.String(45), primary_key=True),
        sa.Column("password_hash", sa.String(255), nullable=False),
        sa.Column("user_name", sa.String(100), nullable=False),
        sa.Column("phone_number", sa.String(20), nullable=False, unique=True),
        sa.Column("created_at", sa.DateTime(), nullable=False, server_default=sa.text("CURRENT_TIMESTAMP")),
        sa.Column("updated_at", sa.DateTime(), nullable=False, server_default=sa.text("CURRENT_TIMESTAMP")),
        **table_options,
    )
    op.create_table(
        "alarms",
        sa.Column("alarm_id", sa.String(45), primary_key=True),
        sa.Column("alarm_music", sa.String(255)),
        sa.Column("alarm_text", sa.String(255)),
        sa.Column("minutes_before", sa.Integer(), nullable=False),
        sa.Column("offset_minutes", sa.Integer(), nullable=False),
        sa.Column("is_obsolete", sa.Boolean(), nullable=False, server_default=sa.text("0")),
        sa.Column("created_at", sa.DateTime(), nullable=False, server_default=sa.text("CURRENT_TIMESTAMP")),
        sa.Column("updated_at", sa.DateTime(), nullable=False, server_default=sa.text("CURRENT_TIMESTAMP")),
        sa.CheckConstraint("minutes_before >= 0", name="ck_alarms_minutes_before"),
        **table_options,
    )
    op.create_table(
        "sources",
        sa.Column("source_id", sa.Integer(), primary_key=True, autoincrement=True),
        sa.Column("name", sa.String(100)),
        sa.Column("created_at", sa.DateTime(), nullable=False, server_default=sa.text("CURRENT_TIMESTAMP")),
        **table_options,
    )
    op.create_table(
        "locations",
        sa.Column("location_id", sa.BigInteger(), primary_key=True, autoincrement=True),
        sa.Column("name", sa.String(100), nullable=False),
        sa.Column("latitude", sa.Numeric(9, 6), nullable=False),
        sa.Column("longitude", sa.Numeric(10, 6), nullable=False),
        sa.Column("source_id", sa.Integer(), sa.ForeignKey("sources.source_id"), nullable=False),
        sa.Column("is_obsolete", sa.Boolean(), nullable=False, server_default=sa.text("0")),
        sa.Column("created_at", sa.DateTime(), nullable=False, server_default=sa.text("CURRENT_TIMESTAMP")),
        sa.Column("updated_at", sa.DateTime(), nullable=False, server_default=sa.text("CURRENT_TIMESTAMP")),
        sa.CheckConstraint("latitude BETWEEN -90 AND 90", name="ck_locations_latitude"),
        sa.CheckConstraint("longitude BETWEEN -180 AND 180", name="ck_locations_longitude"),
        **table_options,
    )
    op.create_index("ix_locations_coordinates", "locations", ["latitude", "longitude"])
    op.create_table(
        "login_histories",
        sa.Column("login_id", sa.BigInteger(), primary_key=True, autoincrement=True),
        sa.Column("logged_in_at", sa.DateTime(), nullable=False),
        sa.Column("version", sa.String(45), nullable=False),
        sa.Column("ip_address", sa.LargeBinary(16), nullable=False),
        sa.Column("hardware", sa.String(255), nullable=False),
        sa.Column("user_id", sa.String(45), sa.ForeignKey("users.user_id"), nullable=False),
        **table_options,
    )
    op.create_index("ix_login_histories_logged_in_at", "login_histories", ["logged_in_at"])
    op.create_index("ix_login_histories_user_id", "login_histories", ["user_id"])
    op.create_table(
        "routines",
        sa.Column("id", sa.Integer(), primary_key=True, autoincrement=True),
        sa.Column("user_id", sa.String(45), sa.ForeignKey("users.user_id"), nullable=False),
        sa.Column("name", sa.String(100), nullable=False),
        sa.Column("frequency", sa.String(16), nullable=False),
        sa.Column("repeat_interval", sa.Integer(), nullable=False, server_default=sa.text("1")),
        sa.Column("start_date", sa.Date(), nullable=False),
        sa.Column("end_date", sa.Date()),
        sa.Column("timezone", sa.String(64), nullable=False, server_default="Asia/Seoul"),
        sa.Column("weekdays", sa.JSON()),
        sa.Column("day_of_month", sa.Integer()),
        sa.Column("start_time", sa.Time()),
        sa.Column("repeat_count", sa.Integer()),
        sa.Column("description", sa.Text()),
        sa.Column("is_active", sa.Boolean(), nullable=False, server_default=sa.text("1")),
        sa.Column("created_at", sa.DateTime(), nullable=False, server_default=sa.text("CURRENT_TIMESTAMP")),
        sa.Column("updated_at", sa.DateTime(), nullable=False, server_default=sa.text("CURRENT_TIMESTAMP")),
        sa.CheckConstraint("repeat_interval >= 1", name="ck_routines_repeat_interval"),
        sa.CheckConstraint("repeat_count IS NULL OR repeat_count >= 1", name="ck_routines_repeat_count"),
        sa.CheckConstraint("day_of_month IS NULL OR day_of_month BETWEEN 1 AND 31", name="ck_routines_day_of_month"),
        sa.CheckConstraint("end_date IS NULL OR end_date >= start_date", name="ck_routines_end_date"),
        sa.CheckConstraint("end_date IS NULL OR repeat_count IS NULL", name="ck_routines_single_termination"),
        sa.CheckConstraint("frequency IN ('DAILY','WEEKLY','MONTHLY','YEARLY')", name="ck_routines_frequency"),
        sa.CheckConstraint("frequency = 'WEEKLY' OR weekdays IS NULL", name="ck_routines_weekdays_scope"),
        sa.CheckConstraint("frequency <> 'WEEKLY' OR weekdays IS NOT NULL", name="ck_routines_weekdays_required"),
        sa.CheckConstraint("frequency = 'MONTHLY' OR day_of_month IS NULL", name="ck_routines_month_day_scope"),
        sa.CheckConstraint("frequency <> 'MONTHLY' OR day_of_month IS NOT NULL", name="ck_routines_month_day_required"),
        **table_options,
    )
    op.create_index("ix_routines_user_active_start", "routines", ["user_id", "is_active", "start_date"])
    op.create_table(
        "schedules",
        sa.Column("schedule_id", sa.BigInteger(), primary_key=True, autoincrement=True),
        sa.Column("scheduled_at", sa.DateTime(), nullable=False),
        sa.Column("timezone", sa.String(64), nullable=False, server_default="Asia/Seoul"),
        sa.Column("description", sa.Text()),
        sa.Column("user_id", sa.String(45), sa.ForeignKey("users.user_id"), nullable=False),
        sa.Column("alarm_id", sa.String(45), sa.ForeignKey("alarms.alarm_id"), nullable=False),
        sa.Column("location_id", sa.BigInteger(), sa.ForeignKey("locations.location_id"), nullable=False),
        sa.Column("is_obsolete", sa.Boolean(), nullable=False, server_default=sa.text("0")),
        sa.Column("routine_id", sa.Integer(), sa.ForeignKey("routines.id")),
        sa.Column("original_scheduled_at", sa.DateTime()),
        sa.Column("is_exception", sa.Boolean(), nullable=False, server_default=sa.text("0")),
        sa.Column("created_at", sa.DateTime(), nullable=False, server_default=sa.text("CURRENT_TIMESTAMP")),
        sa.Column("updated_at", sa.DateTime(), nullable=False, server_default=sa.text("CURRENT_TIMESTAMP")),
        sa.CheckConstraint(
            "is_exception = 0 OR (routine_id IS NOT NULL AND original_scheduled_at IS NOT NULL)",
            name="ck_schedules_exception_metadata",
        ),
        **table_options,
    )
    op.create_index("ix_schedules_routine_id", "schedules", ["routine_id"])
    op.create_index("ix_schedules_obsolete_scheduled", "schedules", ["is_obsolete", "scheduled_at"])
    op.create_index(
        "ix_schedules_user_obsolete_scheduled",
        "schedules",
        ["user_id", "is_obsolete", "scheduled_at"],
    )


def upgrade() -> None:
    bind = op.get_bind()
    inspector = inspect(bind)
    existing = set(inspector.get_table_names())
    legacy_present = "user" in existing and "schedule" in existing

    # A hot-reloading development server may have created the ORM's new tables
    # before this revision existed. They are safe to replace only while empty.
    for table_name in FINAL_TABLES:
        if table_name in existing:
            count = bind.execute(text(f"SELECT COUNT(*) FROM `{table_name}`")).scalar_one()
            if count:
                raise RuntimeError(f"Refusing to replace non-empty pre-created table: {table_name}")
    for table_name in FINAL_TABLES:
        if table_name in existing:
            op.drop_table(table_name)

    _create_final_schema()
    if not legacy_present:
        op.execute("ALTER DATABASE CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci")
        op.execute(
            "ALTER TABLE alembic_version CONVERT TO CHARACTER SET utf8mb4 "
            "COLLATE utf8mb4_0900_ai_ci"
        )
        return

    op.execute(
        """INSERT INTO users (user_id, password_hash, user_name, phone_number)
           SELECT UserId, Password, UserName, PhoneNumber FROM `user`"""
    )
    op.execute(
        """INSERT INTO alarms
             (alarm_id, alarm_music, alarm_text, minutes_before, offset_minutes, is_obsolete)
           SELECT AlarmId, AlarmMusic, AlarmText,
                  CAST(MinutesBefore AS SIGNED), CAST(OffsetMinutes AS SIGNED), obsolete
           FROM alarm"""
    )
    op.execute(
        """INSERT INTO sources (source_id, name)
           SELECT CAST(SourceId AS UNSIGNED), CONCAT('Source ', SourceId) FROM source"""
    )
    op.execute(
        """INSERT INTO locations
             (name, latitude, longitude, source_id, is_obsolete)
           SELECT LocationId, CAST(Latitude AS DECIMAL(9,6)),
                  CAST(Longtitude AS DECIMAL(10,6)), Source_idSourceSourceId, obsolete
           FROM location"""
    )
    op.execute(
        """INSERT INTO routines
             (id, user_id, name, frequency, repeat_interval, start_date, end_date,
              timezone, weekdays, day_of_month, start_time, repeat_count, description,
              is_active, created_at, updated_at)
           SELECT RoutineId, User_UserId, Name, Frequency, RepeatInterval, StartDate,
                  EndDate, Timezone, Weekdays, DayOfMonth, StartTime, RepeatCount,
                  Description, IsActive, CreatedAt, UpdatedAt
           FROM routine"""
    )
    op.execute(
        """INSERT INTO login_histories
             (logged_in_at, version, ip_address, hardware, user_id)
           SELECT STR_TO_DATE(LEFT(CurrentTime, 19), '%Y-%m-%dT%H:%i:%s'), Version,
                  COALESCE(INET6_ATON(IpAddress), UNHEX('00000000000000000000000000000000')),
                  Hardware, User_UserId
           FROM loginhistory"""
    )
    op.execute(
        """INSERT INTO schedules
             (schedule_id, scheduled_at, timezone, description, user_id, alarm_id,
              location_id, is_obsolete, routine_id, original_scheduled_at, is_exception)
           SELECT s.ScheduleId,
                  STR_TO_DATE(LEFT(s.ETA, 19), '%Y-%m-%dT%H:%i:%s'),
                  'Asia/Seoul', s.Description, s.User_UserId, s.Alarm_AlarmId,
                  l.location_id, s.obsolete, s.Routine_RoutineId,
                  CASE WHEN s.OriginalScheduledAt IS NULL THEN NULL
                       ELSE STR_TO_DATE(LEFT(s.OriginalScheduledAt, 19), '%Y-%m-%dT%H:%i:%s') END,
                  s.IsException
           FROM schedule s
           JOIN locations l
             ON l.name = s.Location_LocationId
            AND l.source_id = s.Location_Source_idSourceSourceId"""
    )

    expected = bind.execute(text("SELECT COUNT(*) FROM schedule")).scalar_one()
    actual = bind.execute(text("SELECT COUNT(*) FROM schedules")).scalar_one()
    if expected != actual:
        raise RuntimeError(f"Schedule migration count mismatch: {expected} != {actual}")

    for table_name in ["schedule", "loginhistory", "routine", "location", "source", "alarm", "user", "todos"]:
        if table_name in existing:
            op.drop_table(table_name)
    op.execute("ALTER DATABASE CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci")
    op.execute(
        "ALTER TABLE alembic_version CONVERT TO CHARACTER SET utf8mb4 "
        "COLLATE utf8mb4_0900_ai_ci"
    )


def downgrade() -> None:
    raise RuntimeError(
        "This data-normalizing migration is intentionally irreversible. "
        "Restore the pre-normalization backup database instead."
    )
