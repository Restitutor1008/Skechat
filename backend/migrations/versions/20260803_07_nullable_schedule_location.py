"""Allow schedules without a location.

Revision ID: 20260803_07
Revises: 20260803_06
"""

from alembic import op
import sqlalchemy as sa


revision = "20260803_07"
down_revision = "20260803_06"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.alter_column(
        "schedules",
        "location_id",
        existing_type=sa.BigInteger(),
        nullable=True,
    )


def downgrade() -> None:
    missing = op.get_bind().execute(
        sa.text("SELECT COUNT(*) FROM schedules WHERE location_id IS NULL")
    ).scalar_one()
    if missing:
        raise RuntimeError("Cannot require location while schedules with NULL location exist")
    op.alter_column(
        "schedules",
        "location_id",
        existing_type=sa.BigInteger(),
        nullable=False,
    )
