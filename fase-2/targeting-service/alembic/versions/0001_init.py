"""schema inicial do targeting-service (portado de db/init.sql)

Revision ID: 0001_init
Revises:
Create Date: 2026-09-06
"""
from alembic import op

revision = "0001_init"
down_revision = None
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.execute(
        """
        CREATE TABLE IF NOT EXISTS targeting_rules (
            id SERIAL PRIMARY KEY,
            flag_name VARCHAR(100) UNIQUE NOT NULL,
            is_enabled BOOLEAN NOT NULL DEFAULT true,
            rules JSONB NOT NULL,
            created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
            updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
        );
        """
    )
    op.execute(
        """
        CREATE OR REPLACE FUNCTION trigger_set_timestamp()
        RETURNS TRIGGER AS $$
        BEGIN
          NEW.updated_at = NOW();
          RETURN NEW;
        END;
        $$ LANGUAGE plpgsql;
        """
    )
    op.execute("DROP TRIGGER IF EXISTS set_timestamp ON targeting_rules;")
    op.execute(
        """
        CREATE TRIGGER set_timestamp
        BEFORE UPDATE ON targeting_rules
        FOR EACH ROW
        EXECUTE PROCEDURE trigger_set_timestamp();
        """
    )


def downgrade() -> None:
    op.execute("DROP TRIGGER IF EXISTS set_timestamp ON targeting_rules;")
    op.execute("DROP TABLE IF EXISTS targeting_rules;")
    op.execute("DROP FUNCTION IF EXISTS trigger_set_timestamp();")
