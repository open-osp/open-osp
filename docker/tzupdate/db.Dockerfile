# Overlay for the MariaDB container.
# Updates OS zoneinfo to IANA tzdata 2026c (donor: ubuntu:22.04).
# NOTE: the SQL time zone tables (mysql.time_zone*) live in the data volume and
# must be regenerated at runtime after the container is up:
#   docker compose exec db sh -c 'mysql_tzinfo_to_sql /usr/share/zoneinfo | mysql -uroot -p"$MYSQL_ROOT_PASSWORD" mysql'
FROM ubuntu:22.04 AS osdonor
RUN apt-get update && apt-get install -y --no-install-recommends tzdata && rm -rf /var/lib/apt/lists/*

FROM mariadb:10.5
COPY --from=osdonor /usr/share/zoneinfo /usr/share/zoneinfo
