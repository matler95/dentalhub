#!/usr/bin/env bash
# Uruchamia migracje + pgTAP na lokalnym Postgresie (alternatywa dla `supabase test db`)
set -euo pipefail
cd "$(dirname "$0")/../.."
DB=hub_test
P="su postgres -c"
$P "psql -qc 'drop database if exists $DB'" && $P "psql -qc 'create database $DB'"
$P "psql -q -v ON_ERROR_STOP=1 -d $DB -f $PWD/scripts/local-db/bootstrap.sql"
for f in supabase/migrations/*.sql; do $P "psql -q -v ON_ERROR_STOP=1 -d $DB -f $PWD/$f"; done
$P "pg_prove -d $DB $PWD/supabase/tests/*.sql"
