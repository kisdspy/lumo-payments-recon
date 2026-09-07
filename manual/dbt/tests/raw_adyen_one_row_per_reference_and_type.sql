-- Adyen: a payment must not carry two accounting rows of the same Record Type.
select "Psp Reference", "Record Type", count(*) as n
from {{ ref('raw_adyen_payment_accounting') }}
group by 1, 2
having count(*) > 1
