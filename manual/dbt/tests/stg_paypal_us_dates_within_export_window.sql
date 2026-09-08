-- DuckDB. Parsed timestamps must stay inside the export window, else the date format drifted.
-- warn only: nothing is filtered, the rows returned are the ones to look at.
{{ config(severity = 'warn') }}
select transaction_id, txn_at_utc
from {{ ref('stg_paypal_us_activity') }}
where txn_at_utc < '{{ var("export_window_start") }}'
   or txn_at_utc >= '{{ var("export_window_end") }}'
