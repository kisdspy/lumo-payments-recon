#!/usr/bin/env bash
# Build with dbt, then refresh the read-only copy DBeaver and the notebook look at.
set -euo pipefail
cd "$(dirname "$0")"
# Bootstrap the virtualenv on first run (needs uv).
if [ ! -d ../.venv ]; then
  uv venv ../.venv --python 3.12
  uv pip install --python ../.venv/bin/python -r ../requirements.txt
fi
source ../.venv/bin/activate
export DBT_PROFILES_DIR=.

dbt "${@:-run}"

# The copy keeps the file name recon_dbt.duckdb: DuckDB's catalog name is the file name,
# and dbt stores views with fully qualified sources (recon_dbt.raw.x), so a copy under
# another name breaks every view. Different folder, same name.
mkdir -p ../view
cp ../recon_dbt.duckdb ../view/recon_dbt.tmp
mv -f ../view/recon_dbt.tmp ../view/recon_dbt.duckdb

# Export every table in schemas analysis and marts to out/<schema>/*.csv
for s in analysis marts; do
  mkdir -p "../out/$s"
  duckdb ../view/recon_dbt.duckdb -noheader -list \
    "select table_name from duckdb_tables() where schema_name = '$s'" |
  while read -r t; do
    duckdb ../view/recon_dbt.duckdb \
      "copy (select * from $s.\"$t\") to '../out/$s/$t.csv' (header)"
  done
done