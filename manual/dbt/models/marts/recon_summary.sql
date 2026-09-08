-- DuckDB. README step 3: discrepancy summary at provider x cause grain for June 2026.
-- row_count = pairs with this cause; abs_usd = sum of |diff_usd|; signed_usd = sum of diff_usd
-- (provider - engine, positive = provider shows more); share_pct = abs_usd as a share of the total
-- absolute discrepancy across all providers; share_in_psp_pct = the same within the provider.
-- matched rows are listed too (0 USD) so the row counts reconcile to the full pair population.

with by_cause as (

    select
        psp,
        cause_bucket,
        cause,
        count(*)                                as row_count,
        sum(abs(diff_usd))                      as abs_usd,
        sum(diff_usd)                           as signed_usd
    from {{ ref('recon_pairs') }}
    group by 1, 2, 3

)

select
    psp,
    cause_bucket,
    cause,
    row_count,
    abs_usd,
    signed_usd,
    round(100 * abs_usd / nullif(sum(abs_usd) over (), 0), 2)                  as share_pct,
    round(100 * abs_usd / nullif(sum(abs_usd) over (partition by psp), 0), 2)  as share_in_psp_pct
from by_cause
order by psp, abs_usd desc, cause
