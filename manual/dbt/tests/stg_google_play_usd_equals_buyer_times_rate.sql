-- DuckDB. amount_usd must equal amount_buyer x conversion_rate to the cent.
-- warn only: a break is a finding about Google's conversion, not a reason to stop the build.
{{ config(severity = 'warn') }}
select txn_at_utc, product_id, txn_type, buyer_currency, amount_buyer, conversion_rate, amount_usd,
       round(amount_buyer * conversion_rate, 2) as expected_usd
from {{ ref('stg_google_play_earnings') }}
where abs(amount_usd - round(amount_buyer * conversion_rate, 2)) > 0.01
