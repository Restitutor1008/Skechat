"""Add idempotent offline sync batch receipts.

Revision ID: 20260804_11
Revises: 20260804_10
"""

from alembic import op
import sqlalchemy as sa


revision = "20260804_11"
down_revision = "20260804_10"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "sync_batches",
        sa.Column("batch_id", sa.String(36), primary_key=True),
        sa.Column("user_id", sa.String(45), sa.ForeignKey("users.user_id"), nullable=False),
        sa.Column("payload_hash", sa.String(64), nullable=False),
        sa.Column("status", sa.String(16), nullable=False),
        sa.Column("operation_count", sa.Integer(), nullable=False),
        sa.Column("attempt_count", sa.Integer(), nullable=False, server_default="1"),
        sa.Column("result_payload", sa.JSON()),
        sa.Column("error_code", sa.String(64)),
        sa.Column("created_at", sa.DateTime(), nullable=False, server_default=sa.text("CURRENT_TIMESTAMP")),
        sa.Column("updated_at", sa.DateTime(), nullable=False, server_default=sa.text("CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP")),
        sa.Column("committed_at", sa.DateTime()),
        sa.Column("expires_at", sa.DateTime(), nullable=False),
        mysql_charset="utf8mb4",
        mysql_collate="utf8mb4_0900_ai_ci",
    )
    op.create_index("ix_sync_batches_user_created", "sync_batches", ["user_id", "created_at"])
    op.create_index("ix_sync_batches_status_expires", "sync_batches", ["status", "expires_at"])


def downgrade() -> None:
    op.drop_table("sync_batches")
