# OpenOSP Backup Process (`bin/openosp-backup.sh`)

This document explains what the backup script does, step by step, and then reviews its risks, likely errors and gaps, with suggested fixes.

> The script header says: **do not run this script during production hours.** Every run (except `--hdc`) stops Expedius and restarts OSCAR.

---

## Part 1: How the process works

### 1.1 How it is invoked

The script is normally called through the `openosp` wrapper:

```
./openosp backup -m --s3            # database + documents to Amazon S3
./openosp backup -m --efs           # database + documents to /srv/efs (local or network file storage)
./openosp backup -m --archive-logs  # archive and trim the OSCAR audit "log" table
./openosp backup -m --hdc           # encrypted clinical data extract for HDC (BC Health Data Coalition)
./openosp backup                    # (no -m) starts the "backups" container via bin/run-auto-backups.sh instead
```

Before calling the script, the wrapper:
- loads every variable in `local.env` and exports it (`set -a; source local.env`), and
- passes only **two** arguments on (`"$2" "$3"`). With `-m` in the first slot, there is room for **only one** mode flag per run.

The script must be run from the root of the clinic's OpenOSP directory. It uses relative paths (`./volumes`, `./dump`, `bin/archive-logs.sql`) and takes the clinic's identity from the name of that directory.

### 1.2 Configuration

| Variable | Source | Default | Purpose |
|---|---|---|---|
| `site` | the current directory's name | n/a | Clinic identifier |
| `clinicname` | derived | `openosp-<site>` | Top-level folder in S3/EFS |
| `filename` | derived | `<site>.YYYYMMDD-HHMMSS` | Name of the database dump |
| `folder` | derived | `YYYYMM` | Monthly sub-folder for dumps |
| `BACKUP_BUCKET` | `local.env` | `backups` (with a warning) | S3 bucket name |
| `BACKUP_DB_USER` | `local.env` | `root` | Database user for all dumps (main, HDC, log archive) |
| `BACKUP_DB_PASSWORD` | `local.env`, read **inside the db container** | none | Password for `BACKUP_DB_USER` when it is not `root` |
| `MYSQL_ROOT_PASSWORD` | `local.env`, read **inside the db container** | none | Used for `root` dumps and always for the log `DELETE` |
| `BACKUP_CMD` | env | not set | Optional legacy custom dump command, run with `sh -c` inside the `db` container |
| `BACKUP_MIN_BYTES` | env | `10240` | Smallest dump size accepted as a successful backup |
| `BACKUP_MIN_FREE_MB` | env | `2048` | Disk space that must stay free after a dump is written |
| `BACKUP_HEALTHCHECK_URL` | env | not set | URL pinged after the backup modes (`<url>/fail` on failure) |
| `HDC_HEALTHCHECK_URL` | env | not set | Same as above, for `--hdc` runs |
| `DUMP_LOCATION` | env | `./dump` | Where the dump is staged on disk |
| `BACKUP_EFS_ROOT` | env | `/srv/efs` | Target for `--efs` |
| `BACKUP_EFS_REQUIRE_MOUNT` | env | `1` | Set to `0` to allow `BACKUP_EFS_ROOT` to be a plain directory instead of a mount point |
| `~/.aws/credentials` | file | required for `--s3`/`--hdc` | AWS credentials, mounted into the `amazon/aws-cli` container |

#### Setting up a dedicated backup user (recommended)

By default the dumps run as `root`. To use a least-privilege user instead, first create it in the database:

```sql
CREATE USER 'backup'@'localhost' IDENTIFIED BY '<strong password>';
GRANT SELECT, LOCK TABLES, SHOW VIEW, TRIGGER, EVENT ON oscar.* TO 'backup'@'localhost';
GRANT SELECT ON mysql.proc TO 'backup'@'localhost';   -- needed to dump stored routines
```

Then add `BACKUP_DB_USER=backup` and `BACKUP_DB_PASSWORD=<password>` to `local.env`, and recreate the db container (`docker compose up -d db`) so the container can see the new password. If it can't see the password, the dump stops with a clear error; it does not fall back to `root`.

