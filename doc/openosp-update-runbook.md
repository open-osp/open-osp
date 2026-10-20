# Runbook: Updating an Existing Open OSP Deployment

**Verified end-to-end:** 2026-09-08 on a local Ubuntu host, Docker 29 / Compose v5,
Open OSP master, Open-O `main`. Covers: updating prebuilt images, rebuilding
OpenOscar (and other components) from source, applying time zone data updates,
rolling out safely, verifying health, and rolling back.

Companion doc: [`timezone-update-runbook.md`](timezone-update-runbook.md) —
the tzdata procedure in isolation, with full verification commands.

---

## 0. Scope & assumptions

* Existing deploy at `~/open-osp` with `local.env` and `volumes/` already set up
  (`./openosp setup` has been run). For fresh-install pitfalls, see Appendix A.
* Stack = 4 services from `docker-compose.yml`: `db` (mariadb:10.5),
  `oscar` (openosp/open-osp), `expedius`, `faxws`.
* `./openosp start` uses `docker compose --compatibility` (container names like
  `open-osp_oscar_1`); plain `docker compose` uses dashes (`open-osp-oscar-1`).
  Mixing them forces container recreates — pick one per operation and be
  consistent.

## 1. Pre-flight (15 min)

### 1.1 Baseline health

```bash
cd ~/open-osp
docker compose ps
docker inspect $(docker compose ps -q) --format '{{.Name}} restarts={{.RestartCount}} {{.State.Status}}'

# built-in health suite (needs --no-TTY outside an interactive terminal)
docker compose -f docker-compose.admin.yml run --no-TTY --rm health
# expected: 4x CORRECT (faxws TLS probe=404, expedius=200, drugref2=200, oscar LoginService=500)
```

### 1.2 Baseline time zone probes (if a tz change is in scope)

```bash
# JVM tzdb version
docker compose exec oscar sh -c 'grep -a -m1 -o "20[0-9][0-9][a-z]" /opt/java/openjdk/lib/tzdb.dat'
# OS behaviour on a post-change date (BC change example: Dec 15 2026 must be -0700)
docker compose exec oscar sh -c 'TZ=America/Vancouver date -d "2026-12-15 12:00" +"%z %Z"'
# SQL layer (must be 19:00 for both)
PW=$(grep MYSQL_ROOT_PASSWORD local.env | cut -d= -f2-)
docker compose exec -e PW="$PW" db sh -c 'mysql -uroot -p"$PW" -e \
  "SELECT CONVERT_TZ(\"2026-12-15 12:00:00\",\"America/Vancouver\",\"UTC\") AS dec15, \
          CONVERT_TZ(\"2026-07-15 12:00:00\",\"America/Vancouver\",\"UTC\") AS jul15;"'
```

### 1.3 Backup (non-negotiable)

```bash
cd ~/open-osp
PW=$(grep MYSQL_ROOT_PASSWORD local.env | cut -d= -f2-)
mkdir -p ~/openosp-backups
docker compose exec -e PW="$PW" db sh -c \
  'mysqldump -uroot -p"$PW" --databases oscar drugref2 --single-transaction' \
  > ~/openosp-backups/pre-update-$(date +%Y%m%d).sql
# production: also ./openosp backup  (volume-aware backups)
```

## 2. Update prebuilt images (always try this first)

```bash
docker compose pull oscar expedius faxws db
```

or the project script (note: it pulls `openosp/open-osp:release` while
`docker-compose.yml` references `:latest` — check which tag your deploy uses):

```bash
./openosp update
```

Recreate (`docker compose up -d`) and re-run the section-1 probes. If the new
images carry everything you need (app fixes, tzdata ≥ your target), you are
done. Otherwise continue.

## 3. Build OpenOscar from source (when you need a branch/fix not on Docker Hub)

### 3.1 Choose the source

`OSCAR_REPO` / `OSCAR_TREEISH` in `local.env` select repo and branch
(defaults: `https://github.com/open-osp/Open-O.git`, `main`).

### 3.2 Fix the builder image first (known broken)

`docker/builder/Dockerfile` is `FROM openjdk:8`, which Docker Hub has removed —
the build fails with "not found". This repo now carries the fixed version
(applied 2026-09-08, verified buildable):

```dockerfile
FROM maven:3.9-eclipse-temurin-8
RUN apt-get update \
    && apt-get install -y --no-install-recommends mariadb-client \
    && apt-get clean
```

(Same JDK 8 baseline OSCAR targets, plus Maven; `mariadb-client` is needed for
`--test` builds.)

