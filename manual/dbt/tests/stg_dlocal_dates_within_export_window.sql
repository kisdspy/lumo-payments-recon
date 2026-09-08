-- DuckDB. Parsed timestamps must stay inside the export window. warn only, nothing is filtered.
{{ config(severity = 'warn') }}
select transaction_id, txn_at_utc
from {{ ref('stg_dlocal_transactions') }}
where txn_at_utc < '{{ var("export_window_start") }}'
   or txn_at_utc >= '{{ var("export_window_end") }}'
