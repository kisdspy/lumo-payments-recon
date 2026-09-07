cd /Users/ik/Vscode/simple_life/manual
duckdb recon.duckdb

SET TimeZone = 'UTC';
DESCRIBE SELECT * FROM read_csv('../raw/payment_engine_log.csv', all_varchar = true);

CREATE TABLE raw_payment_engine_log AS
SELECT * FROM read_csv('../raw/payment_engine_log.csv', all_varchar = true);

DESCRIBE SELECT * FROM read_csv('../raw/adyen_payment_accounting_20260601_20260703.csv', all_varchar = true);
CREATE TABLE raw_adyen_payment_accounting AS
SELECT * FROM read_csv('../raw/adyen_payment_accounting_20260601_20260703.csv', all_varchar = true);

DESCRIBE SELECT * FROM read_csv('../raw/dlocal_transactions_20260601_20260703.csv', all_varchar = true);
CREATE TABLE raw_dlocal_transactions AS
SELECT * FROM read_csv('../raw/dlocal_transactions_20260601_20260703.csv', all_varchar = true);

DESCRIBE SELECT * FROM read_csv('../raw/paypal_us_activity_20260601_20260703.csv', all_varchar = true);
CREATE TABLE raw_paypal_us_activity AS
SELECT * FROM read_csv('../raw/paypal_us_activity_20260601_20260703.csv', all_varchar = true);

DESCRIBE SELECT * FROM read_csv('../raw/paypal_eu_activity_20260601_20260703.csv',
    all_varchar = true, delim = ';', encoding = 'cp1252');
CREATE TABLE raw_paypal_eu_activity AS
SELECT * FROM read_csv('../raw/paypal_eu_activity_20260601_20260703.csv',
    all_varchar = true, delim = ';', encoding = 'cp1252');

DESCRIBE SELECT * FROM read_csv('../raw/google_play_earnings_202606.csv',
    all_varchar = true, skip = 1, strict_mode = false);
CREATE TABLE raw_google_play_earnings_202606 AS
SELECT * FROM read_csv('../raw/google_play_earnings_202606.csv',
    all_varchar = true, skip = 1, strict_mode = false);

DESCRIBE SELECT * FROM read_csv('../raw/google_play_earnings_202607_partial.csv',
    all_varchar = true, skip = 1, strict_mode = false);
CREATE TABLE raw_google_play_earnings_202607_partial AS
SELECT * FROM read_csv('../raw/google_play_earnings_202607_partial.csv',
    all_varchar = true, skip = 1, strict_mode = false);

DESCRIBE SELECT * FROM read_csv('../raw/fx_rates.csv', all_varchar = true);
CREATE TABLE raw_fx_rates AS
SELECT * FROM read_csv('../raw/fx_rates.csv', all_varchar = true);

DESCRIBE SELECT * FROM read_csv('../raw/fee_schedule.csv', all_varchar = true);
CREATE TABLE raw_fee_schedule AS
SELECT * FROM read_csv('../raw/fee_schedule.csv', all_varchar = true);

SELECT table_name, estimated_size AS rows
FROM duckdb_tables()
WHERE NOT internal
ORDER BY table_name;

CHECKPOINT;
.quit

cp recon.duckdb backups/01_raw.duckdb

brew install --cask dbeaver-community
source .venv/bin/activate
uv pip install dbt-core==1.12.3 dbt-duckdb==1.11.0 duckdb==1.5.5

cd dbt
export DBT_PROFILES_DIR=.
dbt debug

find . -name '*.yml' -o -name '*.sql' | grep -v target

dbt run --select raw_payment_engine_log
duckdb ../recon_dbt.duckdb "SELECT column_name, comment FROM duckdb_columns() WHERE table_name = 'raw_payment_engine_log' ORDER BY column_index"


chmod +x run.sh 
./run.sh 

SELECT * FROM analysis.profile_summary ORDER BY table_name, column_name;

SELECT * FROM raw.raw_dlocal_transactions WHERE transaction_id = 'DL-90001316';
SELECT * FROM raw.raw_paypal_us_activity WHERE "Transaction ID" = 'DAB2MG8NSYNB3UXDY';
SELECT * FROM raw.raw_fx_rates WHERE rate_date = '2026-06-10' AND currency = 'BRL';

mv ../.venv ../.venv_old

cd /Users/ik/Vscode/simple_life
git init
git add .gitignore raw manual