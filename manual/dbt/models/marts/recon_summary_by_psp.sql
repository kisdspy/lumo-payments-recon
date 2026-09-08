-- DuckDB. recon_summary collapsed to one row per provider plus a total row, no causes.
-- row_count = all pairs; discrepancy_rows = pairs with diff_usd <> 0; abs_usd = sum of |diff_usd|;
-- signed_usd = sum of diff_usd (provider - engine); share_pct = abs_usd share of the total.

with per_psp as (

    select
        psp,
        count(*)                                        as row_count,
        count(*) filter (where diff_usd <> 0)           as discrepancy_rows,
        sum(abs(diff_usd))                              as abs_usd,
        sum(diff_usd)                                   as signed_usd
    from {{ ref('recon_pairs') }}
    group by 1

),

with_total as (

    select * from per_psp
    union all
    select 'total', sum(row_count), sum(discrepancy_rows), sum(abs_usd), sum(signed_usd)
    from per_psp

)

select
    psp,
    row_count,
    discrepancy_rows,
    abs_usd,
    signed_usd,
    round(100 * abs_usd / nullif((select sum(abs_usd) from per_psp), 0), 2) as share_pct
from with_total
order by case when psp = 'total' then 1 else 0 end, abs_usd desc
