# Payments reconciliation, June 2026

Monthly reconciliation of a payment engine log against the exports of five payment providers
(PayPal US, PayPal EU, dLocal, Adyen, Google Play). Every dollar of difference between the
engine and the providers is matched, explained by root cause, or reported as unexplained, and
the three parts must add up to the total discrepancy with a zero residual.

Built as a dbt project on DuckDB. The final report is `manual/Payments reconciliation.pdf`.

## Result

| provider | engine USD | provider USD | difference | explained | unexplained |
|---|---:|---:|---:|---:|---:|
| paypal_us | 36 046.31 | 36 081.29 | +34.98 | +34.98 | 0 |
| paypal_eu | 36 323.01 | 36 197.37 | −125.64 | −125.64 | 0 |
| dlocal | 215 642.53 | 14 949.48 | −200 693.05 | −200 693.05 | 0 |
| adyen | 32 912.09 | 32 796.14 | −115.95 | −115.95 | 0 |
| google_play | 14 744.63 | 14 744.63 | 0 | 0 | 0 |
| **total** | **335 668.57** | **134 768.91** | **−200 899.66** | **−200 899.66** | **0** |

All 7 719 engine/provider pairs are classified, nothing is left unexplained. Almost the whole gap
is one engine bug: three dLocal transactions were converted to USD with an FX rate of 1. The
remaining causes are duplicated rows in exports, a day/month date swap in the PayPal EU file,
payout-batch timing at the month boundary, FX date lag, status and amount mismatches, and a
handful of refunds and chargebacks the engine never saw.

## Layout

```
manual/
  dbt/
    models/raw/            one model per source CSV, every column as text, no transformation
    models/analysis/       profiling: row counts, keys, value distributions, duplicates
    models/staging/        typed and normalised: UTC timestamps, minor units, signed amounts
    models/intermediate/   int_recon_<provider>: engine <-> provider matching and root cause
    models/marts/          recon_pairs, recon_summary, recon_totals, fee_summary, engine_corrected
    tests/                 reconciliation identity, one-to-one matching, staging invariants
    analyses/              written findings from the raw layer and the corrected-revenue mart
    run.sh                 build, refresh the read-only DB copy, export marts to CSV
  eda/                     Jupyter notebooks used to explore raw and staging tables
  out/                     TSV exports of the summary and totals tables
  Payments reconciliation.pdf   final report
  requirements.txt         pinned Python dependencies
```

Pipeline: `raw` → `staging` → `intermediate` → `marts`, all in DuckDB via dbt-duckdb.
Tests (356 schema and singular tests) guard the source keys, the staging
arithmetic, one engine row per provider row, and the identity
`total_diff = matched + explained + unexplained` for every provider.

## How to run

Requirements: Python 3.12, [uv](https://github.com/astral-sh/uv), the DuckDB CLI.

```
cd manual/dbt
./run.sh              # creates ../.venv on first run, then dbt run
./run.sh build        # models + tests
./run.sh test
```

The database is written to `manual/recon_dbt.duckdb`. The script also refreshes a copy in
`manual/view/` for SQL clients and exports every table in `analysis` and `marts` to
`manual/out/<schema>/*.csv`.

## Data

The source CSVs (engine log, provider exports, FX rates, fee schedule) are not part of this
repository. The models expect them under `raw/` at the repository root, with the file names
listed in `manual/dbt/models/raw/sources.yml`.

Reporting period is June 2026; the exports intentionally cover a few days on either side of the
month boundary, and the cut-off is handled in the staging and intermediate layers.

## Dialect

All SQL is DuckDB.
