"""schema inicial do flag-service (portado de db/init.sql)

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
        CREATE TABLE IF NOT EXISTS flags (
            id SERIAL PRIMARY KEY,
            name VARCHAR(100) UNIQUE NOT NULL,
            description TEXT,
            is_enabled BOOLEAN NOT NULL DEFAULT false,
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
    op.execute("DROP TRIGGER IF EXISTS set_timestamp ON flags;")
    op.execute(
        """
        CREATE TRIGGER set_timestamp
        BEFORE UPDATE ON flags
        FOR EACH ROW
        EXECUTE PROCEDURE trigger_set_timestamp();
        """
    )


def downgrade() -> None:
    op.execute("DROP TRIGGER IF EXISTS set_timestamp ON flags;")
    op.execute("DROP TABLE IF EXISTS flags;")
    # trigger_set_timestamp() e compartilhada com outros services no mesmo banco
    # apenas se colocados juntos; aqui cada service tem seu proprio DB, entao
    # remover a funcao e seguro no downgrade.
    op.execute("DROP FUNCTION IF EXISTS trigger_set_timestamp();")
