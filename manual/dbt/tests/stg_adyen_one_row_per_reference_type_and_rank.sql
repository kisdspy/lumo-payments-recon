-- DuckDB. psp_reference + record_type + dup_rank must be unique in stg_adyen_payment_accounting.
select psp_reference, record_type, dup_rank, count(*) as n
from {{ ref('stg_adyen_payment_accounting') }}
group by 1, 2, 3
having count(*) > 1
