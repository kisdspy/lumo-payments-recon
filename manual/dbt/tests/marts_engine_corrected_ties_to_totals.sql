-- DuckDB. Restatement must tie to recon_totals per provider:
--   corrected = engine + correction, and (corrected - provider) = sum of diff_usd on engine-wins causes
--   with the sign flipped (the provider is "wrong" by exactly those rows).
with engine_wins as (
    select psp, -sum(provider_usd - engine_usd) as engine_right_gap
    from {{ ref('engine_corrected') }}
    where corrected_from = 'engine'
    group by 1
)
select r.psp, r.engine_usd, r.corrected_usd, r.correction_usd, r.provider_usd, r.corrected_minus_provider, w.engine_right_gap
from {{ ref('revenue_corrected_by_psp') }} r
left join engine_wins w using (psp)
where r.psp <> 'total'
  and (r.corrected_usd <> r.engine_usd + r.correction_usd
       or r.corrected_minus_provider <> coalesce(w.engine_right_gap, 0))
