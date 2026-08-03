"""Add masked, short-lived schedule command audit logs.

Revision ID: 20260803_08
Revises: 20260803_07
"""

from alembic import op
import sqlalchemy as sa


revision = "20260803_08"
down_revision = "20260803_07"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "schedule_command_logs",
        sa.Column("log_id", sa.BigInteger(), primary_key=True, autoincrement=True),
        sa.Column("user_id", sa.String(45), sa.ForeignKey("users.user_id"), nullable=False),
        sa.Column("conversation_id", sa.String(64), nullable=False),
        sa.Column("masked_input", sa.Text(), nullable=False),
        sa.Column("input_hash", sa.String(64), nullable=False),
        sa.Column("llm_action", sa.String(16)),
        sa.Column("resolved_action", sa.String(16)),
        sa.Column("stage", sa.String(32), nullable=False),
        sa.Column("status", sa.String(16), nullable=False),
        sa.Column("details", sa.JSON()),
        sa.Column("error_code", sa.String(64)),
        sa.Column("operation_id", sa.String(36)),
        sa.Column("model_name", sa.String(100)),
        sa.Column("created_at", sa.DateTime(), nullable=False, server_default=sa.text("CURRENT_TIMESTAMP")),
        sa.Column("completed_at", sa.DateTime()),
        sa.Column("expires_at", sa.DateTime(), nullable=False),
        mysql_charset="utf8mb4",
        mysql_collate="utf8mb4_0900_ai_ci",
    )
    op.create_index(
        "ix_schedule_command_logs_expires_at",
        "schedule_command_logs",
        ["expires_at"],
    )
    op.create_index(
        "ix_schedule_command_logs_user_created",
        "schedule_command_logs",
        ["user_id", "created_at"],
    )


def downgrade() -> None:
    op.drop_table("schedule_command_logs")
