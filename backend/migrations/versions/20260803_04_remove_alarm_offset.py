"""Remove the redundant alarm offset_minutes column.

Revision ID: 20260803_04
Revises: 20260803_03
"""

from alembic import op
import sqlalchemy as sa


revision = "20260803_04"
down_revision = "20260803_03"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.drop_column("alarms", "offset_minutes")


def downgrade() -> None:
    op.add_column(
        "alarms",
        sa.Column(
            "offset_minutes",
            sa.Integer(),
            nullable=False,
            server_default=sa.text("0"),
        ),
    )

