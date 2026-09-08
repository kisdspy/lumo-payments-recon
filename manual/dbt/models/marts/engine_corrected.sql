-- DuckDB. Engine money for June 2026 with every classified discrepancy resolved: one row per pair
-- from recon_pairs, corrected_usd is the figure we believe, chosen per cause from one of the two sides.
-- Rule table (assumption, stated in the note):
--   engine wins   : matched, matched_declined, period_cutoff (money moved in June, provider settled
--                   it later), duplicate_row_in_export (second export line is not money),
--                   provider_date_format (sale was in June, the export date is broken),
--                   provider_fx_rate (engine follows the reference table, provider its own rate).
--   provider wins : engine_fx_rate_error (rate 1 in the engine), engine_fx_date_error and fx_date_lag
--                   (provider valued at the rate of the transaction date), missing_in_engine
--                   (chargebacks / refunds / a payment the engine never saw), missing_at_provider
--                   (a settled sale with no trace at the provider -> 0), status_mismatch (pending that
--                   completed -> money; Refused / IN_MEDIATION -> 0), amount_mismatch (provider's
--                   captured / refunded amount).
-- correction_usd = corrected_usd - engine_usd. Sum over a provider is the restatement of its June revenue.

with rules as (

    select
        cause,
        case
            when cause in ('matched', 'matched_declined', 'period_cutoff', 'duplicate_row_in_export',
                           'provider_date_format', 'provider_fx_rate')      then 'engine'
            else 'provider'
        end as corrected_from
    from (select distinct cause from {{ ref('recon_pairs') }})

)

select
    p.psp,
    p.txn_id,
    p.order_id,
    p.operation_type,
    p.provider_ref,
    p.currency,
    p.cause,
    r.corrected_from,
    p.engine_usd,
    p.provider_usd,
    case r.corrected_from when 'engine' then p.engine_usd else p.provider_usd end  as corrected_usd,
    case r.corrected_from when 'engine' then p.engine_usd else p.provider_usd end
        - p.engine_usd                                                            as correction_usd
from {{ ref('recon_pairs') }} p
join rules r using (cause)
