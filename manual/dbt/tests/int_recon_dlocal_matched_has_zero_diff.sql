-- DuckDB. A pair classified as matched or matched_declined must have no money difference.
select txn_id, transaction_id, cause, engine_usd, provider_usd, diff_usd
from {{ ref('int_recon_dlocal') }}
where cause in ('matched', 'matched_declined')
  and diff_usd <> 0
