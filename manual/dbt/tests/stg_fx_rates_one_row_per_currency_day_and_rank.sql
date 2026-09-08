-- DuckDB. currency + rate_date + dup_rank must be unique in stg_fx_rates.
select currency, rate_date, dup_rank, count(*) as n
from {{ ref('stg_fx_rates') }}
group by 1, 2, 3
having count(*) > 1
