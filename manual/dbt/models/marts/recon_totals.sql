-- DuckDB. README step 5: total discrepancy per provider and the identity
-- total_diff = matched_usd + explained_usd + unexplained_usd, residual is what is left (must be 0).
-- engine_usd / provider_usd are June 2026 money on each side as counted in the pairs; they equal the
-- June revenue computed directly from staging (tested in tests/marts_recon_totals_match_staging_revenue).
-- A 'total' row closes the table.

with per_psp as (

    select
        psp,
        count(*)                                                        as pair_count,
        count(*) filter (where txn_id is not null)                      as engine_rows,
        count(*) filter (where provider_ref is not null)                as provider_rows,
        sum(engine_usd)                                                 as engine_usd,
        sum(provider_usd)                                               as provider_usd,
        sum(diff_usd)                                                   as total_diff,
        sum(diff_usd) filter (where cause_bucket = 'matched')           as matched_usd,
        sum(diff_usd) filter (where cause_bucket = 'explained')         as explained_usd,
        sum(diff_usd) filter (where cause_bucket = 'unexplained')       as unexplained_usd
    from {{ ref('recon_pairs') }}
    group by 1

),

with_total as (

    select * from per_psp
    union all
    select
        'total', sum(pair_count), sum(engine_rows), sum(provider_rows),
        sum(engine_usd), sum(provider_usd), sum(total_diff),
        sum(matched_usd), sum(explained_usd), sum(unexplained_usd)
    from per_psp

)

select
    psp,
    pair_count,
    engine_rows,
    provider_rows,
    engine_usd,
    provider_usd,
    total_diff,
    coalesce(matched_usd, 0)                                            as matched_usd,
    coalesce(explained_usd, 0)                                          as explained_usd,
    coalesce(unexplained_usd, 0)                                        as unexplained_usd,
    total_diff - coalesce(matched_usd, 0) - coalesce(explained_usd, 0)
               - coalesce(unexplained_usd, 0)                           as residual
from with_total
order by case when psp = 'total' then 1 else 0 end, psp
