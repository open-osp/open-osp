#!/usr/bin/env python3
"""insert_eform.py — publish an eformify-produced HTML file into oscar.eform.

Idempotent: if a row with the same form_name exists its form_html/subject are
UPDATEd, otherwise a single row is INSERTed. eForm content lives only in the
database — publishing takes effect immediately, no container restart needed.

It talks to the standard open-osp `db` compose service with
`docker compose exec -T db mysql`, using the MYSQL_ROOT_PASSWORD already set
in the container's environment, so no credentials are needed on the host.

Usage:
    ./insert_eform.py my_form_eform.html --name "Smith.PHC_Vascular_Req" \
        --subject "PHC Vascular Requisition" [--database oscar]

Roll back a newly created form with:
    DELETE FROM eform WHERE fid=<printed fid>;
"""
import argparse
import subprocess
import sys
from pathlib import Path

COMPOSE = ["docker", "compose"]


def sql_escape(s: str) -> str:
    return s.replace("\\", "\\\\").replace("'", "\\'")


def run_sql(sql: str, database: str) -> str:
    proc = subprocess.run(
        COMPOSE + ["exec", "-T", "db", "sh", "-c",
                   f'exec mysql -uroot -p"$MYSQL_ROOT_PASSWORD" -N {database}'],
        input=sql, capture_output=True, text=True)
    if proc.returncode != 0:
        sys.exit(f"mysql failed: {proc.stderr.strip()[:500]}")
    return proc.stdout.strip()


def main():
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("html_file")
    ap.add_argument("--name", required=True, help="eform.form_name (unique per form)")
    ap.add_argument("--subject", required=True)
    ap.add_argument("--database", default="oscar")
    a = ap.parse_args()

    html = Path(a.html_file).read_text()
    name, subject = sql_escape(a.name), sql_escape(a.subject)
    body = sql_escape(html)

    fid = run_sql(f"SELECT fid FROM eform WHERE form_name='{name}' LIMIT 1;", a.database)
    if fid:
        run_sql(f"UPDATE eform SET form_html='{body}', subject='{subject}' "
                f"WHERE fid={int(fid)};", a.database)
        print(f"UPDATEd existing eform fid={fid} ({a.name})")
    else:
        run_sql(
            "INSERT INTO eform (form_name, file_name, subject, form_date, form_time,"
            " form_creator, status, form_html, showLatestFormOnly, patient_independent,"
            " roleType, programNo, restrictToProgram, stable) VALUES "
            f"('{name}', '{name}.html', '{subject}', CURDATE(), CURTIME(),"
            " NULL, 1, '" + body + "', 0, 0, '', NULL, 0, 1);", a.database)
        fid = run_sql(f"SELECT fid FROM eform WHERE form_name='{name}' LIMIT 1;", a.database)
        print(f"INSERTed new eform fid={fid} ({a.name})")
        print(f"Rollback: DELETE FROM eform WHERE fid={fid};")


if __name__ == "__main__":
    main()
