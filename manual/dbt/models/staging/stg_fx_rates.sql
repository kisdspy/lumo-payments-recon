-- DuckDB. Daily FX reference rates with types applied. usd_rate = USD per 1 unit of currency.
-- Business days only (no weekend rows), 2026-05-25 .. 2026-07-03.
-- Known defect kept, not fixed: BRL 2026-06-10 has two rows with different rates,
-- marked dup_rank 1 / 2 (lower rate first). Which one applies is an assumption downstream.

with src as (

    select
        currency,
        rate_date::date                 as rate_date,
        usd_rate::decimal(18, 6)        as usd_rate
    from {{ ref('raw_fx_rates') }}

)

select
    *,
    row_number() over (
        partition by currency, rate_date
        order by usd_rate
    ) as dup_rank
from src
