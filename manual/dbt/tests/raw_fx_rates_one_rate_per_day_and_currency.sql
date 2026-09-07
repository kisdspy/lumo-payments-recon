-- FX: one published rate per (date, currency). Known exception 2026-06-10 BRL
-- was revised two days later, hence warn; staging keeps the earliest publication.
{{ config(severity = 'warn') }}
select rate_date, currency, count(*) as n
from {{ ref('raw_fx_rates') }}
group by 1, 2
having count(*) > 1