### 1.3 Error handling and helper functions

- The script runs with `set -Eeuo pipefail`. Any unhandled failing command, any unset variable, and any failed command inside a pipeline (for example `mysqldump | gzip`) stops the script. An `ERR` trap logs the line and the command that failed.
- Steps that should not block the others, such as the S3 upload and the volume sync, are recorded with **`fail`** and the script carries on. The final exit code is non-zero if any step failed.
- **`on_exit`** (the `EXIT` trap) runs on every exit. It restarts OSCAR and starts Expedius if they were stopped, logs `<mode> complete` or `ERROR: <mode> … failed`, and pings the healthcheck URL if one is configured.
- **`db_exec <user> <program> …`** runs `mysqldump` or `mysql` inside the db container. The password comes from the container's own environment (`MYSQL_ROOT_PASSWORD` or `BACKUP_DB_PASSWORD`) and is passed to the client through `MYSQL_PWD`, so it never appears on a command line.
- **`dump_db`** produces the main dump with `mysqldump --single-transaction --quick --no-tablespaces --routines --events --triggers oscar`, or runs the custom `BACKUP_CMD` if one is set.
- **`verify_dump <file> <min bytes>`** accepts a dump only if three checks pass: the file is at least the minimum size, it passes `gzip -t` (for `.gz` files), and its last line is mysqldump's `-- Dump completed` line, which mysqldump writes only when it finishes successfully.
- **`require_space <dir> <bytes> <label>`** runs before any file is written. It exits the script if writing an estimated `<bytes>` would leave less than `BACKUP_MIN_FREE_MB` (default 2048 MB) free on that disk. The reserve protects MySQL and the OS, because dumps are usually written to the same disk the database runs on. The estimates are:
  - **Database dump (gzipped):** 1.5 × the size of the last successful dump, recorded in `<DUMP_LOCATION>/.last-dump-bytes`. On the first run, a quarter of the database's uncompressed data size (from `information_schema`), since SQL dumps usually compress 5–10×. Any space used by a `db.sql.gz` left over from a failed run is subtracted, because that file gets overwritten.
  - **HDC export:** 2 × the data size of the 26 exported tables, because the plain-text file and its encrypted copy exist together for a moment.
  - **Log archive:** the data size of the `log` table.
  - **EFS copy:** the size of the dump, checked on the target, but only when the target is on a different file system (moving the file within one file system needs no extra space).
  - If no estimate is possible (for example, the size query fails), only the reserve is checked and a warning is logged.
- **`log`** and **`validate_aws`** work as before: timestamped logging, and checking for AWS credentials and setting up the `amazon/aws-cli` command (`$aws`).

### 1.4 Mode: `--hdc` (HDC export)

This mode runs on its own and exits before any of the other steps.

1. Checks the AWS credentials.
2. Checks the free disk space, then dumps 26 clinical tables with `--single-transaction --quick --skip-triggers` to `hdc-<filename>.sql`, using the same database user as the backups. The dump is then verified. On failure the partial file is deleted and the script exits 1.
3. Encrypts the dump with GPG for `pki-prod@hdcbc.ca` (`--trust-model always`; the key is checked by hand). If encryption fails, both files are deleted and the script exits 1. On success, the plain-text file is deleted straight away.
4. Uploads the `.gpg` file to `s3://openosp-hdc-transit/openosp-<site>/<YYYYMM>/` with the `aws` CLI installed on the host.
5. If the upload succeeds, deletes the `.gpg` file and exits 0. If it fails, keeps the `.gpg` file for a retry, logs its path and exits 1.

### 1.5 Common steps for all other modes

1. Runs `docker compose stop expedius`, so Expedius (lab results) does not time out against OSCAR during the backup. From this point, `on_exit` restarts OSCAR and starts Expedius whenever the script ends.
2. Fills in the defaults for `BACKUP_BUCKET` and `DUMP_LOCATION`, logs the dump command that will be used, and creates the dump directory.

