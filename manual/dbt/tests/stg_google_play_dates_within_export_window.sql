-- DuckDB. Converted timestamps must stay inside the export window. warn only, nothing is filtered.
{{ config(severity = 'warn') }}
select source_file, txn_at_utc, product_id, txn_type
from {{ ref('stg_google_play_earnings') }}
where txn_at_utc < '{{ var("export_window_start") }}'
   or txn_at_utc >= '{{ var("export_window_end") }}'
