-- DuckDB. Payment engine log with types applied. One row per transaction attempt.
-- No dedup needed: txn_id is unique in raw.

select
    txn_id,
    order_id,
    operation_type,
    status,
    psp,
    psp_reference,
    sku,
    country,
    currency,
    amount_local::decimal(18, 2)                as amount_local,
    fx_rate_applied::decimal(18, 6)             as fx_rate_applied,
    fx_date_applied::date                       as fx_date_applied,
    amount_usd::decimal(18, 2)                  as amount_usd,
    -- reversals carry a positive amount in the log; make them negative so sums net out
    case
        when operation_type = 'SALE' then amount_usd::decimal(18, 2)
        else -(amount_usd::decimal(18, 2))
    end                                         as signed_amount_usd,
    created_at_utc::timestamp                   as created_at_utc,
    captured_at_utc::timestamp                  as captured_at_utc
from {{ ref('raw_payment_engine_log') }}
