# raw/

Input data for the reconciliation. The files are not committed; put them here with exactly
these names, the dbt sources in `manual/dbt/models/raw/sources.yml` read them by path.

| File | What it is | Format |
|---|---|---|
| `payment_engine_log.csv` | Payment engine log, all providers, internal source of truth | comma, UTF-8 |
| `paypal_us_activity_20260601_20260703.csv` | PayPal US account activity export | comma, UTF-8 |
| `paypal_eu_activity_20260601_20260703.csv` | PayPal EU account activity export | semicolon, cp1252 |
| `adyen_payment_accounting_20260601_20260703.csv` | Adyen payment accounting report | comma, UTF-8 |
| `dlocal_transactions_20260601_20260703.csv` | dLocal transactions export | comma, UTF-8 |
| `google_play_earnings_202606.csv` | Google Play earnings report, June | comma, UTF-8; line 1 is a report header |
| `google_play_earnings_202607_partial.csv` | Google Play earnings report, July 1–3 | same as above |
| `fx_rates.csv` | Daily FX rates, `usd_rate` = USD per 1 unit of currency | comma, UTF-8 |
| `fee_schedule.csv` | Contracted provider fees | comma, UTF-8 |

Everything in this folder except this file is ignored by git.
