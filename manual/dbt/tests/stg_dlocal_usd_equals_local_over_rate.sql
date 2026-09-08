-- DuckDB. dLocal's usd_amount should equal amount_local / fx_rate to the cent.
-- warn only: two rows are off by a cent in raw, a rounding note for the write-up.
{{ config(severity = 'warn') }}
select transaction_id, currency, amount_local, fx_rate_local_per_usd, amount_usd,
       round(amount_local / fx_rate_local_per_usd, 2) as usd_recomputed
from {{ ref('stg_dlocal_transactions') }}
where abs(amount_usd - round(amount_local / fx_rate_local_per_usd, 2)) > 0.005
