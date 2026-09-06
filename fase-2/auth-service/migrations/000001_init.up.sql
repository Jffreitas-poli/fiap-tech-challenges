-- auth-service :: schema inicial (portado de db/init.sql)
CREATE TABLE IF NOT EXISTS api_keys (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    -- key_hash armazena o hash SHA-256 da chave (64 hex chars)
    key_hash VARCHAR(64) NOT NULL UNIQUE,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);
