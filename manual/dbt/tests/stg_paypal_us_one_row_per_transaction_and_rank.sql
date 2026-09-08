-- DuckDB. transaction_id + dup_rank must be unique in stg_paypal_us_activity.
select transaction_id, dup_rank, count(*) as n
from {{ ref('stg_paypal_us_activity') }}
group by 1, 2
having count(*) > 1