### 1.6 Mode: `--s3` (off-site backup to Amazon S3)

1. Checks the AWS credentials and sets up the AWS CLI command.
2. Checks the free disk space, dumps the database, gzips it to `<DUMP_LOCATION>/db.sql.gz` and verifies it. The script exits 1 if the dump or the verification fails.
3. Removes any double quotes from `BACKUP_BUCKET`.
4. **Uploads the database first**, because it is the most important part of the backup: `aws s3 mv` to `s3://<bucket>/openosp-<site>/<YYYYMM>/<site>.<timestamp>.sql.gz`. A failure is recorded and the script carries on.
5. **Syncs documents:** runs `aws s3 sync` from `./volumes` to `s3://<bucket>/openosp-<site>/volumes` (`STANDARD_IA`, skipping `.sync/*`) in the `amazon/aws-cli` container. Exit code 2 (some files skipped) and any other non-zero code are recorded as failures.
6. Logs `Amazon S3 export successful` only if both steps succeeded.

### 1.7 Mode: `--efs` (backup to file storage)

1. Checks that `BACKUP_EFS_ROOT` (default `/srv/efs`) is a mount point, and exits 1 if it is not. This stops the backup from quietly filling the local disk.
2. Checks the free disk space, then dumps, gzips and verifies the database, as in the S3 mode. If the target is on a different file system, also checks that the target has room for the dump.
3. Creates `<root>/openosp-<site>/volumes` and `<root>/openosp-<site>/<YYYYMM>/`.
4. Moves the dump to `<root>/openosp-<site>/<YYYYMM>/<filename>.sql.gz`, then runs `rsync -a ./volumes/ <root>/openosp-<site>/volumes/`. A failure in either step is recorded.

### 1.8 Mode: `--archive-logs` (trim the audit log)

1. Checks the free disk space, then dumps the OSCAR `log` table (the audit trail) to `log_archive_DD-MM-YY.sql` with `--single-transaction --quick`, then checks that the dump completed.
2. **If the export or the check fails:** deletes the partial file, records the failure, and does **not** delete any log rows.
3. Otherwise, moves the archive into `volumes/OscarDocument/oscar/` (so the next S3 or EFS run backs it up), then runs `bin/archive-logs.sql` **as root**, which deletes rows older than 3 months.

### 1.9 End of run

`on_exit` restarts OSCAR and starts Expedius, then logs `backup complete` or an error with the exit code. If `BACKUP_HEALTHCHECK_URL` / `HDC_HEALTHCHECK_URL` is set, it pings `<url>` on success or `<url>/fail` on failure. The script exits non-zero if anything failed, so cron or Jenkins can see the failure.

### 1.10 Flow diagram

```
openosp backup -m <flag>
        │
        ├── --hdc ──► dump 26 tables ─► verify ─► GPG encrypt ─► delete plain text ─► S3 (hdc-transit) ─► delete .gpg ─► exit
        │
        ├── stop expedius (on_exit will restart oscar + start expedius)
        ├── apply defaults, mkdir dump dir
        │
        ├── --s3 ───► mysqldump | gzip ─► verify ─► s3 mv dump ─► s3 sync volumes
        ├── --efs ──► mount check ─► mysqldump | gzip ─► verify ─► mv dump ─► rsync volumes
        ├── --archive-logs ─► dump log table ─► verify ─► move into volumes ─► DELETE rows > 3 months (as root)
        │
        └── on_exit: restart services ─► log result ─► ping healthcheck ─► exit code (non-zero on any failure)
```

---

## Part 2: Risks, errors and oversights

> **Status:** improvements 1, 2 and 5 from Part 3 have been applied to the script. Line numbers below refer to the script as it was before those changes.

Severity: 🔴 critical (backups may be silently missing or data lost) · 🟠 high · 🟡 medium · ⚪ low/cosmetic.

### 2.1 Defects that can make backups silently empty or missing

