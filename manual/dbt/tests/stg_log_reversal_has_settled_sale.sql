-- DuckDB. Every REFUND / CHARGEBACK must have a settled SALE on the same order_id.
-- Error, not warn: an orphan reversal breaks the log's own integrity and the
-- simple signed sum used for revenue would silently understate it.
select r.txn_id, r.order_id, r.operation_type
from {{ ref('stg_payment_engine_log') }} r
where r.operation_type <> 'SALE'
  and not exists (
      select 1
      from {{ ref('stg_payment_engine_log') }} s
      where s.order_id = r.order_id
        and s.operation_type = 'SALE'
        and s.status = 'settled'
  )
