{{ value_counts({
    'raw_payment_engine_log': ['operation_type', 'status', 'psp', 'sku', 'currency', 'country'],
    'raw_adyen_payment_accounting': ['Record Type', 'Merchant Account', 'Gross Currency', 'Net Currency', 'Batch Number'],
    'raw_dlocal_transactions': ['transaction_type', 'status', 'country', 'currency', 'currency_exponent'],
    'raw_paypal_us_activity': ['Type', 'Status', 'Currency'],
    'raw_paypal_eu_activity': ['Type', 'Status', 'Currency'],
    'raw_google_play_earnings_202606': ['Transaction Type', 'Product ID', 'Buyer Country', 'Buyer Currency', 'Merchant Currency'],
    'raw_google_play_earnings_202607_partial': ['Transaction Type', 'Product ID', 'Buyer Country', 'Buyer Currency'],
    'raw_fx_rates': ['currency'],
    'raw_fee_schedule': ['psp', 'account', 'percent_fee']
}) }}
