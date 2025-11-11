-- 04_cutover_check.sql
-- Run on SOURCE and TARGET (modify connection/psql as needed)
-- 1) Replication status (on SOURCE)
-- Check WAL replication slots and streaming status (source)
SELECT pid, usename, application_name, client_addr, state, sync_state, backend_start, sent_lsn, write_lsn, flush_lsn, replay_lsn
FROM pg_stat_replication;

-- For logical replication slots:
SELECT slot_name, plugin, active, restart_lsn, confirmed_flush_lsn
FROM pg_replication_slots WHERE slot_type = 'logical';

-- 2) Subscription status (on TARGET)
-- Run on target DB:
SELECT subname, pid, relid, received_lsn, last_msg_send_time, last_msg_receipt_time, latest_end_lsn
FROM pg_stat_subscription;

-- 3) Per-table row count comparison (generate per-table checks)
-- Replace 'public' with schema and list tables manually or script it

-- Example script to generate a quick parity check (run in psql, returns counts from this DB)
-- On SOURCE run:
\set schema 'public'
\copy (SELECT table_name FROM information_schema.tables WHERE table_schema = :'schema' AND table_type='BASE TABLE') TO '/tmp/source_tables.txt' WITH CSV

-- Alternatively, run per table:
-- On SOURCE:
SELECT 'source' AS side, table_name, (xpath('/row/cnt/text()', query_to_xml(format('SELECT count(*) AS cnt FROM %I.%I', table_schema, table_name), false, true, '')))[1]::text::bigint AS row_count
FROM information_schema.tables
WHERE table_schema='public' AND table_type='BASE TABLE';

-- Simpler: manually compare counts for important tables:
-- On SOURCE:
SELECT COUNT(*) FROM public.report_master;
SELECT COUNT(*) FROM public.report_details;
-- On TARGET:
-- Connect to target DB and run same counts:
-- SELECT COUNT(*) FROM public.report_master;
-- SELECT COUNT(*) FROM public.report_details;

-- 4) Check for replication lag in bytes/time (logical sometimes has no straightforward 'lag' metric, but we can compare last message times)
-- On TARGET:
SELECT subname, pid, received_lsn, last_msg_send_time, last_msg_receipt_time,
       EXTRACT(EPOCH FROM (now() - last_msg_receipt_time)) AS seconds_behind
FROM pg_stat_subscription;

-- 5) Final cutover checklist (manual steps)
-- - Stop writes to source application (put into maintenance mode)
-- - Wait for pg_stat_subscription on target to show no significant lag (seconds_behind ~ 0)
-- - Run final per-table checksum or counts:
--    - SELECT COUNT(*) FROM ...
--    - SELECT md5(array_agg(md5(col1||'|'||col2))::text) FROM table;  -- be careful with huge tables
-- - Promote target if using replication requiring promotion (for some setups)
-- - Re-point application / DNS to target
-- - Monitor for errors, run ANALYZE on target tables after large imports
