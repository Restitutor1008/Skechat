"""Allow a pending operation to represent a schedule not created yet.

Revision ID: 20260803_06
Revises: 20260803_05
"""

from alembic import op
import sqlalchemy as sa


revision = "20260803_06"
down_revision = "20260803_05"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.alter_column(
        "schedule_operations",
        "schedule_id",
        existing_type=sa.BigInteger(),
        nullable=True,
    )


def downgrade() -> None:
    op.execute("DELETE FROM schedule_operations WHERE schedule_id IS NULL")
    op.alter_column(
        "schedule_operations",
        "schedule_id",
        existing_type=sa.BigInteger(),
        nullable=False,
    )
