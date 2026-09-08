-- DuckDB. Engine log vs Adyen payment accounting report, reporting period June 2026. One row per pair.
--
-- Same structure as int_recon_paypal_eu with two differences.
-- 1. The provider side is money events, not export lines: Settled is the sale, Refused the declined
--    attempt, Refunded and Chargeback the reversals. Authorised is the same payment before settlement
--    and carries no money of its own, so it is left out. Settled lands on the capture day for every
--    payment but one (ORD-507794, four days later), so each event is dated by its own time.
-- 2. Two pairing keys. Sales and declines pair on psp_reference. Adyen books a refund or chargeback
--    under the psp_reference of the original payment, while the engine gives its REFUND / CHARGEBACK
--    rows a psp_reference of their own, so reversals pair on order_id (= Merchant Reference) + type.
--    Both are folded into one pair_key per side.
-- The report has no USD column: provider amounts are valued at fx_rates as of the event date (ASOF,
-- last available rate on or before), USD account at 1. The engine's own USD stays as computed.
-- Fees (Commission + Markup) are carried through for the fee_schedule check, they are not part of diff.
-- diff_usd = provider - engine, positive means the provider shows more.

with engine as (

    select
        txn_id,
        order_id,
        operation_type,
        status,
        psp_reference,
        currency,
        amount_local,
        signed_amount_usd,
        fx_rate_applied,
        fx_date_applied,
        coalesce(captured_at_utc, created_at_utc)                     as engine_at,
        case
            when operation_type = 'SALE' then psp_reference
            else order_id || ':' || operation_type
        end                                                           as pair_key
    from {{ ref('stg_payment_engine_log') }}
    where psp = 'adyen'

),

provider as (

    select
        a.psp_reference                                          as provider_reference,
        a.merchant_reference,
        a.merchant_account,
        a.record_type                                            as provider_type,
        a.currency,
        abs(a.signed_gross)                                      as amount_local,
        a.signed_gross,
        a.fee,
        a.event_at_utc                                           as provider_at,
        a.dup_rank,
        case
            when a.record_type in ('Settled', 'Refused') then a.psp_reference
            when a.record_type = 'Refunded'              then a.merchant_reference || ':REFUND'
            when a.record_type = 'Chargeback'            then a.merchant_reference || ':CHARGEBACK'
        end                                                      as pair_key,
        case when a.currency = 'USD' then a.event_at_utc::date else fx.rate_date end   as provider_fx_date,
        case when a.currency = 'USD' then 1 else fx.usd_rate end                       as provider_fx_rate,
        round(a.signed_gross * case when a.currency = 'USD' then 1 else fx.usd_rate end, 2)  as gross_usd,
        round(a.fee         * case when a.currency = 'USD' then 1 else fx.usd_rate end, 2)  as fee_usd
    from {{ ref('stg_adyen_payment_accounting') }} a
    asof left join (select * from {{ ref('stg_fx_rates') }} where dup_rank = 1) fx
      on fx.currency = a.currency
     and fx.rate_date <= a.event_at_utc::date
    where a.record_type <> 'Authorised'

),

pairs as (

    select
        'adyen'                                       as psp,
        e.txn_id,
        e.order_id,
        e.operation_type,
        e.status                                      as engine_status,
        e.engine_at,
        p.provider_reference,
        p.merchant_reference,
        p.merchant_account,
        p.provider_type,
        p.provider_at,
        p.dup_rank,
        coalesce(e.currency, p.currency)              as currency,
        e.amount_local                                as engine_amount,
        p.amount_local                                as provider_amount,
        e.fx_rate_applied                             as engine_fx_rate,
        e.fx_date_applied                             as engine_fx_date,
        p.provider_fx_rate,
        p.provider_fx_date,
        p.fee                                         as provider_fee,
        p.fee_usd                                     as provider_fee_usd,
        e.engine_at >= '{{ var("report_period_start") }}'
            and e.engine_at < '{{ var("report_period_end") }}'      as engine_in_period,
        p.provider_at >= '{{ var("report_period_start") }}'
            and p.provider_at < '{{ var("report_period_end") }}'    as provider_in_period,
        case
            when p.dup_rank = 2 then 0
            when e.status = 'settled'
             and e.engine_at >= '{{ var("report_period_start") }}'
             and e.engine_at <  '{{ var("report_period_end") }}'   then e.signed_amount_usd
            else 0
        end                                           as engine_usd,
        case
            when p.provider_type <> 'Refused'
             and p.provider_at >= '{{ var("report_period_start") }}'
             and p.provider_at <  '{{ var("report_period_end") }}' then p.gross_usd
            else 0
        end                                           as provider_usd
    from engine e
    full join provider p
      on p.pair_key = e.pair_key

),

classified as (

    select
        *,
        case
            when provider_reference is null                                         then 'missing_at_provider'
            when txn_id is null                                                     then 'missing_in_engine'
            when dup_rank = 2                                                       then 'duplicate_row_in_export'
            when engine_in_period <> provider_in_period                             then 'period_cutoff'
            when engine_status = 'declined' and provider_type = 'Refused'           then 'matched_declined'
            when engine_status <> 'settled' or provider_type = 'Refused'            then 'status_mismatch'
            when abs(engine_amount) <> abs(provider_amount)                         then 'amount_mismatch'
            -- local amounts agree from here on; any USD gap is FX
            when engine_usd = provider_usd                                          then 'matched'
            when engine_fx_date < engine_at::date - interval 3 day                  then 'engine_fx_date_error'
            else 'fx_date_lag'
        end                                           as cause
    from pairs
    where coalesce(engine_in_period, false) or coalesce(provider_in_period, false)

)

select
    *,
    provider_usd - engine_usd as diff_usd
from classified
