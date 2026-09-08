-- DuckDB. Adyen payment accounting report with types applied. One row per export line,
-- i.e. one row per event, not per payment: a payment is Authorised -> Settled, optionally
-- followed by Refunded or Chargeback; a declined attempt is a single Refused row.
-- Nothing is collapsed here, intermediate picks the rows it needs by record_type.
-- Amounts come unsigned in a debit/credit pair, exactly one is filled: Gross Credit on
-- Authorised / Settled / Refused, Gross Debit on Refunded / Chargeback. signed_gross follows
-- the engine convention: credit positive, debit negative. Commission, Markup and Net Credit
-- exist only on Settled rows; fee = commission + markup.
-- Creation Date is local Europe/Amsterdam (TimeZone column), converted to UTC here.
-- Refund and Chargeback rows reuse the Psp Reference of the original payment.

with src as (

    select
        "Company Account"                                   as company_account,
        "Merchant Account"                                  as merchant_account,
        "Psp Reference"                                     as psp_reference,
        "Merchant Reference"                                as merchant_reference,
        "Record Type"                                       as record_type,
        timezone('UTC', timezone("TimeZone", "Creation Date"::timestamp))
                                                            as event_at_utc,
        "Creation Date"::timestamp                          as event_at_local,
        "TimeZone"                                          as time_zone,
        "Gross Currency"                                    as currency,
        "Gross Debit"::decimal(18, 2)                       as gross_debit,
        "Gross Credit"::decimal(18, 2)                      as gross_credit,
        "Commission"::decimal(18, 2)                        as commission,
        "Markup"::decimal(18, 2)                            as markup,
        "Net Currency"                                      as net_currency,
        "Net Debit"::decimal(18, 2)                         as net_debit,
        "Net Credit"::decimal(18, 2)                        as net_credit,
        "Batch Number"::integer                             as batch_number
    from {{ ref('raw_adyen_payment_accounting') }}

),

signed as (

    select
        *,
        coalesce(gross_credit, 0) - coalesce(gross_debit, 0)    as signed_gross,
        coalesce(commission, 0) + coalesce(markup, 0)           as fee
    from src

)

select
    *,
    row_number() over (
        partition by psp_reference, record_type
        order by event_at_utc
    ) as dup_rank
from signed
