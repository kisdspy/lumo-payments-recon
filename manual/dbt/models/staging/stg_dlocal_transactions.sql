-- DuckDB. dLocal transactions export with types applied. One row per export line.
-- Nothing is dropped: the one fully identical duplicate line is kept with dup_rank = 2.
-- Amounts: local_amount comes in minor units, amount_local = local_amount / 10^currency_exponent.
-- fx_rate is local currency per 1 USD (inverse of fx_rates.usd_rate); usd_rate here is 1 / fx_rate
-- so it is comparable with the engine and the reference table.
-- Sign is not in the export (refunds positive); signed_* columns follow the engine convention:
-- PAYMENT positive, REFUND negative.

with src as (

    select
        transaction_id,
        invoice_id,
        transaction_type,
        status,
        created_at_utc::timestamp                                       as txn_at_utc,
        country,
        currency,
        currency_exponent::integer                                      as currency_exponent,
        local_amount::bigint                                            as local_amount_minor,
        (local_amount::decimal(18, 2) / power(10, currency_exponent::integer))::decimal(18, 2)
                                                                        as amount_local,
        fx_rate::decimal(18, 6)                                         as fx_rate_local_per_usd,
        (1 / fx_rate::decimal(18, 6))::decimal(18, 6)                   as usd_rate,
        usd_amount::decimal(18, 2)                                      as amount_usd,
        fee_usd::decimal(18, 2)                                         as fee_usd
    from {{ ref('raw_dlocal_transactions') }}

),

signed as (

    select
        *,
        case when transaction_type = 'REFUND' then -amount_local else amount_local end as signed_amount_local,
        case when transaction_type = 'REFUND' then -amount_usd   else amount_usd   end as signed_amount_usd
    from src

)

select
    *,
    row_number() over (
        partition by transaction_id
        order by transaction_id
    ) as dup_rank
from signed