**🔴 1. The default database dump command most likely never runs (lines 147, 174).** **✅ Fixed**
`docker compose exec -T db "$BACKUP_CMD"` passes the whole command line as **one** quoted word. Docker then looks for a program literally named `mysqldump -u root -p… oscar`, which does not exist, so the command fails. The quotes were added in commit `1305a31` ("code cleanup"). The earlier unquoted `$BACKUP_CMD` worked because the shell split it into separate words.
*Fix:* store the command as an array (`BACKUP_CMD=(mysqldump -uroot oscar)` and run `"${BACKUP_CMD[@]}"`), or run it through a shell: `docker compose exec -T db sh -c "$BACKUP_CMD"`.

**🔴 2. The `gzip -t` check cannot catch a failed dump.** **✅ Fixed**
When the dump writes nothing, gzip still produces a valid 20-byte archive, and `gzip -t` passes. I confirmed this locally. The script also lacks `set -o pipefail`, so the failure of `mysqldump` in `mysqldump | gzip` is lost. Together with item 1, the script can log "Gzip successful" and "Amazon S3 export successful" while uploading an empty backup every night.
*Fix:* turn on `set -o pipefail` and check the exit status of the dump. Also check that the file has a sensible minimum size, and that the uncompressed dump ends with mysqldump's `-- Dump completed` line:
`zcat db.sql.gz | tail -1 | grep -q 'Dump completed'`.

**🔴 3. HDC: the success check tests the wrong command (lines 100–103).** **✅ Fixed**
`$?` holds the result of `rm`, not of `aws s3 cp`. So the HDC run always logs success and exits 0, even when the upload failed, and the encrypted file has already been deleted. A failed export cannot be noticed or retried.
*Fix:* save `$?` straight after `aws s3 cp` (or use `if aws s3 cp …; then`), and delete local files only after a successful upload.

**🟠 4. S3: a failed document sync is ignored (line 160).** **✅ Fixed**
Only the final `s3 mv` is checked. If the volumes sync fails (credentials, network, permissions), the run still reports success.
*Fix:* check the sync's exit status. Note that `aws s3 sync` returns 2 when some files were skipped and 1 on errors.

**🟠 5. EFS: nothing is checked (lines 186–191).** **✅ Fixed**
The script ignores the results of `rsync`, `mkdir` and `mv`. It also never checks that `/srv/efs` is mounted. If the network share is missing, the backup quietly fills the local disk under `/srv/efs`. That is not off-server storage, and it can stop production when the disk fills up.
*Fix:* add `mountpoint -q /srv/efs || exit 1` and check each step.

**🟠 6. The script almost never exits with a failure code.** **✅ Fixed**
It does not use `set -e`; the `set -e` in the `openosp` wrapper does not carry over to child scripts. It ends with "backup complete" whatever happened, and it raises no alerts. Cron or Jenkins will report most failures as success.
*Fix:* use `set -Eeuo pipefail` with an `ERR` trap, keep a non-zero exit status for any failure, and send a heartbeat or alert to monitoring (healthchecks.io, CloudWatch, email).

**🟠 7. Archive-logs deletes audit rows without checking the export (lines 199–202).** **🟡 Partly fixed: rows are deleted only after a verified export. Batched deletes and compression are still open.**
The `DELETE` runs whether or not `mysqldump` succeeded. Under the default settings the dump may well be empty (see items 1 and 2; this step uses its own unquoted command, but nothing is checked). The OSCAR `log` table is the access audit trail for patient records, which you may be required to keep. An export of the same name on the same day overwrites the earlier one.
*Fix:* check the export (exit status, `Dump completed` line, row count), compress it, and include the time in its name. Delete in batches (`DELETE … LIMIT 10000` in a loop) so one long-running statement does not lock the table and flood the binlog.

### 2.2 Operational and availability risks

