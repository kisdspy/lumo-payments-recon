-- DuckDB. Every Refund must reference a Completed Website Payment present in the same export.
-- warn only: a refund of a payment made before the export window is legitimate and
-- would show up here; it is a note for the write-up, not a build error.
{{ config(severity = 'warn') }}
select r.transaction_id, r.reference_txn_id, r.gross, r.txn_at_utc
from {{ ref('stg_paypal_us_activity') }} r
where r.txn_type = 'Refund'
  and not exists (
      select 1
      from {{ ref('stg_paypal_us_activity') }} p
      where p.transaction_id = r.reference_txn_id
        and p.txn_type = 'Website Payment'
        and p.status = 'Completed'
  )
