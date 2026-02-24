-- SilentPulse: PostgreSQL extensions (superuser-level)
-- These run via docker-entrypoint-initdb.d before the application starts.
-- The application's golang-migrate handles all schema creation.

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";
CREATE EXTENSION IF NOT EXISTS "age";
