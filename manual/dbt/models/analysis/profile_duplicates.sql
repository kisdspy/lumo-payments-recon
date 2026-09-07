select 'raw_dlocal_transactions' as table_name, transaction_id as key, count(*) as n
from {{ ref('raw_dlocal_transactions') }} group by 2 having count(*) > 1
union all
select 'raw_paypal_us_activity', "Transaction ID", count(*)
from {{ ref('raw_paypal_us_activity') }} group by 2 having count(*) > 1
union all
select 'raw_fx_rates', rate_date || ' ' || currency, count(*)
from {{ ref('raw_fx_rates') }} group by 2 having count(*) > 1