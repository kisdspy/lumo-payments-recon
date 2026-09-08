-- DuckDB. June 2026 revenue per provider: as the engine has it, as we believe it should be after
-- resolving every discrepancy (engine_corrected), and as the provider reports it. A total row closes it.
-- correction_usd = corrected - engine (what the restatement changes);
-- corrected_minus_provider = the rows where the engine is right and the provider is not.

with per_psp as (

    select
        psp,
        sum(engine_usd)                                                 as engine_usd,
        sum(corrected_usd)                                              as corrected_usd,
        sum(correction_usd)                                             as correction_usd,
        sum(provider_usd)                                               as provider_usd,
        count(*) filter (where correction_usd <> 0)                     as corrected_rows
    from {{ ref('engine_corrected') }}
    group by 1

),

with_total as (

    select psp, engine_usd, corrected_usd, correction_usd, provider_usd,
           corrected_usd - provider_usd as corrected_minus_provider, corrected_rows
    from per_psp
    union all
    select 'total', sum(engine_usd), sum(corrected_usd), sum(correction_usd), sum(provider_usd),
           sum(corrected_usd) - sum(provider_usd), sum(corrected_rows)
    from per_psp

)

select *
from with_total
order by case when psp = 'total' then 1 else 0 end, psp
