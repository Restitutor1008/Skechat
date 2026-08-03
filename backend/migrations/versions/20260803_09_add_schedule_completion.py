"""Add explicit schedule completion state.

Revision ID: 20260803_09
Revises: 20260803_08
"""

from alembic import op
import sqlalchemy as sa


revision = "20260803_09"
down_revision = "20260803_08"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        "schedules",
        sa.Column(
            "is_completed",
            sa.Boolean(),
            nullable=False,
            server_default=sa.text("0"),
        ),
    )
    op.create_index(
        "ix_schedules_user_completed_scheduled",
        "schedules",
        ["user_id", "is_completed", "scheduled_at"],
    )


def downgrade() -> None:
    op.drop_index("ix_schedules_user_completed_scheduled", table_name="schedules")
    op.drop_column("schedules", "is_completed")
