-- 01_prepare_source.sql
-- Run this as a postgres superuser on the SOURCE DB (on-prem or via psql to the host).
-- If using RDS, set wal_level and max_wal_senders in the DB parameter group (not here).

-- 1) Check current settings (informational)
SHOW wal_level;
SHOW max_wal_senders;
SHOW max_replication_slots;

-- 2) If running on-prem and wal_level isn't 'logical', update postgresql.conf:
-- Edit postgresql.conf:
-- wal_level = logical
-- max_wal_senders = 10        -- adjust based on concurrent subscribers
-- max_replication_slots = 10  -- adjust based on needs
-- Then reload/restart: SELECT pg_reload_conf();

-- 3) Create a replication user (replace password, follow your secret process)
CREATE ROLE migrator_replication WITH REPLICATION LOGIN PASSWORD 'CHANGE_ME_STRONG_PASSWORD';

-- 4) Grant minimal needed privileges for publication tables (owner or explicit grants may be needed)
-- Example: if migrating specific schema(s), ensure user can read tables:
GRANT SELECT ON ALL TABLES IN SCHEMA public TO migrator_replication;
-- Consider adding default privileges:
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO migrator_replication;

-- 5) Optional: create a dedicated schema to group migration-related objects (audit)
CREATE SCHEMA IF NOT EXISTS migration_audit;
