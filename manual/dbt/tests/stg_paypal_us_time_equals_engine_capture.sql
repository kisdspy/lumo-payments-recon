-- DuckDB. For settled rows PayPal time equals engine capture time (established in EDA 2026-09-07).
-- warn only: a mismatch is a reconciliation finding, not a build error.
{{ config(severity = 'warn') }}
select s.transaction_id, s.txn_at_utc, e.captured_at_utc
from {{ ref('stg_paypal_us_activity') }} s
join {{ ref('stg_payment_engine_log') }} e
  on e.psp_reference = s.transaction_id
where e.psp = 'paypal_us'
  and e.status = 'settled'
  and s.txn_at_utc <> e.captured_at_utc