### 3.3 Build

```bash
# full clean build, tests skipped (~30-60 min). Clones/updates docker/oscar/oscar.
./openosp build oscar

# variants:
./openosp build oscar --test        # runs mvn tests; needs db up
./openosp build oscar path/to/oscar.war   # package an existing WAR instead of compiling

# other components:
./openosp build expedius
./openosp build faxws
```

This compiles `docker/oscar/oscar` → `docker/oscar/oscar.war`, downloads the
DrugRef2 WAR, and runs `docker compose build oscar`, producing a local
`openosp/open-osp:latest`.

### 3.4 ⚠ Interaction with tzdata overlays

If `docker-compose.override.yml` contains the tz overlay blocks (section 4),
`docker compose build oscar` builds the **overlay**, not your source build.
Sequence matters — the overlay must sit **on top of** the freshly built app
image:

```bash
# 1. build the app image without the override in play
docker compose -f docker-compose.yml build oscar
# 2. rebuild the overlay on top of it (its BASE is openosp/open-osp:latest)
docker compose build oscar
```

## 4. Apply time zone data updates (when a tzdata release affects you)

Full detail in [`timezone-update-runbook.md`](timezone-update-runbook.md). The
essence, as verified:

1. **Donors:** JVM `tzdb.dat` from `eclipse-temurin:8-jre` (same vendor/format
   as the app JREs); OS `zoneinfo` from `ubuntu:22.04` + `apt install tzdata`
   (tracks latest IANA). Check versions before reusing:
   `curl -s https://data.iana.org/time-zones/tzdb/version`.
2. **Overlays:** `docker/tzupdate/jre.Dockerfile` (multi-stage, `ARG BASE`,
   copies both tz databases into any app image) and
   `docker/tzupdate/db.Dockerfile` (zoneinfo for mariadb:10.5). Both are in
   this repo from the verified run.
3. **⚠ MERGE into `docker-compose.override.yml`, never overwrite.** That file
   is created by `./openosp setup` from `dc.dev.yml` and carries your host port
   mappings (`8080:8080`, `8081:8081`). Overwriting it silently unpublishes
   OSCAR from the host — this actually happened during the verified run and is
   the single easiest mistake to make here.
4. Build: `docker compose build oscar expedius faxws db`.

## 5. Rollout (brief app downtime)

```bash
cd ~/open-osp

# db first — the mariadb-files volume preserves data across recreate
docker compose up -d db
sleep 12

# regenerate SQL time zone tables (only after tzdata changes; persists in volume)
PW=$(grep MYSQL_ROOT_PASSWORD local.env | cut -d= -f2-)
docker compose exec -e PW="$PW" db sh -c \
  'mysql_tzinfo_to_sql /usr/share/zoneinfo | mysql -uroot -p"$PW" mysql'

# apps (faxws is NOT covered by ./openosp start — bring it up explicitly)
docker compose up -d oscar expedius faxws
```

## 6. Verify (20 min)

### 6.1 Infrastructure

```bash
docker compose ps
docker inspect $(docker compose ps -q) --format '{{.Name}} restarts={{.RestartCount}} {{.State.Status}} oom={{.State.OOMKilled}}'
docker compose -f docker-compose.admin.yml run --no-TTY --rm health   # 4x CORRECT
# log scan — expect nothing but benign startup warnings
for c in oscar expedius faxws db; do
  echo "== $c =="; docker logs --since 1h open-osp-$c-1 2>&1 | grep -iE "SEVERE|ERROR|FATAL" | head -5
done
```

### 6.2 Time zone matrix (after tzdata changes)

Per app container, prove both the tzdb.dat content AND that the running JVM
loaded it (JVM boot time > image bake time; `TZ=America/Vancouver`):

```bash
# compile the probe once (throwaway JDK container)
cat > /tmp/TZTest.java <<'EOF'
import java.util.TimeZone;
import java.time.Instant;
public class TZTest {
  public static void main(String[] x) {
    TimeZone z = TimeZone.getTimeZone("America/Vancouver");
    String[] dates = {"2026-07-15T12:00:00Z","2026-12-15T12:00:00Z","2027-01-15T12:00:00Z"};
    for (String d : dates) {
      long ms = Instant.parse(d).toEpochMilli();
      System.out.println(d.substring(0,10) + " offset=" + (z.getOffset(ms)/3600000) + "h");
    }
  }
}
EOF
docker run --rm -v /tmp:/work -w /work eclipse-temurin:8-jdk javac TZTest.java

for c in oscar expedius faxws; do
  docker cp /tmp/TZTest.class $(docker compose ps -q $c):/tmp/
  docker compose exec $c sh -c 'cd /tmp && /opt/java/openjdk/bin/java TZTest; \
    ps -o lstart= -p $(pidof java); stat -c "tzdb.dat baked %y" /opt/java/openjdk/lib/tzdb.dat'
done
```

