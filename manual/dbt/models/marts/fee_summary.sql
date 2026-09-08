-- DuckDB. README step 4: reported fees against contracted rates, June 2026, one row per
-- provider x account x currency. Amounts stay in the provider's own currency (no FX assumption).
-- contract_pct comes from fee_schedule where a contract exists (adyen, google_play); for paypal and
-- dlocal there is no contract, only the reported fee is shown. fee_contract = sum over rows of
-- round(gross x pct, 2); rows_off_contract = rows whose fee differs from that by more than a cent.
-- fee_on_declined = fees charged on declined / rejected attempts (dLocal does this).

with adyen as (

    select
        'adyen'                                             as psp,
        merchant_account                                    as account,
        currency,
        count(*)                                            as row_count,
        sum(gross_credit)                                   as gross,
        sum(fee)                                            as fee_actual,
        sum(round(gross_credit * 0.025, 2))                 as fee_contract,
        count(*) filter (where abs(fee - round(gross_credit * 0.025, 2)) > 0.01) as rows_off_contract,
        0                                                   as fee_on_declined
    from {{ ref('stg_adyen_payment_accounting') }}
    where record_type = 'Settled'
      and event_at_utc >= '{{ var("report_period_start") }}'
      and event_at_utc <  '{{ var("report_period_end") }}'
    group by 1, 2, 3

),

google_play as (

    select
        'google_play'                                       as psp,
        'LumoPlayMain'                                      as account,
        'USD'                                               as currency,
        count(*)                                            as row_count,
        sum(provider_usd)                                   as gross,
        sum(provider_fee_usd)                               as fee_actual,
        sum(round(provider_usd * 0.15, 2))                  as fee_contract,
        count(*) filter (where abs(provider_fee_usd - round(provider_usd * 0.15, 2)) > 0.01) as rows_off_contract,
        0                                                   as fee_on_declined
    from {{ ref('int_recon_google_play') }}
    where provider_type = 'Charge' and provider_in_period

),

paypal_us as (

    select
        'paypal_us'                                         as psp,
        null                                                as account,
        'USD'                                               as currency,
        count(*)                                            as row_count,
        sum(gross)                                          as gross,
        -sum(fee)                                           as fee_actual,
        null                                                as fee_contract,
        null                                                as rows_off_contract,
        0                                                   as fee_on_declined
    from {{ ref('stg_paypal_us_activity') }}
    where txn_type = 'Website Payment' and status = 'Completed'
      and txn_at_utc >= '{{ var("report_period_start") }}'
      and txn_at_utc <  '{{ var("report_period_end") }}'

),

paypal_eu as (

    select
        'paypal_eu'                                         as psp,
        null                                                as account,
        currency,
        count(*)                                            as row_count,
        sum(gross)                                          as gross,
        -sum(fee)                                           as fee_actual,
        null                                                as fee_contract,
        null                                                as rows_off_contract,
        0                                                   as fee_on_declined
    from {{ ref('stg_paypal_eu_activity') }}
    where txn_type = 'Website Payment' and status = 'Completed'
      and txn_at_utc >= '{{ var("report_period_start") }}'
      and txn_at_utc <  '{{ var("report_period_end") }}'
    group by 1, 2, 3

),

dlocal as (

    select
        'dlocal'                                            as psp,
        null                                                as account,
        'USD'                                               as currency,
        count(*) filter (where status = 'PAID')             as row_count,
        sum(amount_usd) filter (where status = 'PAID')      as gross,
        sum(fee_usd) filter (where status = 'PAID')         as fee_actual,
        null                                                as fee_contract,
        null                                                as rows_off_contract,
        sum(fee_usd) filter (where status = 'REJECTED')     as fee_on_declined
    from {{ ref('stg_dlocal_transactions') }}
    where txn_at_utc >= '{{ var("report_period_start") }}'
      and txn_at_utc <  '{{ var("report_period_end") }}'

),

unioned as (
    select * from adyen
    union all select * from google_play
    union all select * from paypal_us
    union all select * from paypal_eu
    union all select * from dlocal
)

select
    u.psp,
    u.account,
    u.currency,
    u.row_count,
    u.gross::decimal(18, 2)                                             as gross,
    u.fee_actual::decimal(18, 2)                                        as fee_actual,
    round(100 * u.fee_actual / nullif(u.gross, 0), 2)                   as fee_actual_pct,
    f.percent_fee                                                       as contract_pct,
    u.fee_contract::decimal(18, 2)                                      as fee_contract,
    (u.fee_actual - u.fee_contract)::decimal(18, 2)                     as fee_gap,
    u.rows_off_contract,
    u.fee_on_declined::decimal(18, 2)                                   as fee_on_declined
from unioned u
left join {{ ref('stg_fee_schedule') }} f
  on f.psp = u.psp and f.account = u.account
order by u.psp, u.account, u.currency
