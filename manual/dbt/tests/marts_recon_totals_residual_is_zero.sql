-- DuckDB. README identity: matched + explained + unexplained = total discrepancy, per provider and in total.
select psp, total_diff, matched_usd, explained_usd, unexplained_usd, residual
from {{ ref('recon_totals') }}
where residual <> 0
