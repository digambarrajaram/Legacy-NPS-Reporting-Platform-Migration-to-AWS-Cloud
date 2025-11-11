# DB Migration: logical-replication-based workflow

This directory contains scripts and SQL to prepare the source DB, take a snapshot, enable logical replication, and perform cutover checks.

Files:
- 01_prepare_source.sql    -- SQL run on SOURCE to enable logical replication and create replication user
- 02_snapshot.sh           -- helper script to create snapshot (onprem or RDS)
- 03_logical_replication.sql -- publication/subscription examples
- 04_cutover_check.sql     -- checks to validate replication and parity
- README.md                -- this file

## Assumptions & prerequisites
- Source DB is PostgreSQL (version >= 10 recommended for logical replication features).
- You have superuser access (or equivalent) on source and target.
- Network connectivity from TARGET -> SOURCE for logical replication (psql connection).
- If source is RDS, configure parameter group to `wal_level = logical`, increase `max_wal_senders` and `max_replication_slots`.
- The migration user created must be secure and rotated after migration.
- Backup everything and test in dev/stage before production cutover.

## High-level recommended workflow
1. **Prepare source**
    - Apply `01_prepare_source.sql` on the SOURCE DB (or perform equivalent parameter changes in RDS parameter group + run the SQL to create the replication user).
    - Ensure `pg_hba.conf` permits a connection from the TARGET (or use VPN/peering). For RDS, ensure security groups allow inbound from target.

2. **Initial snapshot**
    - For small DBs: use `02_snapshot.sh onprem` (pg_dump) or `02_snapshot.sh rds` (AWS snapshot).
    - For large DBs: use `pg_basebackup` + WAL shipping, or create an RDS snapshot and restore in target region.

3. **Restore snapshot on TARGET**
    - If you used `pg_dump`, restore into target DB (`pg_restore` or `psql`).
    - If you used binary base backup, follow basebackup restore steps.

4. **Create publication on SOURCE**
    - Run `03_logical_replication.sql` (publication part) on SOURCE to create `nps_migration_pub`.

5. **Create subscription on TARGET**
    - Run the `CREATE SUBSCRIPTION` command on the TARGET (see `03_logical_replication.sql` comments).
    - Use `copy_data = false` if you pre-loaded data manually; otherwise `copy_data = true` to copy data.

6. **Monitor replication**
    - Use queries from `04_cutover_check.sql` to monitor `pg_stat_subscription`, confirm received WAL, and check per-table row counts.

7. **Dry-run cutover**
    - Perform a dry-run cutover in staging: put app in read-only, wait for subscription to catch up, validate counts/hashes, promote and switch DNS.

8. **Final cutover (production)**
    - Put source app into maintenance/read-only mode.
    - Wait for subscription to have applied all changes (lag ~ 0).
    - Repoint app to TARGET (update DNS/connection string), perform smoke tests.
    - If required, run post-cutover DB tuning (VACUUM/ANALYZE), and rotate credentials.

## Rollback & safety
- Keep the source available until you are 100% confident the target works.
- Use DNS TTLs and a rollback plan to revert quickly to source if needed.
- Keep snapshots/backups (created in step 2) until cutover is fully validated.
- Document and store migration logs and timing for audits.

## Useful commands
- Check subscription status on target:
  ```sql
  SELECT * FROM pg_stat_subscription;
