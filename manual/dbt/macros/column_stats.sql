{% macro column_stats(models) %}
{% set parts = [] %}
{% for m in models %}
{% set rel = ref(m) %}
{% for c in adapter.get_columns_in_relation(rel) %}
{% set q = adapter.quote(c.name) %}
{% do parts.append(
    "select '" ~ m ~ "' as table_name, '" ~ c.name ~ "' as column_name, "
    ~ "count(*) as rows, "
    ~ "count(distinct " ~ q ~ ") as distinct_exact, "
    ~ "approx_count_distinct(" ~ q ~ ") as distinct_approx, "
    ~ "count(*) filter (where " ~ q ~ " is null) as nulls "
    ~ "from " ~ rel
) %}
{% endfor %}
{% endfor %}
{{ parts | join('\nunion all\n') }}
order by 1, 2
{% endmacro %}