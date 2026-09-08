-- DuckDB. On Settled rows net_credit must equal gross_credit - commission - markup.
-- warn only: a break here is a finding about the report, not a reason to stop the build.
{{ config(severity = 'warn') }}
select psp_reference, gross_credit, commission, markup, net_credit,
       gross_credit - commission - markup - net_credit as gap
from {{ ref('stg_adyen_payment_accounting') }}
where record_type = 'Settled'
  and gross_credit - commission - markup <> net_credit
