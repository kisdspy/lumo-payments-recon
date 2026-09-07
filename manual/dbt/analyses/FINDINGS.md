# Raw layer findings

Profile run 2026-09-06 on raw.* (tables: analysis.profile_summary, profile_values,
profile_duplicates; CSV copies in out/analysis/). Tests derived from these findings
live in models/raw/schema.yml and tests/.

## 1. Row counts and keys (profile_summary)
❯ что в FINDINGS.md написать?

Содержимое models/analysis/FINDINGS.md. Структура: одна дата, три раздела по трём профильным моделям, в каждом факты, выводы и что из них уже сделано или отложено.

# Raw layer findings

Profile run 2026-09-06 on raw.* (tables: analysis.profile_summary, profile_values,
profile_duplicates; CSV copies in out/analysis/). Tests de
live in models/raw/schema.yml and tests/.

## 1. Row counts and keys (profile_summary)

| table | rows | key | distinct | note |
|---|---|---|---|---|
| raw_payment_engine_log | 7988 | txn_id | 7988 | primary key |
| raw_adyen_payment_accounting | 3413 | Psp Reference + Record Type | 3413 | 1756 payments, several rows each |
| raw_dlocal_transactions | 1319 | transaction_id | 1318 | 1 duplicate row |
| raw_paypal_us_activity | 2167 | Transaction ID | 2166 | 1 duplicate row |
| raw_paypal_eu_activity | 1893 | Transaction ID | 1893 |
| raw_google_play_earnings_202606 | 1544 | none | | no provider id at all |
| raw_google_play_earnings_202607_partial | 78 | none | |
| raw_fx_rates | 204 | rate_date + currency | 203 | 1 duplicate pair |
| raw_fee_schedule | 3 | account | 3 | |

- Engine log: order_id has 7813 distinct values = number of SALE rows. One order per sale;
  all 175 REFUND / CHARGEBACK rows reuse the order of a sa
- Engine log: psp_reference is null in 820 rows = all google_play rows. Unique where present.
- Engine log: captured_at_utc is null in 563 rows = 562 declined + 1 pending.
- Adyen: Psp Reference and Merchant Reference both have 1756 distinct values, 1:1.
- Adyen: exactly one of Gross Debit / Gross Credit is fill credit).
  Commission, Markup, Net Credit are filled only on the 1619 Settled rows.
- PayPal: Reference Txn ID is filled only on refunds / revh of them
  shares Invoice ID with its original payment.
- FX: 29 rate dates over a 40-day window, gaps are weekendSD
  currencies of the engine log are covered.
- approx_count_distinct vs exact: the estimate missed the single pending status, one engine
  currency and one FX currency. Exact counts are required

## 2. Value distributions (profile_values)

- All categorical fields are clean closed lists, no case variants, no blanks.
  Lists are encoded as accepted_values tests.
- Engine log: SALE 7813, REFUND 173, CHARGEBACK 2; settled 7425, declined 562, pending 1.
  Amounts are positive for every operation type, sign must
- Adyen: Authorised 1619 = Settled 1619, Refused 137, Refunded 35, Chargeback 3.
  LumoECOM_EU carries EUR + GBP, LumoAPP_US carries USD. Brope/Amsterdam.
- dLocal: PAYMENT 1296 = PAID 1184 + REJECTED 111 + IN_MEDIATION 1; REFUND 23 = REFUNDED 23.
  Status REFUNDED sits on the refund row, not on the original payment.
  currency_exponent 0 only for CLP (153 rows).
- PayPal US: Website Payment 2110 = Completed 1942 + Denied 168; Refund 57. USD only.
- PayPal EU: Website Payment 1851 = Completed 1704 + Denied 147; Refund 41; Payment Reversal 1
  (status Reversed). EUR + GBP. Dates are DD/MM/YYYY, US file is MM/DD/YYYY.
- Google Play: Charge 767 = Google fee 767 in June, i.e. te.
  Charge refund 10 in June, 8 in the July tail. Merchant currency always USD.
- Row counts per PSP in the engine log vs exports: paypal_1891 / 1893,
  dlocal 1319 / 1319. Adyen and Google Play are not 1:1 by construction.
- Chargebacks: providers show 4 (Adyen 3, PayPal EU 1) plu
  the engine log has 2 CHARGEBACK rows. To be resolved at matching.

## 3. Duplicates (profile_duplicates)

- dLocal DL-90001316 and PayPal US DAB2MG8NSYNB3UXDY: full in every
  column. Technical export duplicates. Staging: select distinct. Impact if not removed:
  +7.13 USD dLocal, +9.99 USD PayPal US.
- FX 2026-06-10 BRL: two different rates, 0.185352 published 2026-06-10T16:00Z and 0.190542
  published 2026-06-12T09:00Z. A back-dated revision, 2.8 % apart. Staging keeps the earliest
  publication per (date, currency), since that is what the the day;
  the later value is kept in a separate column for comparison.
- Tests: unique on the three keys is severity warn in raw,edup.

## Open items for later stages

- Staging: sign amounts by operation_type; parse PayPal dates per file; Adyen timestamps
  Europe/Amsterdam -> UTC; Google Play America/Los_Angelesnt /
  10^currency_exponent; PayPal EU decimal comma.
- Deep dive: TXN-107960 pending in the engine, Completed 24.99 USD on the PayPal side.
- Deep dive: fx_date_applied lags created_at by 0..14 days in 1508 rows; amount_usd arithmetic
  itself is exact (0 mismatches).
- Deep dive: chargeback count mismatch between providers a
- Note: Google Play has no provider id, matching by time / product / country / amount is the
  weakest link.
- Note: no fee schedule for PayPal and dLocal, contract fees cannot be verified for them.