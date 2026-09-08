-- DuckDB. Every Refund / Payment Reversal must reference a Completed Website Payment in the same export.
-- warn only: a reversal of a payment made before the export window is legitimate.
{{ config(severity = 'warn') }}
select r.transaction_id, r.txn_type, r.reference_txn_id, r.gross, r.txn_at_utc
from {{ ref('stg_paypal_eu_activity') }} r
where r.txn_type in ('Refund', 'Payment Reversal')
  and not exists (
      select 1
      from {{ ref('stg_paypal_eu_activity') }} p
      where p.transaction_id = r.reference_txn_id
        and p.txn_type = 'Website Payment'
        and p.status = 'Completed'
  )
