-- DuckDB. Engine log vs dLocal export, reporting period June 2026. One row per pair.
--
-- Same structure as int_recon_paypal_eu. dLocal reports its own USD (usd_amount at its own rate),
-- so the provider side is valued as dLocal reports it, not by us. A reference valuation
-- (amount_local x fx_rates rate as of the provider date) is carried alongside for the note.
-- Money: engine counts settled rows in period (engine's own USD); provider counts PAID and
-- REFUNDED rows in period. IN_MEDIATION is a disputed payment with funds held: no money on the
-- provider side, classified as status_mismatch. REJECTED rows carry a dLocal fee but no revenue.
-- The engine booked three dLocal rows with fx_rate_applied = 1 (local amount as dollars);
-- those pairs are engine_fx_rate_error and carry most of this provider's discrepancy.
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
        amount_usd,
        signed_amount_usd,
        fx_rate_applied,
        fx_date_applied,
        coalesce(captured_at_utc, created_at_utc)                     as engine_at
    from {{ ref('stg_payment_engine_log') }}
    where psp = 'dlocal'

),

provider as (

    select
        d.transaction_id,
        d.invoice_id,
        d.transaction_type,
        d.status                                                 as provider_status,
        d.currency,
        d.amount_local,
        d.signed_amount_local,
        d.amount_usd,
        d.signed_amount_usd,
        d.usd_rate                                               as provider_fx_rate,
        d.fee_usd,
        d.txn_at_utc                                             as provider_at,
        d.dup_rank,
        fx.rate_date                                             as reference_fx_date,
        fx.usd_rate                                              as reference_fx_rate,
        round(d.signed_amount_local * fx.usd_rate, 2)            as reference_usd
    from {{ ref('stg_dlocal_transactions') }} d
    asof left join (select * from {{ ref('stg_fx_rates') }} where dup_rank = 1) fx
      on fx.currency = d.currency
     and fx.rate_date <= d.txn_at_utc::date

),

pairs as (

    select
        'dlocal'                                      as psp,
        e.txn_id,
        e.order_id,
        e.operation_type,
        e.status                                      as engine_status,
        e.engine_at,
        p.transaction_id,
        p.invoice_id,
        p.transaction_type                            as provider_type,
        p.provider_status,
        p.provider_at,
        p.dup_rank,
        coalesce(e.currency, p.currency)              as currency,
        e.amount_local                                as engine_amount,
        p.signed_amount_local                         as provider_amount,
        e.fx_rate_applied                             as engine_fx_rate,
        e.fx_date_applied                             as engine_fx_date,
        p.provider_fx_rate,
        p.reference_fx_rate,
        p.reference_fx_date,
        p.reference_usd,
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
            when p.provider_status in ('PAID', 'REFUNDED')
             and p.provider_at >= '{{ var("report_period_start") }}'
             and p.provider_at <  '{{ var("report_period_end") }}' then p.signed_amount_usd
            else 0
        end                                           as provider_usd
    from engine e
    full join provider p
      on p.transaction_id = e.psp_reference

),

classified as (

    select
        *,
        case
            when transaction_id is null                                             then 'missing_at_provider'
            when txn_id is null                                                     then 'missing_in_engine'
            when dup_rank = 2                                                       then 'duplicate_row_in_export'
            when engine_in_period <> provider_in_period                             then 'period_cutoff'
            when engine_status = 'declined' and provider_status = 'REJECTED'        then 'matched_declined'
            when engine_status <> 'settled'
              or provider_status not in ('PAID', 'REFUNDED')                        then 'status_mismatch'
            when abs(engine_amount) <> abs(provider_amount)                         then 'amount_mismatch'
            when engine_fx_rate = 1                                                 then 'engine_fx_rate_error'
            -- local amounts agree from here on; any USD gap is the two sides' FX rates
            when engine_usd = provider_usd                                          then 'matched'
            else 'provider_fx_rate'
        end                                           as cause
    from pairs
    where coalesce(engine_in_period, false) or coalesce(provider_in_period, false)

)

select
    *,
    provider_usd - engine_usd as diff_usd
from classified
