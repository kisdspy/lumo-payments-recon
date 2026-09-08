-- DuckDB. Engine log vs PayPal EU export, reporting period June 2026. One row per pair.
--
-- Same structure as int_recon_paypal_us, plus currency. The export is in EUR / GBP with no USD
-- column, so the provider side is valued in USD by us: gross x reference usd_rate from fx_rates,
-- last available rate on or before the provider's transaction date (ASOF join; the reference
-- table has business days only). That is an assumption, stated in the note. The engine's own
-- USD stays as the engine computed it, so any FX-date lag in the engine shows up as a cause.
--
-- Known export defect kept as-is (staging does not repair data): three lines carry a
-- month-first date inside a day-first file (raw 06/03, 06/09, 06/12/2026 -> March, September,
-- December). The engine captures those exact orders on 3, 9 and 12 June at the same time of day,
-- so the pair is recognised by swapping day and month and classified as provider_date_format.
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
        case when operation_type = 'SALE' then amount_local else -amount_local end as signed_amount_local,
        amount_usd,
        signed_amount_usd,
        fx_rate_applied,
        fx_date_applied,
        coalesce(captured_at_utc, created_at_utc)                     as engine_at
    from {{ ref('stg_payment_engine_log') }}
    where psp = 'paypal_eu'

),

provider as (

    select
        p.transaction_id,
        p.invoice_id,
        p.txn_type,
        p.status                                                 as provider_status,
        p.currency,
        p.gross,
        p.fee,
        p.txn_at_utc                                             as provider_at,
        p.dup_rank,
        fx.rate_date                                             as provider_fx_date,
        fx.usd_rate                                              as provider_fx_rate,
        round(p.gross * fx.usd_rate, 2)                          as gross_usd
    from {{ ref('stg_paypal_eu_activity') }} p
    asof left join (select * from {{ ref('stg_fx_rates') }} where dup_rank = 1) fx
      on fx.currency = p.currency
     and fx.rate_date <= p.txn_at_utc::date

),

pairs as (

    select
        'paypal_eu'                                   as psp,
        e.txn_id,
        e.order_id,
        e.operation_type,
        e.status                                      as engine_status,
        e.engine_at,
        p.transaction_id,
        p.invoice_id,
        p.txn_type                                    as provider_type,
        p.provider_status,
        p.provider_at,
        p.dup_rank,
        coalesce(e.currency, p.currency)              as currency,
        e.amount_local                                as engine_amount,
        p.gross                                       as provider_amount,
        e.fx_rate_applied                             as engine_fx_rate,
        e.fx_date_applied                             as engine_fx_date,
        p.provider_fx_rate,
        p.provider_fx_date,
        e.engine_at >= '{{ var("report_period_start") }}'
            and e.engine_at < '{{ var("report_period_end") }}'      as engine_in_period,
        p.provider_at >= '{{ var("report_period_start") }}'
            and p.provider_at < '{{ var("report_period_end") }}'    as provider_in_period,
        -- month-first line in a day-first file: swapped date and same time of day match the engine
        -- swap day and month: print as m/d/Y, parse as d/m/Y; try_ gives null when the swap is not a date
        coalesce(
            try_strptime(strftime(p.provider_at, '%m/%d/%Y'), '%d/%m/%Y')::date = e.engine_at::date
            and p.provider_at::time = e.engine_at::time, false)      as provider_date_swapped,
        case
            when p.dup_rank = 2 then 0
            when e.status = 'settled'
             and e.engine_at >= '{{ var("report_period_start") }}'
             and e.engine_at <  '{{ var("report_period_end") }}'   then e.signed_amount_usd
            else 0
        end                                           as engine_usd,
        case
            when p.provider_status <> 'Denied'
             and p.provider_at >= '{{ var("report_period_start") }}'
             and p.provider_at <  '{{ var("report_period_end") }}' then p.gross_usd
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
            when provider_date_swapped and engine_in_period <> provider_in_period   then 'provider_date_format'
            when engine_in_period <> provider_in_period                             then 'period_cutoff'
            when engine_status = 'declined' and provider_status = 'Denied'          then 'matched_declined'
            when engine_status <> 'settled'
              or provider_status not in ('Completed', 'Refunded', 'Reversed')       then 'status_mismatch'
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
