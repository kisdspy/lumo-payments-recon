-- DuckDB. Contracted fees with types applied. One row per provider account that has a contract.
select
    psp,
    account,
    valid_from::date                    as valid_from,
    percent_fee::decimal(9, 4)          as percent_fee,
    fixed_fee::decimal(18, 2)           as fixed_fee,
    fixed_fee_currency
from {{ ref('raw_fee_schedule') }}
