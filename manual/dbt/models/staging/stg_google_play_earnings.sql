-- DuckDB. Google Play earnings report with types applied, June file and the partial July file
-- stacked into one view (source_file tells them apart). One row per report line.
-- Three line types stay as they are: Charge (the sale), Google fee (its commission, a separate line
-- with the same time and product), Charge refund (a refund, own time). No declined attempts exist
-- in this report. Amounts are already signed by Google: Charge positive, fee and refund negative.
-- There is no provider id and no order id. The only handle is time + product, so dup_rank is
-- ranked over txn_at_utc + product_id + txn_type.
-- Transaction Date is 'Jun 1, 2026', Transaction Time is HH:MM:SS, both America/Los_Angeles
-- (report banner), converted to UTC here. Merchant currency is always USD; amount_usd is Google's
-- own conversion at conversion_rate (USD per unit of buyer currency).

with src as (

    select 'google_play_earnings_202606' as source_file, *
    from {{ ref('raw_google_play_earnings_202606') }}
    union all
    select 'google_play_earnings_202607_partial' as source_file, *
    from {{ ref('raw_google_play_earnings_202607_partial') }}

),

typed as (

    select
        source_file,
        "Transaction Type"                                      as txn_type,
        "Product ID"                                            as product_id,
        "Buyer Country"                                         as buyer_country,
        "Buyer Currency"                                        as buyer_currency,
        "Amount (Buyer Currency)"::decimal(18, 2)               as amount_buyer,
        "Currency Conversion Rate"::decimal(18, 6)              as conversion_rate,
        "Merchant Currency"                                     as merchant_currency,
        "Amount (Merchant Currency)"::decimal(18, 2)            as amount_usd,
        strptime("Transaction Date" || ' ' || "Transaction Time", '%b %d, %Y %H:%M:%S')
                                                                as txn_at_local,
        timezone('UTC', timezone('America/Los_Angeles',
            strptime("Transaction Date" || ' ' || "Transaction Time", '%b %d, %Y %H:%M:%S')))
                                                                as txn_at_utc
    from src

)

select
    *,
    row_number() over (
        partition by txn_at_utc, product_id, txn_type
        order by amount_usd
    ) as dup_rank
from typed
