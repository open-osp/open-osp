# Runbook: Updating Time Zone Data (tzdata) Across the Open OSP Stack

**Verified end-to-end:** 2026-09-08, for the BC change to permanent UTC-7
(IANA tzdata **2026b**, released 2026-04-23; OS donor layer used **2026c**).

Use this runbook whenever IANA ships a tzdata release affecting
`America/Vancouver` (or your clinic's zone) and the published images have not
caught up yet.

---

## 0. Background — where timezone data lives in this stack

| Layer | Location | Consumers |
|---|---|---|
| JVM tz database | `/opt/java/openjdk/lib/tzdb.dat` inside oscar / expedius / faxws containers | All Java/Tomcat code — OSCAR scheduling, timestamps, lab display |
| OS zoneinfo | `/usr/share/zoneinfo` inside every container | libc (`date`, logs), `mysql_tzinfo_to_sql` source |
| MariaDB SQL tz tables | `mysql.time_zone*` (persist in the `mariadb-files` volume) | `CONVERT_TZ()` and named zones in SQL |
| Compose config | `TZ: America/Vancouver` env on all services | **Never needs changing** — the zone *name* is stable; only the data behind it updates |

Key facts that shape the procedure:

* Java ships **its own** tz database. Updating OS packages does **not** fix the JVM.
* The JVM and OS tz data ship **inside the images**, so updates are done as thin
  overlay images (no WAR rebuild, no app changes).
* The SQL tz tables live in the **data volume**, so they must be regenerated
  once at runtime after the db container is updated.
* OSCAR stores wall-clock local times — no data migration is needed.

## 1. Baseline check (5 min)

```bash
cd ~/open-osp

# JVM tzdb version (works without extra tools in the slim JRE image)
docker compose exec oscar sh -c 'grep -a -m1 -o "20[0-9][0-9][a-z]" /opt/java/openjdk/lib/tzdb.dat'

# OS tzdata + behavior probe: pick a date AFTER the change takes effect.
# For the BC change, Dec 15 2026 must be -0700; old data wrongly shows -0800.
docker compose exec oscar sh -c 'TZ=America/Vancouver date -d "2026-12-15 12:00" +"%z %Z"'

# SQL layer: must return 19:00 for both; old data returns 20:00 for December.
PW=$(grep MYSQL_ROOT_PASSWORD local.env | cut -d= -f2-)
docker compose exec -e PW="$PW" db sh -c 'mysql -uroot -p"$PW" -e \
  "SELECT CONVERT_TZ(\"2026-12-15 12:00:00\",\"America/Vancouver\",\"UTC\") AS dec15, \
          CONVERT_TZ(\"2026-07-15 12:00:00\",\"America/Vancouver\",\"UTC\") AS jul15;"'
```

If all three layers already behave correctly, stop — nothing to do.

## 2. Safety backup (5 min)

```bash
cd ~/open-osp
PW=$(grep MYSQL_ROOT_PASSWORD local.env | cut -d= -f2-)
mkdir -p /tmp/openosp-tz-backup
docker compose exec -e PW="$PW" db sh -c \
  'mysqldump -uroot -p"$PW" --databases oscar drugref2 --single-transaction' \
  > /tmp/openosp-tz-backup/pre-tzupdate-$(date +%Y%m%d).sql
```

(Optionally also `./openosp backup`. The db data volume is not touched by this
procedure, but a dump is cheap insurance.)

## 3. First, try the trivial path (5 min)

```bash
docker compose pull oscar expedius faxws db
```

Re-run the baseline checks after recreating containers (step 6). If upstream
images now carry the new tzdata, you are done — skip everything else and
delete any overlay blocks left in `docker-compose.override.yml`.

## 4. Build tzdata overlay images (15 min)

> **Scripted:** `bin/update-timezones.sh --apply` performs steps 4–6 of this
> runbook automatically (backup → merge override → build → rollout →
> `mysql_tzinfo_to_sql` → verify). `--merge-only` builds just the compose
> override for inspection; `--check` runs the verification matrix read-only;
> `--rollback` reverts. Template: `docker-compose.tz.yml`. Re-running
> `--apply` on an already-updated stack may recreate app containers if donor
> images drifted — harmless (apps are stateless, db untouched).

Two donor sources (verified for this change; re-check versions when reusing):

* **JVM tzdb.dat** — `eclipse-temurin:8-jre`. Same vendor and file format as the
  JRE inside the app images. Verify with:
  `docker run --rm eclipse-temurin:8-jre sh -c 'grep -a -m1 -o "20[0-9][0-9][a-z]" /opt/java/openjdk/lib/tzdb.dat'`
* **OS zoneinfo** — `ubuntu:22.04` + `apt-get install tzdata` (tracks latest IANA).

Create `docker/tzupdate/jre.Dockerfile`:

```dockerfile
ARG BASE
FROM eclipse-temurin:8-jre AS jvmdonor
FROM ubuntu:22.04 AS osdonor
RUN apt-get update && apt-get install -y --no-install-recommends tzdata && rm -rf /var/lib/apt/lists/*
FROM ${BASE}
COPY --from=jvmdonor /opt/java/openjdk/lib/tzdb.dat /opt/java/openjdk/lib/tzdb.dat
COPY --from=osdonor /usr/share/zoneinfo /usr/share/zoneinfo
```

Create `docker/tzupdate/db.Dockerfile`:

```dockerfile
FROM ubuntu:22.04 AS osdonor
RUN apt-get update && apt-get install -y --no-install-recommends tzdata && rm -rf /var/lib/apt/lists/*
FROM mariadb:10.5
COPY --from=osdonor /usr/share/zoneinfo /usr/share/zoneinfo
```

### ⚠ Merge into `docker-compose.override.yml` — do NOT overwrite it

`./openosp setup` copies `dc.dev.yml` to `docker-compose.override.yml`; that
file carries the `8080:8080` / `8081:8081` port mappings. Overwriting it
silently unpublishes OSCAR from the host (hit during the verified run).
**Merge** the overlay blocks with whatever is already there:

```yaml
services:
  oscar:
    image: openosp/open-osp:tz2026b
    build:
      context: .
      dockerfile: docker/tzupdate/jre.Dockerfile
      args: { BASE: openosp/open-osp:latest }
    ports: [ '8080:8080' ]            # keep from dc.dev.yml!
  expedius:
    image: openosp/expedius:tz2026b
    build:
      context: .
      dockerfile: docker/tzupdate/jre.Dockerfile
      args: { BASE: openosp/expedius:latest }
    ports: [ '8081:8081' ]            # keep from dc.dev.yml!
  faxws:
    image: openosp/faxws:tz2026b
    build:
      context: .
      dockerfile: docker/tzupdate/jre.Dockerfile
      args: { BASE: openosp/faxws:latest }
  db:
    image: openosp/mariadb105:tz2026c
    build:
      context: .
      dockerfile: docker/tzupdate/db.Dockerfile
```

Build:

```bash
docker compose build oscar expedius faxws db
```

## 5. Roll out (15 min, brief app downtime)

```bash
# db first — data volume (mariadb-files) is preserved on recreate
docker compose up -d db
sleep 12

# regenerate the SQL time zone tables (persists in the volume)
PW=$(grep MYSQL_ROOT_PASSWORD local.env | cut -d= -f2-)
docker compose exec -e PW="$PW" db sh -c \
  'mysql_tzinfo_to_sql /usr/share/zoneinfo | mysql -uroot -p"$PW" mysql'

# then the apps
docker compose up -d oscar expedius faxws
```

Notes:

* `./openosp start` also works but only brings up db/oscar/expedius — faxws
  needs `docker compose up -d faxws` separately.
* Mixing `docker compose` and `docker compose --compatibility` (what the
  openosp scripts use) changes container naming (`open-osp-oscar-1` vs
  `open-osp_oscar_1`) and forces a recreate. Harmless, but pick one and stick
  with it.

## 6. Verify (15 min)

**JVM layer (each app container).** Compile the probe once, run everywhere:

```bash
mkdir -p /tmp/tztest && cat > /tmp/tztest/TZTest.java <<'EOF'
import java.util.TimeZone;
import java.time.Instant;
public class TZTest {
  public static void main(String[] x) {
    TimeZone z = TimeZone.getTimeZone("America/Vancouver");
    String[] dates = {"2026-07-15T12:00:00Z","2026-12-15T12:00:00Z","2027-01-15T12:00:00Z"};
    for (String d : dates) {
      long ms = Instant.parse(d).toEpochMilli();
      System.out.println(d.substring(0,10) + " offset=" + (z.getOffset(ms)/3600000) + "h dst=" + z.inDaylightTime(new java.util.Date(ms)));
    }
  }
}
EOF
docker run --rm -v /tmp/tztest:/work -w /work eclipse-temurin:8-jdk javac TZTest.java

for c in oscar expedius faxws; do
  docker cp /tmp/tztest/TZTest.class $(docker compose ps -q $c):/tmp/
  docker compose exec $c sh -c 'cd /tmp && /opt/java/openjdk/bin/java TZTest'
done
```

Expected for the BC change: **every date `offset=-7h`** (old data: `-8h` for
Dec/Jan). `dst=true` on 2026-07-15 is expected — the tzdata 2026b transition
modeling quirk (see Risks); the offset is what matters.

**OS layer (each container):**
`docker compose exec oscar sh -c 'TZ=America/Vancouver date -d "2026-12-15 12:00" +"%z"'` → `-0700`

**SQL layer:** rerun the `CONVERT_TZ` probe from step 1 → `19:00` for both dates.

**Application layer:**

```bash
curl -s -c /tmp/oc -o /dev/null -w "%{http_code}\n" \
  -d "username=openodoc&password=openo2025&pin=2025" http://localhost:8080/oscar/login.do   # 302 to providercontrol.jsp
curl -s -L -b /tmp/oc -o /dev/null -w "%{http_code}\n" \
  "http://localhost:8080/oscar/provider/providercontrol.jsp?year=2026&month=12&day=15&view=0&displaymode=day&dboperation=searchappointmentday&viewall=0"  # 200
```

Then eyeball one appointment slot in the browser for a post-change date.

## 7. Rollback

```bash
# remove the image:/build: overlay blocks from docker-compose.override.yml (keep ports!)
docker compose pull oscar expedius faxws db
docker compose up -d db oscar expedius faxws
# regenerate SQL tz tables from the old image's zoneinfo:
docker compose exec -e PW="$PW" db sh -c \
  'mysql_tzinfo_to_sql /usr/share/zoneinfo | mysql -uroot -p"$PW" mysql'
```

DB restore (only if ever needed): `mysql -uroot -p"$PW" < /tmp/openosp-tz-backup/pre-tzupdate-YYYYMMDD.sql`

## 8. Risks & caveats

1. **tzdata 2026b transition quirk:** between 2026-03-09 and 2026-11-01 the zone
   is modeled as still in DST (`dst=true`, "PDT" name) even though the legal
   change already happened; after 2026-11-01 it flips to permanent standard
   time. Wall-clock offset is correct (UTC-7) throughout — only the
   abbreviation/`isdst` flag is cosmetic. Verified harmless for this stack.
2. **Zone-name strings:** anything pattern-matching "PST"/"PDT" (log parsers,
   HL7 feeds) may see "MST"-style abbreviations from the OS layer after the
   update (same quirk, cosmetic).
3. **`docker-compose.override.yml` clobbering:** the setup script and manual
   edits both target this file — always merge, never blind-copy (see step 4).
4. **Donor drift:** when reusing this runbook, re-check that
   `eclipse-temurin:8-jre`'s tzdb and Ubuntu's tzdata package are still at the
   IANA version you need; adjust donors if a newer release exists
   (`curl -s https://data.iana.org/time-zones/tzdb/version`).
5. **Appointments across the transition:** slots booked under old rules for
   dates after the change display at their stored wall-clock time (desired
   behavior for clinics); no data migration. Communicate to staff if the clinic
   relies on automated reminders around the transition day.
