"""Add confirmed schedule operation audit records.

Revision ID: 20260803_05
Revises: 20260803_04
"""

from alembic import op
import sqlalchemy as sa


revision = "20260803_05"
down_revision = "20260803_04"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "schedule_operations",
        sa.Column("operation_id", sa.String(36), primary_key=True),
        sa.Column("user_id", sa.String(45), sa.ForeignKey("users.user_id"), nullable=False),
        sa.Column("conversation_id", sa.String(64), nullable=False),
        sa.Column("action", sa.String(16), nullable=False),
        sa.Column("schedule_id", sa.BigInteger(), sa.ForeignKey("schedules.schedule_id"), nullable=False),
        sa.Column("payload", sa.JSON(), nullable=False),
        sa.Column("before_values", sa.JSON(), nullable=False),
        sa.Column("after_values", sa.JSON()),
        sa.Column("status", sa.String(16), nullable=False, server_default="pending"),
        sa.Column("expires_at", sa.DateTime(), nullable=False),
        sa.Column("created_at", sa.DateTime(), nullable=False, server_default=sa.text("CURRENT_TIMESTAMP")),
        sa.Column("executed_at", sa.DateTime()),
        sa.Column("undone_at", sa.DateTime()),
        mysql_charset="utf8mb4",
        mysql_collate="utf8mb4_0900_ai_ci",
    )
    op.create_index(
        "ix_schedule_operations_pending",
        "schedule_operations",
        ["user_id", "conversation_id", "status", "created_at"],
    )


def downgrade() -> None:
    op.drop_table("schedule_operations")
