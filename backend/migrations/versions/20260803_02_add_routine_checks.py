"""Add database-level routine rule checks."""

from alembic import op
import sqlalchemy as sa


revision = "20260803_02"
down_revision = "20260803_01"
branch_labels = None
depends_on = None


CHECKS = {
    "ck_routine_repeat_interval": "RepeatInterval >= 1",
    "ck_routine_repeat_count": "RepeatCount IS NULL OR RepeatCount >= 1",
    "ck_routine_day_of_month": "DayOfMonth IS NULL OR DayOfMonth BETWEEN 1 AND 31",
    "ck_routine_end_date": "EndDate IS NULL OR EndDate >= StartDate",
    "ck_routine_single_termination": "EndDate IS NULL OR RepeatCount IS NULL",
    "ck_routine_frequency": "Frequency IN ('DAILY','WEEKLY','MONTHLY','YEARLY')",
    "ck_routine_weekdays_scope": "Frequency = 'WEEKLY' OR Weekdays IS NULL",
    "ck_routine_weekdays_required": "Frequency <> 'WEEKLY' OR Weekdays IS NOT NULL",
    "ck_routine_month_day_scope": "Frequency = 'MONTHLY' OR DayOfMonth IS NULL",
    "ck_routine_month_day_required": "Frequency <> 'MONTHLY' OR DayOfMonth IS NOT NULL",
}


def upgrade() -> None:
    if "routine" not in set(sa.inspect(op.get_bind()).get_table_names()):
        return
    existing = {
        item["name"]
        for item in sa.inspect(op.get_bind()).get_check_constraints("routine")
    }
    for name, condition in CHECKS.items():
        if name not in existing:
            op.create_check_constraint(name, "routine", condition)


def downgrade() -> None:
    if "routine" not in set(sa.inspect(op.get_bind()).get_table_names()):
        return
    existing = {
        item["name"]
        for item in sa.inspect(op.get_bind()).get_check_constraints("routine")
    }
    for name in reversed(CHECKS):
        if name in existing:
            op.drop_constraint(name, "routine", type_="check")
