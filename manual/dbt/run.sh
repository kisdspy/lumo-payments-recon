#!/usr/bin/env bash
# Build with dbt, then refresh the copy DBeaver looks at.
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

cp ../recon_dbt.duckdb ../recon_view.tmp
mv -f ../recon_view.tmp ../recon_view.duckdb

# Export every table in schema analysis to out/analysis/*.csv
mkdir -p ../out/analysis
duckdb ../recon_view.duckdb -noheader -list \
  "select table_name from duckdb_tables() where schema_name = 'analysis'" |
while read -r t; do
  duckdb ../recon_view.duckdb \
    "copy (select * from analysis.\"$t\") to '../out/analysis/$t.csv' (header)"
done