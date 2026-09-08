-- DuckDB. PayPal US account activity with types applied. One row per export line.
-- Nothing is dropped: the one fully identical duplicate line is kept and marked with
-- dup_rank = 2, so it can be classified and priced as a discrepancy downstream.
-- Sign convention is PayPal's and matches signed_amount_usd in the log:
-- refunds are negative in gross, fee is always <= 0, net = gross + fee.

with src as (

    select
        "Transaction ID"                                        as transaction_id,
        "Reference Txn ID"                                      as reference_txn_id,
        "Invoice ID"                                            as invoice_id,
        "Type"                                                  as txn_type,
        "Status"                                                as status,
        "Currency"                                              as currency,
        "Gross"::decimal(18, 2)                                 as gross,
        "Fee"::decimal(18, 2)                                   as fee,
        "Net"::decimal(18, 2)                                   as net,
        -- Date is MM/DD/YYYY, Time is HH:MM:SS, Time Zone is always GMT, so the result is UTC
        strptime("Date" || ' ' || "Time", '%m/%d/%Y %H:%M:%S')  as txn_at_utc,
        "Time Zone"                                             as time_zone,
        "Name"                                                  as customer_name
    from {{ ref('raw_paypal_us_activity') }}

)

select
    *,
    row_number() over (
        partition by transaction_id
        order by transaction_id
    ) as dup_rank
from src
