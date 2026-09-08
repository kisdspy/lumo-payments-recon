-- DuckDB. txn_at_utc + product_id + txn_type + dup_rank must be unique in stg_google_play_earnings.
select txn_at_utc, product_id, txn_type, dup_rank, count(*) as n
from {{ ref('stg_google_play_earnings') }}
group by 1, 2, 3, 4
having count(*) > 1
