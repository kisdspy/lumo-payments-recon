-- DuckDB. Parsed timestamps must stay inside the export window, else the date format drifted.
-- This export is day-first (DD/MM/YYYY); a month-first parse would fail loudly on 13+ days,
-- but this test also covers the silent case. warn only, nothing is filtered.
{{ config(severity = 'warn') }}
select transaction_id, txn_at_utc
from {{ ref('stg_paypal_eu_activity') }}
where txn_at_utc < '{{ var("export_window_start") }}'
   or txn_at_utc >= '{{ var("export_window_end") }}'
