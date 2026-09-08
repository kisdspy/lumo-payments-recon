-- DuckDB. Engine log vs Google Play earnings report, reporting period June 2026. One row per pair.
--
-- Same structure as the other int_recon_* models, with no provider id at all: the report carries
-- neither psp_reference nor order id (the engine's psp_reference is null for google_play). The pair
-- key is capture time + product + type: engine captured_at_utc = report time in UTC, sku = Product ID,
-- SALE <-> Charge, REFUND <-> Charge refund. Google fee lines are not money events of their own,
-- they are joined onto the Charge with the same time and product and carried as provider_fee_usd
-- for the fee_schedule check (15%); they are not part of diff.
-- The report has no declined attempts. USD is Google's own conversion (conversion_rate), the
-- engine's USD stays as computed. diff_usd = provider - engine, positive means the provider shows more.

with engine as (

    select
        txn_id,
        order_id,
        operation_type,
        status,
        sku,
        currency,
        amount_local,
        signed_amount_usd,
        fx_rate_applied,
        fx_date_applied,
        coalesce(captured_at_utc, created_at_utc)                     as engine_at,
        case operation_type when 'SALE' then 'Charge' else 'Charge refund' end as pair_type
    from {{ ref('stg_payment_engine_log') }}
    where psp = 'google_play'

),

fees as (

    select txn_at_utc, product_id, sum(amount_usd) as fee_usd
    from {{ ref('stg_google_play_earnings') }}
    where txn_type = 'Google fee'
    group by 1, 2

),

provider as (

    select
        g.source_file,
        g.txn_type                                               as provider_type,
        g.product_id,
        g.buyer_country,
        g.buyer_currency                                         as currency,
        abs(g.amount_buyer)                                      as amount_local,
        g.amount_usd                                             as gross_usd,
        g.conversion_rate                                        as provider_fx_rate,
        g.txn_at_utc                                             as provider_at,
        g.dup_rank,
        -f.fee_usd                                               as fee_usd
    from {{ ref('stg_google_play_earnings') }} g
    left join fees f
      on f.txn_at_utc = g.txn_at_utc
     and f.product_id = g.product_id
     and g.txn_type = 'Charge'
    where g.txn_type in ('Charge', 'Charge refund')

),

pairs as (

    select
        'google_play'                                 as psp,
        e.txn_id,
        e.order_id,
        e.operation_type,
        e.status                                      as engine_status,
        e.engine_at,
        p.source_file,
        p.provider_type,
        p.buyer_country,
        p.provider_at,
        p.dup_rank,
        coalesce(e.sku, p.product_id)                 as product_id,
        coalesce(e.currency, p.currency)              as currency,
        e.amount_local                                as engine_amount,
        p.amount_local                                as provider_amount,
        e.fx_rate_applied                             as engine_fx_rate,
        e.fx_date_applied                             as engine_fx_date,
        p.provider_fx_rate,
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
            when p.provider_at >= '{{ var("report_period_start") }}'
             and p.provider_at <  '{{ var("report_period_end") }}' then p.gross_usd
            else 0
        end                                           as provider_usd
    from engine e
    full join provider p
      on p.provider_at = e.engine_at
     and p.product_id  = e.sku
     and p.provider_type = e.pair_type

),

classified as (

    select
        *,
        case
            when provider_at is null                                                then 'missing_at_provider'
            when txn_id is null                                                     then 'missing_in_engine'
            when dup_rank = 2                                                       then 'duplicate_row_in_export'
            when engine_in_period <> provider_in_period                             then 'period_cutoff'
            when engine_status <> 'settled'                                         then 'status_mismatch'
            when abs(engine_amount) <> abs(provider_amount)                         then 'amount_mismatch'
            -- local amounts agree from here on; any USD gap is Google's rate vs the engine's
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
