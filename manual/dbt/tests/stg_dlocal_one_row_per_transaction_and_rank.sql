-- DuckDB. transaction_id + dup_rank must be unique in stg_dlocal_transactions.
select transaction_id, dup_rank, count(*) as n
from {{ ref('stg_dlocal_transactions') }}
group by 1, 2
having count(*) > 1
