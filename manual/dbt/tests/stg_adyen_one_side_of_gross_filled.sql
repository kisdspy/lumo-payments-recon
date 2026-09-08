-- DuckDB. Exactly one of gross_debit / gross_credit must be filled on every Adyen row,
-- otherwise signed_gross is wrong. Error: this is the sign convention the whole recon rests on.
select psp_reference, record_type, gross_debit, gross_credit
from {{ ref('stg_adyen_payment_accounting') }}
where (gross_debit is null) = (gross_credit is null)
