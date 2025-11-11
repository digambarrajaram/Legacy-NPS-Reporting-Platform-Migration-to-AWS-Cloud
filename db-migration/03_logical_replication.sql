-- 03_logical_replication.sql
-- 1) On the SOURCE DB: create a publication for the tables you want to replicate
-- Connect to source with a superuser or table owner:
-- psql -h SOURCE_HOST -U postgres -d yourdb -f 03_logical_replication.sql

-- Example: publish all tables in public schema
CREATE PUBLICATION nps_migration_pub FOR ALL TABLES;

-- Or publish specific tables:
-- CREATE PUBLICATION nps_migration_pub FOR TABLE public.report_master, public.report_details;

-- 2) On the TARGET DB: create a subscription to the source publication
-- NOTE: run the following on the TARGET DB (RDS/Aurora). You must be able to connect from target to source (network & pg_hba).
-- Example psql command (run from the target or from bastion with psql pointed to target):
--
-- psql -h TARGET_HOST -U postgres -d yourdb
-- Then run:
--
-- CREATE SUBSCRIPTION nps_migration_sub
-- CONNECTION 'host=SOURCE_HOST port=5432 dbname=SOURCE_DB user=migrator_replication password=CHANGE_ME_STRONG_PASSWORD'
-- PUBLICATION nps_migration_pub
-- WITH (copy_data = true);  -- copy_data = true performs initial data copy from source
--
-- If network connectivity from TARGET -> SOURCE is not allowed, you can create an empty subscription (copy_data = false)
-- and restore a logical dump on the target first (see 02_snapshot.sh onprem).
