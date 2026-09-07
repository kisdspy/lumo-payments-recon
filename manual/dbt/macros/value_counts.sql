{% macro value_counts(spec) %}
{% set parts = [] %}
{% for m, cols in spec.items() %}
{% for col in cols %}
{% do parts.append(
    "select '" ~ m ~ "' as table_name, '" ~ col ~ "' as field, "
    ~ adapter.quote(col) ~ " as value, count(*) as n from " ~ ref(m) ~ " group by 3"
) %}
{% endfor %}
{% endfor %}
{{ parts | join('\nunion all\n') }}
order by 1, 2, 4 desc
{% endmacro %}