**🟠 8. OSCAR is restarted on every run, including failed and no-op runs.**
The trap restarts OSCAR even when no mode flag was given (`./openosp backup -m`), when `--archive-logs` was the only step, and when the script exits early. That means user-visible downtime and dropped sessions. A run triggered by mistake during clinic hours takes the EMR offline.
*Fix:* exit early if no mode flag is given. Restart OSCAR only if a step actually needs it, and consider whether a restart is needed at all. Stopping Expedius is enough to avoid the timeouts the comment describes.

**🟠 9. `mysqldump` locks tables and is not throttled.** **🟡 Partly fixed: the dumps use `--single-transaction --quick`. The dump is still not throttled, and MyISAM tables are not locked during it.**
The default `mysqldump` uses `--lock-tables`. That blocks writes for the whole dump and gives no consistent snapshot across tables. The HDC dump has the same problem. The dump, usually the heaviest disk read of the whole backup, also runs at full speed. The separate I/O-throttling work on the `speed-improvements-aws-s3` branch limits only the S3 volume sync.
*Fix:* for InnoDB tables use `--single-transaction --quick --routines --events --triggers`. Consider running the dump against a replica.

**🟡 10. Only one mode per run, and fragile flag parsing.**
The wrapper passes only `$2 $3`, so `backup -m --s3 --archive-logs` silently drops `--archive-logs`. The checks `[[ $* == *--s3* ]]` match substrings, so `--s3x` or `--efs-test` would also trigger a mode. Unknown flags are ignored without a message.
*Fix:* parse the flags with `case`/`getopts`, reject unknown ones, and pass `"${@:2}"` from the wrapper.

**🟡 11. No lock against runs that overlap.**
Two runs at once (cron plus a manual run, or a long sync) write to the same `db.sql.gz` and restart OSCAR in the middle of each other's backup.
*Fix:* wrap the script in `flock -n /var/lock/openosp-backup.lock`.

**🟡 12. No disk space check.** **✅ Fixed**
The dump is staged on the same server before upload. A large database can fill the disk that MySQL is running on.
*Fix:* check free space against the size of the last dump before starting, or stream the dump straight to S3 (`… | gzip | aws s3 cp - s3://…`).

**🟡 13. The clinic's identity comes from the directory name.**
`site` is the name of the current directory. If cron runs the script from another directory, or the checkout is renamed, backups go to a different S3 or EFS prefix without warning, and a later restore may look in the wrong place. The README documents a `CLINIC_NAME` variable that the script never reads.
*Fix:* use `CLINIC_NAME` when it is set, and `cd` to the script's own directory (`cd "$(dirname "$0")/.."`).

**🟡 14. Absolute `DUMP_LOCATION` breaks the S3 upload.**
`$aws` mounts only `$(pwd)` at `/open-osp`, so `/open-osp/$DUMP_LOCATION` works only if the path is relative. `dc.prod.yml` sets `DUMP_LOCATION=/dump` for the backups container. That becomes `/open-osp//dump`, which points at the wrong place unless the working directory happens to be `/`.
*Fix:* mount `$DUMP_LOCATION` into the container directly (`-v "$DUMP_LOCATION":/dump`) and reference `/dump/db.sql.gz`.

**⚪ 15. `docker run -t` under cron.**
Allocating a TTY when no terminal is attached adds carriage returns to the logs. Remove `-t`.

**⚪ 16. The `amazon/aws-cli` image is not pinned.**
Each run can pull a new `latest` image, which is a supply-chain risk and can break things. Pin a version or digest.

### 2.3 Security and privacy (health data)

**🟠 17. Database passwords appear on command lines.** **✅ Fixed**
`-p${MYSQL_ROOT_PASSWORD}` can be seen in `ps` on the host and in the container, can end up in shell history, and makes mysqldump print a warning. The backup also runs as `root`.
*Fix:* use a dedicated read-only backup user with `SELECT, LOCK TABLES, SHOW VIEW, TRIGGER, EVENT`. Pass the credentials through `MYSQL_PWD` or a `--defaults-extra-file` inside the container.

