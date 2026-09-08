-- DuckDB. Converted timestamps must stay inside the export window. warn only, nothing is filtered.
{{ config(severity = 'warn') }}
select psp_reference, record_type, event_at_utc
from {{ ref('stg_adyen_payment_accounting') }}
where event_at_utc < '{{ var("export_window_start") }}'
   or event_at_utc >= '{{ var("export_window_end") }}'
