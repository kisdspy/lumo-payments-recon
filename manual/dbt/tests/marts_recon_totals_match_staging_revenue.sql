-- DuckDB. Independent check of the pair tables: money per side in recon_totals must equal June 2026
-- revenue computed straight from staging with the taxonomy rules (the figures in FINDINGS.md),
-- without going through intermediate. Engine: settled rows, signed. Provider: money rows only,
-- provider's own USD where it has one, else fx_rates as of the row date.
{% set p_start = var("report_period_start") %}
{% set p_end   = var("report_period_end") %}

with engine as (

    select psp, sum(signed_amount_usd) as engine_usd
    from {{ ref('stg_payment_engine_log') }}
    where status = 'settled'
      and coalesce(captured_at_utc, created_at_utc) >= '{{ p_start }}'
      and coalesce(captured_at_utc, created_at_utc) <  '{{ p_end }}'
    group by 1

),

fx as (
    select * from {{ ref('stg_fx_rates') }} where dup_rank = 1
),

provider as (

    select 'paypal_us' as psp, sum(gross) as provider_usd
    from {{ ref('stg_paypal_us_activity') }}
    where status <> 'Denied'
      and txn_at_utc >= '{{ p_start }}' and txn_at_utc < '{{ p_end }}'

    union all

    select 'paypal_eu', sum(round(p.gross * fx.usd_rate, 2))
    from {{ ref('stg_paypal_eu_activity') }} p
    asof left join fx on fx.currency = p.currency and fx.rate_date <= p.txn_at_utc::date
    where p.status <> 'Denied'
      and p.txn_at_utc >= '{{ p_start }}' and p.txn_at_utc < '{{ p_end }}'

    union all

    select 'dlocal', sum(signed_amount_usd)
    from {{ ref('stg_dlocal_transactions') }}
    where status in ('PAID', 'REFUNDED')
      and txn_at_utc >= '{{ p_start }}' and txn_at_utc < '{{ p_end }}'

    union all

    select 'adyen', sum(round(a.signed_gross * case when a.currency = 'USD' then 1 else fx.usd_rate end, 2))
    from {{ ref('stg_adyen_payment_accounting') }} a
    asof left join fx on fx.currency = a.currency and fx.rate_date <= a.event_at_utc::date
    where a.record_type in ('Settled', 'Refunded', 'Chargeback')
      and a.event_at_utc >= '{{ p_start }}' and a.event_at_utc < '{{ p_end }}'

    union all

    select 'google_play', sum(amount_usd)
    from {{ ref('stg_google_play_earnings') }}
    where txn_type in ('Charge', 'Charge refund')
      and txn_at_utc >= '{{ p_start }}' and txn_at_utc < '{{ p_end }}'

)

select
    t.psp,
    t.engine_usd    as totals_engine_usd,
    e.engine_usd    as staging_engine_usd,
    t.provider_usd  as totals_provider_usd,
    p.provider_usd  as staging_provider_usd
from {{ ref('recon_totals') }} t
left join engine e   on e.psp = t.psp
left join provider p on p.psp = t.psp
where t.psp <> 'total'
  and (t.engine_usd <> e.engine_usd or t.provider_usd <> p.provider_usd)
