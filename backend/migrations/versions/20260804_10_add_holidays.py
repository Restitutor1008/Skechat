"""Add centrally managed holiday reference data.

Revision ID: 20260804_10
Revises: 20260803_09
"""

from alembic import op
import sqlalchemy as sa


revision = "20260804_10"
down_revision = "20260803_09"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "holidays",
        sa.Column("country_code", sa.String(2), nullable=False),
        sa.Column("holiday_date", sa.Date(), nullable=False),
        sa.Column("name", sa.String(120), nullable=False),
        sa.Column("description_ko", sa.String(255)),
        sa.Column("description_en", sa.String(255)),
        sa.Column("category", sa.String(20), nullable=False, server_default="NATIONAL"),
        sa.Column("is_substitute", sa.Boolean(), nullable=False, server_default=sa.text("0")),
        sa.Column("source", sa.String(64), nullable=False),
        sa.Column("is_obsolete", sa.Boolean(), nullable=False, server_default=sa.text("0")),
        sa.Column("created_at", sa.DateTime(), nullable=False, server_default=sa.text("CURRENT_TIMESTAMP")),
        sa.Column("updated_at", sa.DateTime(), nullable=False, server_default=sa.text("CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP")),
        sa.PrimaryKeyConstraint("country_code", "holiday_date"),
        mysql_charset="utf8mb4",
        mysql_collate="utf8mb4_0900_ai_ci",
    )
    op.create_index(
        "ix_holidays_country_updated",
        "holidays",
        ["country_code", "updated_at"],
    )
    op.create_index(
        "ix_holidays_country_obsolete_date",
        "holidays",
        ["country_code", "is_obsolete", "holiday_date"],
    )


def downgrade() -> None:
    op.drop_table("holidays")
