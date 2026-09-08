-- DuckDB. share_pct over all rows must add up to 100 (within rounding).
select sum(share_pct) as total_share
from {{ ref('recon_summary') }}
having abs(sum(share_pct) - 100) > 0.05
