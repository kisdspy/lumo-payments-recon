-- DuckDB. The time + product + type key must not fan out: one pair per engine row.
select txn_id, count(*) as n
from {{ ref('int_recon_google_play') }}
where txn_id is not null
group by 1
having count(*) > 1