Expected for BC: **every date `offset=-7h`**. Plus OS `date` probe and SQL
`CONVERT_TZ` probe from section 1.2, and MariaDB live clock
(`SELECT NOW(), UTC_TIMESTAMP()` → exactly 7 h apart).

### 6.3 Application

```bash
curl -s -c /tmp/oc -o /dev/null -w "login: %{http_code}\n" \
  -d "username=openodoc&password=openo2025&pin=2025" http://localhost:8080/oscar/login.do
curl -s -L -b /tmp/oc -o /dev/null -w "schedule: %{http_code}\n" \
  "http://localhost:8080/oscar/provider/providercontrol.jsp?year=2026&month=12&day=15&view=0&displaymode=day&dboperation=searchappointmentday&viewall=0"
```

**Gotcha:** if the account already has an active session (e.g. repeated
scripted logins), `login.do` returns HTTP **200** with the "Session Choice"
page instead of a 302, and hitting protected pages without resolving it 500s.
Not an error — POST `sessionChoice=invalidate` (or `keep`) to
`/oscar/session/loginManageSessions.do` with the same cookie jar to proceed.
In a browser this is one extra click.

## 7. Rollback

```bash
# images: remove overlay image:/build: blocks from docker-compose.override.yml
# (KEEP the ports: mappings!), re-pull upstream, recreate
docker compose pull oscar expedius faxws db
docker compose up -d db oscar expedius faxws

# SQL tz tables persist in the volume — regenerate from whatever zoneinfo
# the active db image ships:
docker compose exec -e PW="$PW" db sh -c \
  'mysql_tzinfo_to_sql /usr/share/zoneinfo | mysql -uroot -p"$PW" mysql'

# database (only if something actually corrupted):
docker compose exec -e PW="$PW" db sh -c 'mysql -uroot -p"$PW"' \
  < ~/openosp-backups/pre-update-YYYYMMDD.sql
```

## 8. Known gotchas (all hit or observed in the verified run)

| # | Gotcha | Handling |
|---|---|---|
| 1 | Builder image `FROM openjdk:8` no longer exists on Docker Hub | §3.2 replacement Dockerfile |
| 2 | `docker-compose.override.yml` holds port mappings from `dc.dev.yml`; overwriting unpublishes OSCAR | Always merge; §4 step 3 |
| 3 | With tz overlays active, `docker compose build oscar` builds the overlay, not a source build | Build order in §3.4 |
| 4 | Runtime `innodb_strict_mode=1` despite `my.cnf` saying 0 → schema loads abort on `Row size too large` | `SET GLOBAL innodb_strict_mode=0` before any DB bootstrap (Appendix A) |
| 5 | `./openosp start` doesn't manage faxws | `docker compose up -d faxws` |
| 6 | `--compatibility` vs plain compose container naming causes recreates | Be consistent |
| 7 | `./openosp update` pulls `:release`, compose references `:latest` | Check your tag |
| 8 | tzdata 2026b models BC's change as effective Nov 1 2026: "PDT"/`dst=true` labels until then, **offset correct throughout** | Cosmetic; no action |
| 9 | OSCAR "Session Choice" page breaks naive scripted logins | §6.3 |

## Appendix A: fresh-bootstrap pitfalls (for new deploys, not updates)

* `./openosp bootstrap` fails at the builder step (gotcha #1). Workaround:
  clone on the host — `git clone --depth 1 https://github.com/open-osp/Open-O.git docker/oscar/oscar` —
  the db container mounts the repo at `/code`, then
  `docker compose exec db ./bin/populate-db.sh`.
* Before populating, `SET GLOBAL innodb_strict_mode=0` (gotcha #4) or
  `oscarinit.sql` aborts at ~25% of tables.
* Some BC seed files partially fail to load (pharmacies, specialists, one
  caisi data file) — schema is complete; fix reference data before production
  use.
* Default Open-O admin is `openodoc` / `openo2025` / pin `2025` (NOT the
  `oscardoc` credentials in the README); disable the 1-month expiry via
  `update security set date_ExpireDate=DATE_ADD(CURDATE(), INTERVAL 360 MONTH), b_ExpireSet=1 where user_name='openodoc';`
