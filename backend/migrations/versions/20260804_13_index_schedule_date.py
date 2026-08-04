"""Index date-only schedule queries.

Revision ID: 20260804_13
Revises: 20260804_12
"""

from alembic import op


revision = "20260804_13"
down_revision = "20260804_12"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_index(
        "ix_schedules_user_obsolete_date_time",
        "schedules",
        ["user_id", "is_obsolete", "scheduled_date", "scheduled_at"],
    )


def downgrade() -> None:
    op.drop_index("ix_schedules_user_obsolete_date_time", table_name="schedules")
