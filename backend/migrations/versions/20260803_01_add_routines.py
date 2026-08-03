"""Add routines and optional schedule recurrence metadata."""

from alembic import op
import sqlalchemy as sa


revision = "20260803_01"
down_revision = None
branch_labels = None
depends_on = None


def upgrade() -> None:
    bind = op.get_bind()
    inspector = sa.inspect(bind)
    tables = set(inspector.get_table_names())
    if "user" not in tables or "schedule" not in tables:
        return

    if "routine" not in tables:
        op.create_table(
            "routine",
            sa.Column("RoutineId", sa.Integer(), autoincrement=True, nullable=False),
            sa.Column("User_UserId", sa.String(length=45), nullable=False),
            sa.Column("Name", sa.String(length=100), nullable=False),
            sa.Column("Frequency", sa.String(length=16), nullable=False),
            sa.Column("RepeatInterval", sa.Integer(), nullable=False),
            sa.Column("StartDate", sa.Date(), nullable=False),
            sa.Column("EndDate", sa.Date(), nullable=True),
            sa.Column("Timezone", sa.String(length=64), nullable=False),
            sa.Column("Weekdays", sa.JSON(), nullable=True),
            sa.Column("DayOfMonth", sa.Integer(), nullable=True),
            sa.Column("StartTime", sa.Time(), nullable=True),
            sa.Column("RepeatCount", sa.Integer(), nullable=True),
            sa.Column("Description", sa.Text(), nullable=True),
            sa.Column(
                "IsActive", sa.Boolean(), server_default=sa.false(), nullable=False
            ),
            sa.Column("CreatedAt", sa.DateTime(), nullable=False),
            sa.Column("UpdatedAt", sa.DateTime(), nullable=False),
            sa.ForeignKeyConstraint(["User_UserId"], ["user.UserId"]),
            sa.PrimaryKeyConstraint("RoutineId"),
        )
        op.create_index(
            "ix_routine_user_active_start",
            "routine",
            ["User_UserId", "IsActive", "StartDate"],
        )

    inspector = sa.inspect(bind)
    schedule_columns = {item["name"] for item in inspector.get_columns("schedule")}
    if "Routine_RoutineId" not in schedule_columns:
        op.add_column(
            "schedule", sa.Column("Routine_RoutineId", sa.Integer(), nullable=True)
        )
        op.create_index(
            "ix_schedule_Routine_RoutineId",
            "schedule",
            ["Routine_RoutineId"],
        )
        op.create_foreign_key(
            "fk_schedule_routine",
            "schedule",
            "routine",
            ["Routine_RoutineId"],
            ["RoutineId"],
            ondelete="SET NULL",
        )
    if "OriginalScheduledAt" not in schedule_columns:
        op.add_column(
            "schedule", sa.Column("OriginalScheduledAt", sa.String(45), nullable=True)
        )
    if "IsException" not in schedule_columns:
        op.add_column(
            "schedule",
            sa.Column(
                "IsException",
                sa.Boolean(),
                server_default=sa.false(),
                nullable=False,
            ),
        )


def downgrade() -> None:
    bind = op.get_bind()
    inspector = sa.inspect(bind)
    schedule_columns = {item["name"] for item in inspector.get_columns("schedule")}
    if "IsException" in schedule_columns:
        op.drop_column("schedule", "IsException")
    if "OriginalScheduledAt" in schedule_columns:
        op.drop_column("schedule", "OriginalScheduledAt")
    if "Routine_RoutineId" in schedule_columns:
        op.drop_constraint("fk_schedule_routine", "schedule", type_="foreignkey")
        op.drop_index("ix_schedule_Routine_RoutineId", table_name="schedule")
        op.drop_column("schedule", "Routine_RoutineId")
    if "routine" in set(inspector.get_table_names()):
        op.drop_table("routine")
