-- DuckDB. The reversal key order_id + type must not fan out: one engine row per pair_key,
-- one provider event per pair_key, else diff_usd double counts.
select txn_id, count(*) as n
from {{ ref('int_recon_adyen') }}
where txn_id is not null
group by 1
having count(*) > 1
