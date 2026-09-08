-- DuckDB. Engine log vs PayPal US export, reporting period June 2026. One row per pair.
--
-- Join key: engine psp_reference = PayPal transaction_id (1:1, proven in EDA 2026-09-07).
-- The join runs over the whole export window; the reporting period is applied inside the pair,
-- so a row that one side dates inside June and the other outside is a cause, not a missing row.
-- Period rule: engine by captured_at_utc (created_at_utc when never captured), provider by txn_at_utc.
-- Money: engine counts settled rows in period (signed_amount_usd); provider counts all but Denied
-- in period (gross, sign already in the export). Both accounts are USD, no FX.
-- diff_usd = provider - engine, positive means the provider shows more.
-- Nothing is dropped except pairs that both sides date outside June.

with engine as (

    select
        txn_id,
        order_id,
        operation_type,
        status,
        psp_reference,
        amount_usd,
        signed_amount_usd,
        coalesce(captured_at_utc, created_at_utc)                     as engine_at
    from {{ ref('stg_payment_engine_log') }}
    where psp = 'paypal_us'

),

provider as (

    select
        transaction_id,
        invoice_id,
        txn_type,
        status                                                   as provider_status,
        gross,
        fee,
        txn_at_utc                                               as provider_at,
        dup_rank
    from {{ ref('stg_paypal_us_activity') }}

),

pairs as (

    select
        'paypal_us'                                   as psp,
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
        e.amount_usd                                  as engine_amount,
        p.gross                                       as provider_amount,
        e.engine_at >= '{{ var("report_period_start") }}'
            and e.engine_at < '{{ var("report_period_end") }}'      as engine_in_period,
        p.provider_at >= '{{ var("report_period_start") }}'
            and p.provider_at < '{{ var("report_period_end") }}'    as provider_in_period,
        -- money only where it moved and only inside the period; the duplicate line
        -- must not count the engine side twice
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
             and p.provider_at <  '{{ var("report_period_end") }}' then p.gross
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
            when engine_status = 'declined' and provider_status = 'Denied'          then 'matched_declined'
            when engine_status = 'settled'
             and provider_status in ('Completed', 'Refunded')
             and abs(engine_amount) <> abs(provider_amount)                         then 'amount_mismatch'
            when engine_status = 'settled' and provider_status in ('Completed', 'Refunded') then 'matched'
            else 'status_mismatch'
        end                                           as cause
    from pairs
    where coalesce(engine_in_period, false) or coalesce(provider_in_period, false)

)

select
    *,
    provider_usd - engine_usd as diff_usd
from classified
