-- DuckDB. All engine <-> provider pairs for June 2026 in one table, one row per pair, common columns.
-- Union of the five int_recon_* models; provider-specific columns (fx, fees, swapped dates) stay in
-- intermediate, this table keeps what the summary and a drill-down need. provider_ref is the id the
-- provider gave the row; google_play has none, so time + product stands in.
-- cause_bucket: matched (money agrees or nothing moved on either side), explained (a cause with a
-- USD effect), unexplained (reserved, no cause produces it: every pair gets a rule).
-- diff_usd = provider_usd - engine_usd, positive means the provider shows more.

with unioned as (

    select
        psp, txn_id, order_id, operation_type, engine_status, engine_at,
        transaction_id                          as provider_ref,
        provider_type, provider_status, provider_at,
        'USD'                                   as currency,
        engine_amount, provider_amount,
        engine_in_period, provider_in_period,
        engine_usd, provider_usd, cause, diff_usd
    from {{ ref('int_recon_paypal_us') }}

    union all

    select
        psp, txn_id, order_id, operation_type, engine_status, engine_at,
        transaction_id,
        provider_type, provider_status, provider_at,
        currency,
        engine_amount, provider_amount,
        engine_in_period, provider_in_period,
        engine_usd, provider_usd, cause, diff_usd
    from {{ ref('int_recon_paypal_eu') }}

    union all

    select
        psp, txn_id, order_id, operation_type, engine_status, engine_at,
        transaction_id,
        provider_type, provider_status, provider_at,
        currency,
        engine_amount, provider_amount,
        engine_in_period, provider_in_period,
        engine_usd, provider_usd, cause, diff_usd
    from {{ ref('int_recon_dlocal') }}

    union all

    select
        psp, txn_id, order_id, operation_type, engine_status, engine_at,
        provider_reference,
        provider_type, provider_type            as provider_status, provider_at,
        currency,
        engine_amount, provider_amount,
        engine_in_period, provider_in_period,
        engine_usd, provider_usd, cause, diff_usd
    from {{ ref('int_recon_adyen') }}

    union all

    select
        psp, txn_id, order_id, operation_type, engine_status, engine_at,
        strftime(provider_at, '%Y-%m-%d %H:%M:%S') || ' ' || product_id,
        provider_type, provider_type            as provider_status, provider_at,
        currency,
        engine_amount, provider_amount,
        engine_in_period, provider_in_period,
        engine_usd, provider_usd, cause, diff_usd
    from {{ ref('int_recon_google_play') }}

)

select
    *,
    case
        when cause in ('matched', 'matched_declined') then 'matched'
        else 'explained'
    end as cause_bucket
from unioned
