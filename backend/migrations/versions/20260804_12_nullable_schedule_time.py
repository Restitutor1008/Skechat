"""Allow schedules without a clock time.

Revision ID: 20260804_12
Revises: 20260804_11
"""

from alembic import op
import sqlalchemy as sa


revision = "20260804_12"
down_revision = "20260804_11"
branch_labels = None
depends_on = None


def upgrade() -> None:
    inspector = sa.inspect(op.get_bind())
    columns = {column["name"] for column in inspector.get_columns("schedules")}
    if "scheduled_date" not in columns:
        op.add_column(
            "schedules", sa.Column("scheduled_date", sa.Date(), nullable=True)
        )
    op.execute("UPDATE schedules SET scheduled_date = DATE(scheduled_at)")
    op.alter_column(
        "schedules",
        "scheduled_date",
        existing_type=sa.Date(),
        nullable=False,
    )
    op.alter_column(
        "schedules",
        "scheduled_at",
        existing_type=sa.DateTime(),
        nullable=True,
    )


def downgrade() -> None:
    op.execute(
        "UPDATE schedules "
        "SET scheduled_at = TIMESTAMP(scheduled_date, '00:00:00') "
        "WHERE scheduled_at IS NULL"
    )
    op.alter_column(
        "schedules",
        "scheduled_at",
        existing_type=sa.DateTime(),
        nullable=False,
    )
    op.drop_column("schedules", "scheduled_date")
