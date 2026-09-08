-- DuckDB. A pair classified as matched must have no money difference.
select txn_id, provider_at, product_id, cause, engine_usd, provider_usd, diff_usd
from {{ ref('int_recon_google_play') }}
where cause = 'matched'
  and diff_usd <> 0
