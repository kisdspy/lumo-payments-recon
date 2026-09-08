-- DuckDB. Every Charge must have exactly one Google fee line with the same time and product,
-- and every fee line must belong to a Charge. warn only: a break is a finding about the report.
{{ config(severity = 'warn') }}
with charges as (
    select txn_at_utc, product_id, count(*) as n_charge
    from {{ ref('stg_google_play_earnings') }}
    where txn_type = 'Charge'
    group by 1, 2
),
fees as (
    select txn_at_utc, product_id, count(*) as n_fee
    from {{ ref('stg_google_play_earnings') }}
    where txn_type = 'Google fee'
    group by 1, 2
)
select coalesce(c.txn_at_utc, f.txn_at_utc) as txn_at_utc,
       coalesce(c.product_id, f.product_id) as product_id,
       coalesce(n_charge, 0) as n_charge,
       coalesce(n_fee, 0) as n_fee
from charges c
full join fees f using (txn_at_utc, product_id)
where coalesce(n_charge, 0) <> coalesce(n_fee, 0)