**🟠 18. HDC uses `MYSQL_PASSWORD` with `-uroot`; everything else uses `MYSQL_ROOT_PASSWORD`.** **✅ Fixed**
This is probably a mistake. The HDC export fails unless both variables happen to hold the same value, and item 3 hides that failure.

**🟠 19. Plain-text patient data can be left on disk.**
The HDC export writes an unencrypted clinical extract to the working directory. If `gpg` or the upload fails, or the script is interrupted, that file stays there, readable by anyone the default umask allows. The local `db.sql.gz` and the log archives are also unencrypted.
*Fix:* `umask 077`, a cleanup trap for temporary files, and a `mktemp` directory. Better still, pipe the dump straight into `gpg` so no plain-text file is ever written.

**🟠 20. Off-site backups depend only on S3's default protection.**
The script does not request encryption (`--sse aws:kms`), and it does not depend on bucket versioning or Object Lock. Because `s3 sync` overwrites changed files, corrupted or ransomware-encrypted documents replace the good copies in S3 on the next run. The same IAM key can typically delete the backups too.
*Fix:* turn on bucket versioning and S3 Object Lock (compliance mode), require SSE-KMS through bucket policy, give the backup IAM user put-only permissions (no delete), and consider client-side encryption.

**🟡 21. `--trust-model always` for GPG.**
This is acceptable because the key is checked by hand. However, the script does not notice if the key expires or is revoked.
*Fix:* check the key's fingerprint and expiry before encrypting.

### 2.4 Retention, recovery and consistency

**🟠 22. No retention policy, and documents have only one version.**
Database dumps pile up in monthly folders forever, with no lifecycle rule in the script. Documents, on the other hand, exist as a single latest copy, with no point-in-time history unless bucket versioning is on. On EFS, nothing is ever pruned.
*Fix:* add S3 lifecycle rules (for example daily for 35 days, monthly for 7 years, then Glacier) that match the clinic's record-keeping obligations.

**🟠 23. No restore testing or restore documentation.**
Nothing checks that a backup can actually be restored. Items 1 and 2 show how a broken backup can go unnoticed for months.
*Fix:* restore the latest dump into a temporary MySQL container on a schedule, check row counts on key tables, and write a restore runbook.

**🟡 24. The database and the documents come from different moments.**
The volumes are synced after the dump, while OSCAR is still accepting changes. Documents and the database rows that point to them can disagree after a restore. This is usually acceptable, but it should be stated in the restore runbook.

**🟡 25. The `DELETE` in `archive-logs.sql` is the only copy of its retention rule.**
The 3-month window is hard-coded in the SQL file. Make it configurable and document it alongside the audit-retention policy.

---

## Part 3: Suggested improvements, in priority order

1. ✅ **Fix the dump command** (item 1) and add `set -Eeuo pipefail` plus real dump checks: exit status, minimum size and the `Dump completed` line (item 2). Do this first, then check the last few S3 uploads to see whether recent backups are empty.
2. ✅ **Fix the exit-status checks** in the HDC, S3-sync and EFS paths (items 3–5), and make the script exit non-zero and send an alert on any failure (item 6).
3. **Protect the audit log:** delete rows only after a verified export (item 7).
4. **Harden S3:** versioning, Object Lock, SSE-KMS, least-privilege IAM, lifecycle rules (items 20 and 22).
5. ✅ **Make the dump consistent and lock-free** with `--single-transaction --quick`, a dedicated backup user and no passwords on the command line (items 9, 17 and 18).
6. **Avoid unnecessary downtime:** no OSCAR restart unless needed, and exit early when no mode flag is given (item 8).
7. **Make it robust to run unattended:** `flock`, ✅ a disk space check (done), a fixed working directory, `CLINIC_NAME`, proper flag parsing, a pinned image and no `-t` (items 10–16).
8. **Clean up plain-text files** with `umask 077` and a cleanup trap, and stream data to `gpg` or S3 where possible (item 19).
9. **Test restores** automatically and document the restore procedure (item 23).
