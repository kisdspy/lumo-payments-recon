-- DuckDB. PayPal EU account activity with types applied. One row per export line.
-- Same layout as PayPal US, three differences: decimal comma in amounts, day-first dates
-- (DD/MM/YYYY), currencies EUR and GBP with no USD column. No duplicates in this export,
-- dup_rank is kept for symmetry with paypal_us so intermediate can treat both alike.
-- Sign convention is PayPal's: refunds and reversals negative in gross, fee <= 0, net = gross + fee.

with src as (

    select
        "Transaction ID"                                        as transaction_id,
        "Reference Txn ID"                                      as reference_txn_id,
        "Invoice ID"                                            as invoice_id,
        "Type"                                                  as txn_type,
        "Status"                                                as status,
        "Currency"                                              as currency,
        -- amounts come as '-59,99'; no thousands separator in this export (max length 6)
        replace("Gross", ',', '.')::decimal(18, 2)              as gross,
        replace("Fee",   ',', '.')::decimal(18, 2)              as fee,
        replace("Net",   ',', '.')::decimal(18, 2)              as net,
        -- Date is DD/MM/YYYY (30/06/2026), Time is HH:MM:SS, Time Zone is always GMT
        strptime("Date" || ' ' || "Time", '%d/%m/%Y %H:%M:%S')  as txn_at_utc,
        "Time Zone"                                             as time_zone,
        "Name"                                                  as customer_name
    from {{ ref('raw_paypal_eu_activity') }}

)

select
    *,
    row_number() over (
        partition by transaction_id
        order by transaction_id
    ) as dup_rank
from src
